# frozen_string_literal: true

require 'httparty'

# AgentSystemService - Manage agent systems in AI Backend (mapped to Chatwoot agent bots)
#
# IMPORTANT: Defaults to id_type=external, using Chatwoot agent_bot.id
# - create_agent_system(agent_bot, store_id) - Creates agent system with external_id = agent_bot.id
#   * store_id MUST be account.id (Chatwoot account ID), NOT the AI Backend UUID
# - get_agent_system(bot_id) - Gets agent system by Chatwoot bot.id
class AiBackendService::AgentSystemService
  include HTTParty

  class AgentSystemError < StandardError; end

  def initialize(id_type: AiBackendService::Constants::IdType::EXTERNAL)
    @id_type = id_type
    self.class.base_uri ai_backend_api_url
    self.class.headers({
                         'Content-Type' => 'application/json',
                         'Authorization' => 'application/json'
                       })
  end

  # Create agent system with external_id (Chatwoot agent_bot.id)
  def create_agent_system(agent_bot, store_id)
    agent_system_data = AiBackendService::Schemas::AgentSystemRequest.from_agent_bot(agent_bot, store_id)

    response = self.class.post(
      "#{ai_backend_api_url}/api/agent-systems",
      query: { store_id: store_id, id_type: @id_type },
      body: agent_system_data.to_h.to_json,
      headers: self.class.headers
    )

    handle_response(response)

    response.parsed_response
  end

  # Get agent system by ID (internal UUID or external ID based on id_type)
  def get_agent_system(agent_system_id)
    response = self.class.get(
      "#{ai_backend_api_url}/api/agent-systems/#{agent_system_id}",
      query: { id_type: @id_type },
      headers: self.class.headers
    )

    handle_response(response)

    response.parsed_response
  end

  # Delete agent system by ID (idempotent - 404 returns true)
  # @param agent_system_id [String, Integer] Agent system identifier
  # @param cascade [Boolean] Reserved for future use (workflows are always cascade-deleted, default: true)
  def delete_agent_system(agent_system_id, cascade: true)
    response = self.class.delete(
      "#{ai_backend_api_url}/api/agent-systems/#{agent_system_id}",
      query: { id_type: @id_type, cascade: cascade },
      headers: self.class.headers
    )

    handle_delete_response(response)
    true
  end

  private

  def handle_response(response)
    case response.code
    when 404
      raise AgentSystemError, "Agent system not found: #{response.request.last_uri}"
    when 400
      raise AgentSystemError, "Bad request: #{response.code} - #{response.body}"
    when 200..299
      # Success
    else
      raise AgentSystemError, "Unexpected error: #{response.code} - #{response.body}"
    end
  end

  def handle_delete_response(response)
    case response.code
    when 404
      # Agent system already deleted - idempotent success
      Rails.logger.info('Agent system already deleted (404) - treating as success')
    when 400
      raise AgentSystemError, "Bad request: #{response.code} - #{response.body}"
    when 200..299
      # Success
    else
      raise AgentSystemError, "Unexpected error: #{response.code} - #{response.body}"
    end
  end

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url
  end
end
