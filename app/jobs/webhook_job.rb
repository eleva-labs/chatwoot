class WebhookJob < ApplicationJob
  queue_as :medium

  # Retry configuration for webhook delivery failures
  # Circuit breaker opens for 1 min, so retries will succeed after recovery
  # Exponential backoff: 3s, 18s, 83s, 258s, 643s (total ~16 minutes)
  retry_on StandardError,
           wait: :exponentially_longer,
           attempts: 5,
           jitter: 0.15  # Add randomness to prevent thundering herd

  # Don't retry on serialization errors (job data corruption)
  discard_on ActiveJob::DeserializationError

  # Track delivery attempts
  before_perform :record_attempt
  after_perform :record_success
  rescue_from(StandardError) do |error|
    record_failure(error)
    raise error  # Re-raise to trigger retry mechanism
  end

  # There are 3 types of webhooks: account, inbox, and agent_bot
  def perform(url, payload, webhook_type = :account_webhook)
    @url = url
    @payload = payload
    @webhook_type = webhook_type

    Webhooks::Trigger.execute(url, payload, webhook_type)
  end

  private

  def record_attempt
    return unless webhook_delivery

    webhook_delivery.update!(
      attempt_count: webhook_delivery.attempt_count + 1,
      status: 'delivering',
      last_attempt_at: Time.current
    )
  end

  def record_success
    return unless webhook_delivery

    webhook_delivery.update!(
      status: 'delivered',
      delivered_at: Time.current,
      last_error: nil
    )
  end

  def record_failure(error)
    return unless webhook_delivery

    # If this is the last attempt, move to dead letter
    if executions >= 5
      webhook_delivery.move_to_dead_letter!(error.message)
    else
      webhook_delivery.update!(
        status: 'failed',
        last_error: error.message,
        last_attempt_at: Time.current
      )
    end
  end

  def webhook_delivery
    return @webhook_delivery if defined?(@webhook_delivery)

    @webhook_delivery = WebhookDelivery.find_or_create_by(
      job_id: job_id,
      url: @url,
      conversation_id: @payload.dig(:conversation, :id),
      message_id: @payload[:id],
      webhook_type: @webhook_type
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to track webhook delivery: #{e.message}")
    nil
  end
end
