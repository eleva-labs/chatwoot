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
    # TEMPORARY: The AI Backend currently wraps the JSON in markdown code blocks
    # This should be fixed on the backend side to return clean JSON
    # Example current format: "```json\n{\"nodes\": [...], \"edges\": [...]}\n```"
    prompt_text = response_data['prompt']
    raise PromptsError, 'No prompt field in response' if prompt_text.nil?

    # Try to extract JSON from markdown code block (temporary workaround)
    json_text = if prompt_text.include?('```json')
                  # The markdown might be incomplete - extract everything after ```json
                  # Use greedy match (.*) instead of lazy (.*?) to capture all content
                  json_match = prompt_text.match(/```json\s*\n(.*)(?:\n```)?$/m)
                  raise PromptsError, 'Could not extract JSON from markdown code block' unless json_match

                  json_match[1].strip
                else
                  # If no markdown wrapper, use the text directly (future clean format)
                  prompt_text
                end

    # Parse the JSON string to get the workflow structure
    parsed_data = JSON.parse(json_text)

    # Transform from AI Backend format {nodes, edges} to frontend StageGraph format
    # AI Backend: {nodes: [{id, name, description}], edges: [{from, to, condition}]}
    # Frontend expects: {data: {stages: [...]}, layoutData: {nodes: {}}}
    transform_to_stage_graph(parsed_data)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse workflow JSON: #{e.message}")
    raise PromptsError, "Invalid workflow JSON: #{e.message}"
  end

  def transform_to_stage_graph(workflow_data)
    # Transform nodes to stages with transitions
    nodes = workflow_data['nodes'] || []
    edges = workflow_data['edges'] || []

    stages = nodes.map do |node|
      # Find all outgoing edges for this node
      outgoing_edges = edges.select { |edge| edge['from'] == node['id'] }

      {
        id: node['id'],
        name: node['name'],
        description: node['description'],
        transitions: outgoing_edges.map do |edge|
          {
            target: edge['to'],
            condition: edge['condition']
          }
        end
      }
    end

    {
      data: { stages: stages },
      layoutData: { nodes: {} } # No layout data from AI Backend yet
    }
  end

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url ||
      'http://localhost:8000'
  end
end
