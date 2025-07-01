# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::WebhookSubscriptionService, type: :service do
  let(:account) { create(:account) }
  let(:integration_hook) do
    create(:integrations_hook,
           app_id: 'shopify',
           reference_id: 'test-shop.myshopify.com',
           access_token: 'test_access_token',
           account: account,
           status: 'enabled')
  end

  let(:service) { described_class.new(integration_hook) }

  describe '#initialize' do
    it 'initializes successfully with valid integration hook' do
      expect(service.shop_domain).to eq('test-shop.myshopify.com')
      expect(service.access_token).to eq('test_access_token')
    end

    it 'normalizes shop domain without .myshopify.com' do
      hook = create(:integrations_hook,
                    app_id: 'shopify',
                    reference_id: 'test-shop',
                    access_token: 'token',
                    account: account)
      
      service = described_class.new(hook)
      expect(service.shop_domain).to eq('test-shop.myshopify.com')
    end

    it 'raises error for invalid integration hook' do
      expect {
        described_class.new(nil)
      }.to raise_error(ArgumentError, /Integration hook cannot be nil/)
    end

    it 'raises error for missing access token' do
      hook = create(:integrations_hook,
                    app_id: 'shopify',
                    reference_id: 'test-shop.myshopify.com',
                    access_token: '',
                    account: account)

      expect {
        described_class.new(hook)
      }.to raise_error(ArgumentError, /Access token missing/)
    end

    it 'raises error for disabled integration hook' do
      hook = create(:integrations_hook,
                    app_id: 'shopify',
                    reference_id: 'test-shop.myshopify.com',
                    access_token: 'token',
                    account: account,
                    status: 'disabled')

      expect {
        described_class.new(hook)
      }.to raise_error(ArgumentError, /hook_active/)
    end
  end

  describe '#subscribe_to_compliance_webhooks' do
    let(:mock_response) do
      {
        'data' => {
          'webhookSubscriptionCreate' => {
            'webhookSubscription' => {
              'id' => 'gid://shopify/WebhookSubscription/123',
              'callbackUrl' => 'https://app.example.com/shopify/webhooks/customers_data_request',
              'apiVersion' => '2024-10'
            },
            'userErrors' => []
          }
        }
      }
    end

    before do
      allow(service).to receive(:execute_graphql_request).and_return({
        success: true,
        data: mock_response['data']
      })
    end

    it 'subscribes to all mandatory topics successfully' do
      result = service.subscribe_to_compliance_webhooks

      expect(result[:success]).to be true
      expect(result[:subscribed_topics]).to eq(3)
      expect(result[:total_topics]).to eq(3)
    end

    it 'updates integration hook settings with subscription data' do
      service.subscribe_to_compliance_webhooks

      integration_hook.reload
      expect(integration_hook.settings['webhook_subscriptions']).to be_present
      expect(integration_hook.settings['compliance_webhooks_subscribed_at']).to be_present
    end

    it 'handles GraphQL errors gracefully' do
      allow(service).to receive(:execute_graphql_request).and_return({
        success: false,
        error: 'GraphQL API error'
      })

      result = service.subscribe_to_compliance_webhooks

      expect(result[:success]).to be false
      expect(result[:error]).to include('GraphQL API error')
    end

    it 'handles user errors from Shopify' do
      error_response = {
        'data' => {
          'webhookSubscriptionCreate' => {
            'webhookSubscription' => nil,
            'userErrors' => [
              { 'field' => 'callbackUrl', 'message' => 'Invalid URL' }
            ]
          }
        }
      }

      allow(service).to receive(:execute_graphql_request).and_return({
        success: true,
        data: error_response['data']
      })

      result = service.subscribe_to_compliance_webhooks

      expect(result[:success]).to be false
    end

    it 'retries on transient failures' do
      call_count = 0
      allow(service).to receive(:execute_graphql_request) do
        call_count += 1
        if call_count == 1
          { success: false, error: 'Rate limit exceeded' }
        else
          { success: true, data: mock_response['data'] }
        end
      end

      # Mock retry logic
      allow(service).to receive(:should_retry_error?).and_return(true, false)
      allow(service).to receive(:sleep)

      result = service.subscribe_to_compliance_webhooks

      expect(result[:success]).to be true
    end
  end

  describe '#build_webhook_url' do
    before do
      allow(ENV).to receive(:[]).with('WEBHOOK_HOST').and_return('app.example.com')
      allow(Rails.env).to receive(:production?).and_return(true)
    end

    it 'builds correct webhook URLs for all topics' do
      topics = ['customers/data_request', 'customers/redact', 'shop/redact']
      
      topics.each do |topic|
        url = service.send(:build_webhook_url, topic)
        
        expect(url).to start_with('https://app.example.com/shopify/webhooks/')
        expect(url).to be_a_valid_url
      end
    end

    it 'uses HTTPS in production' do
      allow(Rails.env).to receive(:production?).and_return(true)
      
      url = service.send(:build_webhook_url, 'customers/data_request')
      expect(url).to start_with('https://')
    end

    it 'validates generated URLs' do
      url = service.send(:build_webhook_url, 'customers/data_request')
      expect(service.send(:valid_webhook_url?, url)).to be true
    end

    it 'raises error for unknown topics' do
      expect {
        service.send(:build_webhook_url, 'unknown/topic')
      }.to raise_error(RuntimeError, /Unknown topic/)
    end
  end

  describe '#normalize_topic_for_graphql' do
    it 'converts topic names to GraphQL enum format' do
      mappings = {
        'customers/data_request' => 'CUSTOMERS_DATA_REQUEST',
        'customers/redact' => 'CUSTOMERS_REDACT',
        'shop/redact' => 'SHOP_REDACT'
      }

      mappings.each do |topic, expected|
        result = service.send(:normalize_topic_for_graphql, topic)
        expect(result).to eq(expected)
      end
    end

    it 'raises error for unknown topics' do
      expect {
        service.send(:normalize_topic_for_graphql, 'unknown/topic')
      }.to raise_error(ArgumentError, /Unknown webhook topic/)
    end
  end

  describe 'error handling and resilience' do
    it 'handles network timeouts gracefully' do
      allow(service).to receive(:execute_graphql_request)
        .and_raise(Net::TimeoutError.new('Request timeout'))

      result = service.subscribe_to_compliance_webhooks

      expect(result[:success]).to be false
      expect(result[:error]).to include('timeout')
    end

    it 'handles HTTP errors from Shopify API' do
      allow(service).to receive(:execute_graphql_request).and_return({
        success: false,
        error: 'HTTP 500: Internal Server Error'
      })

      result = service.subscribe_to_compliance_webhooks

      expect(result[:success]).to be false
      expect(result[:error]).to include('500')
    end

    it 'handles malformed API responses' do
      allow(service).to receive(:execute_graphql_request).and_return({
        success: true,
        data: nil
      })

      expect {
        service.subscribe_to_compliance_webhooks
      }.not_to raise_error
    end
  end

  describe 'webhook subscription verification' do
    it 'verifies successful subscription responses' do
      valid_response = {
        success: true,
        data: {
          'webhookSubscriptionCreate' => {
            'webhookSubscription' => {
              'id' => 'gid://shopify/WebhookSubscription/123',
              'callbackUrl' => 'https://app.example.com/shopify/webhooks/customers_data_request',
              'apiVersion' => '2024-10'
            },
            'userErrors' => []
          }
        }
      }

      result = service.send(:verify_subscription_success, valid_response)
      expect(result).to be true
    end

    it 'fails verification for responses with user errors' do
      error_response = {
        success: true,
        data: {
          'webhookSubscriptionCreate' => {
            'webhookSubscription' => nil,
            'userErrors' => [
              { 'field' => 'callbackUrl', 'message' => 'Invalid URL' }
            ]
          }
        }
      }

      result = service.send(:verify_subscription_success, error_response)
      expect(result).to be false
    end

    it 'fails verification for incomplete subscription data' do
      incomplete_response = {
        success: true,
        data: {
          'webhookSubscriptionCreate' => {
            'webhookSubscription' => {
              'id' => 'gid://shopify/WebhookSubscription/123'
              # Missing callbackUrl and apiVersion
            },
            'userErrors' => []
          }
        }
      }

      result = service.send(:verify_subscription_success, incomplete_response)
      expect(result).to be false
    end
  end

  private

  def be_a_valid_url
    satisfy { |url| URI.parse(url).is_a?(URI::HTTP) rescue false }
  end
end
