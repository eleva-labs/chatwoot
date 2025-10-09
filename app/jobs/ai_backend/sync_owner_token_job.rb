# frozen_string_literal: true

class AiBackend::SyncOwnerTokenJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(account_id, user_id, token)
    # Verify records exist before proceeding
    Account.find(account_id)
    User.find(user_id)

    config_service = AiBackendService::ConfigurationService.new

    # Simple config data - only contains the token
    config_data = {
      chatwoot_access_token: token
    }

    config_service.save_configuration(
      scope: AiBackendService::Constants::Scope::STORE,
      resource_id: account_id,
      config_key: AiBackendService::Constants::ConfigKey::GENERAL_STORE_CONFIG,
      config_data: config_data
    )

    Rails.logger.info("Successfully synced owner token for account_id: #{account_id}")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Record not found when syncing owner token: #{e.message}")
    # Don't retry if record doesn't exist
  rescue StandardError => e
    Rails.logger.error("Failed to sync owner token for account_id: #{account_id} - #{e.message}")
    raise # Will trigger retry
  end
end
