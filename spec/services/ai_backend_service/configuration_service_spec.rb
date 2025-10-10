# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendService::ConfigurationService do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }
  let(:service) { described_class.new }
  let(:scope) { AiBackendService::Constants::Scope::STORE }
  let(:resource_id) { 123 }
  let(:config_key) { AiBackendService::Constants::ConfigKey::GENERAL_STORE_CONFIG }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)
  end

  describe '#save_configuration' do
    let(:config_data) { { timezone: 'America/New_York' } }

    before do
      allow(service).to receive(:get_configuration).and_return({})
      stub_request(:put, "#{ai_backend_url}/api/configurations/#{config_key}")
        .with(query: { scope: scope, store_id: resource_id.to_s, id_type: 'external' })
        .to_return(status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'saves configuration successfully' do
      service.save_configuration(
        scope: scope,
        resource_id: resource_id,
        config_key: config_key,
        config_data: config_data
      )

      expect(a_request(:put, "#{ai_backend_url}/api/configurations/#{config_key}")
        .with(query: { scope: scope, store_id: resource_id.to_s, id_type: 'external' })).to have_been_made
    end

    context 'with partial update' do
      it 'sends only provided data without merging' do
        partial_data = { chatwoot_app_api_token: 'new_token' }

        service.save_configuration(
          scope: scope,
          resource_id: resource_id,
          config_key: config_key,
          config_data: partial_data,
          partial: true
        )

        # Verify the request was made with only the partial data (not merged)
        expect(a_request(:put, "#{ai_backend_url}/api/configurations/#{config_key}")
          .with(
            query: { scope: scope, store_id: resource_id.to_s, id_type: 'external' },
            body: { data: partial_data }.to_json
          )).to have_been_made

        # Verify get_configuration was NOT called for partial updates
        expect(service).not_to have_received(:get_configuration)
      end
    end

    context 'without partial flag' do
      it 'merges with existing configuration' do
        existing_config = { timezone: 'UTC', start_business_hour: 8 }
        allow(service).to receive(:get_configuration).and_return(existing_config)

        new_data = { chatwoot_app_api_token: 'new_token' }
        merged_data = existing_config.merge(new_data)

        service.save_configuration(
          scope: scope,
          resource_id: resource_id,
          config_key: config_key,
          config_data: new_data,
          partial: false
        )

        # Verify the request was made with merged data
        expect(a_request(:put, "#{ai_backend_url}/api/configurations/#{config_key}")
          .with(
            query: { scope: scope, store_id: resource_id.to_s, id_type: 'external' },
            body: { data: merged_data }.to_json
          )).to have_been_made

        # Verify get_configuration WAS called for full updates
        expect(service).to have_received(:get_configuration)
      end
    end
  end

  describe '#get_configuration' do
    let(:api_response) { { data: { timezone: 'UTC' } } }

    before do
      stub_request(:get, "#{ai_backend_url}/api/configurations/#{config_key}")
        .with(query: { scope: scope, store_id: resource_id.to_s, id_type: 'external' })
        .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns configuration data' do
      result = service.get_configuration(
        scope: scope,
        resource_id: resource_id,
        config_key: config_key
      )

      expect(result).to eq({ 'timezone' => 'UTC' })
    end
  end
end
