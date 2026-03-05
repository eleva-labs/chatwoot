# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Chat API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:ai_backend_url) { 'https://test.ai-backend.com' }

  # URL patterns for WebMock
  let(:message_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/message(\?.*)?$} }
  let(:stream_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/message/stream(\?.*)?$} }
  let(:sessions_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/sessions(\?.*)?$} }
  let(:agent_systems_url_pattern) { %r{#{ai_backend_url}/api/agent-systems(\?.*)?$} }
  let(:users_url_pattern) { %r{#{ai_backend_url}/api/users} }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)
  end

  # =============================================================================
  # POST /api/v1/accounts/:account_id/ai_chat (create)
  # =============================================================================
  describe 'POST /api/v1/accounts/:account_id/ai_chat' do
    let(:valid_params) do
      {
        agent_bot_id: agent_bot.id,
        messages: [{ content: 'Hello, AI!' }]
      }
    end

    let(:api_response) do
      {
        'agentOutput' => { 'textResponse' => 'Hello! How can I help you?' },
        'chatSessionId' => 'session-456'
      }
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/ai_chat", params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'with valid parameters' do
        before do
          stub_request(:post, message_url_pattern)
            .to_return(
              status: 200,
              body: api_response.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns success with response and session_id' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:success)
          json = response.parsed_body
          expect(json['response']).to eq('Hello! How can I help you?')
          expect(json['session_id']).to eq('session-456')
        end

        it 'passes chat_session_id when provided' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: valid_params.merge(chat_session_id: 'existing-session'),
               as: :json

          expect(response).to have_http_status(:success)
        end
      end

      context 'with missing message param' do
        it 'returns bad request' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: { agent_bot_id: agent_bot.id },
               as: :json

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['error']).to include('No message')
        end
      end

      context 'with missing agent_bot_id param' do
        it 'returns bad request' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: { messages: [{ content: 'Hello' }] },
               as: :json

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['error']).to include('No agent bot')
        end
      end

      context 'when agent bot not found' do
        it 'returns not found' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: { agent_bot_id: 99_999, messages: [{ content: 'Hello' }] },
               as: :json

          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body['error']).to include('not found')
        end
      end

      context 'when agent bot belongs to different account' do
        let(:other_account) { create(:account) }
        let(:other_bot) { create(:agent_bot, account: other_account) }

        it 'returns not found' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: { agent_bot_id: other_bot.id, messages: [{ content: 'Hello' }] },
               as: :json

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when UserNotFoundError is raised' do
        before do
          stub_request(:post, message_url_pattern)
            .to_return(
              status: 404,
              body: { detail: 'User not found' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )

          stub_request(:post, users_url_pattern)
            .to_return(status: 201, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns not found with appropriate message' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body['error']).to include('User account not found')
        end
      end

      context 'when AgentSystemNotFoundError is raised' do
        before do
          stub_request(:post, message_url_pattern)
            .to_return(
              status: 404,
              body: { detail: 'Agent system not found' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns not found with appropriate message' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body['error']).to include('AI bot is no longer available')
        end
      end

      context 'when OwnershipError is raised' do
        before do
          stub_request(:post, message_url_pattern)
            .to_return(
              status: 404,
              body: { detail: 'User does not belong to this store' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns forbidden' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:forbidden)
          expect(response.parsed_body['error']).to include('Access denied')
        end
      end

      context 'when ValidationError is raised' do
        before do
          stub_request(:post, message_url_pattern)
            .to_return(
              status: 400,
              body: { detail: 'Invalid message format' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns bad request' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['error']).to include('Invalid request')
        end
      end

      context 'when ServiceUnavailableError is raised' do
        before do
          stub_request(:post, message_url_pattern)
            .to_return(status: 503, body: 'Service Unavailable')
        end

        it 'returns service unavailable' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:service_unavailable)
          expect(response.parsed_body['error']).to include('temporarily unavailable')
        end
      end

      context 'when ServiceError is raised' do
        before do
          stub_request(:post, message_url_pattern)
            .to_return(
              status: 200,
              body: { unexpected: 'format' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns internal server error' do
          post "/api/v1/accounts/#{account.id}/ai_chat",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:internal_server_error)
          expect(response.parsed_body['error']).to include('AI service error')
        end
      end
    end
  end

  # =============================================================================
  # POST /api/v1/accounts/:account_id/ai_chat/stream
  # =============================================================================
  describe 'POST /api/v1/accounts/:account_id/ai_chat/stream' do
    let(:valid_params) do
      {
        agent_bot_id: agent_bot.id,
        messages: [{ content: 'Hello, AI!' }]
      }
    end

    let(:stream_body) { "data: {\"text\":\"Hello\"}\n\ndata: {\"text\":\" World\"}\n\n" }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/ai_chat/stream", params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'with valid parameters' do
        before do
          stub_request(:post, users_url_pattern)
            .to_return(status: 409, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

          stub_request(:post, stream_url_pattern)
            .to_return(
              status: 200,
              body: stream_body,
              headers: {
                'Content-Type' => 'text/event-stream',
                'X-Chat-Session-Id' => 'session-789'
              }
            )
        end

        it 'returns success' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:success)
        end

        it 'sets SSE content type header' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response.headers['Content-Type']).to include('text/event-stream')
        end

        it 'sets Cache-Control header to no-cache' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response.headers['Cache-Control']).to include('no-cache')
        end

        it 'sets X-Accel-Buffering header for nginx' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response.headers['X-Accel-Buffering']).to eq('no')
        end

        it 'sets Vercel AI SDK headers' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response.headers['x-vercel-ai-ui-message-stream']).to eq('v1')
          expect(response.headers['x-ai-streaming-protocol']).to eq('v1')
        end

        it 'streams response body' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: valid_params,
               as: :json

          expect(response.body).to include('Hello')
        end
      end

      context 'with missing message param' do
        it 'returns bad request' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: { agent_bot_id: agent_bot.id },
               as: :json

          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'with missing agent_bot_id param' do
        it 'returns bad request' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: { messages: [{ content: 'Hello' }] },
               as: :json

          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'when agent bot not found' do
        it 'returns not found' do
          post "/api/v1/accounts/#{account.id}/ai_chat/stream",
               headers: agent.create_new_auth_token,
               params: { agent_bot_id: 99_999, messages: [{ content: 'Hello' }] },
               as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  # =============================================================================
  # GET /api/v1/accounts/:account_id/ai_chat/bots
  # =============================================================================
  describe 'GET /api/v1/accounts/:account_id/ai_chat/bots' do
    let(:agent_systems_response) do
      [
        {
          'externalId' => agent_bot.id.to_s,
          'name' => 'Test Bot',
          'description' => 'A test bot',
          'isActive' => true,
          'workflows' => [{ 'name' => 'Workflow 1' }]
        }
      ]
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_chat/bots"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'when AI Backend returns bots' do
        before do
          stub_request(:get, agent_systems_url_pattern)
            .to_return(
              status: 200,
              body: agent_systems_response.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns list of bots' do
          get "/api/v1/accounts/#{account.id}/ai_chat/bots",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          json = response.parsed_body
          expect(json['bots']).to be_an(Array)
          expect(json['bots'].length).to eq(1)
        end

        it 'returns bot with expected fields' do
          get "/api/v1/accounts/#{account.id}/ai_chat/bots",
              headers: agent.create_new_auth_token,
              as: :json

          bot = response.parsed_body['bots'].first
          expect(bot['id']).to eq(agent_bot.id)
          expect(bot['name']).to eq('Test Bot')
          expect(bot['description']).to eq('A test bot')
          expect(bot['is_active']).to be true
          expect(bot['workflows']).to eq('Workflow 1')
        end

        it 'enriches with Chatwoot avatar URL when avatar is attached' do
          agent_bot.avatar.attach(
            io: Rails.root.join('spec/assets/avatar.png').open,
            filename: 'avatar.png',
            content_type: 'image/png'
          )

          get "/api/v1/accounts/#{account.id}/ai_chat/bots",
              headers: agent.create_new_auth_token,
              as: :json

          bot = response.parsed_body['bots'].first
          expect(bot['avatar_url']).to be_present
          expect(bot['avatar_url']).to include('avatar.png')
        end
      end

      context 'when AI Backend returns empty list' do
        before do
          stub_request(:get, agent_systems_url_pattern)
            .to_return(
              status: 200,
              body: [].to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns empty bots array' do
          get "/api/v1/accounts/#{account.id}/ai_chat/bots",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['bots']).to eq([])
        end
      end

      context 'when AI Backend is unavailable' do
        before do
          stub_request(:get, agent_systems_url_pattern)
            .to_return(status: 503, body: 'Service Unavailable')
        end

        it 'returns service unavailable' do
          get "/api/v1/accounts/#{account.id}/ai_chat/bots",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:service_unavailable)
          expect(response.parsed_body['error']).to include('temporarily unavailable')
        end
      end
    end
  end

  # =============================================================================
  # GET /api/v1/accounts/:account_id/ai_chat/sessions
  # =============================================================================
  describe 'GET /api/v1/accounts/:account_id/ai_chat/sessions' do
    let(:sessions_response) do
      {
        'chatSessions' => [
          {
            'chatSessionId' => 'sess-1',
            'externalId' => 'ext-1',
            'isActive' => true,
            'createdAt' => '2025-01-01T00:00:00Z',
            'updatedAt' => '2025-01-02T00:00:00Z'
          }
        ],
        'totalCount' => 1
      }
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_chat/sessions", params: { agent_bot_id: agent_bot.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'with valid parameters' do
        before do
          stub_request(:get, sessions_url_pattern)
            .to_return(
              status: 200,
              body: sessions_response.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns sessions list' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions",
              headers: agent.create_new_auth_token,
              params: { agent_bot_id: agent_bot.id },
              as: :json

          expect(response).to have_http_status(:success)
          json = response.parsed_body
          expect(json['sessions']).to be_an(Array)
          expect(json['total_count']).to eq(1)
        end

        it 'uses default limit of 25' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions",
              headers: agent.create_new_auth_token,
              params: { agent_bot_id: agent_bot.id },
              as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['limit']).to eq(25)
        end

        it 'respects custom limit parameter' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions",
              headers: agent.create_new_auth_token,
              params: { agent_bot_id: agent_bot.id, limit: 10 },
              as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['limit']).to eq(10)
        end

        it 'clamps limit to maximum of 100' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions",
              headers: agent.create_new_auth_token,
              params: { agent_bot_id: agent_bot.id, limit: 500 },
              as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['limit']).to eq(100)
        end

        it 'clamps limit to minimum of 1' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions",
              headers: agent.create_new_auth_token,
              params: { agent_bot_id: agent_bot.id, limit: 0 },
              as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['limit']).to eq(1)
        end
      end

      context 'with missing agent_bot_id param' do
        it 'returns bad request' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['error']).to include('No agent bot')
        end
      end

      context 'when agent bot not found' do
        it 'returns not found' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions",
              headers: agent.create_new_auth_token,
              params: { agent_bot_id: 99_999 },
              as: :json

          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body['error']).to include('not found')
        end
      end

      context 'when service returns error' do
        before do
          stub_request(:get, sessions_url_pattern)
            .to_return(status: 500, body: 'Internal Server Error')
        end

        it 'returns service unavailable' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions",
              headers: agent.create_new_auth_token,
              params: { agent_bot_id: agent_bot.id },
              as: :json

          expect(response).to have_http_status(:service_unavailable)
          expect(response.parsed_body['error']).to include('Failed to load')
        end
      end
    end
  end

  # =============================================================================
  # GET /api/v1/accounts/:account_id/ai_chat/sessions/:session_id/messages
  # =============================================================================
  describe 'GET /api/v1/accounts/:account_id/ai_chat/sessions/:session_id/messages' do
    let(:session_id) { 'session-123' }
    let(:messages_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/sessions/#{session_id}/messages(\?.*)?$} }

    let(:messages_response) do
      {
        'messages' => [
          {
            'id' => 1,
            'externalId' => 'msg-1',
            'messageRole' => 'user',
            'content' => 'Hello',
            'sentDate' => '2025-01-01T00:00:00Z',
            'hasMedia' => false
          },
          {
            'id' => 2,
            'externalId' => 'msg-2',
            'messageRole' => 'assistant',
            'content' => 'Hi there!',
            'sentDate' => '2025-01-01T00:01:00Z',
            'hasMedia' => false
          }
        ],
        'totalCount' => 2
      }
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_chat/sessions/#{session_id}/messages"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'with valid session_id' do
        before do
          stub_request(:get, messages_url_pattern)
            .to_return(
              status: 200,
              body: messages_response.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns messages list' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions/#{session_id}/messages",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          json = response.parsed_body
          expect(json['messages']).to be_an(Array)
          expect(json['messages'].length).to eq(2)
          expect(json['total_count']).to eq(2)
        end

        it 'transforms messages to frontend format' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions/#{session_id}/messages",
              headers: agent.create_new_auth_token,
              as: :json

          message = response.parsed_body['messages'].first
          expect(message['id']).to be_present
          expect(message['role']).to eq('user')
          expect(message['content']).to eq('Hello')
          expect(message['timestamp']).to eq('2025-01-01T00:00:00Z')
        end

        it 'respects optional limit parameter' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions/#{session_id}/messages",
              headers: agent.create_new_auth_token,
              params: { limit: 10 },
              as: :json

          expect(response).to have_http_status(:success)
        end
      end

      context 'when service returns error' do
        before do
          stub_request(:get, messages_url_pattern)
            .to_return(status: 500, body: 'Internal Server Error')
        end

        it 'returns service unavailable' do
          get "/api/v1/accounts/#{account.id}/ai_chat/sessions/#{session_id}/messages",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:service_unavailable)
          expect(response.parsed_body['error']).to include('Failed to load')
        end
      end
    end
  end

  # =============================================================================
  # DELETE /api/v1/accounts/:account_id/ai_chat/sessions/:session_id
  # =============================================================================
  describe 'DELETE /api/v1/accounts/:account_id/ai_chat/sessions/:session_id' do
    let(:session_id) { 'session-123' }
    let(:delete_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/sessions/#{session_id}(\?.*)?$} }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/ai_chat/sessions/#{session_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'with valid session_id' do
        before do
          stub_request(:patch, delete_url_pattern)
            .to_return(
              status: 200,
              body: { success: true }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns success' do
          delete "/api/v1/accounts/#{account.id}/ai_chat/sessions/#{session_id}",
                 headers: agent.create_new_auth_token,
                 as: :json

          expect(response).to have_http_status(:success)
          json = response.parsed_body
          expect(json['success']).to be true
          expect(json['message']).to include('deleted successfully')
        end
      end

      context 'when service returns error' do
        before do
          stub_request(:patch, delete_url_pattern)
            .to_return(status: 500, body: 'Internal Server Error')
        end

        it 'returns service unavailable' do
          delete "/api/v1/accounts/#{account.id}/ai_chat/sessions/#{session_id}",
                 headers: agent.create_new_auth_token,
                 as: :json

          expect(response).to have_http_status(:service_unavailable)
          expect(response.parsed_body['error']).to include('Failed to delete')
        end
      end
    end
  end
end
