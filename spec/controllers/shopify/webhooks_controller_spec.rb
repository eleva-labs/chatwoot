# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::WebhooksController, type: :request do
  let(:valid_secret) { 'test_webhook_secret' }
  let(:shop_domain) { 'test-shop.myshopify.com' }
  let(:customer_payload) do
    {
      shop_domain: shop_domain,
      customer: { id: 123, email: 'test@example.com', phone: '555-1234' },
      data_request: { id: 456 }
    }
  end

  before do
    allow(ENV).to receive(:[]).with('SHOPIFY_CLIENT_SECRET').and_return(valid_secret)
  end

  describe 'webhook signature verification' do
    context 'with valid signature' do
      before do
        setup_valid_request(customer_payload.to_json)
      end

      it 'processes customers_data_request successfully' do
        expect(Shopify::CustomersDataRequestJob).to receive(:perform_later).with(customer_payload.stringify_keys)

        post '/shopify/webhooks/customers_data_request'

        expect(response).to have_http_status(:ok)
      end

      it 'processes customers_redact successfully' do
        expect(Shopify::CustomersRedactJob).to receive(:perform_later).with(customer_payload.stringify_keys)

        post '/shopify/webhooks/customers_redact'

        expect(response).to have_http_status(:ok)
      end

      it 'processes shop_redact successfully' do
        shop_payload = { shop_domain: shop_domain, shop_id: 789 }
        setup_valid_request(shop_payload.to_json)

        expect(Shopify::ShopRedactJob).to receive(:perform_later).with(shop_payload.stringify_keys)

        post '/shopify/webhooks/shop_redact'

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid signature' do
      before do
        setup_invalid_request(customer_payload.to_json)
      end

      it 'returns unauthorized for customers_data_request' do
        post '/shopify/webhooks/customers_data_request'
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not enqueue job for invalid signature' do
        expect(Shopify::CustomersDataRequestJob).not_to receive(:perform_later)
        post '/shopify/webhooks/customers_data_request'
      end

      it 'logs security warning' do
        expect(Rails.logger).to receive(:warn).with(/Invalid Shopify webhook signature/)
        post '/shopify/webhooks/customers_data_request'
      end
    end

    context 'with missing signature' do
      before do
        setup_request_without_signature(customer_payload.to_json)
      end

      it 'returns unauthorized' do
        post '/shopify/webhooks/customers_data_request'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'content type validation' do
    before do
      setup_valid_signature
    end

    it 'rejects requests without application/json content type' do
      post '/shopify/webhooks/customers_data_request',
           params: customer_payload.to_json,
           headers: {
             'Content-Type' => 'text/plain',
             'X-Shopify-Hmac-SHA256' => calculate_hmac(customer_payload.to_json)
           }

      expect(response).to have_http_status(:bad_request)
    end

    it 'accepts requests with correct content type' do
      setup_valid_request(customer_payload.to_json)
      expect(Shopify::CustomersDataRequestJob).to receive(:perform_later)

      post '/shopify/webhooks/customers_data_request'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'payload size validation' do
    before do
      setup_valid_signature
    end

    it 'rejects payloads that are too large' do
      large_payload = { shop_domain: shop_domain, data: 'x' * 2.megabytes }

      post '/shopify/webhooks/customers_data_request',
           params: large_payload.to_json,
           headers: {
             'Content-Type' => 'application/json',
             'Content-Length' => (2.megabytes + 1000).to_s,
             'X-Shopify-Hmac-SHA256' => calculate_hmac(large_payload.to_json)
           }

      expect(response).to have_http_status(:request_entity_too_large)
    end
  end

  describe 'payload validation' do
    before do
      setup_valid_signature
    end

    context 'with invalid JSON' do
      it 'returns bad request' do
        post '/shopify/webhooks/customers_data_request',
             params: 'invalid json',
             headers: {
               'Content-Type' => 'application/json',
               'X-Shopify-Hmac-SHA256' => calculate_hmac('invalid json')
             }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with missing required fields' do
      it 'returns bad request for missing shop_domain' do
        invalid_payload = customer_payload.except(:shop_domain)
        setup_valid_request(invalid_payload.to_json)

        post '/shopify/webhooks/customers_data_request'
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns bad request for missing customer data' do
        invalid_payload = customer_payload.except(:customer)
        setup_valid_request(invalid_payload.to_json)

        post '/shopify/webhooks/customers_data_request'
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with non-hash payload' do
      it 'returns bad request for array payload' do
        array_payload = [customer_payload]
        setup_valid_request(array_payload.to_json)

        post '/shopify/webhooks/customers_data_request'
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'job enqueueing failures' do
    before do
      setup_valid_request(customer_payload.to_json)
    end

    it 'still returns 200 OK even if job enqueueing fails' do
      allow(Shopify::CustomersDataRequestJob).to receive(:perform_later)
        .and_raise(StandardError.new('Redis down'))

      expect(Rails.logger).to receive(:error).with(/Failed to enqueue customers_data_request job/)

      post '/shopify/webhooks/customers_data_request'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'logging and monitoring' do
    before do
      setup_valid_request(customer_payload.to_json)
    end

    it 'includes request ID in log messages' do
      expect(Rails.logger).to receive(:info).with(/request_id/)
      expect(Shopify::CustomersDataRequestJob).to receive(:perform_later)

      post '/shopify/webhooks/customers_data_request'
    end

    it 'logs verification duration for monitoring' do
      expect(Rails.logger).to receive(:debug).with(/verification_duration_ms/)
      expect(Shopify::CustomersDataRequestJob).to receive(:perform_later)

      post '/shopify/webhooks/customers_data_request'
    end

    it 'logs security events for invalid signatures' do
      setup_invalid_request(customer_payload.to_json)
      
      expect(Rails.logger).to receive(:warn).with(/Invalid Shopify webhook signature/, hash_including(
        verification_duration_ms: be_a(Numeric),
        user_agent: be_a(String),
        request_id: be_a(String)
      ))

      post '/shopify/webhooks/customers_data_request'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'content type validation' do
    it 'requires application/json content type' do
      post '/shopify/webhooks/customers_data_request',
           params: customer_payload.to_json,
           headers: {
             'Content-Type' => 'text/plain',
             'X-Shopify-Hmac-SHA256' => calculate_hmac(customer_payload.to_json)
           }

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it 'accepts application/json with charset' do
      post '/shopify/webhooks/customers_data_request',
           params: customer_payload.to_json,
           headers: {
             'Content-Type' => 'application/json; charset=utf-8',
             'X-Shopify-Hmac-SHA256' => calculate_hmac(customer_payload.to_json)
           }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'payload size validation' do
    it 'rejects payloads larger than 1MB' do
      large_payload = {
        shop_domain: shop_domain,
        customer: { id: 123, large_data: 'x' * 2_000_000 }
      }

      post '/shopify/webhooks/customers_data_request',
           params: large_payload.to_json,
           headers: webhook_headers(large_payload.to_json)

      expect(response).to have_http_status(:payload_too_large)
    end

    it 'accepts payloads within size limit' do
      normal_payload = customer_payload
      
      post '/shopify/webhooks/customers_data_request',
           params: normal_payload.to_json,
           headers: webhook_headers(normal_payload.to_json)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'security testing' do
    it 'prevents timing attacks through consistent response times' do
      invalid_signatures = [
        'a',
        'short_signature',
        calculate_hmac(customer_payload.to_json)[0..20] + 'modified'
      ]

      times = invalid_signatures.map do |sig|
        start_time = Time.current
        
        post '/shopify/webhooks/customers_data_request',
             params: customer_payload.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'X-Shopify-Hmac-SHA256' => sig
             }

        Time.current - start_time
      end

      # Response times should be consistent (within 50ms variance)
      expect(times.max - times.min).to be < 0.05
      
      # All should return unauthorized
      invalid_signatures.each do |sig|
        post '/shopify/webhooks/customers_data_request',
             params: customer_payload.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'X-Shopify-Hmac-SHA256' => sig
             }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'blocks requests with tampered payloads' do
      original_payload = customer_payload.to_json
      original_hmac = calculate_hmac(original_payload)
      
      # Modify payload after HMAC calculation
      tampered_payload = original_payload.gsub('123', '456')

      post '/shopify/webhooks/customers_data_request',
           params: tampered_payload,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => original_hmac
           }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'requires exact HMAC match' do
      # Try with modified HMAC (single character change)
      original_hmac = calculate_hmac(customer_payload.to_json)
      modified_hmac = original_hmac[0..-2] + (original_hmac[-1] == 'A' ? 'B' : 'A')

      post '/shopify/webhooks/customers_data_request',
           params: customer_payload.to_json,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => modified_hmac
           }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'rate limiting considerations' do
    it 'handles rapid webhook requests efficiently' do
      # Simulate multiple rapid requests
      requests = 5
      start_time = Time.current

      requests.times do
        post '/shopify/webhooks/customers_data_request',
             params: customer_payload.to_json,
             headers: webhook_headers(customer_payload.to_json)
        
        expect(response).to have_http_status(:ok)
      end

      total_time = Time.current - start_time
      
      # Should handle 5 requests in under 1 second total
      expect(total_time).to be < 1.0
      
      # Each request should be under 200ms
      expect(total_time / requests).to be < 0.2
    end
  end

  describe 'HMAC verification security' do
    it 'uses secure comparison to prevent timing attacks' do
      setup_valid_request(customer_payload.to_json)

      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original
      expect(Shopify::CustomersDataRequestJob).to receive(:perform_later)

      post '/shopify/webhooks/customers_data_request'
    end

    it 'validates Base64 format of HMAC header' do
      post '/shopify/webhooks/customers_data_request',
           params: customer_payload.to_json,
           headers: {
             'Content-Type' => 'application/json',
             'X-Shopify-Hmac-SHA256' => 'invalid@base64!'
           }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  private

  def setup_valid_request(body)
    post_with_headers(body, {
      'Content-Type' => 'application/json',
      'X-Shopify-Hmac-SHA256' => calculate_hmac(body)
    })
  end

  def setup_invalid_request(body)
    post_with_headers(body, {
      'Content-Type' => 'application/json',
      'X-Shopify-Hmac-SHA256' => 'invalid_signature'
    })
  end

  def setup_request_without_signature(body)
    post_with_headers(body, {
      'Content-Type' => 'application/json'
    })
  end

  def setup_valid_signature
    allow_any_instance_of(Shopify::IntegrationHelper).to receive(:verify_shopify_webhook).and_return(true)
  end

  def post_with_headers(body, headers)
    @request_body = body
    @request_headers = headers
  end

  def post(path, params: nil)
    if @request_body && @request_headers
      super(path, params: @request_body, headers: @request_headers)
    else
      super(path, params: params)
    end
  end

  def calculate_hmac(body)
    Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', valid_secret, body))
  end
end 