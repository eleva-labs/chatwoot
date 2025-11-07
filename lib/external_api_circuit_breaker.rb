# frozen_string_literal: true

module ExternalApiCircuitBreaker
  extend ActiveSupport::Concern

  # Circuit breaker states: closed (working), open (failing), half_open (testing)
  CIRCUIT_BREAKER_TTL = 300 # 5 minutes
  FAILURE_THRESHOLD = 3     # Open circuit after 3 consecutive failures
  RETRY_INTERVALS = [1, 2, 4].freeze # Exponential backoff: 1s, 2s, 4s

  # Class methods for use in class contexts (e.g., ChatwootHub.sync_with_hub)
  # rubocop:disable Metrics/BlockLength
  class_methods do
    def with_circuit_breaker(service_name, retries: 3)
      # Check if circuit is open
      raise StandardError, "#{service_name} service is temporarily unavailable. Please try again in a few minutes." if circuit_open?(service_name)

      last_error = nil

      retries.times do |attempt|
        result = yield
        # Success - reset circuit breaker
        reset_circuit_breaker(service_name)
        return result
      rescue StandardError => e
        last_error = e

        # Don't retry on certain errors (like authentication failures)
        break if non_retryable_error?(e)

        # Record failure
        record_failure(service_name)

        # Check if we should open the circuit
        open_circuit_if_threshold_reached(service_name)

        # Apply exponential backoff (except on last attempt)
        if attempt < retries - 1
          sleep_time = RETRY_INTERVALS[attempt] || RETRY_INTERVALS.last
          sleep(sleep_time)
        end
      end

      # All retries failed - open circuit if threshold reached
      open_circuit_if_threshold_reached(service_name)
      raise last_error
    end

    private

    def circuit_open?(service_name)
      Rails.cache.read(circuit_breaker_key(service_name)).present?
    end

    def reset_circuit_breaker(service_name)
      Rails.cache.delete(circuit_breaker_key(service_name))
      Rails.cache.delete(failure_count_key(service_name))
    end

    def record_failure(service_name)
      key = failure_count_key(service_name)
      current_count = Rails.cache.read(key) || 0
      Rails.cache.write(key, current_count + 1, expires_in: CIRCUIT_BREAKER_TTL)
    end

    def open_circuit_if_threshold_reached(service_name)
      failure_count = Rails.cache.read(failure_count_key(service_name)) || 0

      return unless failure_count >= FAILURE_THRESHOLD

      Rails.cache.write(circuit_breaker_key(service_name), true, expires_in: CIRCUIT_BREAKER_TTL)
      Rails.logger.warn "Circuit breaker opened for #{service_name} after #{failure_count} failures"
    end

    def non_retryable_error?(error)
      # Don't retry on authentication errors, rate limits, etc.
      error.message.include?('401') ||
        error.message.include?('403') ||
        error.message.include?('already authenticated') ||
        error.is_a?(CustomExceptions::RateLimitExceeded)
    end

    def circuit_breaker_key(service_name)
      "circuit_breaker:#{service_name}:open"
    end

    def failure_count_key(service_name)
      "circuit_breaker:#{service_name}:failures"
    end
  end
  # rubocop:enable Metrics/BlockLength

  # Instance methods for backward compatibility - delegate to class methods
  def with_circuit_breaker(service_name, retries: 3, &)
    self.class.with_circuit_breaker(service_name, retries: retries, &)
  end

  private

  # Instance method helpers delegate to class method helpers
  def circuit_open?(service_name)
    self.class.send(:circuit_open?, service_name)
  end

  def reset_circuit_breaker(service_name)
    self.class.send(:reset_circuit_breaker, service_name)
  end

  def record_failure(service_name)
    self.class.send(:record_failure, service_name)
  end

  def open_circuit_if_threshold_reached(service_name)
    self.class.send(:open_circuit_if_threshold_reached, service_name)
  end

  def non_retryable_error?(error)
    self.class.send(:non_retryable_error?, error)
  end

  def circuit_breaker_key(service_name)
    self.class.send(:circuit_breaker_key, service_name)
  end

  def failure_count_key(service_name)
    self.class.send(:failure_count_key, service_name)
  end
end
