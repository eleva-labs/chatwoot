require 'httparty'

# StoreService - Manage stores in AI Backend (mapped to Chatwoot accounts)
#
# IMPORTANT: Defaults to id_type=external, using Chatwoot account.id
# - create_store(account, email) - Creates store with external_id = account.id
# - get_store(account_id) - Gets store by Chatwoot account.id
# - update_store(account_id, attrs) - Updates store by Chatwoot account.id
class AiBackendService::StoreService
  include HTTParty

  class StoreError < StandardError; end

  def initialize(id_type: AiBackendService::Constants::IdType::EXTERNAL)
    @id_type = id_type
    self.class.base_uri ai_backend_api_url
    self.class.headers({
                         'Content-Type' => 'application/json',
                         'Authorization' => 'application/json'
                       })
  end

  # Create store with external_id (Chatwoot account.id)
  def create_store(account, user_email)
    store_data = AiBackendService::Schemas::StoreRequest.from_account(account, user_email)

    response = self.class.post(
      "#{ai_backend_api_url}/api/stores",
      body: store_data.to_h.to_json,
      headers: self.class.headers
    )

    handle_response(response)

    AiBackendService::Schemas::StoreResponse.from_api(response.parsed_response)
  end

  # Get store by ID (internal UUID or external ID based on id_type)
  def get_store(store_id)
    response = self.class.get(
      "#{ai_backend_api_url}/api/stores/#{store_id}",
      query: { id_type: @id_type },
      headers: self.class.headers
    )

    handle_response(response)

    AiBackendService::Schemas::StoreResponse.from_api(response.parsed_response)
  end

  # Update store by ID
  def update_store(store_id, attributes)
    store_data = AiBackendService::Schemas::StoreRequest.new(**attributes)

    response = self.class.put(
      "#{ai_backend_api_url}/api/stores/#{store_id}",
      query: { id_type: @id_type },
      body: store_data.to_h.to_json,
      headers: self.class.headers
    )

    handle_response(response)

    AiBackendService::Schemas::StoreResponse.from_api(response.parsed_response)
  end

  # Delete store by ID (idempotent - 404 returns true)
  # @param store_id [String, Integer] Store identifier
  # @param cascade [Boolean] If true, also delete related users and agent-systems (default: true)
  def delete_store(store_id, cascade: true)
    response = self.class.delete(
      "#{ai_backend_api_url}/api/stores/#{store_id}",
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
      raise StoreError, "Store not found: #{response.request.last_uri}"
    when 400
      raise StoreError, "Bad request: #{response.code} - #{response.body}"
    when 200..299
      # Success
    else
      raise StoreError, "Unexpected error: #{response.code} - #{response.body}"
    end
  end

  def handle_delete_response(response)
    case response.code
    when 404
      # Store already deleted - idempotent success
      Rails.logger.info('Store already deleted (404) - treating as success')
    when 400
      raise StoreError, "Bad request: #{response.code} - #{response.body}"
    when 200..299
      # Success
    else
      raise StoreError, "Unexpected error: #{response.code} - #{response.body}"
    end
  end

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url ||
      'http://localhost:8000'
  end
end
