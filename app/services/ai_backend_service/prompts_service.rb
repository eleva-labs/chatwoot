# frozen_string_literal: true

require 'httparty'

# PromptsService - Fetch workflow prompts (StageGraph) from AI Backend
#
# IMPORTANT: Defaults to id_type=external, using Chatwoot IDs
# - account_id (Chatwoot) maps to store_id (AI Backend)
# - agent_bot.id (Chatwoot) maps to agent_system_id (AI Backend) with external_id
class AiBackendService::PromptsService
  include HTTParty

  class PromptsError < StandardError; end

  def initialize(account_id:, bot_id:, id_type: AiBackendService::Constants::IdType::EXTERNAL)
    @account_id = account_id
    @bot_id = bot_id
    @id_type = id_type
    self.class.base_uri ai_backend_api_url
    self.class.headers({
                         'Content-Type' => 'application/json',
                         'Authorization' => 'application/json'
                       })
  end

  # Fetch default prompt/workflow for an agent system
  # Returns StageGraph structure with layout data
  def default_prompt
    response = self.class.get(
      "#{ai_backend_api_url}/api/prompts/default",
      query: {
        store_id: @account_id.to_s,
        agent_system_id: @bot_id.to_s,
        id_type: @id_type
      },
      headers: self.class.headers
    )

    handle_response(response)

    response.parsed_response
  rescue StandardError => e
    Rails.logger.error("PromptsService error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise PromptsError, e.message
  end

  private

  def handle_response(response)
    case response.code
    when 404
      raise PromptsError, I18n.t('errors.workflows.not_found')
    when 400
      error_message = parse_error_message(response)
      raise PromptsError, "Bad request: #{error_message}"
    when 500..599
      raise PromptsError, I18n.t('errors.workflows.invalid_response')
    when 200..299
      # Success
    else
      raise PromptsError, "Unexpected error: #{response.code} - #{response.body}"
    end
  end

  def parse_error_message(response)
    body = JSON.parse(response.body)
    body['error'] || body['message'] || 'Unknown error'
  rescue JSON::ParserError
    response.body
  end

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url ||
      'http://localhost:8000'
  end
end
