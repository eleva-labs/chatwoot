class Api::V1::Accounts::AiChatController < Api::V1::Accounts::BaseController
  include ActionController::Live

  # Stream endpoint - proxies SSE from Python backend to Vue frontend
  def stream
    # Validate required parameters
    last_message = params[:messages]&.last
    return render json: { error: 'No message provided' }, status: :bad_request if last_message.blank?

    agent_bot_id = params[:agent_bot_id]
    return render json: { error: 'No agent bot selected' }, status: :bad_request if agent_bot_id.blank?

    # Validate bot belongs to current account
    agent_bot = Current.account.agent_bots.find_by(id: agent_bot_id)
    return render json: { error: 'Agent bot not found' }, status: :not_found unless agent_bot

    # Set SSE headers
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no' # Disable nginx buffering
    # Vercel AI / standard protocol hint headers for mobile client parsers
    response.headers['x-vercel-ai-ui-message-stream'] = 'v1'
    response.headers['x-ai-streaming-protocol'] = 'v1'

    # Build request body (same format as non-streaming endpoint)
    request_body = {
      agentInput: {
        messages: [last_message[:content]],
        context: {
          sender: {
            id: Current.user.id,
            name: Current.user.name,
            email: Current.user.email
          },
          event: 'message_created'
        }
      }
    }

    # Include session ID if provided
    request_body[:chatSessionId] = params[:chat_session_id] if params[:chat_session_id].present?

    # Build query parameters for Python backend
    query_params = {
      store_id: Current.account.id.to_s,
      agent_system_id: agent_bot_id.to_s,
      user_id: Current.user.id.to_s,
      id_type: 'external'
    }

    # Proxy streaming request to Python backend using Net::HTTP
    uri = URI("#{ENV['AI_BACKEND_URL']}/api/messaging/agent-systems/message/stream")
    uri.query = URI.encode_www_form(query_params)

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'text/event-stream'
      request.body = request_body.to_json

      http.request(request) do |backend_response|
        # Extract session ID from backend response headers
        session_id = backend_response['X-Chat-Session-Id']
        response.headers['X-Chat-Session-Id'] = session_id if session_id.present?

        Rails.logger.info("[AI Streaming Proxy] Starting stream for account=#{Current.account.id}, user=#{Current.user.id}, bot=#{agent_bot_id}")

        # Stream chunks from backend to frontend
        chunk_count = 0
        backend_response.read_body do |chunk|
          chunk_count += 1
          
          # Log received chunk (truncate if too long)
          chunk_preview = chunk.length > 200 ? "#{chunk[0..200]}..." : chunk
          Rails.logger.info("[AI Streaming Proxy] Chunk ##{chunk_count} received (#{chunk.bytesize} bytes): #{chunk_preview}")
          
          # Parse and log event type if it's SSE format
          if chunk.include?('event:')
            event_match = chunk.match(/event:\s*(\S+)/)
            Rails.logger.info("[AI Streaming Proxy] Event type detected: #{event_match[1]}") if event_match
          end
          
          # Forward chunk to frontend
          response.stream.write chunk
          Rails.logger.info("[AI Streaming Proxy] Chunk ##{chunk_count} forwarded to frontend")
        rescue IOError => e
          # Client disconnected - stop streaming
          Rails.logger.info("[AI Streaming Proxy] Client disconnected during streaming: #{e.message}")
          break
        end
        
        Rails.logger.info("[AI Streaming Proxy] Stream completed. Total chunks: #{chunk_count}")
      end
    end
  rescue StandardError => e
    Rails.logger.error("Streaming error: #{e.message}")
    # Send error event in SSE format
    error_event = "event: error\ndata: {\"error\":\"#{e.message}\"}\n\n"
    response.stream.write error_event rescue nil # Ignore if stream already closed
  ensure
    response.stream.close rescue nil # Ensure stream is closed
  end

  def create
    # Validate required parameters
    last_message = params[:messages]&.last
    return render json: { error: 'No message provided' }, status: :bad_request if last_message.blank?

    agent_bot_id = params[:agent_bot_id]
    return render json: { error: 'No agent bot selected' }, status: :bad_request if agent_bot_id.blank?

    # Validate bot belongs to current account
    agent_bot = Current.account.agent_bots.find_by(id: agent_bot_id)
    return render json: { error: 'Agent bot not found' }, status: :not_found unless agent_bot

    # Call AI Backend service
    service = AiBackendService::AiAssistantService.new
    result = service.send_message(
      account_id: Current.account.id,
      user_id: Current.user.id,
      agent_bot_id: agent_bot.id,
      message: last_message[:content],
      chat_session_id: params[:chat_session_id] # Optional, from frontend
    )

    render json: {
      response: result['response_text'],
      session_id: result['chat_session_id']
    }
  rescue AiBackendService::AiAssistantService::UserNotFoundError => e
    Rails.logger.error("User not found in AI Backend: #{e.message}")
    render json: { error: 'User account not found in AI system. Please contact support.' }, status: :not_found

  rescue AiBackendService::AiAssistantService::AgentSystemNotFoundError => e
    Rails.logger.error("Agent system not found: #{e.message}")
    render json: { error: 'Selected AI bot is no longer available' }, status: :not_found

  rescue AiBackendService::AiAssistantService::OwnershipError => e
    Rails.logger.error("Ownership violation: #{e.message}")
    render json: { error: 'Access denied to AI bot' }, status: :forbidden

  rescue AiBackendService::AiAssistantService::ValidationError => e
    Rails.logger.error("Validation error: #{e.message}")
    render json: { error: "Invalid request: #{e.message}" }, status: :bad_request

  rescue AiBackendService::AiAssistantService::ServiceUnavailableError => e
    Rails.logger.error("AI Backend unavailable: #{e.message}")
    render json: { error: 'AI service temporarily unavailable. Please try again later.' }, status: :service_unavailable

  rescue AiBackendService::AiAssistantService::ServiceError => e
    Rails.logger.error("AI Backend error: #{e.message}")
    render json: { error: 'AI service error. Please try again.' }, status: :internal_server_error
  end

  # List available bots (Hybrid: AI Backend + Chatwoot enrichment)
  def bots
    service = AiBackendService::AgentSystemService.new

    # PRIMARY: Fetch from AI Backend (source of truth)
    # Only show active bots that are fully configured
    agent_systems = service.list_agent_systems(
      store_id: Current.account.id,
      is_active: true # Only active, configured bots
    )

    # ENRICHMENT: Add avatar URLs from Chatwoot
    enriched_bots = enrich_with_chatwoot_avatars(agent_systems)

    render json: { bots: enriched_bots }
  rescue AiBackendService::AgentSystemService::AgentSystemError => e
    Rails.logger.error("Failed to fetch bots from AI Backend: #{e.message}")
    render json: {
      error: 'AI service temporarily unavailable. Please try again.'
    }, status: :service_unavailable
  end

  # List chat sessions for a user and bot
  # GET /api/v1/accounts/:account_id/ai_chat/sessions
  # Params: agent_bot_id (required), limit (optional, default 25)
  def sessions
    agent_bot_id = params[:agent_bot_id]
    return render json: { error: 'No agent bot selected' }, status: :bad_request if agent_bot_id.blank?

    # Validate bot belongs to account
    agent_bot = Current.account.agent_bots.find_by(id: agent_bot_id)
    return render json: { error: 'Agent bot not found' }, status: :not_found unless agent_bot

    limit = (params[:limit] || 25).to_i
    limit = [[limit, 1].max, 100].min # Clamp between 1-100

    service = AiBackendService::AiAssistantService.new
    result = service.list_sessions(
      account_id: Current.account.id,
      user_id: Current.user.id,
      agent_bot_id: agent_bot.id,
      limit: limit
    )

    render json: {
      sessions: result['sessions'],
      total_count: result['total_count'],
      limit: limit
    }
  rescue AiBackendService::AiAssistantService::ServiceError => e
    Rails.logger.error("Failed to fetch sessions: #{e.message}")
    render json: { error: 'Failed to load conversation history' }, status: :service_unavailable
  end

  # Get messages for a specific chat session
  # GET /api/v1/accounts/:account_id/ai_chat/sessions/:session_id/messages
  # Params: limit (optional, default nil = all messages)
  def session_messages
    session_id = params[:session_id]
    return render json: { error: 'No session ID provided' }, status: :bad_request if session_id.blank?

    limit = params[:limit]&.to_i

    service = AiBackendService::AiAssistantService.new
    result = service.get_session_messages(
      chat_session_id: session_id,
      limit: limit
    )

    # Transform to frontend format
    transformed_messages = (result['messages'] || []).map do |msg|
      {
        id: msg['id'] || msg['external_id'],
        role: msg['message_role'],
        content: msg['content'],
        timestamp: msg['sent_date']
      }
    end

    render json: {
      messages: transformed_messages,
      total_count: result['total_count']
    }
  rescue AiBackendService::AiAssistantService::ServiceError => e
    Rails.logger.error("Failed to fetch messages: #{e.message}")
    render json: { error: 'Failed to load messages' }, status: :service_unavailable
  end

  # Delete (deactivate) a chat session
  # DELETE /api/v1/accounts/:account_id/ai_chat/sessions/:session_id
  def delete_session
    session_id = params[:session_id]
    return render json: { error: 'No session ID provided' }, status: :bad_request if session_id.blank?

    service = AiBackendService::AiAssistantService.new
    service.delete_session(chat_session_id: session_id)

    render json: { success: true, message: 'Conversation deleted successfully' }
  rescue AiBackendService::AiAssistantService::ServiceError => e
    Rails.logger.error("Failed to delete session: #{e.message}")
    render json: { error: 'Failed to delete conversation' }, status: :service_unavailable
  end

  private

  # Enrich AI Backend data with Chatwoot avatar URLs
  def enrich_with_chatwoot_avatars(agent_systems)
    return [] if agent_systems.empty?

    # Get external_ids (Chatwoot agent_bot IDs)
    bot_ids = agent_systems.map { |sys| sys['externalId'].to_i }

    # Batch fetch avatar URLs from Chatwoot (local DB - fast)
    agent_bots = AgentBot.where(id: bot_ids)
                         .select(:id, :name, :avatar_url)

    # Create lookup map: id => agent_bot
    avatar_lookup = agent_bots.index_by(&:id)

    # Merge data: AI Backend (primary) + Chatwoot avatars (enrichment)
    agent_systems.map do |agent_system|
      bot_id = agent_system['externalId'].to_i
      agent_bot = avatar_lookup[bot_id]

      {
        id: bot_id,
        name: agent_system['name'],
        description: agent_system['description'],
        is_active: agent_system['isActive'],
        workflows: agent_system['workflows']&.map { |w| w['name'] }&.join(', '),
        # Enrichment from Chatwoot
        avatar_url: agent_bot&.avatar_url
      }
    end
  rescue StandardError => e
    Rails.logger.warn("Failed to enrich with avatars: #{e.message}")
    # Graceful degradation: Return AI Backend data without avatars
    agent_systems.map do |agent_system|
      {
        id: agent_system['externalId'].to_i,
        name: agent_system['name'],
        description: agent_system['description'],
        is_active: agent_system['isActive'],
        workflows: agent_system['workflows']&.map { |w| w['name'] }&.join(', '),
        avatar_url: nil # No avatar if enrichment fails
      }
    end
  end
end