# frozen_string_literal: true

class Api::V2::Accounts::PricingController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper

  before_action :current_account
  before_action :check_authorization

  # GET /api/v2/accounts/:account_id/pricing
  def index
    service = Billing::FetchPricingTableService.new
    pricing_data = service.fetch

    render json: {
      success: true,
      data: { plans: pricing_data }
    }
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching pricing table: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch pricing data'
    }, status: :internal_server_error
  end

  private

  def check_authorization
    authorize(:account, :billing_access?)
  end
end

