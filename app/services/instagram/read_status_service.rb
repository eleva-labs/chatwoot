class Instagram::ReadStatusService
  RECONCILIATION_DELAYS = [2.seconds, 5.seconds, 15.seconds, 30.seconds].freeze

  pattr_initialize [:params!, :channel!, { reconciliation_attempt: 0 }]

  def perform
    return if channel.blank?

    return schedule_reconciliation unless message.present?

    ::Conversations::UpdateMessageStatusJob.perform_later(message.conversation.id, message.created_at)
  end

  def message
    @message ||= channel.inbox.messages.find_by(source_id: mid)
  end

  private

  def schedule_reconciliation
    return log_terminal_miss if mid.blank? || reconciliation_attempt >= RECONCILIATION_DELAYS.length

    Instagram::ReadStatusReconciliationJob.set(wait: RECONCILIATION_DELAYS[reconciliation_attempt]).perform_later(
      channel,
      mid,
      params[:timestamp],
      reconciliation_attempt + 1
    )
  end

  def log_terminal_miss
    return if mid.blank?

    Rails.logger.warn(
      "[#{self.class.name}] event=read_status_terminal_miss " \
      "channel_id=#{channel.id} inbox_id=#{channel.inbox.id} mid=#{mid} " \
      "attempt=#{reconciliation_attempt} webhook_timestamp=#{params[:timestamp]}"
    )
  end

  def mid
    params[:read]&.[](:mid)
  end
end
