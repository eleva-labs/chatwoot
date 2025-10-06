# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendService::AgentSystemService do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, id: 456, name: 'Test Bot', description: 'Test description', account: account) }
  let(:store_id) { 'uuid-store-123' }
  let(:service) { described_class.new }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)
  end

  describe '#initialize' do
    it 'defaults to external id_type' do
      service = described_class.new
      expect(service.instance_variable_get(:@id_type)).to eq('external')
    end

    it 'accepts custom id_type' do
      service = described_class.new(id_type: 'internal')
      expect(service.instance_variable_get(:@id_type)).to eq('internal')
    end
  end

  describe '#create_agent_system' do
    let(:expected_request_body) do
      {
        agent_system: {
          name: 'Test Bot',
          external_id: '456',
          store_id: store_id,
          description: 'Test description',
          is_active: true
        }
      }
    end

    let(:api_response) do
      {
        id: 'uuid-agent-system-123',
        name: 'Test Bot',
        external_id: '456',
        store_id: store_id,
        description: 'Test description',
        is_active: true
      }
    end

    context 'when API call is successful' do
      before do
        stub_request(:post, "#{ai_backend_url}/api/agent_systems")
          .to_return(
            status: 200,
            body: api_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'creates agent system with external_id' do
        response = service.create_agent_system(agent_bot, store_id)

        expect(response['id']).to eq('uuid-agent-system-123')
        expect(response['external_id']).to eq('456')
        expect(response['name']).to eq('Test Bot')
      end

      it 'sends external_id as string' do
        service.create_agent_system(agent_bot, store_id)

        expect(a_request(:post, "#{ai_backend_url}/api/agent_systems").with do |req|
          body = JSON.parse(req.body)
          body['agent_system']['external_id'] == '456'
        end).to have_been_made
      end

      it 'includes store_id in request' do
        service.create_agent_system(agent_bot, store_id)

        expect(a_request(:post, "#{ai_backend_url}/api/agent_systems").with do |req|
          body = JSON.parse(req.body)
          body['agent_system']['store_id'] == store_id
        end).to have_been_made
      end
    end

    context 'when agent_bot has nil description' do
      before do
        agent_bot.update(description: nil)
        stub_request(:post, "#{ai_backend_url}/api/agent_systems")
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sends empty string for description' do
        service.create_agent_system(agent_bot, store_id)

        expect(a_request(:post, "#{ai_backend_url}/api/agent_systems").with do |req|
          body = JSON.parse(req.body)
          body['agent_system']['description'] == ''
        end).to have_been_made
      end
    end

    context 'when API call fails' do
      it 'raises AgentSystemError on 404' do
        stub_request(:post, "#{ai_backend_url}/api/agent_systems")
          .to_return(status: 404, body: { error: 'Not found' }.to_json)

        expect do
          service.create_agent_system(agent_bot, store_id)
        end.to raise_error(AiBackendService::AgentSystemService::AgentSystemError, /Agent system not found/)
      end

      it 'raises AgentSystemError on 400' do
        stub_request(:post, "#{ai_backend_url}/api/agent_systems")
          .to_return(status: 400, body: { error: 'Bad request' }.to_json)

        expect do
          service.create_agent_system(agent_bot, store_id)
        end.to raise_error(AiBackendService::AgentSystemService::AgentSystemError, /Bad request/)
      end

      it 'raises AgentSystemError on 500' do
        stub_request(:post, "#{ai_backend_url}/api/agent_systems")
          .to_return(status: 500, body: { error: 'Internal error' }.to_json)

        expect do
          service.create_agent_system(agent_bot, store_id)
        end.to raise_error(AiBackendService::AgentSystemService::AgentSystemError, /Unexpected error/)
      end
    end
  end

  describe '#get_agent_system' do
    let(:agent_system_id) { 456 } # External ID
    let(:api_response) do
      {
        id: 'uuid-agent-system-123',
        name: 'Test Bot',
        external_id: '456',
        is_active: true
      }
    end

    context 'with default id_type (external)' do
      before do
        stub_request(:get, "#{ai_backend_url}/api/agent_systems/#{agent_system_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'queries by external_id' do
        response = service.get_agent_system(agent_system_id)

        expect(response['external_id']).to eq('456')
        expect(a_request(:get, "#{ai_backend_url}/api/agent_systems/#{agent_system_id}").with(
                 query: { id_type: 'external' }
               )).to have_been_made
      end
    end

    context 'when agent system not found' do
      before do
        stub_request(:get, "#{ai_backend_url}/api/agent_systems/#{agent_system_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 404, body: { error: 'Not found' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises AgentSystemError' do
        expect do
          service.get_agent_system(agent_system_id)
        end.to raise_error(AiBackendService::AgentSystemService::AgentSystemError, /Agent system not found/)
      end
    end
  end
end
