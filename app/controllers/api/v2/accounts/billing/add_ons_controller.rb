# frozen_string_literal: true

# Controller for managing subscription add-ons (extra agents, inboxes, channels)
class Api::V2::Accounts::Billing::AddOnsController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper

  before_action :current_account
  before_action :check_authorization
  before_action :validate_add_on_type, only: [:update, :preview, :preview_purchase]

  # GET /api/v2/accounts/:account_id/billing/add_ons
  # Returns current add-on quantities and pricing for all add-on types
  # Categorizes add-ons into capacity_add_ons and training_services
  def index
    capacity_add_ons = {}
    training_services = {}

    Billing::ManageSubscriptionAddOnService::ADD_ON_TYPES.each do |type|
      begin
        service = Billing::ManageSubscriptionAddOnService.new(current_account, type)
        info = service.add_on_info
        next unless info

        # Categorize by category field
        if info[:category] == 'training'
          training_services[type] = info
        else
          capacity_add_ons[type] = info
        end
      rescue StandardError => e
        Rails.logger.warn "Error fetching #{type} add-on info: #{e.message}"
      end
    end

    render json: {
      success: true,
      data: {
        account_id: current_account.id,
        plan_name: current_account.custom_attributes&.dig('plan_name'),
        add_ons: capacity_add_ons,
        training_services: training_services
      }
    }
  rescue StandardError => e
    Rails.logger.error "Error fetching add-ons: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch add-on information'
    }, status: :internal_server_error
  end

  # POST /api/v2/accounts/:account_id/billing/add_ons/preview
  # Provides a proration credit estimate before removal
  def preview
    add_on_type = params[:add_on_type] || params.dig(:add_on, :add_on_type)
    raw_action = request.request_parameters['action']
    action_type = raw_action || params.dig(:add_on, :action) || params[:action_type]
    quantity = params[:quantity]&.to_i || params.dig(:add_on, :quantity)&.to_i

    service = Billing::PreviewAddOnRemovalService.new(
      current_account,
      add_on_type,
      action_type,
      quantity
    )

    result = service.preview_removal

    if result[:success]
      render json: {
        success: true,
        estimated_credit: result[:estimated_credit],
        details: result[:details]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Error previewing add-on removal: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)

    render json: {
      success: false,
      error: 'Failed to preview removal'
    }, status: :internal_server_error
  end

  # POST /api/v2/accounts/:account_id/billing/add_ons/preview_purchase
  # Provides a proration charge estimate before purchasing an add-on
  def preview_purchase
    add_on_type = params[:add_on_type] || params.dig(:add_on, :add_on_type)
    raw_action = request.request_parameters['action']
    action_type = raw_action || params.dig(:add_on, :action) || params[:action_type] || 'add'
    quantity = params[:quantity]&.to_i || params.dig(:add_on, :quantity)&.to_i

    service = Billing::PreviewAddOnPurchaseService.new(
      current_account,
      add_on_type,
      action_type,
      quantity
    )

    result = service.preview_purchase

    if result[:success]
      render json: {
        success: true,
        estimated_charge: result[:estimated_charge],
        estimated_charge_cents: result[:estimated_charge_cents],
        details: result[:details]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Error previewing add-on purchase: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)

    render json: {
      success: false,
      error: 'Failed to preview purchase'
    }, status: :internal_server_error
  end

  # POST /api/v2/accounts/:account_id/billing/add_ons
  # Body: { add_on_type: 'agent', action: 'add' } or { add_on_type: 'agent', action: 'set', quantity: 5 }
  def update
    # Read from add_on params or root params (for backward compatibility)
    add_on_type = params[:add_on_type] || params.dig(:add_on, :add_on_type)
    raw_action = request.request_parameters['action']
    action_type = raw_action || params.dig(:add_on, :action) || params[:action_type]
    quantity = params[:quantity] || params.dig(:add_on, :quantity)

    service = Billing::ManageSubscriptionAddOnService.new(current_account, add_on_type)

    result = case action_type
             when 'add'
               service.add_unit
             when 'remove'
               service.remove_unit
             when 'set'
               service.set_quantity(quantity.to_i)
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

    limits_data[:ai_tokens] = ai_token_status

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
    add_on_type = params[:add_on_type] || params.dig(:add_on, :add_on_type)

    unless add_on_type.present? && valid_types.include?(add_on_type)
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

  def ai_token_status
    # Use account.id (integer) with id_type=external, following the same pattern as other AI Backend services
    store_id = current_account.id

    token_service = AiBackendService::TokenCreditsService.new
    balance = token_service.balance(store_id)
    transactions = token_service.transactions(store_id)

    build_ai_token_status(balance, transactions)
  rescue AiBackendService::TokenCreditsService::TokenCreditsError => e
    Rails.logger.error "Error fetching AI token status: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "Unexpected error fetching AI token status: #{e.message}"
    nil
  end

  def build_ai_token_status(balance, transactions)
    balance_data = balance.is_a?(Hash) ? (balance['data'] || balance) : {}
    transaction_entries = transactions.is_a?(Hash) ? (transactions['data'] || []) : []

    tokens_used = balance_data['tokens_used'].to_i
    token_limit = balance_data['token_limit'].to_i
    available_tokens = balance_data['available_tokens'].to_i

    backend_base_limit = balance_data['base_limit']
    backend_purchased = balance_data['purchased_credits']

    plan_base_limit_value = plan_ai_token_limit
    unlimited_plan = plan_base_limit_value == -1

    calculated_base_limit =
      if unlimited_plan
        -1
      elsif backend_base_limit.present?
        backend_base_limit.to_i
      elsif plan_base_limit_value.present? && !plan_base_limit_value.negative?
        plan_base_limit_value
      else
        token_limit
      end

    purchased_total =
      if backend_purchased.present?
        backend_purchased.to_i
      else
        purchased_from_history = purchases_in_current_period(transaction_entries).sum { |entry| entry['tokens_added'].to_i }
        fallback_from_balance = calculated_base_limit >= 0 ? [token_limit - calculated_base_limit, 0].max : 0
        [fallback_from_balance, purchased_from_history, 0].compact.max
      end

    total_allowed_value =
      if unlimited_plan
        -1
      else
        effective_base = [calculated_base_limit, 0].max
        effective_base + purchased_total
      end

    included_used =
      if unlimited_plan
        tokens_used
      elsif calculated_base_limit <= 0
        0
      else
        [tokens_used, calculated_base_limit].min
      end

    purchased_used =
      if unlimited_plan
        0
      else
        [tokens_used - included_used, 0].max
      end

    purchased_remaining =
      if unlimited_plan
        0
      else
        [purchased_total - purchased_used, 0].max
      end

    included_remaining =
      if unlimited_plan
        -1
      else
        [[calculated_base_limit, 0].max - included_used, 0].max
      end

    usage_denominator =
      if unlimited_plan || total_allowed_value <= 0
        nil
      else
        total_allowed_value
      end

    usage_percentage =
      if usage_denominator.present?
        ((tokens_used.to_f / usage_denominator) * 100).round(1)
      else
        0
      end

    remaining_value = unlimited_plan ? -1 : available_tokens

    {
      current: tokens_used,
      base_limit: calculated_base_limit,
      purchased: purchased_total,
      total_allowed: total_allowed_value,
      remaining: remaining_value,
      usage_percentage: usage_percentage,
      can_create: unlimited_plan ? true : remaining_value.positive?,
      approaching_limit: usage_denominator.present? ? usage_percentage >= 80 : false,
      at_limit: unlimited_plan ? false : !remaining_value.positive?,
      included_used: included_used,
      included_remaining: included_remaining,
      purchased_used: purchased_used,
      purchased_remaining: purchased_remaining,
      current_period_purchases: purchased_total
    }
  end

  def plan_ai_token_limit
    plan_name = current_account.custom_attributes&.dig('plan_name') || 'starter'

    stripe_limits = Billing::Providers::Stripe.get_plan_limits_from_stripe(plan_name)
    fallback_limits = BillingPlans.plan_details(plan_name)&.dig('limits')

    limits = (stripe_limits.presence || fallback_limits || {}).with_indifferent_access
    token_limit = limits[:token_credits]

    return nil if token_limit.nil?

    token_limit.to_i
  rescue StandardError => e
    Rails.logger.error "Error resolving AI token base limit for plan #{plan_name}: #{e.message}"
    nil
  end

  def purchases_in_current_period(entries)
    period_start = current_billing_period_start

    Array(entries).select do |entry|
      timestamp = transaction_timestamp(entry)
      timestamp.nil? || timestamp >= period_start
    end
  end

  def current_billing_period_start
    period_start_timestamp = current_account.custom_attributes&.dig('current_period_start')
    return Time.zone.at(period_start_timestamp.to_i) if period_start_timestamp.present?

    Time.current.beginning_of_month
  end

  def transaction_timestamp(entry)
    raw_timestamp = entry['purchased_at'] || entry['created_at'] || entry['occurred_at'] || entry['timestamp']
    return nil if raw_timestamp.blank?

    return Time.zone.at(raw_timestamp.to_i) if raw_timestamp.is_a?(Numeric)

    Time.zone.parse(raw_timestamp.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end

