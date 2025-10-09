# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendService::ChannelService do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }
  let(:account) { create(:account, id: 456) }
  let(:inbox) { create(:inbox, id: 789, account: account, name: 'Test Channel') }
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

  describe '#create_channel' do
    let(:store_id) { account.id }
    let(:expected_request_body) do
      {
        name: 'Test Channel',
        channelType: inbox.channel_type,
        externalId: '789',
        storeId: '456',
        isActive: true,
        metadata: {
          email_address: inbox.email_address,
          phone_number: inbox.channel.try(:phone_number),
          greeting_enabled: inbox.greeting_enabled,
          timezone: inbox.timezone
        }
      }
    end

    let(:api_response) do
      {
        id: 'uuid-channel-123',
        name: 'Test Channel',
        channelType: inbox.channel_type,
        externalId: '789',
        storeId: '456',
        isActive: true,
        metadata: {}
      }
    end

    context 'when the API call is successful' do
      before do
        stub_request(:post, "#{ai_backend_url}/api/channels")
          .with(
            query: { id_type: 'external' },
            body: expected_request_body.to_json
          )
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'creates channel with external_id' do
        response = service.create_channel(inbox, store_id)

        expect(response).to be_a(OpenStruct)
        expect(response.externalId).to eq('789')
        expect(response.name).to eq('Test Channel')
        expect(response.id).to eq('uuid-channel-123')
      end

      it 'sends external_id as string in request' do
        service.create_channel(inbox, store_id)

        expect(a_request(:post, "#{ai_backend_url}/api/channels").with(
                 query: { id_type: 'external' },
                 body: hash_including(externalId: '789')
               )).to have_been_made
      end

      it 'includes store_id in request body' do
        service.create_channel(inbox, store_id)

        expect(a_request(:post, "#{ai_backend_url}/api/channels").with(
                 query: { id_type: 'external' },
                 body: hash_including(storeId: '456')
               )).to have_been_made
      end
    end

    context 'when the API call fails' do
      it 'raises ChannelError on 400' do
        stub_request(:post, "#{ai_backend_url}/api/channels")
          .with(query: { id_type: 'external' })
          .to_return(status: 400, body: { error: 'Bad request' }.to_json)

        expect do
          service.create_channel(inbox, store_id)
        end.to raise_error(AiBackendService::ChannelService::ChannelError, /Failed to create channel/)
      end

      it 'raises ChannelError on 500' do
        stub_request(:post, "#{ai_backend_url}/api/channels")
          .with(query: { id_type: 'external' })
          .to_return(status: 500, body: { error: 'Internal error' }.to_json)

        expect do
          service.create_channel(inbox, store_id)
        end.to raise_error(AiBackendService::ChannelService::ChannelError, /Failed to create channel/)
      end

      it 'wraps StandardError in ChannelError' do
        allow(HTTParty).to receive(:post).and_raise(StandardError, 'Network error')

        expect do
          service.create_channel(inbox, store_id)
        end.to raise_error(AiBackendService::ChannelService::ChannelError, /Channel creation failed: Network error/)
      end
    end
  end

  describe '#get_channel' do
    let(:channel_id) { 789 } # External ID (Chatwoot inbox.id)
    let(:api_response) do
      {
        id: 'uuid-channel-123',
        name: 'Test Channel',
        channelType: 'Channel::WebWidget',
        externalId: '789',
        storeId: '456',
        isActive: true
      }
    end

    context 'with default id_type (external)' do
      it 'queries by external_id' do
        stub_request(:get, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })

        response = service.get_channel(channel_id)

        expect(response).to be_a(OpenStruct)
        expect(response.externalId).to eq('789')
        expect(a_request(:get, "#{ai_backend_url}/api/channels/#{channel_id}").with(
                 query: { id_type: 'external' }
               )).to have_been_made
      end
    end

    context 'with custom id_type (internal)' do
      let(:service) { described_class.new(id_type: 'internal') }
      let(:channel_id) { 'uuid-channel-123' }

      it 'queries by internal UUID' do
        stub_request(:get, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'internal' })
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })

        service.get_channel(channel_id)

        expect(a_request(:get, "#{ai_backend_url}/api/channels/#{channel_id}").with(
                 query: { id_type: 'internal' }
               )).to have_been_made
      end
    end

    context 'when channel not found' do
      it 'raises ChannelError' do
        stub_request(:get, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)

        expect do
          service.get_channel(channel_id)
        end.to raise_error(AiBackendService::ChannelService::ChannelError, /Failed to get channel/)
      end
    end
  end

  describe '#delete_channel' do
    let(:channel_id) { 789 }
    let(:store_id) { 456 }

    context 'when deletion succeeds' do
      it 'deletes the channel and returns true' do
        stub_request(:delete, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'external', store_id: store_id })
          .to_return(status: 200, body: '{}')

        result = service.delete_channel(channel_id, store_id)

        expect(result).to be true
        expect(a_request(:delete, "#{ai_backend_url}/api/channels/#{channel_id}").with(
                 query: { id_type: 'external', store_id: store_id }
               )).to have_been_made
      end
    end

    context 'when deletion fails with bad request (400)' do
      it 'raises ChannelError' do
        stub_request(:delete, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'external', store_id: store_id })
          .to_return(status: 400, body: { error: 'Bad request' }.to_json)

        expect { service.delete_channel(channel_id, store_id) }
          .to raise_error(AiBackendService::ChannelService::ChannelError, /Failed to delete channel/)
      end
    end

    context 'when deletion fails with server error (500)' do
      it 'raises ChannelError' do
        stub_request(:delete, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'external', store_id: store_id })
          .to_return(status: 500, body: { error: 'Internal server error' }.to_json)

        expect { service.delete_channel(channel_id, store_id) }
          .to raise_error(AiBackendService::ChannelService::ChannelError, /Failed to delete channel/)
      end
    end

    context 'with custom id_type' do
      let(:service) { described_class.new(id_type: 'internal') }
      let(:channel_id) { 'uuid-channel-123' }

      it 'uses custom id_type in query params' do
        stub_request(:delete, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'internal', store_id: store_id })
          .to_return(status: 200, body: '{}')

        service.delete_channel(channel_id, store_id)

        expect(a_request(:delete, "#{ai_backend_url}/api/channels/#{channel_id}").with(
                 query: { id_type: 'internal', store_id: store_id }
               )).to have_been_made
      end
    end
  end

  describe '#update_channel' do
    let(:channel_id) { 789 }
    let(:update_attributes) do
      {
        name: 'Updated Channel',
        isActive: false
      }
    end

    let(:api_response) do
      {
        id: 'uuid-channel-123',
        name: 'Updated Channel',
        channelType: 'Channel::WebWidget',
        externalId: '789',
        storeId: '456',
        isActive: false
      }
    end

    context 'when update is successful' do
      before do
        stub_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(
            query: { id_type: 'external' },
            body: update_attributes.to_json
          )
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'updates channel and returns response' do
        response = service.update_channel(channel_id, update_attributes)

        expect(response).to be_a(OpenStruct)
        expect(response.name).to eq('Updated Channel')
        expect(response.isActive).to be false
      end

      it 'includes id_type in query params' do
        service.update_channel(channel_id, update_attributes)

        expect(a_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}").with(
                 query: { id_type: 'external' }
               )).to have_been_made
      end

      it 'uses PUT HTTP verb (not PATCH)' do
        service.update_channel(channel_id, update_attributes)

        expect(a_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}").with(query: { id_type: 'external' })).to have_been_made
        expect(a_request(:patch, "#{ai_backend_url}/api/channels/#{channel_id}")).not_to have_been_made
      end
    end

    context 'when update fails' do
      it 'raises ChannelError' do
        stub_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 400, body: { error: 'Invalid data' }.to_json)

        expect do
          service.update_channel(channel_id, update_attributes)
        end.to raise_error(AiBackendService::ChannelService::ChannelError, /Failed to update channel/)
      end
    end
  end

  describe '#assign_agent_system' do
    let(:channel_id) { 789 }
    let(:agent_system_id) { 456 }

    let(:api_response) do
      {
        id: 'uuid-channel-123',
        externalId: '789',
        agentSystemId: '456'
      }
    end

    context 'when assignment succeeds' do
      before do
        stub_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(
            query: { id_type: 'external' },
            body: { agent_system_id: '456' }.to_json
          )
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'calls update_channel with agent_system_id' do
        result = service.assign_agent_system(channel_id, agent_system_id)

        expect(result).to be_a(OpenStruct)
        expect(result.agentSystemId).to eq('456')
        expect(a_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}").with(query: { id_type: 'external' })).to have_been_made
      end

      it 'logs the assignment' do
        expect(Rails.logger).to receive(:info).with(
          "AI Backend: Assigning agent system #{agent_system_id} to channel #{channel_id}"
        )

        service.assign_agent_system(channel_id, agent_system_id)
      end

      it 'converts agent_system_id to string' do
        service.assign_agent_system(channel_id, agent_system_id)

        expect(a_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}").with(
                 query: { id_type: 'external' },
                 body: hash_including('agent_system_id' => '456')
               )).to have_been_made
      end
    end

    context 'when assignment fails' do
      before do
        stub_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json)
      end

      it 'raises ChannelError' do
        expect do
          service.assign_agent_system(channel_id, agent_system_id)
        end.to raise_error(AiBackendService::ChannelService::ChannelError, /Channel update failed/)
      end
    end
  end

  describe '#unassign_agent_system' do
    let(:channel_id) { 789 }

    let(:api_response) do
      {
        id: 'uuid-channel-123',
        externalId: '789',
        agentSystemId: nil
      }
    end

    context 'when unassignment succeeds' do
      before do
        stub_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(
            query: { id_type: 'external' },
            body: { agent_system_id: nil }.to_json
          )
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'calls update_channel with null agent_system_id' do
        result = service.unassign_agent_system(channel_id)

        expect(result).to be_a(OpenStruct)
        expect(result.agentSystemId).to be_nil
        expect(a_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}").with(query: { id_type: 'external' })).to have_been_made
      end

      it 'logs the unassignment' do
        expect(Rails.logger).to receive(:info).with(
          "AI Backend: Unassigning agent system from channel #{channel_id}"
        )

        service.unassign_agent_system(channel_id)
      end
    end

    context 'when unassignment fails' do
      before do
        stub_request(:put, "#{ai_backend_url}/api/channels/#{channel_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'raises ChannelError' do
        expect do
          service.unassign_agent_system(channel_id)
        end.to raise_error(AiBackendService::ChannelService::ChannelError, /Channel update failed/)
      end
    end
  end
end
