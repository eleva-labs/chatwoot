# frozen_string_literal: true

class AiBackendService::ChannelService
  class ChannelError < StandardError; end

  def initialize(id_type: AiBackendService::Constants::IdType::EXTERNAL)
    @id_type = id_type
    @base_url = ai_backend_api_url
  end

  # Create channel in AI backend
  # @param inbox [Inbox] The Chatwoot inbox to create
  # @param store_id [Integer] The Chatwoot account.id (used as external_id)
  # @return [Hash] Response from AI backend
  def create_channel(inbox, store_id)
    request_body = AiBackendService::Schemas::ChannelRequest.from_inbox(inbox, store_id).to_h

    response = HTTParty.post(
      "#{@base_url}/api/channels",
      body: request_body.to_json,
      headers: { 'Content-Type' => 'application/json' },
      query: { id_type: @id_type }
    )

    raise ChannelError, "Failed to create channel: #{response.body}" unless response.success?

    JSON.parse(response.body, object_class: OpenStruct)
  rescue StandardError => e
    raise ChannelError, "Channel creation failed: #{e.message}"
  end

  # Get channel from AI backend
  # @param channel_id [Integer] The Chatwoot inbox.id (when id_type=external)
  # @return [Hash] Channel data
  def get_channel(channel_id)
    response = HTTParty.get(
      "#{@base_url}/api/channels/#{channel_id}",
      query: { id_type: @id_type }
    )

    raise ChannelError, "Failed to get channel: #{response.body}" unless response.success?

    JSON.parse(response.body, object_class: OpenStruct)
  rescue StandardError => e
    raise ChannelError, "Channel fetch failed: #{e.message}"
  end

  # Delete channel from AI backend
  # @param channel_id [Integer] The Chatwoot inbox.id
  # @param store_id [Integer] The Chatwoot account.id (for verification)
  # @return [Boolean] true if successful
  def delete_channel(channel_id, store_id)
    response = HTTParty.delete(
      "#{@base_url}/api/channels/#{channel_id}",
      query: { id_type: @id_type, store_id: store_id }
    )

    raise ChannelError, "Failed to delete channel: #{response.body}" unless response.success?

    true
  rescue StandardError => e
    raise ChannelError, "Channel deletion failed: #{e.message}"
  end

  # Update channel in AI backend
  # @param channel_id [Integer] The Chatwoot inbox.id
  # @param attributes [Hash] Attributes to update
  # @return [Hash] Updated channel data
  def update_channel(channel_id, attributes)
    response = HTTParty.patch(
      "#{@base_url}/api/channels/#{channel_id}",
      body: attributes.to_json,
      headers: { 'Content-Type' => 'application/json' },
      query: { id_type: @id_type }
    )

    raise ChannelError, "Failed to update channel: #{response.body}" unless response.success?

    JSON.parse(response.body, object_class: OpenStruct)
  rescue StandardError => e
    raise ChannelError, "Channel update failed: #{e.message}"
  end

  private

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url
  end
end
