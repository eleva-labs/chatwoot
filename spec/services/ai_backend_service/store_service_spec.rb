# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendService::StoreService do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }
  let(:account) { create(:account, id: 123, name: 'Test Store') }
  let(:user_email) { 'test@example.com' }
  let(:service) { described_class.new }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('AI_BACKEND_WEBHOOK_SECRET').and_return('test-webhook-secret')
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

  describe '#create_store' do
    let(:expected_request_body) do
      {
        name: 'Test Store',
        email: 'test@example.com',
        external_id: '123', # String conversion
        is_active: true,
        custom_attributes: {}
      }
    end

    let(:api_response) do
      {
        id: 'uuid-abc-123',
        name: 'Test Store',
        email: 'test@example.com',
        externalId: '123',
        isActive: true,
        customAttributes: {}
      }
    end

    context 'when the API call is successful' do
      before do
        stub_request(:post, "#{ai_backend_url}/api/stores")
          .with(body: expected_request_body.to_json)
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'creates store with external_id' do
        response = service.create_store(account, user_email)

        expect(response).to be_a(AiBackendService::Schemas::StoreResponse)
        expect(response.external_id).to eq('123')
        expect(response.name).to eq('Test Store')
        expect(response.id).to eq('uuid-abc-123')
      end

      it 'sends external_id as string in request' do
        service.create_store(account, user_email)

        expect(a_request(:post, "#{ai_backend_url}/api/stores").with(
                 body: hash_including(external_id: '123')
               )).to have_been_made
      end

      it 'uses POST method instead of PUT' do
        service.create_store(account, user_email)

        expect(a_request(:post, "#{ai_backend_url}/api/stores")).to have_been_made
      end
    end

    context 'when the API call fails' do
      it 'raises StoreError on 404' do
        stub_request(:post, "#{ai_backend_url}/api/stores")
          .to_return(status: 404, body: { error: 'Not found' }.to_json)

        expect do
          service.create_store(account, user_email)
        end.to raise_error(AiBackendService::StoreService::StoreError, /Store not found/)
      end

      it 'raises StoreError on 400' do
        stub_request(:post, "#{ai_backend_url}/api/stores")
          .to_return(status: 400, body: { error: 'Bad request' }.to_json)

        expect do
          service.create_store(account, user_email)
        end.to raise_error(AiBackendService::StoreService::StoreError, /Bad request/)
      end

      it 'raises StoreError on 500' do
        stub_request(:post, "#{ai_backend_url}/api/stores")
          .to_return(status: 500, body: { error: 'Internal error' }.to_json)

        expect do
          service.create_store(account, user_email)
        end.to raise_error(AiBackendService::StoreService::StoreError, /Unexpected error/)
      end
    end
  end

  describe '#get_store' do
    let(:store_id) { 123 } # External ID (Chatwoot account.id)
    let(:api_response) do
      {
        id: 'uuid-abc-123',
        name: 'Test Store',
        email: 'test@example.com',
        externalId: '123',
        isActive: true
      }
    end

    context 'with default id_type (external)' do
      it 'queries by external_id' do
        stub_request(:get, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })

        response = service.get_store(store_id)

        expect(response).to be_a(AiBackendService::Schemas::StoreResponse)
        expect(response.external_id).to eq('123')
        expect(a_request(:get, "#{ai_backend_url}/api/stores/#{store_id}").with(
                 query: { id_type: 'external' }
               )).to have_been_made
      end
    end

    context 'with custom id_type (internal)' do
      let(:service) { described_class.new(id_type: 'internal') }
      let(:store_id) { 'uuid-abc-123' }

      it 'queries by internal UUID' do
        stub_request(:get, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'internal' })
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })

        service.get_store(store_id)

        expect(a_request(:get, "#{ai_backend_url}/api/stores/#{store_id}").with(
                 query: { id_type: 'internal' }
               )).to have_been_made
      end
    end

    context 'when store not found' do
      it 'raises StoreError' do
        stub_request(:get, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)

        expect do
          service.get_store(store_id)
        end.to raise_error(AiBackendService::StoreService::StoreError, /Store not found/)
      end
    end
  end

  describe '#update_store' do
    let(:store_id) { 123 }
    let(:update_attributes) do
      {
        name: 'Updated Store',
        email: 'updated@example.com',
        external_id: 123,
        is_active: true
      }
    end

    let(:expected_request_body) do
      {
        name: 'Updated Store',
        email: 'updated@example.com',
        external_id: '123',
        is_active: true,
        custom_attributes: {}
      }
    end

    let(:api_response) do
      {
        id: 'uuid-abc-123',
        name: 'Updated Store',
        email: 'updated@example.com',
        externalId: '123',
        isActive: true
      }
    end

    context 'when update is successful' do
      before do
        stub_request(:put, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(
            query: { id_type: 'external' },
            body: expected_request_body.to_json
          )
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'updates store and returns response' do
        response = service.update_store(store_id, update_attributes)

        expect(response).to be_a(AiBackendService::Schemas::StoreResponse)
        expect(response.name).to eq('Updated Store')
        expect(response.email).to eq('updated@example.com')
      end

      it 'includes id_type in query params' do
        service.update_store(store_id, update_attributes)

        expect(a_request(:put, "#{ai_backend_url}/api/stores/#{store_id}").with(
                 query: { id_type: 'external' }
               )).to have_been_made
      end
    end

    context 'when update fails' do
      it 'raises StoreError' do
        stub_request(:put, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 400, body: { error: 'Invalid data' }.to_json)

        expect do
          service.update_store(store_id, update_attributes)
        end.to raise_error(AiBackendService::StoreService::StoreError, /Bad request/)
      end
    end
  end

  describe '#delete_store' do
    let(:store_id) { 123 }

    context 'when deletion succeeds' do
      it 'deletes the store and returns true' do
        stub_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external', cascade: true })
          .to_return(status: 200, body: '{}')

        result = service.delete_store(store_id)

        expect(result).to be true
        expect(a_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}").with(
                 query: { id_type: 'external', cascade: true }
               )).to have_been_made
      end

      it 'accepts cascade parameter' do
        stub_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external', cascade: false })
          .to_return(status: 200, body: '{}')

        result = service.delete_store(store_id, cascade: false)

        expect(result).to be true
        expect(a_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}").with(
                 query: { id_type: 'external', cascade: false }
               )).to have_been_made
      end
    end

    context 'when store not found (404)' do
      it 'returns true (idempotent deletion)' do
        stub_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external', cascade: true })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)

        result = service.delete_store(store_id)

        expect(result).to be true
      end

      it 'logs 404 as success' do
        stub_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external', cascade: true })
          .to_return(status: 404)
        allow(Rails.logger).to receive(:info)

        service.delete_store(store_id)

        expect(Rails.logger).to have_received(:info).with(/Store already deleted/)
      end
    end

    context 'when deletion fails with bad request (400)' do
      it 'raises StoreError' do
        stub_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external', cascade: true })
          .to_return(status: 400, body: { error: 'Bad request' }.to_json)

        expect { service.delete_store(store_id) }
          .to raise_error(AiBackendService::StoreService::StoreError, /Bad request/)
      end
    end

    context 'when deletion fails with server error (500)' do
      it 'raises StoreError' do
        stub_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'external', cascade: true })
          .to_return(status: 500, body: { error: 'Internal server error' }.to_json)

        expect { service.delete_store(store_id) }
          .to raise_error(AiBackendService::StoreService::StoreError, /Unexpected error/)
      end
    end

    context 'with custom id_type' do
      let(:service) { described_class.new(id_type: 'internal') }
      let(:store_id) { 'uuid-abc-123' }

      it 'uses custom id_type in query params' do
        stub_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}")
          .with(query: { id_type: 'internal', cascade: true })
          .to_return(status: 200, body: '{}')

        service.delete_store(store_id)

        expect(a_request(:delete, "#{ai_backend_url}/api/stores/#{store_id}").with(
                 query: { id_type: 'internal', cascade: true }
               )).to have_been_made
      end
    end
  end
end
