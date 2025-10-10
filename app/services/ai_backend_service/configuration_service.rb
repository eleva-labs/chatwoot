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
  # @param partial [Boolean] If true, send only the provided data without merging with existing config
  # @param store_id [Integer/String] Store ID (required for agent_system and user scopes)
  # @return [Hash] API response
  def save_configuration(scope:, resource_id:, config_key:, config_data:, partial: false, store_id: nil)
    validate_scope!(scope)
    validate_config_key!(config_key)

    # For partial updates, send only the provided data
    # For full updates, merge with existing config
    final_data = if partial
                   config_data
                 else
                   existing_data = get_configuration(scope: scope, resource_id: resource_id, config_key: config_key, store_id: store_id)
                   existing_data.merge(config_data)
                 end

    # Build query parameters based on scope
    query_params = build_query_params(scope: scope, resource_id: resource_id, store_id: store_id)

    response = self.class.put(
      "#{ai_backend_api_url}/api/configurations/#{config_key}",
      query: query_params,
      body: { data: final_data }.to_json,
      headers: self.class.headers
    )

    handle_response(response)

    response.parsed_response
  end

  # Get a specific configuration
  # @param scope [String] Resource scope (store, agent_system, user)
  # @param resource_id [Integer/String] Resource ID
  # @param config_key [String] Configuration key
  # @param store_id [Integer/String] Store ID (required for agent_system and user scopes)
  # @return [Hash] Configuration data (empty hash if not found)
  def get_configuration(scope:, resource_id:, config_key:, store_id: nil)
    validate_scope!(scope)
    validate_config_key!(config_key)

    query_params = build_query_params(scope: scope, resource_id: resource_id, store_id: store_id)

    response = self.class.get(
      "#{ai_backend_api_url}/api/configurations/#{config_key}",
      query: query_params,
      headers: self.class.headers
    )

    # If configuration doesn't exist yet, return empty hash instead of raising error
    return {} if response.code == 404

    handle_response(response)

    body = response.parsed_response
    body.is_a?(Hash) ? (body.dig('data') || {}) : {}
  end

  # Get all configurations for a resource
  # @param scope [String] Resource scope
  # @param resource_id [Integer/String] Resource ID
  # @param store_id [Integer/String] Store ID (required for agent_system and user scopes)
  # @return [Hash] All configurations grouped by key
  def get_all_configurations(scope:, resource_id:, store_id: nil)
    validate_scope!(scope)

    query_params = build_query_params(scope: scope, resource_id: resource_id, store_id: store_id)

    response = self.class.get(
      "#{ai_backend_api_url}/api/configurations/all",
      query: query_params,
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
  # @param store_id [Integer/String] Store ID (required for agent_system and user scopes)
  # @return [Boolean] Success status
  def delete_configuration(scope:, resource_id:, config_key:, store_id: nil)
    validate_scope!(scope)
    validate_config_key!(config_key)

    query_params = build_query_params(scope: scope, resource_id: resource_id, store_id: store_id)

    response = self.class.delete(
      "#{ai_backend_api_url}/api/configurations/#{config_key}",
      query: query_params,
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

  # Build query parameters based on scope
  # The API expects different parameter names for different scopes:
  # - store -> store_id only
  # - agent_system -> agent_system_id + store_id (for multi-tenant validation)
  # - user -> user_id + store_id (for multi-tenant validation)
  # store_id is ALWAYS required for multi-tenant validation
  def build_query_params(scope:, resource_id:, store_id: nil)
    params = {
      scope: scope,
      id_type: @id_type
    }

    # Add scope-specific resource ID parameter
    case scope
    when AiBackendService::Constants::Scope::STORE
      # For store scope, resource_id IS the store_id
      params[:store_id] = resource_id.to_s
    when AiBackendService::Constants::Scope::AGENT_SYSTEM
      # For agent_system scope, need both agent_system_id and store_id
      params[:agent_system_id] = resource_id.to_s
      params[:store_id] = store_id.to_s
    when AiBackendService::Constants::Scope::USER
      # For user scope, need both user_id and store_id
      params[:user_id] = resource_id.to_s
      params[:store_id] = store_id.to_s
    else
      # Fallback for unknown scopes
      params[:resource_id] = resource_id.to_s
      params[:store_id] = store_id.to_s if store_id
    end

    params
  end

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
      Rails.application.credentials.ai_backend_api_url ||
      'http://localhost:8000'
  end
end
