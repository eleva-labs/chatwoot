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

      # Pass raise_on_error: true to allow exceptions to propagate for retry logic
      # Service now uses account.id directly (no need to check for store_id)
      service = Billing::InitializeAiTokenCreditsService.new(account, raise_on_error: true)
      service.perform

      Rails.logger.info "Successfully initialized AI token credits for account #{account_id}"
    rescue StandardError => e
      Rails.logger.error "Error initializing AI token credits for account #{account_id}: #{e.message}"
      raise # Re-raise to trigger Sidekiq retry
    end
  end
end

