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

  describe 'improved thresholds' do
    let(:test_instance) { TestInstanceClass.new }

    it 'has increased failure threshold to 10' do
      expect(ExternalApiCircuitBreaker::FAILURE_THRESHOLD).to eq(10)
    end

    it 'has reduced TTL to 1 minute' do
      expect(ExternalApiCircuitBreaker::CIRCUIT_BREAKER_TTL).to eq(60)
    end
  end
end
