# frozen_string_literal: true

module Billing
  # Background job to initialize AI token credits for new accounts
  # This provides retry capability and doesn't block account creation
  # Following the same pattern as ProvisionStripeSubscriptionJob (raises exceptions for retries)
  class InitializeAiTokenCreditsJob < ApplicationJob
    queue_as :default
    sidekiq_options retry: 5 # Retry 5 times on failure (same as ProvisionStripeSubscriptionJob)

    def perform(account_id)
      Rails.logger.info "Starting AI token credits initialization for account #{account_id}"

      account = Account.find_by(id: account_id)
      unless account
        Rails.logger.error "Account not found with ID: #{account_id}"
        return
      end

      # Check if already initialized
      if account.custom_attributes&.dig('ai_tokens_initialized_at').present?
        Rails.logger.info "Account #{account_id} already has tokens initialized, skipping"
        return
      end

      # Check if store_id exists (required for initialization)
      store_id = account.custom_attributes&.dig('store_id')
      if store_id.blank?
        Rails.logger.warn "Account #{account_id} does not have store_id yet, will retry"
        raise StandardError, "store_id not set for account #{account_id}"
      end

      # Pass raise_on_error: true to allow exceptions to propagate for retry logic
      service = Billing::InitializeAiTokenCreditsService.new(account, raise_on_error: true)
      service.perform

      Rails.logger.info "Successfully initialized AI token credits for account #{account_id}"
    rescue StandardError => e
      Rails.logger.error "Error initializing AI token credits for account #{account_id}: #{e.message}"
      raise # Re-raise to trigger Sidekiq retry
    end
  end
end

