class Whatsapp::WhapiConnectionStatusService
  pattr_initialize [:channel!, :params!, :correlation_id]

  def perform
    # Handle events array (for users.post, users.delete, etc.)
    if params['events']&.any?
      ActiveSupport::Notifications.instrument(
        'whapi.webhook',
        action: 'events',
        event_count: params['events'].size,
        channel_id: channel.id,
        correlation_id: correlation_id
      )

      params['events'].each do |event|
        process_connection_event(event)
      end
    end

    # Handle top-level event structure (for users.post, users.delete webhooks)
    # Whapi sends: { "event": { "type": "users", "event": "post" }, "user": {...} }
    if params['event'].present? && params['event']['type'] == 'users'
      process_users_event(params['event'], params['user'])
    end
  end

  def process_health_status(health)
    status_text = health.dig('status', 'text')
    case status_text
    when 'AUTH'
      handle_authenticated_status
    when 'STOP', 'ERROR'
      handle_disconnection_status(status_text)
    when 'SYNC_ERROR'
      handle_sync_error_status
    when 'QR', 'INIT', 'LAUNCH', 'NOT_INIT'
      # Transient states - do not trigger disconnection
      Rails.logger.info "[Whapi][#{correlation_id}] Channel in transient state: #{status_text}"
    else
      Rails.logger.info "[Whapi][#{correlation_id}] Unhandled health status: #{status_text}"
    end
  end

  private

  def process_connection_event(event)
    case event['type']
    when 'ready', 'connected'
      handle_connected_event(event)
    when 'disconnected'
      handle_disconnected_event(event)
    when 'users'
      # Handle users.post/delete from events array
      process_users_event(event, event['user'])
    else
      Rails.logger.info "[Whapi][#{correlation_id}] Unhandled event type: #{event['type']}"
    end
  end

  def process_users_event(event_obj, user_obj)
    # event_obj has: { "type": "users", "event": "post" } or { "type": "users", "event": "delete" }
    event_action = event_obj['event'] || event_obj['action']
    
    case event_action
    when 'post'
      # users.post - account connected
      handle_users_connected(user_obj)
    when 'delete'
      # users.delete - account disconnected
      handle_users_disconnected(user_obj)
    else
      Rails.logger.info "[Whapi][#{correlation_id}] Unhandled users event action: #{event_action}"
    end
  end

  def handle_users_connected(user_obj)
    Rails.logger.info "[Whapi][#{correlation_id}] Channel #{channel.id} - user connected: #{user_obj&.dig('id') || user_obj&.dig('name')}"
    
    # Extract phone number from user if available
    phone_number = user_obj&.dig('id') || user_obj&.dig('phone')
    
    if phone_number.present?
      formatted_phone = phone_number.to_s.start_with?('+') ? phone_number.to_s : "+#{phone_number}"
      
      # Update webhook URL with phone number (same as handle_connected_event)
      webhook_updated = false
      new_webhook_url = nil
      begin
        webhook_updated, new_webhook_url = update_webhook_with_phone_number(formatted_phone)
      rescue StandardError => e
        Rails.logger.warn "[Whapi][#{correlation_id}] Failed to update webhook with phone number: #{e.message}"
      end

      # Update channel with connected phone number and status
      config_object = channel.provider_config_object
      config_object.update_connection_status('connected')
      config_object.update_phone_number(formatted_phone)
      config_object.update_webhook_url(new_webhook_url) if webhook_updated && new_webhook_url.present?
    else
      # Still update status even without phone number
      channel.provider_config_object.update_connection_status('connected')
    end

    # Clear reauthorization state when successfully reconnected
    channel.reauthorized!

    # Broadcast status update for UI
    broadcast_connection_status('connected')
    ActiveSupport::Notifications.instrument(
      'whapi.onboarding',
      action: 'connected',
      channel_id: channel.id,
      inbox_id: channel.inbox.id,
      correlation_id: correlation_id
    )
  end

  def handle_users_disconnected(user_obj)
    Rails.logger.info "[Whapi][#{correlation_id}] Channel #{channel.id} - user disconnected: #{user_obj&.dig('id') || user_obj&.dig('name')}"

    channel.update!(
      provider_config: channel.provider_config.merge(
        'connection_status' => 'disconnected',
        'disconnected_at' => Time.current.iso8601
      )
    )

    # Trigger reauthorization flow
    channel.prompt_reauthorization!

    # Broadcast status update for UI
    broadcast_connection_status('disconnected')
    ActiveSupport::Notifications.instrument(
      'whapi.onboarding',
      action: 'disconnected',
      channel_id: channel.id,
      inbox_id: channel.inbox.id,
      correlation_id: correlation_id
    )
  end

  def handle_connected_event(event)
    phone_number = event['phone']
    return unless phone_number.present?

    # Ensure phone number is in E.164 format
    formatted_phone = phone_number.start_with?('+') ? phone_number : "+#{phone_number}"

    Rails.logger.info "[Whapi][#{correlation_id}] Channel #{channel.id} connected with phone: #{formatted_phone}"

    # Update webhook URL with phone number
    webhook_updated = false
    new_webhook_url = nil
    begin
      webhook_updated, new_webhook_url = update_webhook_with_phone_number(formatted_phone)
    rescue StandardError => e
      Rails.logger.warn "[Whapi][#{correlation_id}] Failed to update webhook with phone number: #{e.message}"
    end

    # Update channel with connected phone number and status
    config_object = channel.provider_config_object
    config_object.update_connection_status('connected')
    config_object.update_phone_number(formatted_phone)

    config_object.update_webhook_url(new_webhook_url) if webhook_updated && new_webhook_url.present?

    # Clear reauthorization state when successfully reconnected
    channel.reauthorized!

    # Broadcast status update for UI
    broadcast_connection_status('connected')
    ActiveSupport::Notifications.instrument(
      'whapi.onboarding',
      action: 'connected',
      channel_id: channel.id,
      inbox_id: channel.inbox.id,
      correlation_id: correlation_id
    )
  end

  def handle_disconnected_event(_event)
    Rails.logger.info "[Whapi][#{correlation_id}] Channel #{channel.id} disconnected"

    channel.update!(
      provider_config: channel.provider_config.merge(
        'connection_status' => 'disconnected',
        'disconnected_at' => Time.current.iso8601
      )
    )

    # Trigger reauthorization flow
    channel.prompt_reauthorization!

    # Broadcast status update for UI
    broadcast_connection_status('disconnected')
    ActiveSupport::Notifications.instrument(
      'whapi.onboarding',
      action: 'disconnected',
      channel_id: channel.id,
      inbox_id: channel.inbox.id,
      correlation_id: correlation_id
    )
  end

  def update_webhook_with_phone_number(formatted_phone)
    channel_token = channel.provider_config_object.whapi_channel_token
    return [false, nil] unless channel_token.present?

    service = Whatsapp::Partner::WhapiPartnerService.new
    new_webhook_url = service.update_webhook_with_phone_number(
      channel_token: channel_token,
      phone_number: formatted_phone
    )

    Rails.logger.info "[Whapi][#{correlation_id}] Webhook updated with phone number: #{formatted_phone}, new URL: #{new_webhook_url}"
    [true, new_webhook_url]
  end

  def handle_authenticated_status
    # Clear reauthorization state when successfully reconnected
    channel.reauthorized!

    # Update connection status
    channel.provider_config_object.update_connection_status('connected')

    # Bust health check cache to ensure subsequent health checks read fresh data
    # This is critical to prevent stale cache from causing issues during reconnection
    begin
      service = Whatsapp::Providers::WhapiService.new(whatsapp_channel: channel)
      service.bust_health_check_cache
    rescue StandardError => e
      Rails.logger.warn "[Whapi][#{correlation_id}] Failed to bust health check cache: #{e.message}"
      # Non-critical, continue with status update
    end

    # Bust inbox cache to ensure background jobs see updated channel status
    channel.inbox.account.update_cache_key('inbox')

    broadcast_connection_status('connected')
  end

  def handle_disconnection_status(status_text)
    Rails.logger.warn "[Whapi][#{correlation_id}] Channel #{channel.id} in disconnection state: #{status_text}"

    channel.update!(
      provider_config: channel.provider_config.merge(
        'connection_status' => status_text.downcase,
        'disconnected_at' => Time.current.iso8601
      )
    )

    # Trigger reauthorization
    channel.prompt_reauthorization!
    broadcast_connection_status(status_text.downcase)
  end

  def handle_sync_error_status
    Rails.logger.warn "[Whapi][#{correlation_id}] Channel #{channel.id} in SYNC_ERROR state"

    # SYNC_ERROR is special - can still send but not receive
    # Notify but don't fully block operations
    channel.update!(
      provider_config: channel.provider_config.merge(
        'connection_status' => 'sync_error',
        'sync_error_at' => Time.current.iso8601
      )
    )

    # Still trigger reauthorization as reconnection is recommended
    channel.prompt_reauthorization!
    broadcast_connection_status('sync_error')
  end

  def broadcast_connection_status(status)
    ActionCable.server.broadcast(
      "account_#{channel.account_id}",
      {
        event: 'whapi_channel_status_updated',
        data: {
          account_id: channel.account_id,
          inbox_id: channel.inbox.id,
          connection_status: status,
          phone_number: channel.phone_number,
          correlation_id: correlation_id
        }
      }
    )
  end
end

