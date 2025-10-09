# frozen_string_literal: true

# Job to unassign an agent bot from a channel in the AI Backend
# Triggered when an AgentBotInbox record is destroyed
class AiBackend::UnassignAgentBotFromChannelJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # @param inbox_id [Integer] The Chatwoot inbox.id (external_id)
  def perform(inbox_id)
    channel_service = AiBackendService::ChannelService.new

    # Call channel update API with agent_system_id = null
    channel_service.unassign_agent_system(inbox_id)

    Rails.logger.info("AI Backend: Successfully unassigned agent bot from channel #{inbox_id}")
  rescue AiBackendService::ChannelService::ChannelError => e
    Rails.logger.error("AI Backend: Failed to unassign agent bot from channel #{inbox_id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("AI Backend: Unexpected error unassigning agent bot from channel #{inbox_id} - #{e.message}")
    raise
  end
end
