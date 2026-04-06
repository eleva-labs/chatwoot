# frozen_string_literal: true

class Api::V2::Accounts::Billing::AiTokenCreditsController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper
  include BillingPlans

  before_action :current_account
  before_action :check_authorization

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

    unless BillingPlans.ai_token_packs_available_for_plan?(plan_name)
      return render json: {
        success: true,
        data: {
          packs: [],
          eligible: false,
          message: 'AI token packs not available for this plan'
        }
      }
    end

    packs_catalog = BillingPlans.ai_token_packs_catalog
    enriched_packs = packs_catalog.map do |pack|
      price = fetch_price_from_stripe(pack['lookup_key'])
      {
        lookup_key: pack['lookup_key'],
        token_credits: pack['token_credits'],
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
  rescue StandardError => e
    Rails.logger.error "Error fetching AI token packs: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch AI token packs'
    }, status: :internal_server_error
  end

  def check_payment_method
    customer_id = current_account.custom_attributes&.dig('stripe_customer_id')

    if customer_id.blank?
      return render json: {
        has_payment_method: false,
        message: 'No Stripe customer found'
      }
    end

    customer = ::Stripe::Customer.retrieve(customer_id)
    has_payment_method = customer.invoice_settings&.default_payment_method.present? ||
                         customer.default_source.present?

    render json: {
      has_payment_method: has_payment_method,
      message: has_payment_method ? 'Payment method on file' : 'No payment method on file'
    }
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error checking payment method for AI tokens: #{e.message}"
    render json: {
      has_payment_method: false,
      message: e.message
    }, status: :unprocessable_entity
  end

  def purchase
    lookup_key = params[:lookup_key]

    unless lookup_key.present?
      return render json: {
        success: false,
        error: 'Missing lookup_key parameter'
      }, status: :bad_request
    end

    service = Billing::PurchaseAiTokenCreditsService.new(current_account, lookup_key)
    result = service.perform

    if result[:success]
      render json: {
        success: true,
        message: result[:message],
        data: {
          tokens_added: result[:tokens_added],
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
    Rails.logger.error "Error purchasing AI token credits: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to purchase AI token credits'
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

    ::Stripe::Price.list(lookup_keys: [lookup_key], limit: 1).data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching AI token pack price: #{e.message}"
    nil
  end

  def format_price(price)
    return nil unless price

    amount = price.unit_amount / 100.0
    currency_symbol = price.currency.upcase == 'USD' ? '$' : price.currency.upcase
    "#{currency_symbol}#{amount}"
  end
end

