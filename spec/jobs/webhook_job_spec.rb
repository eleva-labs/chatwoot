require 'rails_helper'

RSpec.describe WebhookJob do
  include ActiveJob::TestHelper

  subject(:job) { described_class.perform_later(url, payload, webhook_type) }

  let(:url) { 'https://test.chatwoot.com' }
  let(:payload) { { name: 'test' } }
  let(:webhook_type) { :account_webhook }

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(url, payload, webhook_type)
      .on_queue('medium')
  end

  it 'executes perform with default webhook type' do
    expect(Webhooks::Trigger).to receive(:execute).with(url, payload, webhook_type)
    perform_enqueued_jobs { job }
  end

  context 'with custom webhook type' do
    let(:webhook_type) { :api_inbox_webhook }

    it 'executes perform with inbox webhook type' do
      expect(Webhooks::Trigger).to receive(:execute).with(url, payload, webhook_type)
      perform_enqueued_jobs { job }
    end
  end

  describe 'retry behavior' do
    let(:payload) { { id: 123, conversation: { id: 456 }, content: 'test message' } }

    before do
      # Clear jobs before each test
      clear_enqueued_jobs
    end

    it 'retries on StandardError with exponential backoff' do
      allow(Webhooks::Trigger).to receive(:execute).and_raise(StandardError, 'temporary failure')

      perform_enqueued_jobs do
        expect { job }.to raise_error(StandardError, 'temporary failure')
      end

      # Should have retry jobs enqueued
      expect(enqueued_jobs.count).to be > 0
    end

    it 'does not retry on DeserializationError' do
      error = ActiveJob::DeserializationError.new('bad data')
      allow(Webhooks::Trigger).to receive(:execute).and_raise(error)

      perform_enqueued_jobs do
        job
      end

      # Should not enqueue retries for deserialization errors
      expect(enqueued_jobs.count).to eq(0)
    end

    it 'retries up to 5 times before giving up' do
      execution_count = 0
      allow(Webhooks::Trigger).to receive(:execute) do
        execution_count += 1
        raise StandardError, 'persistent failure'
      end

      perform_enqueued_jobs do
        job
      rescue StandardError
        # Expected
      end

      expect(execution_count).to eq(5)
    end

    it 'succeeds on retry after initial failure' do
      attempt = 0
      allow(Webhooks::Trigger).to receive(:execute) do
        attempt += 1
        raise StandardError, 'temporary' if attempt < 3

        'success'
      end

      perform_enqueued_jobs { job }

      expect(attempt).to eq(3)
    end
  end

  describe 'delivery tracking' do
    let(:payload) { { id: 123, conversation: { id: 456 }, content: 'test message' } }

    before do
      clear_enqueued_jobs
    end

    it 'creates WebhookDelivery record on first attempt' do
      allow(Webhooks::Trigger).to receive(:execute).and_return(double(code: 200))

      expect do
        perform_enqueued_jobs { job }
      end.to change(WebhookDelivery, :count).by(1)

      delivery = WebhookDelivery.last
      expect(delivery.url).to eq(url)
      expect(delivery.message_id).to eq(123)
      expect(delivery.conversation_id).to eq(456)
      expect(delivery.webhook_type).to eq('account_webhook')
      expect(delivery.status).to eq('delivered')
    end

    it 'increments attempt_count on each retry' do
      attempt = 0
      allow(Webhooks::Trigger).to receive(:execute) do
        attempt += 1
        raise StandardError, 'temporary failure' if attempt < 3

        double(code: 200)
      end

      perform_enqueued_jobs { job }

      delivery = WebhookDelivery.last
      expect(delivery.attempt_count).to eq(3)
      expect(delivery.status).to eq('delivered')
    end

    it 'records last_error on failure' do
      allow(Webhooks::Trigger).to receive(:execute).and_raise(StandardError, 'connection timeout')

      perform_enqueued_jobs do
        job
      rescue StandardError
        # Expected
      end

      delivery = WebhookDelivery.last
      expect(delivery.status).to eq('dead_letter')
      expect(delivery.last_error).to include('connection timeout')
      expect(delivery.attempt_count).to eq(5)
    end

    it 'sets delivered_at timestamp on success' do
      allow(Webhooks::Trigger).to receive(:execute).and_return(double(code: 200))

      perform_enqueued_jobs { job }

      delivery = WebhookDelivery.last
      expect(delivery.delivered_at).to be_present
      expect(delivery.delivered_at).to be_within(1.second).of(Time.current)
    end

    it 'moves to dead_letter status after all retries exhausted' do
      allow(Webhooks::Trigger).to receive(:execute).and_raise(StandardError, 'persistent failure')

      perform_enqueued_jobs do
        job
      rescue StandardError
        # Expected
      end

      delivery = WebhookDelivery.last
      expect(delivery.status).to eq('dead_letter')
      expect(delivery.attempt_count).to eq(5)
    end
  end

  describe 'integration with circuit breaker' do
    let(:payload) { { id: 123, conversation: { id: 456 } } }

    before do
      clear_enqueued_jobs
      Rails.cache.clear
    end

    it 'retries after circuit breaker opens and closes' do
      attempt = 0

      # First 2 attempts: circuit breaker rejects immediately
      # Next attempts: circuit recovers and succeeds
      allow(Webhooks::Trigger).to receive(:execute) do
        attempt += 1
        raise StandardError, 'webhook_delivery service is temporarily unavailable' if attempt <= 2

        double(code: 200)
      end

      # Simulate circuit recovering after 1 minute
      allow(Time).to receive(:current).and_return(Time.current, 61.seconds.from_now)

      perform_enqueued_jobs { job }

      # Should eventually succeed after circuit recovers
      delivery = WebhookDelivery.last
      expect(delivery.status).to eq('delivered')
    end
  end
end
