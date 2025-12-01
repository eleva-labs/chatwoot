# frozen_string_literal: true

module Billing
  # Service to initialize AI token credits when account is first created
  # Sets initial token_limit from plan configuration (Stripe or billing_plans.yml)
  class InitializeAiTokenCreditsService
    include BillingPlans

    def initialize(account, raise_on_error: false)
      @account = account
      @raise_on_error = raise_on_error
    end

    def perform
      Rails.logger.info "🔍 [TOKEN INIT] Starting token initialization for account #{@account.id}"

      base_limit = compute_base_token_limit
      if base_limit.nil? || base_limit.zero?
        Rails.logger.info "🔍 [TOKEN INIT] Skipping init: base_limit is #{base_limit.inspect} (nil or zero)"
        return
      end

      # Check store_id from custom_attributes (no fallback - must be present)
      # Following the same pattern as PurchaseAiTokenCreditsService
      store_id = @account.custom_attributes&.dig('store_id')
      if store_id.blank?
        error_message = "store_id not set for account #{@account.id}"
        Rails.logger.warn "Skipping AI token init for account #{@account.id}: #{error_message}"
        raise StandardError, error_message if @raise_on_error
        return
      end

      # Check if already initialized to prevent duplicate calls
      if already_initialized?
        Rails.logger.info "🔍 [TOKEN INIT] Already initialized for account #{@account.id}"
        return
      end

      initialize_tokens(store_id, base_limit)
    rescue AiBackendService::TokenCreditsService::TokenCreditsError => e
      Rails.logger.error "Failed to initialize AI token credits for account #{@account.id}: #{e.message}"
      # Re-raise if called from background job to enable retry logic
      raise if @raise_on_error
      # Don't raise - allow account creation to continue even if token init fails
      # The initialization can be retried later via background job
    rescue StandardError => e
      Rails.logger.error "Unexpected error initializing AI token credits for account #{@account.id}: #{e.message}"
      # Re-raise if called from background job to enable retry logic
      raise if @raise_on_error
      # Don't raise - allow account creation to continue
    end

    private

    def compute_base_token_limit
      plan_name = @account.custom_attributes&.dig('plan_name') || 'starter'

      # Try Stripe first (source of truth for production)
      stripe_limits = Billing::Providers::Stripe.get_plan_limits_from_stripe(plan_name)
      # Fallback to billing_plans.yml (for development/testing)
      fallback_limits = BillingPlans.plan_details(plan_name)&.dig('limits')

      limits = (stripe_limits.presence || fallback_limits || {}).with_indifferent_access
      token_limit = limits[:token_credits]

      return nil if token_limit.nil?

      token_limit.to_i
    rescue StandardError => e
      Rails.logger.error "Error computing base token limit for plan #{plan_name}: #{e.message}"
      nil
    end

    def already_initialized?
      # Check if we've already initialized tokens for this account
      # Store a flag in custom_attributes to prevent duplicate initialization
      @account.custom_attributes&.dig('ai_tokens_initialized_at').present?
    end

    def initialize_tokens(store_id, base_limit)
      Rails.logger.info "Initializing AI token credits for account #{@account.id}: base_limit=#{base_limit}"

      service = AiBackendService::TokenCreditsService.new
      service.reset_credits(store_id: store_id, base_limit: base_limit)

      # Mark as initialized to prevent duplicates
      attrs = @account.custom_attributes || {}
      attrs['ai_tokens_initialized_at'] = Time.current.to_i
      @account.update!(custom_attributes: attrs)

      Rails.logger.info "Successfully initialized AI token credits for account #{@account.id}"
    end
  end
end

