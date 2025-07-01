# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shopify Webhook Error Scenarios', type: :request do
  include ActiveJob::TestHelper

  let(:valid_secret) { 'test_webhook_secret' }
  let(:shop_domain) { 'test-shop.myshopify.com' }
  let(:account) { create(:account) }
  let(:integration_hook) { create(:integrations_hook, app_id: 'shopify', reference_id: shop_domain, account: account) }

  before do
    allow(ENV).to receive(:[]).with('SHOPIFY_CLIENT_SECRET').and_return(valid_secret)
    integration_hook
  end

  describe 'malformed webhook payloads' do
    it 'handles invalid JSON gracefully' do
      invalid_payloads = [
        '{ invalid json }',
        '{"missing": brace',
        'not json at all',
        '',
        nil
      ]

      invalid_payloads.each do |payload|
        post '/shopify/webhooks/customers_data_request',
             params: payload,
             headers: webhook_headers(payload || '')

        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'rejects payloads with missing required fields' do
      invalid_payloads = [
        { customer: { id: 123 } },                                # Missing shop_domain
        { shop_domain: shop_domain },                             # Missing customer
        { shop_domain: shop_domain, customer: {} },               # Empty customer
        { shop_domain: '', customer: { id: 123 } }                # Empty shop_domain
      ]

      invalid_payloads.each do |payload|
        post '/shopify/webhooks/customers_data_request',
             params: payload.to_json,
             headers: webhook_headers(payload.to_json)

        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'handles oversized payloads' do
      large_payload = {
        shop_domain: shop_domain,
        customer: { id: 123, data: 'x' * 2_000_000 }
      }.to_json

      post '/shopify/webhooks/customers_data_request',
           params: large_payload,
           headers: webhook_headers(large_payload)

      expect(response).to have_http_status(:payload_too_large)
    end
  end

  describe 'missing data scenarios' do
    it 'handles missing integration hook' do
      integration_hook.destroy

      payload = {
        shop_domain: 'non-existent.myshopify.com',
        customer: { id: 123, email: 'test@example.com' },
        data_request: { id: 456 }
      }.to_json

      post '/shopify/webhooks/customers_data_request',
           params: payload,
           headers: webhook_headers(payload)

      expect(response).to have_http_status(:ok)
      expect { perform_enqueued_jobs }.not_to raise_error
    end

    it 'handles missing contact gracefully' do
      payload = {
        shop_domain: shop_domain,
        customer: { id: 999, email: 'nonexistent@example.com' },
        data_request: { id: 456 }
      }.to_json

      post '/shopify/webhooks/customers_data_request',
           params: payload,
           headers: webhook_headers(payload)

      expect(response).to have_http_status(:ok)
      expect { perform_enqueued_jobs }.not_to raise_error
    end
  end

  describe 'job processing failures' do
    it 'retries on transient errors' do
      allow_any_instance_of(Shopify::CustomersDataRequestJob)
        .to receive(:resolve_account)
        .and_raise(ActiveRecord::ConnectionTimeoutError.new('Timeout'))

      payload = {
        shop_domain: shop_domain,
        customer: { id: 123, email: 'test@example.com' },
        data_request: { id: 456 }
      }.to_json

      post '/shopify/webhooks/customers_data_request',
           params: payload,
           headers: webhook_headers(payload)

      expect(response).to have_http_status(:ok)

      expect {
        perform_enqueued_jobs
      }.to raise_error(ActiveRecord::ConnectionTimeoutError)
    end

    it 'handles job enqueueing failures' do
      allow(Shopify::CustomersDataRequestJob).to receive(:perform_later)
        .and_raise(Redis::ConnectionError.new('Redis down'))

      payload = {
        shop_domain: shop_domain,
        customer: { id: 123, email: 'test@example.com' },
        data_request: { id: 456 }
      }.to_json

      expect(Rails.logger).to receive(:error).with(/Failed to enqueue.*job/)

      post '/shopify/webhooks/customers_data_request',
           params: payload,
           headers: webhook_headers(payload)

      expect(response).to have_http_status(:ok)
    end
  end

  private

  def webhook_headers(payload)
    {
      'Content-Type' => 'application/json',
      'X-Shopify-Hmac-SHA256' => calculate_hmac(payload)
    }
  end

  def calculate_hmac(payload)
    Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', valid_secret, payload))
  end
end
