class WebhookJob < ApplicationJob
  queue_as :medium

  # Retry configuration for webhook delivery failures
  # Circuit breaker opens for 1 min, so retries will succeed after recovery
  # Polynomial backoff: 3s, 18s, 83s, 258s, 643s (total ~16 minutes)
  retry_on StandardError,
           wait: :polynomially_longer,
           attempts: 5,
           jitter: 0.15  # Add randomness to prevent thundering herd

  # Don't retry on serialization errors (job data corruption)
  discard_on ActiveJob::DeserializationError

  # There are 3 types of webhooks: account, inbox, and agent_bot
  def perform(url, payload, webhook_type = :account_webhook)
    Webhooks::Trigger.execute(url, payload, webhook_type)
  end
end
