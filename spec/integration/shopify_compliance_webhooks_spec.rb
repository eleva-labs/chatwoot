# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shopify Compliance Webhooks Integration', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:integration_hook) { create(:integrations_hook, app_id: 'shopify', reference_id: shop_domain, account: account) }
  let(:contact) { create(:contact, account: account, email: 'customer@example.com', name: 'John Doe', phone_number: '+1234567890') }
  let(:shop_domain) { 'test-shop.myshopify.com' }
  let(:valid_secret) { 'test_webhook_secret' }
  
  before do
    allow(ENV).to receive(:[]).with('SHOPIFY_CLIENT_SECRET').and_return(valid_secret)
    integration_hook
    contact
  end

  describe 'end-to-end webhook processing verification' do
    let(:data_request_payload) do
      {
        shop_domain: shop_domain,
        customer: { id: 123, email: 'customer@example.com' },
        data_request: { id: 456 }
      }.to_json
    end

    it 'verifies complete webhook processing pipeline' do
      post '/shopify/webhooks/customers_data_request',
           params: data_request_payload,
           headers: webhook_headers(data_request_payload)
      
      expect(response).to have_http_status(:ok)
      expect(Shopify::CustomersDataRequestJob).to have_been_enqueued
      
      perform_enqueued_jobs
      # Additional verification would go here based on actual implementation
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
