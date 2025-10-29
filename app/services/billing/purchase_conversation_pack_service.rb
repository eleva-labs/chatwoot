# frozen_string_literal: true

# Service to purchase one-time conversation packs
# Creates immediate invoice for extra conversations
class Billing::PurchaseConversationPackService
  include BillingPlans

  def initialize(account)
    @account = account
    @plan_name = account.custom_attributes&.dig('plan_name') || 'free_trial'
    @plan_config = plan_details(@plan_name)
  end

  def perform
    # Validate pack is available for this plan
    return failure_response('Conversation packs not available for this plan') unless pack_available?

    # Get pack configuration
    pack_config = @plan_config.dig('conversation_packs')
    return failure_response('Pack configuration not found') unless pack_config

    # Fetch price from Stripe
    lookup_key = pack_config['lookup_key']
    price = fetch_price_from_stripe(lookup_key)
    return failure_response("Price not found in Stripe for lookup_key: #{lookup_key}") unless price

    # Get customer ID
    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return failure_response('No Stripe customer found for this account') unless customer_id

    # Create one-time invoice item
    invoice_item = ::Stripe::InvoiceItem.create(
      customer: customer_id,
      price: price.id,
      description: "#{format_number(pack_config['conversations'])} Conversation Pack"
    )

    # Create and finalize invoice
    invoice = ::Stripe::Invoice.create(
      customer: customer_id,
      auto_advance: true, # Automatically finalize and attempt payment
      description: "Conversation Pack Purchase"
    )

    # Update account with extra conversations
    current_extra = @account.custom_attributes&.dig('extra_conversations_purchased')&.to_i || 0
    attrs = @account.custom_attributes || {}
    attrs['extra_conversations_purchased'] = current_extra + pack_config['conversations']
    @account.custom_attributes = attrs
    @account.save!

    Rails.logger.info "Conversation pack purchased for account #{@account.id}: #{pack_config['conversations']} conversations"

    success_response(
      'Conversation pack purchased successfully',
      conversations_added: pack_config['conversations'],
      new_total: current_extra + pack_config['conversations'],
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
    failure_response("Invalid request: #{e.message}")
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Stripe error purchasing conversation pack: #{e.message}"
    failure_response("Purchase failed: #{e.message}")
  rescue StandardError => e
    Rails.logger.error "Error purchasing conversation pack: #{e.message}"
    failure_response("Purchase failed: #{e.message}")
  end

  private

  def pack_available?
    # Not available for free trial, community, or enterprise
    return false if %w[free_trial community enterprise].include?(@plan_name)

    # Check if plan has conversation pack configuration
    @plan_config&.dig('conversation_packs').present?
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

