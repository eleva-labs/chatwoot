# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendService::UserService do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }
  let(:user) { create(:user, id: 789, name: 'Test User', email: 'user@example.com') }
  let(:store_id) { 'uuid-store-123' }
  let(:service) { described_class.new }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)
  end

  describe '#create_user' do
    let(:expected_request_body) do
      {
        firstName: 'Test',
        lastName: 'User',
        email: 'user@example.com',
        externalId: '789',
        role: 'admin',
        customAttributes: {}
      }
    end

    let(:api_response) do
      {
        id: 'uuid-user-123',
        firstName: 'Test',
        lastName: 'User',
        email: 'user@example.com',
        externalId: '789',
        role: 'admin'
      }
    end

    context 'when API call is successful' do
      before do
        stub_request(:post, "#{ai_backend_url}/api/users")
          .with(query: { store_id: store_id, id_type: 'external' })
          .to_return(
            status: 200,
            body: api_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'creates user with external_id' do
        response = service.create_user(user, store_id)

        expect(response['externalId']).to eq('789')
        expect(response['firstName']).to eq('Test')
      end
    end

    context 'when API call fails' do
      it 'raises UserError on 400' do
        stub_request(:post, "#{ai_backend_url}/api/users")
          .with(query: { store_id: store_id, id_type: 'external' })
          .to_return(status: 400, body: { error: 'Bad request' }.to_json)

        expect do
          service.create_user(user, store_id)
        end.to raise_error(AiBackendService::UserService::UserError, /Bad request/)
      end
    end
  end

  describe '#get_user' do
    let(:user_id) { 789 }
    let(:api_response) { { id: 'uuid-user-123', external_id: '789' } }

    it 'queries by external_id' do
      stub_request(:get, "#{ai_backend_url}/api/users/#{user_id}")
        .with(query: { id_type: 'external' })
        .to_return(
          status: 200,
          body: api_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      service.get_user(user_id)

      expect(a_request(:get, "#{ai_backend_url}/api/users/#{user_id}").with(
               query: { id_type: 'external' }
             )).to have_been_made
    end
  end

  describe '#delete_user' do
    let(:user_id) { 789 }

    context 'when deletion succeeds' do
      it 'deletes the user and returns true' do
        stub_request(:delete, "#{ai_backend_url}/api/users/#{user_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 200, body: '{}')

        result = service.delete_user(user_id)

        expect(result).to be true
        expect(a_request(:delete, "#{ai_backend_url}/api/users/#{user_id}").with(
                 query: { id_type: 'external' }
               )).to have_been_made
      end
    end

    context 'when user not found (404)' do
      it 'returns true (idempotent deletion)' do
        stub_request(:delete, "#{ai_backend_url}/api/users/#{user_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)

        result = service.delete_user(user_id)

        expect(result).to be true
      end

      it 'logs 404 as success' do
        stub_request(:delete, "#{ai_backend_url}/api/users/#{user_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 404)
        allow(Rails.logger).to receive(:info)

        service.delete_user(user_id)

        expect(Rails.logger).to have_received(:info).with(/User already deleted/)
      end
    end

    context 'when deletion fails with bad request (400)' do
      it 'raises UserError' do
        stub_request(:delete, "#{ai_backend_url}/api/users/#{user_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 400, body: { error: 'Bad request' }.to_json)

        expect { service.delete_user(user_id) }
          .to raise_error(AiBackendService::UserService::UserError, /Bad request/)
      end
    end

    context 'when deletion fails with server error (500)' do
      it 'raises UserError' do
        stub_request(:delete, "#{ai_backend_url}/api/users/#{user_id}")
          .with(query: { id_type: 'external' })
          .to_return(status: 500, body: { error: 'Internal server error' }.to_json)

        expect { service.delete_user(user_id) }
          .to raise_error(AiBackendService::UserService::UserError, /Unexpected error/)
      end
    end
  end
end
