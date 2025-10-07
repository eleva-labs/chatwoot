# frozen_string_literal: true

class AiBackend::DeleteAgentSystemJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(agent_bot_id)
    service = AiBackendService::AgentSystemService.new
    service.delete_agent_system(agent_bot_id)

    Rails.logger.info("Successfully deleted agent system for agent_bot_id: #{agent_bot_id} from AI Backend")
  rescue StandardError => e
    Rails.logger.error("Failed to delete agent system for agent_bot_id: #{agent_bot_id} - #{e.message}")
    raise
  end
end
