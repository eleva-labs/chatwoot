require 'rails_helper'

RSpec.describe Shopify::WebhookSubscriptionRetryJob, type: :job do
  let(:account) { create(:account) }
  let(:integration_hook) do
    create(:integrations_hook,
           app_id: 'shopify',
           reference_id: 'test-shop.myshopify.com',
           access_token: 'test_token',
           account: account,
           status: 'enabled')
  end
  let(:previous_failure_result) do
    {
      success: false,
      error: 'API rate limit exceeded',
      subscribed_topics: 1,
      total_topics: 3
    }
  end

  describe '#perform' do
    context 'when retry succeeds' do
      before do
        allow(Shopify::WebhookSubscriptionService).to receive(:call).and_return({
          success: true,
          subscribed_topics: 3,
          total_topics: 3
        })
      end

      it 'updates integration hook settings on success' do
        described_class.perform_now(integration_hook.id, previous_failure_result, retry_count: 2)

        integration_hook.reload
        expect(integration_hook.settings['compliance_webhooks_pending']).to be false
        expect(integration_hook.settings['compliance_webhooks_subscribed']).to be true
        expect(integration_hook.settings['webhook_subscription_retry_succeeded_at']).to be_present
        expect(integration_hook.settings['webhook_subscription_retry_count']).to eq(2)
        expect(integration_hook.settings['subscribed_topics_count']).to eq(3)
      end

      it 'removes failure indicators from settings' do
        integration_hook.update!(settings: {
          'webhook_subscription_failure_reason' => 'Previous error',
          'webhook_subscription_retry_queued_at' => Time.current.iso8601
        })

        described_class.perform_now(integration_hook.id, previous_failure_result, retry_count: 1)

        integration_hook.reload
        expect(integration_hook.settings['webhook_subscription_failure_reason']).to be_nil
        expect(integration_hook.settings['webhook_subscription_retry_queued_at']).to be_nil
      end

      it 'logs successful retry' do
        expect(Rails.logger).to receive(:info).with(/Webhook subscription retry succeeded/)

        described_class.perform_now(integration_hook.id, previous_failure_result, retry_count: 1)
      end
    end

    context 'when retry fails but retries remain' do
      let(:failure_result) do
        {
          success: false,
          error: 'Still rate limited',
          subscribed_topics: 1,
          total_topics: 3
        }
      end

      before do
        allow(Shopify::WebhookSubscriptionService).to receive(:call).and_return(failure_result)
        allow(described_class).to receive(:set).and_return(described_class)
        allow(described_class).to receive(:perform_later)
      end

      it 'schedules next retry' do
        described_class.perform_now(integration_hook.id, previous_failure_result, retry_count: 1, max_retries: 3)

        expect(described_class).to have_received(:set).with(wait: 15.minutes)
        expect(described_class).to have_received(:perform_later).with(
          integration_hook.id,
          failure_result,
          retry_count: 2,
          max_retries: 3
        )
      end

      it 'logs retry scheduling' do
        expect(Rails.logger).to receive(:info).with(/Scheduling next webhook subscription retry/)

        described_class.perform_now(integration_hook.id, previous_failure_result, retry_count: 1, max_retries: 3)
      end
    end

    context 'when final retry fails' do
      let(:final_failure_result) do
        {
          success: false,
          error: 'Permanent failure',
          subscribed_topics: 0,
          total_topics: 3
        }
      end

      before do
        allow(Shopify::WebhookSubscriptionService).to receive(:call).and_return(final_failure_result)
      end

      it 'marks integration hook as permanently failed' do
        described_class.perform_now(integration_hook.id, previous_failure_result, retry_count: 3, max_retries: 3)

        integration_hook.reload
        expect(integration_hook.settings['compliance_webhooks_pending']).to be false
        expect(integration_hook.settings['compliance_webhooks_subscribed']).to be false
        expect(integration_hook.settings['webhook_subscription_permanently_failed_at']).to be_present
        expect(integration_hook.settings['webhook_subscription_final_retry_count']).to eq(3)
        expect(integration_hook.settings['webhook_subscription_final_error']).to eq('Permanent failure')
        expect(integration_hook.settings['requires_manual_intervention']).to be true
      end

      it 'logs final failure with alert' do
        expect(Rails.logger).to receive(:error).with(/Webhook subscription failed after all retries/)
        expect(Rails.logger).to receive(:error).with(/ALERT: Manual intervention required/)

        described_class.perform_now(integration_hook.id, previous_failure_result, retry_count: 3, max_retries: 3)
      end
    end

    context 'when integration hook is not found' do
      it 'raises RecordNotFound error' do
        expect {
          described_class.perform_now(999999, previous_failure_result)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'retry calculation' do
    let(:job) { described_class.new }

    describe '#calculate_retry_delay' do
      it 'calculates exponential backoff delays' do
        expect(job.send(:calculate_retry_delay, 1)).to eq(5)   # 5 * (3^0) = 5
        expect(job.send(:calculate_retry_delay, 2)).to eq(15)  # 5 * (3^1) = 15
        expect(job.send(:calculate_retry_delay, 3)).to eq(45)  # 5 * (3^2) = 45
      end
    end
  end

  describe '.webhook_subscription_health_report' do
    let!(:successful_hook) do
      create(:integrations_hook,
             app_id: 'shopify',
             account: account,
             settings: { 'compliance_webhooks_subscribed' => 'true' })
    end

    let!(:pending_hook) do
      create(:integrations_hook,
             app_id: 'shopify',
             account: account,
             settings: { 'compliance_webhooks_pending' => 'true' })
    end

    let!(:failed_hook) do
      create(:integrations_hook,
             app_id: 'shopify',
             account: account,
             settings: { 'requires_manual_intervention' => 'true' })
    end

    let!(:non_shopify_hook) do
      create(:integrations_hook,
             app_id: 'slack',
             account: account)
    end

    it 'returns health statistics for Shopify integrations' do
      report = described_class.webhook_subscription_health_report

      expect(report[:total_hooks]).to eq(3) # Only Shopify hooks
      expect(report[:successful_subscriptions]).to eq(1)
      expect(report[:pending_subscriptions]).to eq(1)
      expect(report[:failed_subscriptions]).to eq(1)
      expect(report[:success_rate]).to eq(33.33) # 1/3 * 100
    end

    it 'handles zero total hooks' do
      Integrations::Hook.where(app_id: 'shopify').destroy_all

      report = described_class.webhook_subscription_health_report

      expect(report[:total_hooks]).to eq(0)
      expect(report[:success_rate]).to eq(0)
    end
  end

  describe 'job configuration' do
    it 'is configured with correct queue and retry settings' do
      expect(described_class.queue_adapter.class).to eq(ActiveJob::QueueAdapters::TestAdapter)
      expect(described_class.retry_on_blocks.size).to eq(1)
      expect(described_class.discard_on_blocks.size).to eq(1)
    end

    it 'discards jobs with deserialization errors' do
      expect {
        described_class.perform_now('invalid_hook_id', previous_failure_result)
      }.to raise_error(ActiveJob::DeserializationError)
    end
  end
end 