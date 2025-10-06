require 'httparty'

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
    store_data = Schemas::StoreRequest.from_account(account, user_email)

    response = self.class.post(
      "#{ai_backend_api_url}/api/stores",
      body: { store: store_data.to_h }.to_json,
      headers: self.class.headers
    )

    handle_response(response)

    Schemas::StoreResponse.from_api(response.parsed_response)
  end

  # Get store by ID (internal UUID or external ID based on id_type)
  def get_store(store_id)
    response = self.class.get(
      "#{ai_backend_api_url}/api/stores/#{store_id}",
      query: { id_type: @id_type },
      headers: self.class.headers
    )

    handle_response(response)

    Schemas::StoreResponse.from_api(response.parsed_response)
  end

  # Update store by ID
  def update_store(store_id, attributes)
    store_data = Schemas::StoreRequest.new(**attributes)

    response = self.class.put(
      "#{ai_backend_api_url}/api/stores/#{store_id}",
      query: { id_type: @id_type },
      body: { store: store_data.to_h }.to_json,
      headers: self.class.headers
    )

    handle_response(response)

    Schemas::StoreResponse.from_api(response.parsed_response)
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

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url
  end
end
