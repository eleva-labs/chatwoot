# frozen_string_literal: true

module Billing
  # Service to create Stripe Checkout Sessions for all subscription plans
  # This ensures payment methods are always collected before charging customers
  # and provides a better UX by redirecting users to Stripe's hosted checkout
  class CreateCheckoutSessionService
    include BillingPlans

    def initialize(account, plan_name = nil)
      @account = account
      @plan_name = plan_name || self.class.default_plan_name
      @provider = ProviderFactory.get_provider
    end

    def perform
      return failure_response('Invalid plan') unless self.class.plan_exists?(@plan_name)
      # Allow checkout sessions for plan upgrades/changes, but prevent if already on the same plan
      return failure_response('Account already has this plan') if already_has_current_plan?

      # For paid plans, validate that we have a valid price ID
      if @plan_name != 'free_trial'
        price_id = self.class.plan_price_id(@plan_name)
        if price_id.blank? || (price_id.start_with?('price_') && !price_id.start_with?('price_1'))
          return failure_response("Price ID not configured for plan '#{@plan_name}'. Please configure a valid Stripe price ID.")
        end
      end

      begin
        # Create checkout session:
        # - For free_trial: Setup mode (collects payment method without charging)
        # - For paid plans: Subscription mode (creates subscription and collects payment)
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

    def already_has_current_plan?
      current_plan = @account.custom_attributes&.dig('plan_name')
      subscription_status = @account.custom_attributes&.dig('subscription_status')

      # Allow checkout if no current plan or if subscription is inactive
      return false if current_plan.blank? || subscription_status == 'inactive'

      # Prevent checkout only if they already have this exact plan and it's active
      current_plan == @plan_name && subscription_status == 'active'
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

      # For free trial plans, we just collect payment method without charging
      if @plan_name == 'free_trial'
        session_params[:mode] = 'setup'
      else
        # For paid plans, create a subscription checkout
        price_id = self.class.plan_price_id(@plan_name)
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
      end

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
  end
end