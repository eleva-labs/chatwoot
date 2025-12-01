# frozen_string_literal: true

module Billing
  # Service to create Stripe Checkout Sessions for all subscription plans
  # This ensures payment methods are always collected before charging customers
  # and provides a better UX by redirecting users to Stripe's hosted checkout
  class CreateCheckoutSessionService
    include BillingPlans

    def initialize(account, plan_name = nil, billing_interval = 'monthly')
      @account = account
      @plan_name = plan_name || self.class.default_plan_name
      @billing_interval = billing_interval
      @provider = ProviderFactory.get_provider
    end

    def perform
      return failure_response('Invalid plan') unless self.class.plan_exists?(@plan_name)

      # If the account is trialing on the same plan, use the portal to add payment info
      return portal_response if trialing_same_plan?

      # Allow checkout sessions for plan upgrades/changes, but prevent if already on the same plan
      return failure_response('Account already has this plan') if already_has_current_plan?

      # Validate that we have a valid price ID for paid plans
      price_id = plan_price_id_for_interval(@plan_name, @billing_interval)
      if price_id.blank? || (price_id.start_with?('price_') && !price_id.start_with?('price_1'))
        return failure_response("Price ID not configured for plan '#{@plan_name}' with interval '#{@billing_interval}'. Please configure a valid Stripe price ID.")
      end

      begin
        # Create checkout session:
        # All plans go through subscription mode (creates subscription and collects payment)
        # Subscription finalization is handled via checkout.session.completed webhook
        checkout_session = create_checkout_session

        success_response(
          checkout_url: checkout_session.url,
          session_id: checkout_session.id
        )
      rescue StandardError => e
        Rails.logger.error "Error in CreateCheckoutSessionService: #{e.message}"
        failure_response("Checkout session creation failed: #{e.message}")
      end
    end

    private

    def trialing_same_plan?
      current_plan = @account.custom_attributes&.dig('plan_name')
      subscription_status = @account.custom_attributes&.dig('subscription_status')

      current_plan == @plan_name && subscription_status == Billing::SubscriptionStatuses::TRIALING
    end

    def portal_response
      portal_service = Billing::CreatePortalSessionService.new(@account)
      result = portal_service.perform
      return failure_response(result[:error]) unless result[:success]

      success_response(
        portal_url: result[:data][:session_url],
        session_id: result[:data][:session_id]
      )
    end

    def already_has_current_plan?
      current_plan = @account.custom_attributes&.dig('plan_name')
      subscription_status = @account.custom_attributes&.dig('subscription_status')

      # Allow checkout if no current plan
      return false if current_plan.blank?

      # Allow checkout if subscription status is blank/nil (no subscription exists)
      return false if subscription_status.blank?

      # Allow checkout if trying to switch to a different plan (upgrade/downgrade)
      return false if current_plan != @plan_name

      # Allow checkout if subscription is in a failed/ended state
      # These statuses indicate the subscription is not active and user should be able to reactivate/upgrade
      failed_or_ended_statuses = [
        Billing::SubscriptionStatuses::INACTIVE,
        Billing::SubscriptionStatuses::CANCELED,
        Billing::SubscriptionStatuses::UNPAID,
        Billing::SubscriptionStatuses::PAST_DUE,
        Billing::SubscriptionStatuses::INCOMPLETE_EXPIRED
      ]
      return false if failed_or_ended_statuses.include?(subscription_status)

      # Allow checkout if subscription is incomplete (initial payment failed, user can retry)
      return false if subscription_status == Billing::SubscriptionStatuses::INCOMPLETE

      # Allow checkout if subscription is paused (user can reactivate)
      return false if subscription_status == Billing::SubscriptionStatuses::PAUSED

      # Allow checkout if subscription is trialing (user wants to convert trial to paid)
      # This allows users on trial to add a payment method and convert to paid subscription
      return false if subscription_status == Billing::SubscriptionStatuses::TRIALING

      # Prevent checkout only if they already have this exact plan and it's in an active paid state
      # Active paid state: active (indicates subscription is currently active and paid)
      subscription_status == Billing::SubscriptionStatuses::ACTIVE
    end

    def create_checkout_session
      session_params = {
        success_url: success_url,
        cancel_url: cancel_url,
        allow_promotion_codes: true,
        client_reference_id: @account.id.to_s, # Additional tracking reference
        metadata: {
          account_id: @account.id.to_s, # Store as string per Stripe best practice
          plan_name: @plan_name
        }
      }

      # Use existing customer if available to prevent duplicate customers
      existing_customer_id = @account.custom_attributes&.dig('stripe_customer_id')
      if existing_customer_id.present?
        Rails.logger.info "Using existing Stripe customer for checkout: #{existing_customer_id}"
        session_params[:customer] = existing_customer_id
        # Update customer info if it has changed
        session_params[:customer_update] = { name: 'auto', address: 'auto' }
      else
        Rails.logger.info 'No existing customer found for checkout; Stripe will create one after completion'
        session_params[:customer_email] = @account.users.first&.email
      end

      # Create a subscription checkout for all paid plans
      price_id = plan_price_id_for_interval(@plan_name, @billing_interval)
      session_params[:mode] = 'subscription'
      session_params[:line_items] = [{
        price: price_id,
        quantity: 1
      }]

      # Propagate metadata to the subscription object for reliable account linking
      session_params[:subscription_data] = {
        metadata: {
          account_id: @account.id.to_s, # Store as string per Stripe best practice
          plan_name: @plan_name
        },
        # Enable flexible billing mode for checkout-created subscriptions (Stripe recommended)
        # Provides more accurate proration calculations, improved trial handling,
        # and access to new features like mixed-interval subscriptions
        # See: docs/ignore/ClassicToFlexible.md for details
        billing_mode: {
          type: 'flexible',
          flexible: {
            proration_discounts: 'itemized' # Show accurate discount amounts on invoices
          }
        },
        trial_settings: {
          end_behavior: {
            missing_payment_method: 'cancel' # Cancel subscription if no payment method at trial end
          }
        }
      }

      @provider.create_checkout_session(session_params)
    end

    def success_url
      "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/app/settings/billing?success=true"
    end

    def cancel_url
      "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/app/settings/billing?canceled=true"
    end

    def success_response(data = {})
      {
        success: true,
        data: data
      }
    end

    def failure_response(message)
      {
        success: false,
        error: message
      }
    end

    # Get price ID for a plan with a specific billing interval
    def plan_price_id_for_interval(plan_name, billing_interval)
      # Map frontend interval names to Stripe interval values
      stripe_interval = billing_interval == 'yearly' ? 'year' : 'month'

      # Try to get price from Stripe product metadata first
      plan_data = Billing::Providers::Stripe.get_plan_data_from_stripe(plan_name)
      if plan_data && plan_data[:product_id]
        # Fetch prices for this product and find the one matching the interval
        prices = ::Stripe::Price.list(
          product: plan_data[:product_id],
          active: true,
          limit: 10
        )

        matching_price = prices.data.find do |price|
          price.recurring&.interval == stripe_interval
        end

        if matching_price
          Rails.logger.info "Found price ID for plan '#{plan_name}' with interval '#{billing_interval}': #{matching_price.id}"
          return matching_price.id
        end
      end

      # Fallback to default plan_price_id if interval-specific lookup fails
      Rails.logger.warn "Could not find price for interval '#{billing_interval}', falling back to default price for plan '#{plan_name}'"
      self.class.plan_price_id(plan_name)
    end
  end
end