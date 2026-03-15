class Instagram::ReadStatusService
  RECONCILIATION_DELAYS = [2.seconds, 5.seconds, 15.seconds, 30.seconds].freeze
  OBSERVABILITY_EVENT_NAME = 'instagram.read_status_reconciliation'.freeze

  pattr_initialize [:params!, :channel!, { reconciliation_attempt: 0 }]

  def perform
    return if channel.blank?

    return handle_message_found if message.present?

    schedule_reconciliation
  end

  def message
    @message ||= channel.inbox.messages.find_by(source_id: mid)
  end

  private

  def handle_message_found
    emit_lifecycle_event('read_status_recovered_on_retry', log: true) if reconciliation_attempt.positive?
    ::Conversations::UpdateMessageStatusJob.perform_later(message.conversation.id, message.created_at)
  end

  def schedule_reconciliation
    return log_terminal_miss if mid.blank? || reconciliation_attempt >= RECONCILIATION_DELAYS.length

    emit_lifecycle_event('read_status_initial_miss', log: false) if reconciliation_attempt.zero?
    emit_lifecycle_event(
      'read_status_retry_scheduled',
      log: false,
      next_attempt: reconciliation_attempt + 1,
      scheduled_delay_seconds: RECONCILIATION_DELAYS[reconciliation_attempt].to_i
    )

    Instagram::ReadStatusReconciliationJob.set(wait: RECONCILIATION_DELAYS[reconciliation_attempt]).perform_later(
      channel,
      mid,
      params[:timestamp],
      reconciliation_attempt + 1
    )
  end

  def log_terminal_miss
    return if mid.blank?

    emit_lifecycle_event('read_status_terminal_miss', level: :warn)
  end

  def mid
    params[:read]&.[](:mid)
  end

  def emit_lifecycle_event(event, level: :info, log: true, **metadata)
    payload = observability_payload(event, **metadata)
    ActiveSupport::Notifications.instrument(OBSERVABILITY_EVENT_NAME, payload)
    Rails.logger.public_send(level, payload) if log
  end

  def observability_payload(event, **metadata)
    payload = {
      service: self.class.name,
      event: event,
      channel_id: channel.id,
      account_id: channel.account_id,
      inbox_id: channel.inbox.id,
      instagram_account_id: channel.instagram_id,
      mid: mid,
      attempt: reconciliation_attempt,
      webhook_timestamp: params[:timestamp]
    }

    payload[:recovery_lag_seconds] = recovery_lag_seconds if event == 'read_status_recovered_on_retry'

    payload.merge(metadata).compact
  end

  def recovery_lag_seconds
    return if parsed_webhook_timestamp.blank?

    (Time.current - parsed_webhook_timestamp).round(3)
  end

  def parsed_webhook_timestamp
    @parsed_webhook_timestamp ||= begin
      raw_timestamp = params[:timestamp]
      if raw_timestamp.blank?
        nil
      else
        numeric_timestamp = Float(raw_timestamp, exception: false)
        timestamp = if numeric_timestamp
                      Time.zone.at(normalized_timestamp_seconds(numeric_timestamp))
                    else
                      Time.zone.parse(raw_timestamp.to_s)
                    end

        timestamp
      end
    rescue ArgumentError, TypeError
      nil
    end
  end

  def normalized_timestamp_seconds(timestamp)
    timestamp > 10_000_000_000 ? timestamp / 1000.0 : timestamp
  end
end
