# frozen_string_literal: true

require 'httparty'

class AiBackendService::ConfigurationService
  include HTTParty

  class ConfigurationError < StandardError; end

  def initialize(id_type: AiBackendService::Constants::IdType::EXTERNAL)
    @id_type = id_type
    validate_id_type!

    self.class.base_uri ai_backend_api_url
    self.class.headers({
                         'Content-Type' => 'application/json',
                         'Authorization' => 'application/json'
                       })
  end

  # Save or update a configuration
  # @param scope [String] Resource scope (store, agent_system, user)
  # @param resource_id [Integer/String] Resource ID (external or internal based on id_type)
  # @param config_key [String] Configuration key
  # @param config_data [Hash] Configuration data to save
  # @return [Hash] API response
  def save_configuration(scope:, resource_id:, config_key:, config_data:)
    validate_scope!(scope)
    validate_config_key!(config_key)

    # Get existing config and merge with new data
    existing_data = get_configuration(scope: scope, resource_id: resource_id, config_key: config_key)
    merged_data = existing_data.merge(config_data)

    configuration_payload = {
      key: config_key,
      scope: scope,
      resource_id: resource_id.to_s,
      data: merged_data
    }

    response = self.class.put(
      "#{ai_backend_api_url}/api/configurations",
      query: { id_type: @id_type },
      body: { configuration: configuration_payload }.to_json,
      headers: self.class.headers
    )

    handle_response(response)

    response.parsed_response
  end

  # Get a specific configuration
  # @param scope [String] Resource scope (store, agent_system, user)
  # @param resource_id [Integer/String] Resource ID
  # @param config_key [String] Configuration key
  # @return [Hash] Configuration data (empty hash if not found)
  def get_configuration(scope:, resource_id:, config_key:)
    validate_scope!(scope)
    validate_config_key!(config_key)

    response = self.class.get(
      "#{ai_backend_api_url}/api/configurations",
      query: {
        key: config_key,
        scope: scope,
        resource_id: resource_id.to_s,
        id_type: @id_type
      },
      headers: self.class.headers
    )

    # If configuration doesn't exist yet, return empty hash instead of raising error
    return {} if response.code == 404

    handle_response(response)

    body = response.parsed_response
    body.is_a?(Hash) ? (body.dig('configuration', 'data') || {}) : {}
  end

  # Get all configurations for a resource
  # @param scope [String] Resource scope
  # @param resource_id [Integer/String] Resource ID
  # @return [Hash] All configurations grouped by key
  def get_all_configurations(scope:, resource_id:)
    validate_scope!(scope)

    response = self.class.get(
      "#{ai_backend_api_url}/api/configurations/all",
      query: {
        scope: scope,
        resource_id: resource_id.to_s,
        id_type: @id_type
      },
      headers: self.class.headers
    )

    return {} if response.code == 404

    handle_response(response)

    response.parsed_response['configurations'] || {}
  end

  # Delete a configuration
  # @param scope [String] Resource scope
  # @param resource_id [Integer/String] Resource ID
  # @param config_key [String] Configuration key
  # @return [Boolean] Success status
  def delete_configuration(scope:, resource_id:, config_key:)
    validate_scope!(scope)
    validate_config_key!(config_key)

    response = self.class.delete(
      "#{ai_backend_api_url}/api/configurations",
      query: {
        key: config_key,
        scope: scope,
        resource_id: resource_id.to_s,
        id_type: @id_type
      },
      headers: self.class.headers
    )

    handle_response(response)

    response.success?
  end

  # Batch save multiple configurations for a resource
  # @param scope [String] Resource scope
  # @param resource_id [Integer/String] Resource ID
  # @param configurations [Hash] Hash of config_key => config_data
  # @return [Array<Hash>] Array of responses
  def batch_save_configurations(scope:, resource_id:, configurations:)
    validate_scope!(scope)

    configurations.map do |config_key, config_data|
      save_configuration(
        scope: scope,
        resource_id: resource_id,
        config_key: config_key,
        config_data: config_data
      )
    rescue ConfigurationError => e
      Rails.logger.error "Failed to save #{config_key}: #{e.message}"
      { config_key: config_key, error: e.message }
    end
  end

  private

  def validate_id_type!
    return if AiBackendService::Constants::IdType.valid?(@id_type)

    raise ConfigurationError, "Invalid id_type: #{@id_type}. Must be one of: #{AiBackendService::Constants::IdType::ALL.join(', ')}"
  end

  def validate_scope!(scope)
    return if AiBackendService::Constants::Scope.valid?(scope)

    raise ConfigurationError, "Invalid scope: #{scope}. Must be one of: #{AiBackendService::Constants::Scope::ALL.join(', ')}"
  end

  def validate_config_key!(config_key)
    return if AiBackendService::Constants::ConfigKey.valid?(config_key)

    Rails.logger.warn "Unknown config_key: #{config_key}. Valid keys: #{AiBackendService::Constants::ConfigKey::ALL.join(', ')}"
  end

  def handle_response(response)
    case response.code
    when 404
      # 404 for GET is acceptable (config doesn't exist yet), but not for PUT/DELETE
      raise ConfigurationError, "Configuration not found: #{response.request.last_uri}" unless response.request.http_method == Net::HTTP::Get
    when 400
      raise ConfigurationError, "Bad request: #{response.code} - #{response.body}"
    when 200..299
      # Success
    else
      raise ConfigurationError, "Unexpected error: #{response.code} - #{response.body}"
    end
  end

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url
  end
end
