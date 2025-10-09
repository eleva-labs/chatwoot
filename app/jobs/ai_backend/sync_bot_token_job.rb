# frozen_string_literal: true

class AiBackend::SyncBotTokenJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(agent_bot_id, account_id, token)
    # Verify records exist before proceeding
    AgentBot.find(agent_bot_id)
    Account.find(account_id)

    config_service = AiBackendService::ConfigurationService.new

    # Simple config data - only contains the token
    config_data = {
      chatwoot_access_token: token
    }

    config_service.save_configuration(
      scope: AiBackendService::Constants::Scope::AGENT_SYSTEM,
      resource_id: agent_bot_id,
      config_key: AiBackendService::Constants::ConfigKey::AGENT_SYSTEM_CONFIG,
      config_data: config_data
    )

    Rails.logger.info("Successfully synced bot token for agent_bot_id: #{agent_bot_id}")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Record not found when syncing bot token: #{e.message}")
    # Don't retry if record doesn't exist
  rescue StandardError => e
    Rails.logger.error("Failed to sync bot token for agent_bot_id: #{agent_bot_id} - #{e.message}")
    raise # Will trigger retry
  end
end
