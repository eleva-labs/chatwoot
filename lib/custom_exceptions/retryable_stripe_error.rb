# frozen_string_literal: true

module CustomExceptions
  # Exception for retryable Stripe errors (network issues, rate limits)
  # These errors indicate temporary failures that can be safely retried
  class RetryableStripeError < StandardError; end
end

