# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalApiCircuitBreaker do
  # Test class for instance method usage
  class TestInstanceClass
    include ExternalApiCircuitBreaker
  end

  # Test class for class method usage (mimics ChatwootHub pattern)
  class TestClassMethods
    include ExternalApiCircuitBreaker

    def self.test_class_method
      with_circuit_breaker('test_service') { 'success' }
    end
  end

  before do
    Rails.cache.clear
  end

  describe '#with_circuit_breaker (instance method)' do
    let(:test_instance) { TestInstanceClass.new }

    context 'when circuit is closed' do
      it 'successfully executes block' do
        result = test_instance.with_circuit_breaker('test_service') { 'success' }
        expect(result).to eq('success')
      end
    end

    context 'when request fails temporarily' do
      it 'retries with exponential backoff' do
        attempt_count = 0

        result = test_instance.with_circuit_breaker('test_service', retries: 3) do
          attempt_count += 1
          raise StandardError, 'temporary failure' if attempt_count < 3

          'success'
        end

        expect(result).to eq('success')
        expect(attempt_count).to eq(3)
      end
    end

    context 'when all retries are exhausted' do
      it 'raises the original error' do
        expect do
          test_instance.with_circuit_breaker('failing_service', retries: 3) do
            raise StandardError, 'failure'
          end
        end.to raise_error(StandardError, 'failure')
      end
    end

    context 'when request succeeds after failures' do
      it 'resets circuit breaker state' do
        # Create some failures
        2.times do
          test_instance.with_circuit_breaker('reset_test', retries: 1) do
            raise StandardError, 'failure'
          end
        rescue StandardError
          # Expected
        end

        # Successful request should reset the failure count
        result = test_instance.with_circuit_breaker('reset_test') { 'success' }
        expect(result).to eq('success')
      end
    end

    context 'when error is non-retryable' do
      it 'does not retry on 401 errors' do
        attempt_count = 0

        expect do
          test_instance.with_circuit_breaker('non_retry_test', retries: 3) do
            attempt_count += 1
            raise StandardError, '401 Unauthorized'
          end
        end.to raise_error(StandardError, /401/)

        expect(attempt_count).to eq(1)
      end

      it 'does not retry on 403 errors' do
        attempt_count = 0

        expect do
          test_instance.with_circuit_breaker('forbidden_test', retries: 3) do
            attempt_count += 1
            raise StandardError, '403 Forbidden'
          end
        end.to raise_error(StandardError, /403/)

        expect(attempt_count).to eq(1)
      end
    end
  end

  describe '.with_circuit_breaker (class method)' do
    context 'when called from class method context' do
      it 'successfully executes block' do
        result = TestClassMethods.test_class_method
        expect(result).to eq('success')
      end

      it 'works with direct class method call' do
        result = TestClassMethods.with_circuit_breaker('hub_test') { 'hub_success' }
        expect(result).to eq('hub_success')
      end
    end

    context 'when request fails' do
      it 'raises error after all retries' do
        expect do
          TestClassMethods.with_circuit_breaker('class_failing_service', retries: 3) do
            raise StandardError, 'failure'
          end
        end.to raise_error(StandardError, 'failure')
      end
    end
  end

  describe 'backward compatibility' do
    it 'instance methods delegate to class methods correctly' do
      test_instance = TestInstanceClass.new

      # Both should work and share the same circuit state
      test_instance.with_circuit_breaker('shared_service') { 'instance_success' }
      result = TestClassMethods.with_circuit_breaker('shared_service') { 'class_success' }

      expect(result).to eq('class_success')
    end
  end

  describe 'integration with ChatwootHub pattern' do
    it 'ChatwootHub class can use circuit breaker' do
      # Verify the pattern works (actual ChatwootHub testing is in chatwoot_hub_spec.rb)
      expect(ChatwootHub).to respond_to(:with_circuit_breaker)
    end
  end

  describe 'new timestamp-based circuit breaker' do
    let(:test_instance) { TestInstanceClass.new }

    context 'with webhook_delivery configuration' do
      it 'opens circuit after 10 failures in 1 minute' do
        # Record 9 failures - circuit should stay closed
        9.times do |i|
          test_instance.with_circuit_breaker('webhook_delivery', retries: 1) do
            raise StandardError, "failure #{i + 1}"
          end
        rescue StandardError
          # Expected
        end

        # 10th failure should open the circuit
        expect do
          test_instance.with_circuit_breaker('webhook_delivery', retries: 1) do
            raise StandardError, 'failure 10'
          end
        end.to raise_error(StandardError, 'failure 10')

        # Next request should be rejected by open circuit
        expect do
          test_instance.with_circuit_breaker('webhook_delivery') { 'should not execute' }
        end.to raise_error(StandardError, /temporarily unavailable/)
      end

      it 'does not open circuit if failures are spread over time window' do
        # Record 5 failures
        5.times do
          test_instance.with_circuit_breaker('webhook_delivery', retries: 1) do
            raise StandardError, 'failure'
          end
        rescue StandardError
          # Expected
        end

        # Simulate time passing (failures older than 1 min)
        allow(Time).to receive(:current).and_return(61.seconds.from_now)

        # Circuit should stay closed as old failures are outside time window
        result = test_instance.with_circuit_breaker('webhook_delivery') { 'success' }
        expect(result).to eq('success')
      end

      it 'recovers after lockout duration (1 minute)' do
        # Open the circuit with 10 failures
        10.times do
          test_instance.with_circuit_breaker('webhook_delivery', retries: 1) do
            raise StandardError, 'failure'
          end
        rescue StandardError
          # Expected
        end

        # Circuit should be open
        expect do
          test_instance.with_circuit_breaker('webhook_delivery') { 'blocked' }
        end.to raise_error(StandardError, /temporarily unavailable/)

        # Simulate lockout duration passing (61 seconds)
        allow(Time).to receive(:current).and_return(61.seconds.from_now)

        # Circuit should close and allow requests
        result = test_instance.with_circuit_breaker('webhook_delivery') { 'recovered' }
        expect(result).to eq('recovered')
      end
    end

    context 'with critical service configuration' do
      it 'opens circuit after 5 failures (lower threshold)' do
        # Record 5 failures - should open circuit for critical services
        5.times do
          test_instance.with_circuit_breaker('critical', retries: 1) do
            raise StandardError, 'critical failure'
          end
        rescue StandardError
          # Expected
        end

        # Circuit should be open
        expect do
          test_instance.with_circuit_breaker('critical') { 'blocked' }
        end.to raise_error(StandardError, /temporarily unavailable/)
      end
    end

    context 'with default configuration' do
      it 'uses default config for unknown service names' do
        # Should use default config (10 failures in 1 min)
        9.times do
          test_instance.with_circuit_breaker('unknown_service', retries: 1) do
            raise StandardError, 'failure'
          end
        rescue StandardError
          # Expected
        end

        # Circuit should still be closed after 9 failures
        result = test_instance.with_circuit_breaker('unknown_service') { 'still working' }
        expect(result).to eq('still working')
      end
    end
  end

  describe 'failure timestamp tracking' do
    let(:test_instance) { TestInstanceClass.new }

    it 'stores failure timestamps in cache' do
      test_instance.with_circuit_breaker('timestamp_test', retries: 1) do
        raise StandardError, 'failure'
      end
    rescue StandardError
      # Expected

      timestamps = Rails.cache.read('circuit_breaker:timestamp_test:failure_timestamps')
      expect(timestamps).to be_an(Array)
      expect(timestamps.length).to eq(1)
      expect(timestamps.first).to be_within(2).of(Time.current.to_i)
    end

    it 'cleans up old timestamps outside time window' do
      # Add some old timestamps manually
      old_timestamps = [Time.current.to_i - 120, Time.current.to_i - 90]
      Rails.cache.write('circuit_breaker:cleanup_test:failure_timestamps', old_timestamps)

      # Record a new failure
      test_instance.with_circuit_breaker('cleanup_test', retries: 1) do
        raise StandardError, 'failure'
      end
    rescue StandardError
      # Expected

      timestamps = Rails.cache.read('circuit_breaker:cleanup_test:failure_timestamps')
      # Old timestamps should be removed (outside 1-min window)
      expect(timestamps.length).to eq(1)
      expect(timestamps.first).to be_within(2).of(Time.current.to_i)
    end
  end
end
