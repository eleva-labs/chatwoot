# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendService::ConfigurationService do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }
  let(:service) { described_class.new }
  let(:scope) { AiBackendService::Constants::Scope::STORE }
  let(:resource_id) { 123 }
  let(:config_key) { AiBackendService::Constants::ConfigKey::GENERAL_STORE }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)
  end

  describe '#save_configuration' do
    let(:config_data) { { timezone: 'America/New_York' } }

    before do
      allow(service).to receive(:get_configuration).and_return({})
      stub_request(:put, "#{ai_backend_url}/api/configurations")
        .with(query: { id_type: 'external' })
        .to_return(status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'saves configuration successfully' do
      service.save_configuration(
        scope: scope,
        resource_id: resource_id,
        config_key: config_key,
        config_data: config_data
      )

      expect(a_request(:put, "#{ai_backend_url}/api/configurations")
        .with(query: { id_type: 'external' })).to have_been_made
    end
  end

  describe '#get_configuration' do
    let(:api_response) { { configuration: { data: { timezone: 'UTC' } } } }

    before do
      stub_request(:get, "#{ai_backend_url}/api/configurations")
        .with(query: { scope: scope, resource_id: resource_id, key: config_key, id_type: 'external' })
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
