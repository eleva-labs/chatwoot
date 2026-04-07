class Api::V1::Accounts::AiChatController < Api::V1::Accounts::BaseController
  include ActionController::Live

  before_action :validate_message, only: [:stream, :create]
  before_action :validate_and_set_agent_bot, only: [:stream, :create]

  # Stream endpoint - SSE streaming via service
  def stream
    setup_sse_headers

    session_id_set = false

    messaging_service.stream_message(
      account_id: Current.account.id,
      user_id: Current.user.id,
      agent_bot_id: @agent_bot.id,
      message: @message_content,
      chat_session_id: params[:chat_session_id],
      chat_mode: params[:chat_mode] || 'admin'
    ) do |chunk, session_id|
      # Set session ID header (before first write commits headers)
      if session_id.present? && !session_id_set
        response.headers['X-Chat-Session-Id'] = session_id
        session_id_set = true
      end
      response.stream.write(chunk)
    end
  rescue IOError => e
    Rails.logger.info("[AiChat] Client disconnected: #{e.message}")
  rescue AiBackendService::AgentSystemMessagingService::UserNotFoundError
    write_sse_error('User account not found in AI system', 'USER_NOT_FOUND')
  rescue AiBackendService::AgentSystemMessagingService::AgentSystemNotFoundError
    write_sse_error('Selected AI bot is no longer available', 'BOT_NOT_FOUND')
  rescue AiBackendService::AgentSystemMessagingService::ServiceUnavailableError
    write_sse_error('AI service temporarily unavailable', 'SERVICE_UNAVAILABLE')
  rescue AiBackendService::AgentSystemMessagingService::ServiceError => e
    Rails.logger.error("[AiChat] Streaming error: #{e.message}")
    write_sse_error(e.message, 'STREAM_ERROR')
  ensure
    begin
      response.stream.close
    rescue StandardError
      nil
    end
  end

  def create
    result = messaging_service.send_message(
      account_id: Current.account.id,
      user_id: Current.user.id,
      agent_bot_id: @agent_bot.id,
      message: @message_content,
      chat_session_id: params[:chat_session_id]
    )

    render json: {
      response: result['response_text'],
      session_id: result['chat_session_id']
    }
  rescue AiBackendService::AgentSystemMessagingService::UserNotFoundError => e
    Rails.logger.error("User not found in AI Backend: #{e.message}")
    render_error('User account not found in AI system. Please contact support.', :not_found)
  rescue AiBackendService::AgentSystemMessagingService::AgentSystemNotFoundError => e
    Rails.logger.error("Agent system not found: #{e.message}")
    render_error('Selected AI bot is no longer available', :not_found)
  rescue AiBackendService::AgentSystemMessagingService::OwnershipError => e
    Rails.logger.error("Ownership violation: #{e.message}")
    render_error('Access denied to AI bot', :forbidden)
  rescue AiBackendService::AgentSystemMessagingService::ValidationError => e
    Rails.logger.error("Validation error: #{e.message}")
    render_error("Invalid request: #{e.message}", :bad_request)
  rescue AiBackendService::AgentSystemMessagingService::ServiceUnavailableError => e
    Rails.logger.error("AI Backend unavailable: #{e.message}")
    render_error('AI service temporarily unavailable. Please try again later.', :service_unavailable)
  rescue AiBackendService::AgentSystemMessagingService::ServiceError => e
    Rails.logger.error("AI Backend error: #{e.message}")
    render_error('AI service error. Please try again.', :internal_server_error)
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

    service = AiBackendService::AgentSystemMessagingService.new
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
  rescue AiBackendService::AgentSystemMessagingService::ServiceError => e
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

    service = AiBackendService::AgentSystemMessagingService.new
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
  rescue AiBackendService::AgentSystemMessagingService::ServiceError => e
    Rails.logger.error("Failed to fetch messages: #{e.message}")
    render json: { error: 'Failed to load messages' }, status: :service_unavailable
  end

  # Delete (deactivate) a chat session
  # DELETE /api/v1/accounts/:account_id/ai_chat/sessions/:session_id
  def delete_session
    session_id = params[:session_id]
    return render json: { error: 'No session ID provided' }, status: :bad_request if session_id.blank?

    service = AiBackendService::AgentSystemMessagingService.new
    service.delete_session(chat_session_id: session_id)

    render json: { success: true, message: 'Conversation deleted successfully' }
  rescue AiBackendService::AgentSystemMessagingService::ServiceError => e
    Rails.logger.error("Failed to delete session: #{e.message}")
    render json: { error: 'Failed to delete conversation' }, status: :service_unavailable
  end

  private

  def messaging_service
    @messaging_service ||= AiBackendService::AgentSystemMessagingService.new
  end

  def validate_message
    @message_content = params.dig(:messages, -1, :content) || params[:messages]&.last&.dig('content')
    render_error('No message provided', :bad_request) if @message_content.blank?
  end

  def validate_and_set_agent_bot
    agent_bot_id = params[:agent_bot_id]
    return render_error('No agent bot selected', :bad_request) if agent_bot_id.blank?

    @agent_bot = Current.account.agent_bots.find_by(id: agent_bot_id)
    return render_error('Agent bot not found', :not_found) unless @agent_bot
  end

  def setup_sse_headers
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'
    response.headers['x-vercel-ai-ui-message-stream'] = 'v1'
    response.headers['x-ai-streaming-protocol'] = 'v1'
  end

  def write_sse_error(message, code)
    error_data = { type: 'error', errorText: message, errorCode: code }
    begin
      response.stream.write("data: #{error_data.to_json}\n\n")
    rescue StandardError
      nil
    end
  end

  def render_error(message, status)
    render json: { error: message }, status: status
  end

  # Enrich AI Backend data with Chatwoot avatar URLs
  def enrich_with_chatwoot_avatars(agent_systems)
    return [] if agent_systems.empty?

    # Get external_ids (Chatwoot agent_bot IDs)
    bot_ids = agent_systems.map { |sys| sys['externalId'].to_i }

    # Batch fetch avatar URLs from Chatwoot (local DB - fast)
    # Note: Can't use select(:avatar_url) because it's a method from Avatarable, not a column
    agent_bots = AgentBot.where(id: bot_ids).with_attached_avatar

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
