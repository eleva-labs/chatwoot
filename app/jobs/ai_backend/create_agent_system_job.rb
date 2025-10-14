# frozen_string_literal: true

class AiBackend::CreateAgentSystemJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(agent_bot_id, store_id)
    agent_bot = AgentBot.find(agent_bot_id)
    service = AiBackendService::AgentSystemService.new
    service.create_agent_system(agent_bot, store_id)

    # Update agent_bot's outgoing_url with correct webhook callback URL
    webhook_url = agent_bot.generate_webhook_url
    agent_bot.update!(outgoing_url: webhook_url)

    Rails.logger.info("Successfully created agent system and set webhook URL for agent_bot_id: #{agent_bot_id}")
  rescue StandardError => e
    Rails.logger.error("Failed to create agent system for agent_bot_id: #{agent_bot_id} - #{e.message}")
    raise
  end
end
