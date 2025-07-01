# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::CustomersDataRequestJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:shop_domain) { 'test-shop.myshopify.com' }
  let(:integration_hook) do
    create(:integrations_hook, 
           app_id: 'shopify', 
           reference_id: shop_domain, 
           account: account,
           status: 'enabled')
  end
  let(:webhook_payload) do
    {
      'shop_domain' => shop_domain,
      'customer' => {
        'id' => 123,
        'email' => 'test@example.com'
      },
      'data_request' => { 'id' => 456 }
    }
  end

  before do
    integration_hook
  end

  describe '#perform' do
    context 'with valid account and payload' do
      it 'processes the webhook successfully' do
        expect(Rails.logger).to receive(:info).with(/Processing customers_data_request job/)
        expect(Rails.logger).to receive(:info).with(/Successfully processed customers_data_request/)
        
        described_class.perform_now(webhook_payload)
      end

      it 'includes job duration in context logging' do
        expect(Rails.logger).to receive(:info).with(hash_including(:job_duration_ms))
        
        described_class.perform_now(webhook_payload)
      end

      it 'tracks job performance metrics' do
        expect(Rails.logger).to receive(:info).with(/Job performance metrics/)
        
        described_class.perform_now(webhook_payload)
      end

      it 'logs processing phase information' do
        expect(Rails.logger).to receive(:info).with(/Phase 4 - Data Request Implementation/)
        
        described_class.perform_now(webhook_payload)
      end
    end

    context 'when account resolution fails' do
      before do
        integration_hook.destroy
      end

      it 'logs account not found warning with enhanced context' do
        expect(Rails.logger).to receive(:warn).with(/Account not found for shop_domain/)
        expect(Rails.logger).to receive(:warn).with(hash_including(
          resolution_attempted: true,
          fallback_attempted: true
        ))
        
        described_class.perform_now(webhook_payload)
      end

      it 'logs available hooks for debugging' do
        expect(Rails.logger).to receive(:warn).with(/No integration hook found for shop domain/)
        
        described_class.perform_now(webhook_payload)
      end
    end

    context 'with domain normalization fallback' do
      let(:short_domain) { 'test-shop' }
      let(:webhook_payload_short_domain) do
        webhook_payload.merge('shop_domain' => short_domain)
      end

      it 'resolves account using normalized domain' do
        expect(Rails.logger).to receive(:debug).with(/Trying normalized domain fallback/)
        expect(Rails.logger).to receive(:info).with(/Account resolved using normalized domain/)
        expect(Rails.logger).to receive(:info).with(/Successfully processed customers_data_request/)
        
        described_class.perform_now(webhook_payload_short_domain)
      end
    end

    context 'when job times out' do
      it 'logs timeout error and re-raises' do
        allow_any_instance_of(described_class).to receive(:process_customer_data_request) do
          sleep(0.1) # Simulate long-running operation
          raise Timeout::Error, 'execution timeout'
        end

        expect(Rails.logger).to receive(:error).with(/Job timeout exceeded/)
        
        expect {
          described_class.perform_now(webhook_payload)
        }.to raise_error(Timeout::Error)
      end
    end

    context 'when job fails' do
      before do
        allow_any_instance_of(described_class).to receive(:resolve_account).and_raise(StandardError.new('Database error'))
      end

      it 'logs error with enhanced context and re-raises for retry' do
        expect(Rails.logger).to receive(:error).with(/Failed to process customers_data_request/)
        expect(Rails.logger).to receive(:error).with(hash_including(
          error: 'Database error',
          job_class: 'Shopify::CustomersDataRequestJob'
        ))
        
        expect {
          described_class.perform_now(webhook_payload)
        }.to raise_error(StandardError, 'Database error')
      end
    end

    context 'when performance tracking fails' do
      before do
        allow_any_instance_of(described_class).to receive(:process_customer_data_request).and_raise(StandardError.new('Processing error'))
      end

      it 'logs performance tracking failure' do
        expect(Rails.logger).to receive(:error).with(/Job performance tracking failed/)
        
        expect {
          described_class.perform_now(webhook_payload)
        }.to raise_error(StandardError, 'Processing error')
      end
    end
  end

  describe 'account resolution with shared concern' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@shop_domain, shop_domain)
      job.instance_variable_set(:@payload, webhook_payload.with_indifferent_access)
      job.instance_variable_set(:@job_started_at, Time.current)
    end

    it 'uses the shared AccountResolver concern' do
      expect(job.class.included_modules).to include(Shopify::Concerns::AccountResolver)
    end

    it 'resolves account successfully' do
      account = job.send(:resolve_account, shop_domain)
      expect(account).to eq(integration_hook.account)
    end

    it 'returns nil for blank shop domain' do
      account = job.send(:resolve_account, '')
      expect(account).to be_nil
    end

    it 'returns nil for non-existent shop domain' do
      account = job.send(:resolve_account, 'non-existent-shop.myshopify.com')
      expect(account).to be_nil
    end

    it 'normalizes shop domain correctly' do
      normalized = job.send(:normalize_shop_domain, 'test-shop')
      expect(normalized).to eq('test-shop.myshopify.com')
    end

    it 'does not modify already normalized domain' do
      normalized = job.send(:normalize_shop_domain, 'test-shop.myshopify.com')
      expect(normalized).to eq('test-shop.myshopify.com')
    end
  end

  describe 'job configuration' do
    it 'is configured with correct queue' do
      expect(described_class.queue_name).to eq('default')
    end

    it 'has proper retry configuration' do
      expect(described_class.retry_on_block).to be_present
    end

    it 'discards on deserialization errors' do
      expect(described_class.discard_on_block).to be_present
    end
  end

  describe 'job context logging' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@shop_domain, shop_domain)
      job.instance_variable_set(:@payload, webhook_payload.with_indifferent_access)
      job.instance_variable_set(:@job_started_at, Time.current - 1.second)
    end

    it 'includes all required context fields' do
      context = job.send(:job_context)
      
      expect(context).to include(
        job_class: 'Shopify::CustomersDataRequestJob',
        shop_domain: shop_domain,
        customer_id: 123,
        data_request_id: 456,
        timestamp: be_a(Time),
        job_duration_ms: be_a(Numeric)
      )
    end

    it 'calculates job duration correctly' do
      duration = job.send(:job_duration_ms)
      expect(duration).to be >= 1000 # At least 1 second
      expect(duration).to be < 2000  # Less than 2 seconds
    end
  end
end 