class Api::V1::Accounts::WhapiChannelsController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox, only: [:retry_webhook, :reauthorize, :initiate_reconnection]
  before_action :ensure_whapi_partner_feature_enabled

  rescue_from CustomExceptions::RateLimitExceeded do |exception|
    correlation_id = request.request_id || SecureRandom.uuid
    Rails.logger.warn "[WhapiPartner][RateLimit][#{correlation_id}] #{exception.message}"
    render json: { 
      message: exception.message, 
      correlation_id: correlation_id 
    }, status: :too_many_requests
  end

  # POST /api/v1/accounts/:account_id/whapi_channels
  def create
    correlation_id = request.request_id || SecureRandom.uuid
    ActiveSupport::Notifications.instrument('whapi.onboarding', action: 'create_channel.start', account_id: Current.account.id,
                                                                correlation_id: correlation_id)

    name = whapi_channel_params[:name].to_s.strip
    if name.blank?
      ActiveSupport::Notifications.instrument('whapi.onboarding', action: 'create_channel.invalid', reason: 'missing_name',
                                                                  account_id: Current.account.id, correlation_id: correlation_id)
      render_error('name is required', correlation_id: correlation_id) and return
    end

    # Basic input validation & sanitization
    # Allow letters, numbers, spaces, hyphens and underscores. Enforce length 2..80
    unless name.match?(/\A[\p{Alnum} _-]{2,80}\z/u)
      ActiveSupport::Notifications.instrument('whapi.onboarding', action: 'create_channel.invalid', reason: 'invalid_name',
                                                                  account_id: Current.account.id, correlation_id: correlation_id)
      render_error('invalid name', correlation_id: correlation_id) and return
    end

    service = Whatsapp::Partner::WhapiPartnerService.new

    # Determine project id with multiple fallbacks
    # 1) explicit param, 2) installation default via env, 3) partner API projects list
    explicit_project_id = whapi_channel_params[:project_id].presence
    default_project_id = ENV['WHAPI_PARTNER_DEFAULT_PROJECT_ID'].presence

    projects = begin
      service.fetch_projects
    rescue CustomExceptions::RateLimitExceeded => e
      Rails.logger.warn "[WhapiPartner][#{correlation_id}] Project fetch rate limited: #{e.message}"
      raise e # Re-raise to be handled by rescue_from
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      Rails.logger.warn "[WhapiPartner][#{correlation_id}] Project fetch timeout: #{e.message}"
      [] # Empty array is acceptable for timeout - user can retry
    rescue HTTParty::Error, Net::HTTPError => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Project fetch HTTP error: #{e.message}"
      [] # Empty array for HTTP errors - fallback to env defaults
    rescue JSON::ParserError => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Project fetch JSON parse error: #{e.message}"
      [] # Empty array for parsing errors - API response malformed
    rescue StandardError => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Unexpected project fetch error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Re-raise unknown errors to fail fast and alert monitoring
      raise e
    end
    first_project = Array(projects).first
    project_list_id = first_project.is_a?(Hash) ? first_project['id'] : nil

    project_id = explicit_project_id || default_project_id || project_list_id
    unless project_id.present?
      ActiveSupport::Notifications.instrument('whapi.onboarding', action: 'create_channel.unavailable', reason: 'no_projects',
                                                                  account_id: Current.account.id, correlation_id: correlation_id)
      render_error('No partner projects available', correlation_id: correlation_id) and return
    end

    # Generate environment-specific webhook URL
    webhook_service = Whatsapp::WebhookUrlService.new
    webhook_url = webhook_service.generate_webhook_url

    channel_info = begin
      service.create_channel(name: name, project_id: project_id)
    rescue CustomExceptions::RateLimitExceeded => e
      Rails.logger.warn "[WhapiPartner][#{correlation_id}] Channel creation rate limited: #{e.message}"
      raise e # Re-raise to be handled by rescue_from
    rescue StandardError => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Channel creation failed: #{e.message}"
      raise e
    end
    whapi_channel_id = channel_info['id']
    whapi_channel_token = channel_info['token']

    provider_config = {
      'api_key' => whapi_channel_token,
      'whapi_channel_id' => whapi_channel_id,
      'whapi_channel_token' => whapi_channel_token,
      'webhook_url' => webhook_url,
      'connection_status' => 'pending',
      'onboarding' => {
        'created_at' => Time.current.iso8601
      }
    }

    ActiveRecord::Base.transaction do
      channel = Current.account.whatsapp_channels.create!(
        phone_number: "pending:#{whapi_channel_id}",
        provider: 'whapi',
        provider_config: provider_config
      )

      @inbox = Current.account.inboxes.build(name: name, channel: channel)
      @inbox.save!
    end

    # Configure webhook at channel level (critical for message sync) - moved to background job
    Whatsapp::Whapi::WebhookSetupJob.perform_later(@inbox.channel.id)

    ActiveSupport::Notifications.instrument('whapi.onboarding', action: 'create_channel.success', account_id: Current.account.id,
                                                                inbox_id: @inbox.id, channel_id: @inbox.channel_id, correlation_id: correlation_id)

    render 'api/v1/accounts/inboxes/show', format: :json, status: :ok
  rescue StandardError => e
    Rails.logger.error "[WhapiPartner][#{correlation_id}] whapi_channel creation failed: #{e.message}"
    ActiveSupport::Notifications.instrument('whapi.onboarding', action: 'create_channel.error', account_id: Current.account.id, error: e.class.name,
                                                                message: e.message, correlation_id: correlation_id)
    render_error(e.message, correlation_id: correlation_id)
  end

  # POST /api/v1/accounts/:account_id/whapi_channels/:id/reauthorize
  def reauthorize
    correlation_id = request.request_id || SecureRandom.uuid
    channel = @inbox.channel

    unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'whapi'
      render_error('Not a WHAPI WhatsApp inbox', correlation_id: correlation_id)
      return
    end

    # Verify channel has required configuration
    channel_token = channel.provider_config_object&.whapi_channel_token || channel.provider_config_object&.api_key
    if channel_token.blank?
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Reauthorize failed: channel token missing for channel #{channel.id}"
      render_error('Channel configuration is missing. Please recreate the channel.', correlation_id: correlation_id)
      return
    end

    # Verify channel is actually connected before clearing reauthorization
    begin
      health_response = check_channel_health(channel)
    rescue StandardError => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Health check error during reauthorize: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      render_error('Failed to check channel health. Please try again.', status: :internal_server_error, correlation_id: correlation_id)
      return
    end

    if health_response[:connected]
      begin
        channel.reauthorized!
        channel.provider_config_object.update_connection_status('connected')

        render json: {
          success: true,
          message: 'Channel reauthorized successfully',
          correlation_id: correlation_id
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "[WhapiPartner][#{correlation_id}] Error updating channel status: #{e.class} - #{e.message}"
        render json: {
          success: false,
          message: 'Channel is connected but failed to update status. Please refresh the page.',
          correlation_id: correlation_id
        }, status: :internal_server_error
      end
    else
      render json: {
        success: false,
        message: 'Channel is not connected. Please scan QR code first.',
        status: health_response[:status],
        correlation_id: correlation_id
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/accounts/:account_id/whapi_channels/:id/initiate_reconnection
  # Webhook-driven reconnection flow - triggers channel wakeup and returns immediately
  # QR code will be delivered via ActionCable when channel reaches QR state
  #
  # Endpoint Contract:
  # This endpoint has three possible response paths:
  #
  # 1. Already Connected (200 OK):
  #    Returns: { status: 'connected', whapi_status: 'AUTH', message: 'Already connected', correlation_id: <id> }
  #    Triggered when: Channel health check confirms connection (status == 'AUTH')
  #    Action: Updates channel status, clears reauthorization state, schedules phone sync
  #
  # 2. QR Code Available (200 OK):
  #    Returns: { image_base64: <string>, expires_in: <number>, poll_in: 15, correlation_id: <id> }
  #    Triggered when: Channel is already in QR state (status == 'QR') and QR code can be fetched immediately
  #    Action: Returns QR code directly without waiting for webhook
  #
  # 3. Webhook-Driven (200 OK):
  #    Returns: { status: 'starting', whapi_status: <current_status>, message: 'QR code will be delivered via websocket', correlation_id: <id> }
  #    Triggered when: Channel needs to be woken up or is in a transitional state (INIT, LAUNCH, etc.)
  #    Action: Triggers channel wakeup, QR code will be delivered via ActionCable when channel reaches QR state
  #
  # Error Responses (422 Unprocessable Entity):
  # - { message: 'Not a WHAPI WhatsApp inbox', correlation_id: <id> }
  # - { message: 'Channel token missing', correlation_id: <id> }
  def initiate_reconnection
    correlation_id = request.request_id || SecureRandom.uuid
    channel = @inbox.channel
    Rails.logger.info "[WhapiController][#{correlation_id}] Initiating reconnection for channel #{channel.id}"

    unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'whapi'
      render_error('Not a WHAPI WhatsApp inbox', correlation_id: correlation_id)
      return
    end

    channel_token = channel.provider_config_object.whapi_channel_token
    if channel_token.blank?
      render_error('Channel token missing', correlation_id: correlation_id)
      return
    end

    # Check if already connected
    bust_health_check_cache(channel)
    begin
      Rails.logger.info "[WhapiController][#{correlation_id}] Checking channel health..."
      health_response = check_channel_health(channel)
      Rails.logger.info "[WhapiController][#{correlation_id}] Health check result: #{health_response.inspect}"

      # Update status in DB based on fresh health check
      channel.provider_config_object.update_whapi_status(health_response[:status])
      Rails.logger.info "[WhapiController][#{correlation_id}] Updated whapi_status in DB to: #{health_response[:status]}"

      if health_response[:connected]
        Rails.logger.info "[WhapiPartner][#{correlation_id}] Channel is already connected"
        result = handle_already_connected_channel(channel, correlation_id)
        render json: {
          status: 'connected',
          whapi_status: 'AUTH',
          message: 'Already connected',
          correlation_id: correlation_id
        }, status: :ok
        return
      end
    rescue StandardError => e
      Rails.logger.warn "[WhapiPartner][#{correlation_id}] Health check failed during reconnection initiation: #{e.message}"
    end

    # If health check showed QR status, fetch QR code immediately and return it
    if health_response && health_response[:status] == 'QR'
      Rails.logger.info "[WhapiController][#{correlation_id}] Channel is in QR state, fetching QR code directly."
      qr_payload = fetch_qr_code_safe(channel, correlation_id)
      if qr_payload
        render json: qr_payload, status: :ok
        return
      else
        Rails.logger.warn "[WhapiController][#{correlation_id}] Failed to fetch QR code directly despite QR status, falling back to webhook flow."
      end
    end

    # Trigger channel wakeup - this will cause Whapi to send status webhooks
    trigger_channel_wakeup(channel, channel_token, correlation_id)

    # Update status to reconnecting only if the channel was previously disconnected
    if channel.provider_config_object.whapi_connection_status != 'pending'
      channel.provider_config_object.update_connection_status('reconnecting')
      Rails.logger.info "[WhapiController][#{correlation_id}] Set connection_status to 'reconnecting' for channel #{channel.id}"
    end

    current_whapi_status = channel.provider_config_object.whapi_status
    ActiveSupport::Notifications.instrument('whapi.onboarding', action: 'reconnection.initiated', account_id: Current.account.id,
                                                                inbox_id: @inbox.id, correlation_id: correlation_id)

    # Return immediately - QR will come via webhook/ActionCable
    Rails.logger.info "[WhapiController][#{correlation_id}] Responding to frontend with status: 'starting', whapi_status: #{current_whapi_status}"
    render json: {
      status: 'starting',
      whapi_status: current_whapi_status,
      message: 'Reconnection initiated. QR code will be delivered via websocket.',
      correlation_id: correlation_id
    }, status: :ok
  end

  # POST /api/v1/accounts/:account_id/whapi_channels/:id/retry_webhook
  def retry_webhook
    correlation_id = request.request_id || SecureRandom.uuid
    channel = @inbox.channel

    unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'whapi'
      render_error('Not a WHAPI WhatsApp inbox', correlation_id: correlation_id) and return
    end

    # Use config objects for accessing channel token
    channel_token = channel.provider_config_object.whapi_channel_token
    if channel_token.blank?
      render_error('Channel token missing', correlation_id: correlation_id) and return
    end

    # Generate environment-specific webhook URL, include phone number if available
    webhook_service = Whatsapp::WebhookUrlService.new
    phone_number = extract_phone_number_from_channel(channel)
    webhook_url = webhook_service.generate_webhook_url(phone_number: phone_number)
    service = Whatsapp::Partner::WhapiPartnerService.new

    begin
      service.retry_webhook_setup(channel_token: channel_token, webhook_url: webhook_url)

      # Update provider config to indicate webhook setup succeeded
      channel.provider_config_object.set_webhook_configured(webhook_url)

      Rails.logger.info "[WhapiPartner][#{correlation_id}] Webhook retry successful"
      render json: {
        message: 'Webhook configured successfully',
        webhook_url: webhook_url,
        correlation_id: correlation_id
      }, status: :ok

    rescue Net::ReadTimeout, Net::OpenTimeout => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Webhook retry timeout: #{e.message}"
      channel.provider_config_object.set_webhook_retry_info("Timeout: #{e.message}")
      render_error('Webhook configuration timed out. Please try again.', status: :service_unavailable, correlation_id: correlation_id)
    rescue HTTParty::Error, Net::HTTPError => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Webhook retry HTTP error: #{e.message}"
      channel.provider_config_object.set_webhook_retry_info("HTTP Error: #{e.message}")
      render_error('Webhook configuration failed due to network error. Please try again.', status: :service_unavailable, correlation_id: correlation_id)
    rescue JSON::ParserError => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Webhook retry JSON parse error: #{e.message}"
      channel.provider_config_object.set_webhook_retry_info("JSON Parse Error: #{e.message}")
      render_error('Invalid response from service. Please try again.', status: :service_unavailable, correlation_id: correlation_id)
    rescue StandardError => e
      Rails.logger.error "[WhapiPartner][#{correlation_id}] Webhook retry unexpected error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      channel.provider_config_object.set_webhook_retry_info("Unknown Error: #{e.message}")
      render_error("Webhook configuration failed: #{e.message}", correlation_id: correlation_id)
    end
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
    authorize @inbox, :show?
  end

  def render_error(message, status: :unprocessable_entity, correlation_id: nil)
    correlation_id ||= request.request_id || SecureRandom.uuid
    render json: { message: message, correlation_id: correlation_id }, status: status
  end

  def handle_already_connected_channel(channel, correlation_id)
    channel.reauthorized! if channel.reauthorization_required?
    channel.provider_config_object.update_connection_status('connected')
    Whatsapp::Whapi::PhoneSyncJob.perform_later(channel.id)

    { authenticated: true, message: 'WhatsApp account successfully connected!', correlation_id: correlation_id }
  end

  def extract_phone_number_from_channel(channel)
    return nil unless channel.is_a?(Channel::Whatsapp)

    phone_number = channel.phone_number
    return nil if phone_number.blank? || phone_number.start_with?('pending:')

    phone_number
  end

  def whapi_channel_params
    return params.require(:whapi_channel).permit(:name, :project_id) if params[:whapi_channel].present?

    params.permit(:name, :project_id)
  end

  def ensure_whapi_partner_feature_enabled
    return if Current.account&.feature_enabled?('channel_whatsapp_whapi_partner')

    render json: { message: 'Feature not enabled' }, status: :forbidden
  end

  def check_channel_health(channel)
    # Validate channel has required configuration before attempting health check
    channel_token = channel.provider_config_object&.whapi_channel_token || channel.provider_config_object&.api_key
    unless channel_token.present?
      Rails.logger.warn "[Whapi] Health check skipped: channel token missing for channel #{channel.id}"
      return { connected: false, status: 'MISSING_CONFIG' }
    end

    service = Whatsapp::Providers::WhapiService.new(whatsapp_channel: channel)
    health = service.health_status
    is_connected = health['text'] == 'AUTH'

    { connected: is_connected, status: health['text'] }
  rescue StandardError => e
    Rails.logger.error "[Whapi] Health check failed: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    # Return disconnected status instead of ERROR to allow QR code generation to proceed
    # This is especially important for disconnected channels that need reconnection
    { connected: false, status: 'ERROR' }
  end

  def bust_health_check_cache(channel)
    # Clear the health check cache to ensure fresh data is read
    # This is critical when channel authentication happens via webhook
    channel_token = channel.provider_config_object&.whapi_channel_token || channel.provider_config_object&.api_key
    return unless channel_token.present?

    cache_key = "whapi_health_#{channel_token[0..8]}"
    Rails.cache.delete(cache_key)
    Rails.logger.debug "[WhapiPartner] Health check cache busted for channel #{channel.id}"
  end

  def fetch_qr_code_safe(channel, correlation_id)
    service = Whatsapp::Partner::WhapiPartnerService.new
    channel_token = channel.provider_config_object.whapi_channel_token
    qr_payload = service.generate_qr_code_simple(channel_token: channel_token)

    return nil unless qr_payload

    channel.provider_config_object.update_qr_timestamp
    {
      image_base64: qr_payload['image_base64'],
      expires_in: qr_payload['expires_in'] || 20,
      poll_in: 15, # Frontend doesn't poll, but this is for consistency
      correlation_id: correlation_id
    }
  rescue StandardError => e
    Rails.logger.error "[WhapiController][#{correlation_id}] fetch_qr_code_safe failed: #{e.message}"
    nil
  end

  def trigger_channel_wakeup(channel, channel_token, correlation_id)
    # Call health endpoint with wakeup=true to start channel
    # This triggers Whapi to send status webhooks (INIT -> LAUNCH -> QR)
    Rails.logger.info "[WhapiPartner][#{correlation_id}] Triggering channel wakeup for channel #{channel.id}"

    response = HTTParty.get(
      'https://gate.whapi.cloud/health',
      headers: { 'Authorization' => "Bearer #{channel_token}" },
      query: { wakeup: 'true', channel_type: 'web' },
      timeout: 5
    )

    Rails.logger.info "[WhapiPartner][#{correlation_id}] Channel wakeup response: #{response.code}"
  rescue StandardError => e
    Rails.logger.warn "[WhapiPartner][#{correlation_id}] Channel wakeup failed: #{e.message}"
    # Non-blocking - webhook flow will handle it even if wakeup fails
  end
end
