# frozen_string_literal: true

require 'httparty'

# UserService - Manage users in AI Backend (mapped to Chatwoot users)
#
# IMPORTANT: Defaults to id_type=external, using Chatwoot user.id
# - create_user(user, store_id) - Creates user with external_id = user.id
#   * store_id MUST be account.id (Chatwoot account ID), NOT the AI Backend UUID
# - get_user(user_id) - Gets user by Chatwoot user.id
class AiBackendService::UserService
  include HTTParty

  class UserError < StandardError; end

  def initialize(id_type: AiBackendService::Constants::IdType::EXTERNAL)
    @id_type = id_type
    self.class.base_uri ai_backend_api_url
    self.class.headers({
                         'Content-Type' => 'application/json',
                         'Authorization' => 'application/json'
                       })
  end

  # Create user with external_id (Chatwoot user.id)
  def create_user(user, store_id)
    user_data = AiBackendService::Schemas::UserRequest.from_user(user, store_id)

    response = self.class.post(
      "#{ai_backend_api_url}/api/users",
      query: { store_id: store_id.to_s, id_type: @id_type },
      body: user_data.to_h.to_json,
      headers: self.class.headers
    )

    handle_response(response)

    response.parsed_response
  end

  # Get user by ID (internal UUID or external ID based on id_type)
  def get_user(user_id)
    response = self.class.get(
      "#{ai_backend_api_url}/api/users/#{user_id}",
      query: { id_type: @id_type },
      headers: self.class.headers
    )

    handle_response(response)

    response.parsed_response
  end

  # Delete user by ID (idempotent - 404 returns true)
  # @param user_id [String, Integer] User identifier
  # @param store_id [String, Integer] Store identifier (account_id)
  def delete_user(user_id, store_id)
    response = self.class.delete(
      "#{ai_backend_api_url}/api/users/#{user_id}",
      query: { id_type: @id_type, store_id: store_id.to_s },
      headers: self.class.headers
    )

    handle_delete_response(response)
    true
  end

  private

  def handle_response(response)
    case response.code
    when 404
      raise UserError, "User not found: #{response.request.last_uri}"
    when 400
      raise UserError, "Bad request: #{response.code} - #{response.body}"
    when 200..299
      # Success
    else
      raise UserError, "Unexpected error: #{response.code} - #{response.body}"
    end
  end

  def handle_delete_response(response)
    case response.code
    when 404
      # User already deleted - idempotent success
      Rails.logger.info('User already deleted (404) - treating as success')
    when 400
      raise UserError, "Bad request: #{response.code} - #{response.body}"
    when 200..299
      # Success
    else
      raise UserError, "Unexpected error: #{response.code} - #{response.body}"
    end
  end

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url ||
      'http://localhost:8000'
  end
end
