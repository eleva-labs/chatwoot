# frozen_string_literal: true

require 'httparty'

# AiAssistantService - Send messages to AI Backend for AI Assistant feature
#
# This service implements the messaging API integration for the floating AI assistant.
# It uses the /api/messaging/agent-systems/message endpoint with minimal payload approach.
#
# Key Features:
# - Sends only NEW message (backend loads history from DB)
# - Handles user creation if needed
# - Supports conversation continuity via chat_session_id
# - Includes rich context for better AI responses
module AiBackendService
  class AiAssistantService
    include HTTParty

    class ServiceError < StandardError; end
    class UserNotFoundError < ServiceError; end
    class AgentSystemNotFoundError < ServiceError; end
    class OwnershipError < ServiceError; end
    class ValidationError < ServiceError; end
    class ServiceUnavailableError < ServiceError; end

    def initialize
      self.class.base_uri ai_backend_api_url
      self.class.headers({
        'Content-Type' => 'application/json'
      })
    end

    # List chat sessions for a user and agent system
    # @param account_id [Integer] Chatwoot account ID
    # @param user_id [Integer] Chatwoot user ID
    # @param agent_bot_id [Integer] Selected AgentBot ID
    # @param limit [Integer] Maximum number of sessions to return (default: 25)
    # @return [Hash] { sessions: Array, total_count: Integer }
    def list_sessions(account_id:, user_id:, agent_bot_id:, limit: 25)
      query_params = {
        store_id: account_id.to_s,
        user_id: user_id.to_s,
        agent_system_id: agent_bot_id.to_s,
        id_type: 'external'
      }

      url = "#{ai_backend_api_url}/api/messaging/agent-systems/sessions"

      Rails.logger.info(
        "Fetching chat sessions from AI Backend: account_id=#{account_id}, " \
        "user_id=#{user_id}, agent_bot_id=#{agent_bot_id}, limit=#{limit}, url=#{url}"
      )

      response = self.class.get(
        url,
        query: query_params,
        headers: self.class.headers,
        timeout: 10
      )

      Rails.logger.info(
        "AI Backend sessions response: code=#{response&.code}, " \
        "body=#{response&.body&.slice(0, 200)}"
      )

      handle_response(response)

      # Transform response to frontend format
      sessions_data = response.parsed_response
      
      # AI Backend uses camelCase (chatSessions), not snake_case (chat_sessions)
      raw_sessions = sessions_data['chatSessions'] || sessions_data['chat_sessions'] || []
      
      # Transform camelCase to snake_case for controller
      transformed_sessions = raw_sessions.first(limit).map do |session|
        {
          'chat_session_id' => session['chatSessionId'] || session['chat_session_id'],
          'external_id' => session['externalId'] || session['external_id'],
          'is_active' => session['isActive'] || session['is_active'],
          'created_at' => session['createdAt'] || session['created_at'],
          'updated_at' => session['updatedAt'] || session['updated_at']
        }
      end
      
      {
        'sessions' => transformed_sessions,
        'total_count' => sessions_data['totalCount'] || sessions_data['total_count'] || raw_sessions.length
      }
    rescue StandardError => e
      Rails.logger.error(
        "AI Backend list_sessions failed: #{e.class.name} - #{e.message}\n" \
        "Backtrace: #{e.backtrace.first(3).join("\n")}"
      )
      raise ServiceError, "Failed to fetch sessions: #{e.message}"
    end

    # Delete (deactivate) a chat session
    # @param chat_session_id [String] Chat session ID (external)
    # @return [Boolean] true if successful
    def delete_session(chat_session_id:)
      url = "#{ai_backend_api_url}/api/messaging/agent-systems/sessions/#{chat_session_id}"

      Rails.logger.info("Deleting chat session #{chat_session_id}, url=#{url}")

      response = self.class.patch(
        url,
        query: { id_type: 'external' },
        body: { is_active: false }.to_json,
        headers: self.class.headers,
        timeout: 10
      )

      Rails.logger.info(
        "AI Backend delete response: code=#{response&.code}, " \
        "body=#{response&.body&.slice(0, 100)}"
      )

      handle_response(response)

      true # Success
    rescue StandardError => e
      Rails.logger.error(
        "AI Backend delete_session failed: #{e.class.name} - #{e.message}\n" \
        "Backtrace: #{e.backtrace.first(3).join("\n")}"
      )
      raise ServiceError, "Failed to delete session: #{e.message}"
    end

    # Get messages for a specific chat session
    # @param chat_session_id [String] Chat session ID (external)
    # @param limit [Integer, nil] Maximum number of messages to return (nil = all, max 1000)
    # @return [Hash] { messages: Array, total_count: Integer }
    def get_session_messages(chat_session_id:, limit: nil)
      query_params = { id_type: 'external' }
      query_params[:limit] = limit if limit

      url = "#{ai_backend_api_url}/api/messaging/agent-systems/sessions/#{chat_session_id}/messages"

      Rails.logger.info(
        "Fetching messages for session #{chat_session_id} (limit: #{limit || 'all'}), url=#{url}"
      )

      response = self.class.get(
        url,
        query: query_params,
        headers: self.class.headers,
        timeout: 10
      )

      Rails.logger.info(
        "AI Backend messages response: code=#{response&.code}, " \
        "body=#{response&.body&.slice(0, 200)}"
      )

      handle_response(response)

      # Transform response to frontend format
      messages_data = response.parsed_response
      raw_messages = messages_data['messages'] || []
      
      # Transform camelCase to snake_case for controller
      transformed_messages = raw_messages.map do |msg|
        {
          'id' => msg['id'],
          'external_id' => msg['externalId'] || msg['external_id'],
          'message_role' => msg['messageRole'] || msg['message_role'],
          'content' => msg['content'],
          'sent_date' => msg['sentDate'] || msg['sent_date'],
          'has_media' => msg['hasMedia'] || msg['has_media']
        }
      end
      
      {
        'messages' => transformed_messages,
        'total_count' => messages_data['totalCount'] || messages_data['total_count'] || raw_messages.length
      }
    rescue StandardError => e
      Rails.logger.error(
        "AI Backend get_session_messages failed: #{e.class.name} - #{e.message}\n" \
        "Backtrace: #{e.backtrace.first(3).join("\n")}"
      )
      raise ServiceError, "Failed to fetch messages: #{e.message}"
    end

    # Send message to AI Backend
    # @param account_id [Integer] Chatwoot account ID
    # @param user_id [Integer] Chatwoot user ID
    # @param agent_bot_id [Integer] Selected AgentBot ID
    # @param message [String] User message text
    # @param chat_session_id [String, nil] Optional session ID for continuity
    # @return [Hash] { 'response_text' => String, 'chat_session_id' => String }
    def send_message(account_id:, user_id:, agent_bot_id:, message:, chat_session_id: nil)
      # Build request body (Approach 3: Minimal - only new message)
      body = build_request_body(message, user_id, chat_session_id)

      # Build query parameters
      query_params = {
        store_id: account_id.to_s,
        agent_system_id: agent_bot_id.to_s,
        user_id: user_id.to_s,
        id_type: 'external'
      }

      Rails.logger.info(
        "Sending message to AI Backend: account_id=#{account_id}, user_id=#{user_id}, " \
        "agent_bot_id=#{agent_bot_id}, has_session=#{chat_session_id.present?}"
      )

      # Make API call with retry logic for user creation
      response = make_api_call_with_retry(query_params, body, account_id, user_id)

      # Parse and transform response
      parse_response(response)
    rescue UserNotFoundError, AgentSystemNotFoundError, OwnershipError,
           ValidationError, ServiceUnavailableError => e
      # Re-raise specific errors for controller handling
      raise
    rescue StandardError => e
      Rails.logger.error("AI Backend API call failed: #{e.message}", error: e.class.name)
      raise ServiceError, e.message
    end

    private

    # Build request body according to Approach 3 (Minimal)
    def build_request_body(message, user_id, chat_session_id)
      user = User.find(user_id)

      body = {
        agentInput: {
          messages: [message], # ✅ Array with ONLY the new message
          context: {
            sender: {
              id: user.id,
              name: user.name,
              email: user.email
            },
            event: 'message_created'
          }
        }
      }

      # Include session ID if provided (for conversation continuity)
      body[:chatSessionId] = chat_session_id if chat_session_id.present?

      body
    end

    # Make API call with retry logic for user not found errors
    def make_api_call_with_retry(query_params, body, account_id, user_id)
      attempts = 0
      max_attempts = 2

      begin
        response = self.class.post(
          "#{ai_backend_api_url}/api/messaging/agent-systems/message",
          query: query_params,
          body: body.to_json,
          headers: self.class.headers,
          timeout: 60 # 60 second timeout for AI processing
        )

        handle_response(response)
        response
      rescue UserNotFoundError => e
        if attempts < max_attempts
          Rails.logger.info("User not found, attempting to create: #{e.message}")
          ensure_user_exists(user_id, account_id)
          attempts += 1
          retry
        end
        raise
      end
    end

    # Ensure user exists in AI Backend (proactive creation)
    def ensure_user_exists(user_id, account_id)
      user = User.find(user_id)
      user_service = AiBackendService::UserService.new

      user_service.create_user(user, account_id)
    rescue StandardError => e
      Rails.logger.warn("User creation failed (might already exist): #{e.message}")
      # Continue anyway - user might already exist
    end

    # Handle HTTP response and raise appropriate errors
    def handle_response(response)
      # Check for nil or empty response (connection failure)
      if response.nil? || response.body.nil? || response.body.empty?
        Rails.logger.error('AI Backend response is nil or empty - connection failed')
        raise ServiceUnavailableError, 'AI Backend connection failed'
      end

      # Check for response code
      unless response.respond_to?(:code)
        Rails.logger.error("AI Backend response has no code: #{response.inspect}")
        raise ServiceError, 'Invalid response from AI Backend'
      end

      case response.code
      when 404
        error_detail = response.parsed_response&.dig('detail') || 'Resource not found'

        # Specific handling for different 404 cases
        if error_detail.include?('User not found') || error_detail.include?('user')
          raise UserNotFoundError, error_detail
        elsif error_detail.include?('Agent system not found') || error_detail.include?('agent_system')
          raise AgentSystemNotFoundError, error_detail
        elsif error_detail.include?('ownership') || error_detail.include?('belong')
          raise OwnershipError, error_detail
        else
          raise ServiceError, error_detail
        end

      when 400
        error_detail = response.parsed_response&.dig('detail') || response.body
        raise ValidationError, "Bad request: #{error_detail}"

      when 503, 500..599
        raise ServiceUnavailableError, "AI service unavailable (#{response.code})"

      when 200..299
        # Success - validate response structure
        unless response.parsed_response.is_a?(Hash)
          raise ServiceError, 'Invalid response format from AI Backend'
        end

      else
        raise ServiceError, "Unexpected error: #{response.code}"
      end
    end

    # Parse AI Backend response to expected format
    # Backend returns: { agentOutput: { textResponse: "..." }, chatSessionId: "..." }
    # We transform to: { response_text: "...", chat_session_id: "..." }
    def parse_response(response)
      result = response.parsed_response

      {
        'response_text' => result['agentOutput']['textResponse'],
        'chat_session_id' => result['chatSessionId']
      }
    rescue StandardError => e
      Rails.logger.error("Failed to parse AI Backend response: #{e.message}")
      raise ServiceError, "Invalid response format: #{e.message}"
    end

    def ai_backend_api_url
      Rails.application.config.ai_backend_api_url ||
        ENV['AI_BACKEND_URL'] ||
        Rails.application.credentials.ai_backend_api_url ||
        'http://localhost:8000'
    end
  end
end

