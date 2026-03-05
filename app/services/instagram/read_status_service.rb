class Instagram::ReadStatusService
  pattr_initialize [:params!, :channel!]

  def perform
    return if channel.blank?

    ::Conversations::UpdateMessageStatusJob.perform_later(message.conversation.id, message.created_at) if message.present?
  end

  def instagram_id
    params[:recipient][:id]
  end

  def message
    mid = params[:read][:mid]
    return unless mid

    msg = @channel.inbox.messages.find_by(source_id: mid)
    if msg.nil?
      Rails.logger.warn(
        "[Instagram::ReadStatusService] No message found for source_id=#{mid} " \
        "inbox_id=#{@channel.inbox.id}"
      )
    end
    @message ||= msg
  end
end
