# frozen_string_literal: true

module ExternalApiCircuitBreaker
  extend ActiveSupport::Concern

  # Circuit breaker configurations per service
  # More flexible approach: track failures in time window instead of consecutive failures
  CIRCUIT_BREAKER_CONFIGS = {
    default: {
      failure_threshold: 10,        # Open after 10 failures
      time_window: 60,               # Within 1 minute
      lockout_duration: 60,          # Lock for 1 minute
      retry_attempts: 3,
      retry_intervals: [1, 2, 4]     # Exponential backoff: 1s, 2s, 4s
    },
    webhook_delivery: {
      failure_threshold: 10,         # Open after 10 failures
      time_window: 60,               # Within 1 minute window
      lockout_duration: 60,          # Recover after 1 minute
      retry_attempts: 3,
      retry_intervals: [1, 2, 4]
    },
    critical: {                      # For critical services (e.g., payment gateways)
      failure_threshold: 5,
      time_window: 60,
      lockout_duration: 120,         # 2 minutes for critical services
      retry_attempts: 5,
      retry_intervals: [1, 2, 4, 8, 16]
    }
  }.freeze

  # Class methods for use in class contexts (e.g., ChatwootHub.sync_with_hub)
  # rubocop:disable Metrics/BlockLength
  class_methods do
    def with_circuit_breaker(service_name, retries: nil)
      config = CIRCUIT_BREAKER_CONFIGS[service_name.to_sym] || CIRCUIT_BREAKER_CONFIGS[:default]
      retries ||= config[:retry_attempts]

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

        # Record failure with timestamp
        record_failure(service_name, config)

        # Check if we should open the circuit based on failure rate
        open_circuit_if_threshold_reached(service_name, config)

        # Apply exponential backoff (except on last attempt)
        if attempt < retries - 1
          sleep_time = config[:retry_intervals][attempt] || config[:retry_intervals].last
          sleep(sleep_time)
        end
      end

      # All retries failed - open circuit if threshold reached
      open_circuit_if_threshold_reached(service_name, config)
      raise last_error
    end

    private

    def circuit_open?(service_name)
      Rails.cache.read(circuit_breaker_key(service_name)).present?
    end

    def reset_circuit_breaker(service_name)
      Rails.cache.delete(circuit_breaker_key(service_name))
      Rails.cache.delete(failure_timestamps_key(service_name))
    end

    def record_failure(service_name, config)
      key = failure_timestamps_key(service_name)

      # Store failure timestamps, not just count
      timestamps = Rails.cache.read(key) || []
      timestamps << Time.current.to_i

      # Keep only recent failures within time window
      cutoff_time = Time.current.to_i - config[:time_window]
      timestamps = timestamps.select { |ts| ts > cutoff_time }

      Rails.cache.write(key, timestamps, expires_in: config[:time_window] * 2)
    end

    def open_circuit_if_threshold_reached(service_name, config)
      timestamps = Rails.cache.read(failure_timestamps_key(service_name)) || []

      # Count failures in current time window
      cutoff_time = Time.current.to_i - config[:time_window]
      recent_failures = timestamps.count { |ts| ts > cutoff_time }

      return unless recent_failures >= config[:failure_threshold]

      Rails.cache.write(
        circuit_breaker_key(service_name),
        true,
        expires_in: config[:lockout_duration]
      )

      Rails.logger.error(
        "Circuit breaker opened for #{service_name}: " \
        "#{recent_failures} failures in #{config[:time_window]}s " \
        "(threshold: #{config[:failure_threshold]})"
      )
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

    def failure_timestamps_key(service_name)
      "circuit_breaker:#{service_name}:failure_timestamps"
    end
  end
  # rubocop:enable Metrics/BlockLength

  # Instance methods for backward compatibility - delegate to class methods
  def with_circuit_breaker(service_name, retries: nil, &)
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

  def record_failure(service_name, config)
    self.class.send(:record_failure, service_name, config)
  end

  def open_circuit_if_threshold_reached(service_name, config)
    self.class.send(:open_circuit_if_threshold_reached, service_name, config)
  end

  def non_retryable_error?(error)
    self.class.send(:non_retryable_error?, error)
  end

  def circuit_breaker_key(service_name)
    self.class.send(:circuit_breaker_key, service_name)
  end

  def failure_timestamps_key(service_name)
    self.class.send(:failure_timestamps_key, service_name)
  end
end
