class Instagram::ReadStatusReconciliationJob < ApplicationJob
  queue_as :default

  def perform(channel, mid, webhook_timestamp = nil, attempt = 1)
    return if channel.blank?

    Instagram::ReadStatusService.new(
      params: {
        read: { mid: mid },
        timestamp: webhook_timestamp
      },
      channel: channel,
      reconciliation_attempt: attempt
    ).perform
  end
end
