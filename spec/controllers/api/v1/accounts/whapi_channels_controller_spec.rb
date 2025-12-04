require 'rails_helper'

RSpec.describe 'WhapiChannelsController', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before do
    # Mock the feature flag check for tests since the custom features system has validation issues
    allow_any_instance_of(Account).to receive(:feature_enabled?).with('channel_whatsapp_whapi_partner').and_return(true)

    # Stub required WHAPI env vars so service builds valid URLs/headers
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('WHAPI_PARTNER_TOKEN').and_return('test_partner_token')
    allow(ENV).to receive(:[]).with('WHAPI_PARTNER_BASE_URL').and_return('https://manager.whapi.cloud')
    allow(ENV).to receive(:[]).with('WHAPI_API_BASE_URL').and_return('https://gate.whapi.cloud')
    allow(ENV).to receive(:[]).with('WHAPI_PARTNER_DEFAULT_PROJECT_ID').and_return('proj_1')

    # Stub WebhookUrlService to avoid FRONTEND_URL dependency in CI
    allow_any_instance_of(Whatsapp::WebhookUrlService).to receive(:generate_webhook_url).and_return('https://test-webhook.example.com/webhooks/whapi')
  end

  describe 'POST /api/v1/accounts/:account_id/whapi_channels' do
    it 'validates name param' do
      post "/api/v1/accounts/#{account.id}/whapi_channels",
           headers: admin.create_new_auth_token,
           params: { name: '' },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('name is required')
      expect(response.parsed_body['correlation_id']).to be_present
    end

    it 'creates inbox and channel and sets provider_config' do
      # Partner endpoints
      stub_request(:get, %r{/projects$}).to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { projects: [{ id: 'proj_1' }] }.to_json
      )
      stub_request(:put, %r{/channels$}).to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { id: 'chan_1', token: 'tok_1' }.to_json
      )
      # Channel-level webhook
      stub_request(:patch, %r{/settings$}).to_return(status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' })
      # WHAPI health check endpoint
      stub_request(:get, 'https://gate.whapi.cloud/health').to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { status: 'ok' }.to_json
      )

      post "/api/v1/accounts/#{account.id}/whapi_channels",
           headers: admin.create_new_auth_token,
           params: { name: 'My Inbox' },
           as: :json

      expect(response).to have_http_status(:success)
      data = response.parsed_body
      expect(data['name']).to eq('My Inbox')
      expect(data['channel_type']).to eq('Channel::Whatsapp')
      expect(data['provider']).to eq('whapi')
      expect(data['provider_config']).to include('whapi_channel_id' => 'chan_1', 'connection_status' => 'pending')
      expect(data['provider_config']).to include('whapi_channel_token' => 'tok_1')
      expect(data['provider_config']['onboarding']).to be_present
    end

    it 'validates name format and length' do
      # Test invalid characters
      post "/api/v1/accounts/#{account.id}/whapi_channels",
           headers: admin.create_new_auth_token,
           params: { name: 'Invalid@Name!' },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('invalid name')
      expect(response.parsed_body['correlation_id']).to be_present

      # Test too short name
      post "/api/v1/accounts/#{account.id}/whapi_channels",
           headers: admin.create_new_auth_token,
           params: { name: 'A' },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('invalid name')

      # Test too long name
      post "/api/v1/accounts/#{account.id}/whapi_channels",
           headers: admin.create_new_auth_token,
           params: { name: 'A' * 81 },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('invalid name')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/whapi_channels/:id/retry_webhook' do
    let(:channel) do
      create(:channel_whatsapp,
             account: account,
             provider: 'whapi',
             phone_number: '1234567890',
             provider_config: { 'whapi_channel_id' => 'chan_1', 'whapi_channel_token' => 'tok_1', 'webhook_retry_needed' => true },
             sync_templates: false,
             validate_provider_config: false)
    end
    let(:inbox) do
      inbox = create(:inbox, account: account, channel: channel)
      create(:inbox_member, user: admin, inbox: inbox)
      inbox
    end

    it 'retries webhook setup successfully' do
      stub_request(:patch, %r{/settings$}).to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { ok: true }.to_json
      )

      post "/api/v1/accounts/#{account.id}/whapi_channels/#{inbox.id}/retry_webhook",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      data = response.parsed_body
      expect(data['message']).to eq('Webhook configured successfully')
      expect(data).to have_key('webhook_url')
    end

    it 'returns 422 when not a whapi inbox' do
      other_inbox = create(:inbox, account: account)
      create(:inbox_member, user: admin, inbox: other_inbox)
      post "/api/v1/accounts/#{account.id}/whapi_channels/#{other_inbox.id}/retry_webhook",
           headers: admin.create_new_auth_token,
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('Not a WHAPI WhatsApp inbox')
      expect(response.parsed_body['correlation_id']).to be_present
    end

    it 'handles webhook retry failure' do
      # Mock retry webhook to fail
      allow_any_instance_of(Whatsapp::Partner::WhapiPartnerService).to receive(:retry_webhook_setup)
        .and_raise(StandardError.new('Webhook configuration failed'))

      post "/api/v1/accounts/#{account.id}/whapi_channels/#{inbox.id}/retry_webhook",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('Webhook configuration failed')
      expect(response.parsed_body['correlation_id']).to be_present
    end
  end
end
