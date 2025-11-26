# frozen_string_literal: true

module Billing
  # Service to reset AI token credits on subscription renewal
  # Resets tokens_used to 0 and restores token_limit to base plan limit
  class ResetAiTokenCreditsService
    include BillingPlans

    def initialize(account, invoice)
      @account = account
      @invoice = invoice
    end

    def perform
      return unless should_reset?

      base_limit = compute_base_token_limit
      return if base_limit.nil? || base_limit.zero?

      period_end = extract_period_end
      return if period_end.nil? # Skip reset if period_end is unavailable (incomplete invoice data)
      return if already_reset_for_period?(period_end)

      reset_tokens(base_limit, period_end)
    rescue AiBackendService::TokenCreditsService::TokenCreditsError => e
      Rails.logger.error "Failed to reset AI token credits for account #{@account.id}: #{e.message}"
      # Don't raise - allow webhook processing to continue
    rescue StandardError => e
      Rails.logger.error "Unexpected error resetting AI token credits for account #{@account.id}: #{e.message}"
      # Don't raise - allow webhook processing to continue
    end

    private

    def should_reset?
      # Only reset for subscription renewals, not one-time purchases
      return false unless subscription_invoice?

      # Only reset for active subscriptions
      subscription_status = @account.custom_attributes&.dig('subscription_status')
      return false unless Billing::SubscriptionStatuses.paid_status?(subscription_status)

      true
    end

    def subscription_invoice?
      # Subscription invoices have a subscription field
      # One-time purchases (conversation packs, token packs) don't
      subscription_id = if @invoice.is_a?(Hash)
                          @invoice['subscription']
                        else
                          @invoice.subscription
                        end

      subscription_id.present?
    end

    def compute_base_token_limit
      plan_name = @account.custom_attributes&.dig('plan_name') || 'free_trial'

      stripe_limits = Billing::Providers::Stripe.get_plan_limits_from_stripe(plan_name)
      fallback_limits = BillingPlans.plan_details(plan_name)&.dig('limits')

      limits = (stripe_limits.presence || fallback_limits || {}).with_indifferent_access
      token_limit = limits[:token_credits]

      return nil if token_limit.nil?

      token_limit.to_i
    rescue StandardError => e
      Rails.logger.error "Error computing base token limit for plan #{plan_name}: #{e.message}"
      nil
    end

    def extract_period_end
      if @invoice.is_a?(Hash)
        @invoice['period_end'] || @invoice.dig('lines', 'data', 0, 'period', 'end')
      else
        @invoice.period_end || @invoice.lines&.data&.first&.period&.end
      end
    end

    def already_reset_for_period?(period_end)
      return false unless period_end

      last_reset_period_end = @account.custom_attributes&.dig('ai_tokens_last_reset_period_end')
      return false unless last_reset_period_end

      # Convert to integer for comparison (Stripe timestamps are Unix timestamps)
      period_end_int = period_end.is_a?(Time) ? period_end.to_i : period_end.to_i
      last_reset_int = last_reset_period_end.to_i

      period_end_int == last_reset_int
    end

    def reset_tokens(base_limit, period_end)
      Rails.logger.info "Resetting AI token credits for account #{@account.id}: base_limit=#{base_limit}, period_end=#{period_end}"

      store_id = store_identifier
      if store_id.blank?
        Rails.logger.warn "Skipping AI token reset for account #{@account.id}: store_id not set"
        return
      end

      service = AiBackendService::TokenCreditsService.new
      service.reset_credits(store_id: store_id, base_limit: base_limit)

      # Track reset to prevent duplicates
      attrs = @account.custom_attributes || {}
      period_end_int = period_end.is_a?(Time) ? period_end.to_i : period_end.to_i
      attrs['ai_tokens_last_reset_period_end'] = period_end_int
      attrs['ai_tokens_last_reset_at'] = Time.current.to_i
      @account.update!(custom_attributes: attrs)

      Rails.logger.info "Successfully reset AI token credits for account #{@account.id}"
    end

    def store_identifier
      store_id = @account.custom_attributes&.dig('store_id')
      return store_id if store_id.present?

      # Fallback: use account.id (legacy behaviour) if store_id not yet stored
      @account.id
    end
  end
end

