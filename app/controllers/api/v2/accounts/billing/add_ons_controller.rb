# frozen_string_literal: true

# Controller for managing subscription add-ons (extra agents, inboxes, channels)
class Api::V2::Accounts::Billing::AddOnsController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper

  before_action :current_account
  before_action :check_authorization
  before_action :validate_add_on_type, only: [:update]

  # GET /api/v2/accounts/:account_id/billing/add_ons
  # Returns current add-on quantities and pricing for all add-on types
  def index
    add_ons = {}

    Billing::ManageSubscriptionAddOnService::ADD_ON_TYPES.each do |type|
      begin
        service = Billing::ManageSubscriptionAddOnService.new(current_account, type)
        add_ons[type] = service.add_on_info
      rescue StandardError => e
        Rails.logger.warn "Error fetching #{type} add-on info: #{e.message}"
        add_ons[type] = nil
      end
    end

    render json: {
      success: true,
      data: {
        account_id: current_account.id,
        plan_name: current_account.custom_attributes&.dig('plan_name'),
        add_ons: add_ons.compact
      }
    }
  rescue StandardError => e
    Rails.logger.error "Error fetching add-ons: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch add-on information'
    }, status: :internal_server_error
  end

  # POST /api/v2/accounts/:account_id/billing/add_ons
  # Body: { add_on_type: 'agent', action: 'add' } or { add_on_type: 'agent', action: 'set', quantity: 5 }
  def update
    service = Billing::ManageSubscriptionAddOnService.new(current_account, params[:add_on_type])

    result = case params[:action]
             when 'add'
               service.add_unit
             when 'remove'
               service.remove_unit
             when 'set'
               quantity = params[:quantity].to_i
               service.set_quantity(quantity)
             else
               { success: false, error: 'Invalid action. Must be: add, remove, or set' }
             end

    if result[:success]
      render json: {
        success: true,
        message: result[:message],
        data: {
          add_on_type: result[:add_on_type],
          quantity: result[:quantity]
        }
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: {
      success: false,
      error: e.message
    }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "Error updating add-on: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to update add-on'
    }, status: :internal_server_error
  end

  # GET /api/v2/accounts/:account_id/billing/add_ons/limits
  # Returns usage and limits for all resource types
  def limits
    limits_data = {}

    Billing::UnifiedLimitService::RESOURCE_TYPES.each do |type|
      begin
        service = Billing::UnifiedLimitService.new(current_account, type)
        limits_data[type] = service.status
      rescue StandardError => e
        Rails.logger.warn "Error fetching #{type} limit info: #{e.message}"
        limits_data[type] = nil
      end
    end

    # Add conversation limits
    begin
      conv_service = Billing::ConversationLimitService.new(current_account)
      limits_data[:conversation] = conv_service.status
    rescue StandardError => e
      Rails.logger.warn "Error fetching conversation limit info: #{e.message}"
      limits_data[:conversation] = nil
    end

    render json: {
      success: true,
      data: {
        account_id: current_account.id,
        plan_name: current_account.custom_attributes&.dig('plan_name'),
        limits: limits_data.compact
      }
    }
  rescue StandardError => e
    Rails.logger.error "Error fetching limits: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch limit information'
    }, status: :internal_server_error
  end

  # GET /api/v2/accounts/:account_id/billing/add_ons/breakdown
  # Returns subscription cost breakdown (base plan + add-ons)
  def breakdown
    service = Billing::SubscriptionBreakdownService.new(current_account)
    breakdown_data = service.breakdown

    render json: {
      success: true,
      data: breakdown_data
    }
  rescue StandardError => e
    Rails.logger.error "Error fetching subscription breakdown: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch subscription breakdown'
    }, status: :internal_server_error
  end

  private

  def validate_add_on_type
    valid_types = Billing::ManageSubscriptionAddOnService::ADD_ON_TYPES.map(&:to_s)

    unless params[:add_on_type].present? && valid_types.include?(params[:add_on_type])
      render json: {
        success: false,
        error: "Invalid add_on_type. Must be one of: #{valid_types.join(', ')}"
      }, status: :bad_request
    end
  end

  def check_authorization
    authorize(:account, :billing_access?)
  rescue Pundit::NotAuthorizedError
    render json: { error: 'Access denied' }, status: :forbidden
  end
end

