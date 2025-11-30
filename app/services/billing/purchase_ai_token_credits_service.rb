# frozen_string_literal: true

# Service to purchase one-time AI token credit packs
class Billing::PurchaseAiTokenCreditsService
  include BillingPlans

  def initialize(account, lookup_key)
    @account = account
    @lookup_key = lookup_key
    @plan_name = account.custom_attributes&.dig('plan_name') || 'starter'
    @pack_config = find_pack_config
  end

  def perform
    return failure_response('AI token credit packs are not available for this plan') unless packs_available_for_plan?
    return failure_response('Token pack configuration not found') unless @pack_config

    # Use unified service to check if add-ons can be purchased
    purchase_check = Billing::CanPurchaseAddOnsService.new(@account)
    return failure_response(purchase_check.error_message) if purchase_check.blocked?

    store_id = @account.custom_attributes&.dig('store_id')
    return failure_response('AI store ID not found for account') if store_id.blank?

    price = fetch_price_from_stripe(@pack_config['lookup_key'])
    return failure_response("Price not found in Stripe for lookup_key: #{@pack_config['lookup_key']}") unless price

    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return failure_response('No Stripe customer found for this account') unless customer_id

    unless payment_method_available?(customer_id)
      return failure_response(
        'No payment method on file. Please add a payment method in the billing portal before purchasing.'
      )
    end

    preflight_ai_backend!(store_id)

    invoice_item = nil
    invoice = nil

    invoice_item = ::Stripe::InvoiceItem.create(
      customer: customer_id,
      pricing: {
        price: price.id
      },
      description: "#{@pack_config['token_credits']} AI Token Credits Pack"
    )

    invoice = ::Stripe::Invoice.create(
      customer: customer_id,
      auto_advance: true,
      pending_invoice_items_behavior: 'include',
      description: 'AI Token Credits Purchase'
    )

    add_tokens_with_retry(store_id, invoice.id, price)

    Rails.logger.info "AI token credits purchased for account #{@account.id}: #{@pack_config['token_credits']} tokens"

    success_response(
      'AI token credits purchased successfully',
      tokens_added: @pack_config['token_credits'],
      invoice_id: invoice.id,
      amount: price.unit_amount,
      currency: price.currency,
      invoice_item_id: invoice_item.id
    )
  rescue ::Stripe::CardError => e
    Rails.logger.error "Card error purchasing AI token credits: #{e.message}"
    cleanup_stripe_objects(invoice, invoice_item)
    failure_response("Payment failed: #{e.user_message}")
  rescue ::Stripe::RateLimitError => e
    Rails.logger.warn "Stripe rate limit hit: #{e.message}"
    cleanup_stripe_objects(invoice, invoice_item)
    failure_response('Rate limited - please try again')
  rescue ::Stripe::InvalidRequestError => e
    Rails.logger.error "Stripe invalid request purchasing AI token credits: #{e.message}"
    cleanup_stripe_objects(invoice, invoice_item)
    failure_response("Invalid request: #{e.message}")
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Stripe error purchasing AI token credits: #{e.message}"
    cleanup_stripe_objects(invoice, invoice_item)
    failure_response("Purchase failed: #{e.message}")
  rescue Billing::PurchaseAiTokenCreditsService::AiBackendError => e
    Rails.logger.error "AI Backend error purchasing AI token credits: #{e.message}"
    cleanup_stripe_objects(invoice, invoice_item)
    failure_response("Failed to add AI token credits: #{e.message}")
  rescue StandardError => e
    Rails.logger.error "Unexpected error purchasing AI token credits: #{e.message}"
    cleanup_stripe_objects(invoice, invoice_item)
    failure_response("Purchase failed: #{e.message}")
  end

  class AiBackendError < StandardError; end

  private

  def find_pack_config
    BillingPlans.ai_token_packs_catalog.find { |pack| pack['lookup_key'] == @lookup_key }
  end

  def packs_available_for_plan?
    BillingPlans.ai_token_packs_available_for_plan?(@plan_name)
  end

  def fetch_price_from_stripe(lookup_key)
    ::Stripe::Price.list(lookup_keys: [lookup_key], limit: 1).data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching price from Stripe: #{e.message}"
    nil
  end

  def payment_method_available?(customer_id)
    customer = ::Stripe::Customer.retrieve(customer_id)
    customer.invoice_settings&.default_payment_method.present? || customer.default_source.present?
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error checking payment method: #{e.message}"
    false
  end

  def preflight_ai_backend!(store_id)
    token_service = AiBackendService::TokenCreditsService.new
    token_service.balance(store_id)
  rescue AiBackendService::TokenCreditsService::TokenCreditsError => e
    raise AiBackendError, "AI Backend preflight failed: #{e.message}"
  end

  def add_tokens_with_retry(store_id, transaction_id, price)
    attempts = 0
    begin
      add_tokens_to_ai_backend(store_id, transaction_id, price)
    rescue AiBackendError => e
      attempts += 1
      if attempts < 3
        sleep(2**attempts)
        retry
      end
      raise e
    end
  end

  def add_tokens_to_ai_backend(store_id, transaction_id, price)
    tokens_to_add = @pack_config['token_credits'].to_i

    token_service = AiBackendService::TokenCreditsService.new
    token_service.add_credits(
      store_id: store_id,
      tokens_to_add: tokens_to_add,
      transaction_id: transaction_id,
      amount_paid_usd: price.unit_amount ? (price.unit_amount / 100.0) : nil,
      metadata: {
        lookup_key: @pack_config['lookup_key'],
        price_id: price.id,
        product_id: @pack_config['product_id']
      }
    )
  rescue AiBackendService::TokenCreditsService::TokenCreditsError => e
    raise AiBackendError, e.message
  end

  def cleanup_stripe_objects(invoice, invoice_item)
    if invoice&.id
      ::Stripe::Invoice.void_invoice(invoice.id)
    end
  rescue ::Stripe::StripeError => e
    Rails.logger.warn "Failed to void Stripe invoice #{invoice&.id}: #{e.message}"
  ensure
    begin
      ::Stripe::InvoiceItem.delete(invoice_item.id) if invoice_item&.id
    rescue ::Stripe::StripeError => e
      Rails.logger.warn "Failed to delete Stripe invoice item #{invoice_item&.id}: #{e.message}"
    end
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

