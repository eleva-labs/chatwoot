# frozen_string_literal: true

# Service to purchase one-time conversation packs
# Creates immediate invoice for extra conversations
class Billing::PurchaseConversationPackService
  include BillingPlans

  def initialize(account, lookup_key)
    @account = account
    @plan_name = account.custom_attributes&.dig('plan_name') || 'free_trial'
    @lookup_key = lookup_key
    @pack_config = find_pack_config
  end

  def perform
    # Validate pack is available for this plan
    return failure_response('Conversation packs not available for this plan') unless pack_available?

    if @account.custom_attributes&.dig('subscription_status') == 'past_due'
      return failure_response('Your subscription payment is past due. Please update your payment method before purchasing add-ons.')
    end

    # Get pack configuration
    return failure_response('Pack configuration not found') unless @pack_config

    # Fetch price from Stripe
    price = fetch_price_from_stripe(@pack_config['lookup_key'])
    return failure_response("Price not found in Stripe for lookup_key: #{@pack_config['lookup_key']}") unless price

    # Get customer ID
    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return failure_response('No Stripe customer found for this account') unless customer_id

    # NEW: Verify payment method exists before attempting purchase
    unless has_payment_method?(customer_id)
      return failure_response(
        'No payment method on file. Please add a payment method in the billing portal before purchasing.'
      )
    end

    # Create one-time invoice item
    invoice_item = ::Stripe::InvoiceItem.create(
      customer: customer_id,
      pricing: {
        price: price.id
      },
      description: "#{format_number(@pack_config['size'])} Conversation Pack"
    )

    # Create and finalize invoice
    invoice = ::Stripe::Invoice.create(
      customer: customer_id,
      auto_advance: true, # Automatically finalize and attempt payment
      pending_invoice_items_behavior: 'include',
      description: 'Conversation Pack Purchase'
    )

    # Update account with extra conversations
    current_extra = @account.custom_attributes&.dig('extra_conversations_purchased')&.to_i || 0
    attrs = @account.custom_attributes || {}
    attrs['extra_conversations_purchased'] = current_extra + @pack_config['size']
    attrs['conversations_last_reset'] = Time.current.to_i # Track when packs were added (prevents immediate reset)
    @account.custom_attributes = attrs
    @account.save!

    Rails.logger.info "Conversation pack purchased for account #{@account.id}: #{@pack_config['size']} conversations"

    success_response(
      'Conversation pack purchased successfully',
      conversations_added: @pack_config['size'],
      new_total: current_extra + @pack_config['size'],
      invoice_id: invoice.id,
      amount: price.unit_amount,
      currency: price.currency
    )
  rescue ::Stripe::CardError => e
    Rails.logger.error "Card error purchasing conversation pack: #{e.message}"
    failure_response("Payment failed: #{e.user_message}")
  rescue ::Stripe::RateLimitError => e
    Rails.logger.warn "Stripe rate limit hit: #{e.message}"
    failure_response('Rate limited - please try again')
  rescue ::Stripe::InvalidRequestError => e
    Rails.logger.error "Stripe invalid request: #{e.message}"
    # Check for specific "no payment method" errors
    if e.message.include?('no attached payment source') ||
       e.message.include?('no payment method')
      failure_response('No payment method on file. Please add one in the billing portal.')
    else
      failure_response("Invalid request: #{e.message}")
    end
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Stripe error purchasing conversation pack: #{e.message}"
    failure_response("Purchase failed: #{e.message}")
  rescue StandardError => e
    Rails.logger.error "Error purchasing conversation pack: #{e.message}"
    failure_response("Purchase failed: #{e.message}")
  end

  private

  def find_pack_config
    packs = self.class.conversation_packs_catalog
    packs.find { |pack| pack['lookup_key'] == @lookup_key }
  end

  def pack_available?
    return false unless @pack_config.present?

    # Check if plan is eligible
    return false unless self.class.conversation_packs_available_for_plan?(@plan_name)

    true
  end

  # NEW: Check if customer has a payment method on file
  def has_payment_method?(customer_id)
    customer = ::Stripe::Customer.retrieve(customer_id)

    # Check for default payment method (preferred) or default source (legacy)
    customer.invoice_settings&.default_payment_method.present? ||
      customer.default_source.present?
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error checking payment method: #{e.message}"
    false # Fail safely - will be caught during invoice creation
  end

  def fetch_price_from_stripe(lookup_key)
    return nil unless lookup_key

    prices = ::Stripe::Price.list(lookup_keys: [lookup_key], limit: 1)
    prices.data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching price from Stripe: #{e.message}"
    nil
  end

  def format_number(num)
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def success_response(message, data = {})
    {
      success: true,
      message: message
    }.merge(data)
  end

  def failure_response(error)
    {
      success: false,
      error: error
    }
  end
end

