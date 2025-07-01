# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shopify Webhook Security', type: :request do
  let(:valid_secret) { 'test_webhook_secret_for_security_testing' }
  let(:shop_domain) { 'test-shop.myshopify.com' }
  let(:valid_payload) do
    {
      shop_domain: shop_domain,
      customer: { id: 123, email: 'test@example.com' },
      data_request: { id: 456 }
    }.to_json
  end

  before do
    allow(ENV).to receive(:[]).with('SHOPIFY_CLIENT_SECRET').and_return(valid_secret)
  end

  describe 'HMAC signature security' do
    it 'blocks requests with invalid signatures' do
      post '/shopify/webhooks/customers_data_request',
           params: valid_payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => 'fake_signature'
           }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'uses constant-time comparison' do
      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original

      post '/shopify/webhooks/customers_data_request',
           params: valid_payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => calculate_valid_hmac(valid_payload)
           }
    end

    it 'detects payload tampering' do
      original_hmac = calculate_valid_hmac(valid_payload)
      modified_payload = valid_payload.gsub('123', '999')

      post '/shopify/webhooks/customers_data_request',
           params: modified_payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => original_hmac
           }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'payload security' do
    it 'blocks oversized payloads' do
      large_payload = {
        shop_domain: shop_domain,
        customer: { id: 123, data: 'x' * 2_000_000 }
      }.to_json

      post '/shopify/webhooks/customers_data_request',
           params: large_payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => calculate_valid_hmac(large_payload)
           }

      expect(response).to have_http_status(:payload_too_large)
    end

    it 'handles malformed JSON gracefully' do
      malformed_payload = '{"invalid": json}'

      post '/shopify/webhooks/customers_data_request',
           params: malformed_payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => calculate_valid_hmac(malformed_payload)
           }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'authentication bypass prevention' do
    it 'blocks requests without authentication headers' do
      post '/shopify/webhooks/customers_data_request',
           params: valid_payload,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not leak sensitive information in error responses' do
      post '/shopify/webhooks/customers_data_request',
           params: valid_payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => 'invalid_signature'
           }

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to be_empty
    end
  end

  private

  def calculate_valid_hmac(payload)
    Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', valid_secret, payload))
  end
end
