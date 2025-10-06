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
        user: {
          name: 'Test User',
          email: 'user@example.com',
          external_id: '789',
          store_id: store_id,
          is_active: true
        }
      }
    end

    let(:api_response) do
      {
        id: 'uuid-user-123',
        name: 'Test User',
        email: 'user@example.com',
        external_id: '789',
        is_active: true
      }
    end

    context 'when API call is successful' do
      before do
        stub_request(:post, "#{ai_backend_url}/api/users")
          .to_return(
            status: 200,
            body: api_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'creates user with external_id' do
        response = service.create_user(user, store_id)

        expect(response['external_id']).to eq('789')
        expect(response['name']).to eq('Test User')
      end
    end

    context 'when API call fails' do
      it 'raises UserError on 400' do
        stub_request(:post, "#{ai_backend_url}/api/users")
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
end
