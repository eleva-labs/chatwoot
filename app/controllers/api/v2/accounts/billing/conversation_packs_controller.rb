# frozen_string_literal: true

# Controller for purchasing conversation packs
class Api::V2::Accounts::Billing::ConversationPacksController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper
  include BillingPlans

  before_action :current_account
  before_action :check_authorization

  # GET /api/v2/accounts/:account_id/billing/conversation_packs
  # Returns available conversation packs with pricing
  def index
    plan_name = current_account.custom_attributes&.dig('plan_name')

    # Use unified service to check if add-ons can be purchased
    purchase_check = Billing::CanPurchaseAddOnsService.new(current_account)
    if purchase_check.blocked?
      return render json: {
        success: true,
        data: {
          packs: [],
          eligible: false,
          message: purchase_check.error_message
        }
      }
    end

    # Check if conversation packs are available for this plan
    eligible = BillingPlans.conversation_packs_available_for_plan?(plan_name)

    if eligible
      # Get pack catalog
      packs_catalog = BillingPlans.conversation_packs_catalog

      # Enrich with Stripe pricing data
      enriched_packs = packs_catalog.map do |pack|
        price = fetch_price_from_stripe(pack['lookup_key'])
        {
          lookup_key: pack['lookup_key'],
          size: pack['size'],
          display_name: pack['display_name'],
          product_id: pack['product_id'],
          price_id: price&.id,
          unit_amount: price&.unit_amount,
          currency: price&.currency,
          formatted_price: format_price(price)
        }
      end

      render json: {
        success: true,
        data: {
          packs: enriched_packs,
          eligible: true
        }
      }
    else
      render json: {
        success: true,
        data: {
          packs: [],
          eligible: false,
          message: 'Conversation packs not available for this plan'
        }
      }
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching conversation packs: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch conversation packs'
    }, status: :internal_server_error
  end

  # GET /api/v2/accounts/:account_id/billing/conversation_packs/check_payment_method
  # Checks if customer has a payment method on file
  def check_payment_method
    customer_id = current_account.custom_attributes&.dig('stripe_customer_id')

    if customer_id.blank?
      return render json: {
        has_payment_method: false,
        message: 'No Stripe customer found'
      }
    end

    begin
      customer = ::Stripe::Customer.retrieve(customer_id)

      # Check for payment method in two places:
      # 1. invoice_settings.default_payment_method (preferred)
      # 2. default_source (legacy credit cards)
      has_payment_method = customer.invoice_settings&.default_payment_method.present? ||
                           customer.default_source.present?

      render json: {
        has_payment_method: has_payment_method,
        message: has_payment_method ? 'Payment method on file' : 'No payment method on file'
      }
    rescue ::Stripe::StripeError => e
      Rails.logger.error "Error checking payment method: #{e.message}"
      render json: {
        has_payment_method: false,
        message: e.message
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v2/accounts/:account_id/billing/conversation_packs/purchase
  # Purchases a one-time conversation pack
  def purchase
    lookup_key = params[:lookup_key]

    unless lookup_key.present?
      return render json: {
        success: false,
        error: 'Missing lookup_key parameter'
      }, status: :bad_request
    end

    service = Billing::PurchaseConversationPackService.new(current_account, lookup_key)
    result = service.perform

    if result[:success]
      render json: {
        success: true,
        message: result[:message],
        data: {
          conversations_added: result[:conversations_added],
          new_total: result[:new_total],
          invoice_id: result[:invoice_id],
          amount: result[:amount],
          currency: result[:currency]
        }
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Error purchasing conversation pack: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to purchase conversation pack'
    }, status: :internal_server_error
  end

  private

  def check_authorization
    authorize(:account, :billing_access?)
  rescue Pundit::NotAuthorizedError
    render json: { error: 'Access denied' }, status: :forbidden
  end

  def fetch_price_from_stripe(lookup_key)
    return nil unless lookup_key

    prices = ::Stripe::Price.list(lookup_keys: [lookup_key], limit: 1)
    prices.data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching price from Stripe: #{e.message}"
    nil
  end

  def format_price(price)
    return nil unless price

    amount = price.unit_amount / 100.0
    currency_symbol = price.currency.upcase == 'USD' ? '$' : price.currency
    "#{currency_symbol}#{amount}"
  end
end

