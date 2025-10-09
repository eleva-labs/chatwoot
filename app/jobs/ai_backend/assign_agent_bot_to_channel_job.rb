# frozen_string_literal: true

# Job to assign an agent bot to a channel in the AI Backend
# Triggered when an AgentBotInbox record is created
class AiBackend::AssignAgentBotToChannelJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # @param agent_bot_id [Integer] The Chatwoot agent_bot.id (external_id)
  # @param inbox_id [Integer] The Chatwoot inbox.id (external_id)
  # @param account_id [Integer] The Chatwoot account.id (store_id)
  def perform(agent_bot_id, inbox_id, account_id)
    channel_service = AiBackendService::ChannelService.new

    # Call channel update API with agent_system_id
    channel_service.assign_agent_system(inbox_id, account_id, agent_bot_id)

    Rails.logger.info("AI Backend: Successfully assigned agent bot #{agent_bot_id} to channel #{inbox_id}")
  rescue AiBackendService::ChannelService::ChannelError => e
    Rails.logger.error("AI Backend: Failed to assign agent bot #{agent_bot_id} to channel #{inbox_id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("AI Backend: Unexpected error assigning agent bot #{agent_bot_id} to channel #{inbox_id} - #{e.message}")
    raise
  end
end
