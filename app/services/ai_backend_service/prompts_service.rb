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
                         'Content-Type' => 'application/json'
                       })
  end

  # Fetch default prompt/workflow for an agent system
  # Returns StageGraph structure with layout data
  # Uses the GET /api/prompts/{prompt_key} endpoint where prompt_key = 'workflow_graph_json_prompt'
  def default_prompt
    url = "#{ai_backend_api_url}/api/prompts/workflow_graph_json_prompt"
    query_params = {
      store_id: @account_id.to_s,
      agent_system_id: @bot_id.to_s,
      id_type: @id_type
    }

    Rails.logger.info("PromptsService - Requesting: #{url}")
    Rails.logger.info("PromptsService - Query params: #{query_params.inspect}")

    response = self.class.get(url, query: query_params, headers: self.class.headers)

    handle_response(response)

    # The AI Backend returns the workflow as a JSON string inside a "prompt" field
    # We need to parse it to get the actual StageGraph structure
    parse_workflow_from_prompt(response.parsed_response)
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
    return format_validation_errors(body['detail']) if body['detail'].is_a?(Array)

    body['error'] || body['message'] || body['detail'] || 'Unknown error'
  rescue JSON::ParserError
    response.body
  end

  def format_validation_errors(details)
    errors = details.map { |e| "#{e['loc']&.join('.')}: #{e['msg']}" }.join(', ')
    "Validation errors: #{errors}"
  end

  def parse_workflow_from_prompt(response_data)
    # PromptResponse schema: { "prompt": "<json_string>" } or { "prompt": {...} }
    prompt_data = response_data['prompt']
    raise PromptsError, 'No prompt field in response' if prompt_data.nil?

    # Handle both cases: prompt is already a Hash (HTTParty auto-parsed) or a JSON string
    parsed_data = if prompt_data.is_a?(Hash)
                    # Already parsed by HTTParty
                    prompt_data
                  elsif prompt_data.is_a?(String)
                    # Parse the JSON string to get the workflow structure
                    JSON.parse(prompt_data)
                  else
                    raise PromptsError, "Unexpected prompt data type: #{prompt_data.class}"
                  end

    # AI Backend format: {nodes: [{id, name, description, initial_node, details}], edges: [{from, to, condition}]}
    # Transform from AI Backend format to frontend StageGraph format
    # Frontend expects: {data: {stages: [...]}, layoutData: {nodes: {}}}
    transform_to_stage_graph(parsed_data)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse workflow JSON: #{e.message}")
    Rails.logger.error("Prompt data was: #{prompt_data.inspect}")
    raise PromptsError, "Invalid workflow JSON: #{e.message}"
  end

  def transform_to_stage_graph(workflow_data)
    # Transform nodes to stages with transitions
    nodes = workflow_data['nodes'] || []
    edges = workflow_data['edges'] || []

    Rails.logger.info("Transforming workflow - nodes count: #{nodes.size}, edges count: #{edges.size}")

    stages = nodes.map do |node|
      # Find all outgoing edges for this node
      outgoing_edges = edges.select { |edge| edge['from'] == node['id'] }

      {
        id: node['id'],
        name: node['name'],
        description: node['description'],
        initial_node: node['initial_node'] || false,
        requirements: node.dig('details', 'requirements') || [],
        transitions: outgoing_edges.map do |edge|
          {
            target: edge['to'],
            condition: edge['condition']
          }
        end
      }
    end

    result = {
      data: { stages: stages },
      layoutData: { nodes: {} } # No layout data from AI Backend yet
    }

    Rails.logger.info("Transformed StageGraph: #{result.to_json}")
    result
  end

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url ||
      'http://localhost:8000'
  end
end
