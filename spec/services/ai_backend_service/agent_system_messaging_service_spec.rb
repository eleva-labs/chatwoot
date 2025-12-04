# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendService::AgentSystemMessagingService do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }
  let(:service) { described_class.new }
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, name: 'Test User', email: 'test@example.com') }
  let(:agent_bot) { create(:agent_bot, account: account) }

  # URL patterns - using regex to match URLs with query params
  let(:message_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/message(\?.*)?$} }
  let(:stream_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/message/stream(\?.*)?$} }
  let(:sessions_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/sessions(\?.*)?$} }
  let(:users_url_pattern) { %r{#{ai_backend_url}/api/users} }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)
  end

  # =============================================================================
  # #send_message
  # =============================================================================
  describe '#send_message' do
    let(:message) { 'Hello, AI!' }
    let(:chat_session_id) { 'session-123' }

    let(:api_response) do
      {
        'agentOutput' => { 'textResponse' => 'Hello! How can I help you?' },
        'chatSessionId' => 'session-456'
      }
    end

    context 'when API call is successful' do
      before do
        stub_request(:post, message_url_pattern)
          .to_return(
            status: 200,
            body: api_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns response_text and chat_session_id' do
        result = service.send_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message
        )

        expect(result['response_text']).to eq('Hello! How can I help you?')
        expect(result['chat_session_id']).to eq('session-456')
      end

      it 'builds correct query params with external id_type' do
        service.send_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message
        )

        expect(a_request(:post, message_url_pattern)
          .with(query: {
                  store_id: account.id.to_s,
                  agent_system_id: agent_bot.id.to_s,
                  user_id: user.id.to_s,
                  id_type: 'external'
                })).to have_been_made
      end

      it 'builds correct request body with agentInput structure' do
        service.send_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message
        )

        expect(a_request(:post, message_url_pattern)
          .with do |req|
            body = JSON.parse(req.body)
            body['agentInput']['messages'] == [message] &&
              body['agentInput']['context']['sender']['id'] == user.id &&
              body['agentInput']['context']['sender']['name'] == user.name &&
              body['agentInput']['context']['sender']['email'] == user.email &&
              body['agentInput']['context']['event'] == 'message_created'
          end).to have_been_made
      end

      it 'includes chatSessionId when provided' do
        service.send_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message,
          chat_session_id: chat_session_id
        )

        expect(a_request(:post, message_url_pattern)
          .with do |req|
            body = JSON.parse(req.body)
            body['chatSessionId'] == chat_session_id
          end).to have_been_made
      end

      it 'omits chatSessionId when nil' do
        service.send_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message,
          chat_session_id: nil
        )

        expect(a_request(:post, message_url_pattern)
          .with do |req|
            body = JSON.parse(req.body)
            !body.key?('chatSessionId')
          end).to have_been_made
      end
    end

    context 'when user not found on first attempt' do
      before do
        # First call returns 404 user not found, second succeeds
        stub_request(:post, message_url_pattern)
          .to_return(
            { status: 404, body: { detail: 'User not found' }.to_json, headers: { 'Content-Type' => 'application/json' } },
            { status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' } }
          )

        # User creation endpoint
        stub_request(:post, users_url_pattern)
          .to_return(status: 201, body: { id: 'new-user-id' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'retries after creating user and succeeds' do
        result = service.send_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message
        )

        expect(result['response_text']).to eq('Hello! How can I help you?')
        expect(a_request(:post, message_url_pattern)).to have_been_made.times(2)
      end
    end

    context 'when user not found after retry' do
      before do
        # Both calls return 404
        stub_request(:post, message_url_pattern)
          .to_return(
            status: 404,
            body: { detail: 'User not found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # User creation endpoint
        stub_request(:post, users_url_pattern)
          .to_return(status: 201, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises UserNotFoundError after max attempts' do
        expect do
          service.send_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          )
        end.to raise_error(described_class::UserNotFoundError)
      end
    end

    context 'when agent system not found' do
      before do
        stub_request(:post, message_url_pattern)
          .to_return(
            status: 404,
            body: { detail: 'Agent system not found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises AgentSystemNotFoundError' do
        expect do
          service.send_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          )
        end.to raise_error(described_class::AgentSystemNotFoundError)
      end
    end

    context 'when ownership error occurs' do
      before do
        stub_request(:post, message_url_pattern)
          .to_return(
            status: 404,
            body: { detail: 'User does not belong to this store' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises OwnershipError' do
        expect do
          service.send_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          )
        end.to raise_error(described_class::OwnershipError)
      end
    end

    context 'when validation error (400)' do
      before do
        stub_request(:post, message_url_pattern)
          .to_return(
            status: 400,
            body: { detail: 'Invalid message format' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ValidationError' do
        expect do
          service.send_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          )
        end.to raise_error(described_class::ValidationError, /Invalid message format/)
      end
    end

    context 'when service unavailable (503)' do
      before do
        stub_request(:post, message_url_pattern)
          .to_return(status: 503, body: 'Service Unavailable')
      end

      it 'raises ServiceUnavailableError' do
        expect do
          service.send_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          )
        end.to raise_error(described_class::ServiceUnavailableError)
      end
    end

    context 'when server error (500)' do
      before do
        stub_request(:post, message_url_pattern)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ServiceUnavailableError' do
        expect do
          service.send_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          )
        end.to raise_error(described_class::ServiceUnavailableError)
      end
    end

    context 'when response has invalid format' do
      before do
        stub_request(:post, message_url_pattern)
          .to_return(
            status: 200,
            body: { unexpected: 'format' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ServiceError for invalid response' do
        expect do
          service.send_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          )
        end.to raise_error(described_class::ServiceError, /Invalid response format/)
      end
    end
  end

  # =============================================================================
  # #stream_message
  # =============================================================================
  describe '#stream_message' do
    let(:message) { 'Hello, AI!' }

    context 'when block is not provided' do
      it 'raises ArgumentError' do
        expect do
          service.stream_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          )
        end.to raise_error(ArgumentError, 'Block required for streaming')
      end
    end

    context 'when streaming succeeds' do
      let(:stream_body) { "data: {\"text\":\"Hello\"}\n\ndata: {\"text\":\" World\"}\n\n" }

      before do
        # User exists check
        stub_request(:post, users_url_pattern)
          .to_return(status: 409, body: { detail: 'User already exists' }.to_json, headers: { 'Content-Type' => 'application/json' })

        # Stream endpoint
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

      it 'yields chunks to the block' do
        chunks_received = []

        service.stream_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message
        ) do |chunk, _session_id|
          chunks_received << chunk
        end

        expect(chunks_received.join).to include('Hello')
      end

      it 'passes session_id from response headers' do
        session_ids = []

        service.stream_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message
        ) do |_chunk, session_id|
          session_ids << session_id
        end

        expect(session_ids.first).to eq('session-789')
      end

      it 'builds correct stream URI with query params' do
        service.stream_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message
        ) { |_c, _s| nil }

        expect(a_request(:post, stream_url_pattern)
          .with(query: {
                  store_id: account.id.to_s,
                  agent_system_id: agent_bot.id.to_s,
                  user_id: user.id.to_s,
                  id_type: 'external'
                })).to have_been_made
      end

      it 'includes chatSessionId in body when provided' do
        service.stream_message(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          message: message,
          chat_session_id: 'existing-session'
        ) { |_c, _s| nil }

        expect(a_request(:post, stream_url_pattern)
          .with do |req|
            body = JSON.parse(req.body)
            body['chatSessionId'] == 'existing-session'
          end).to have_been_made
      end
    end

    context 'when stream returns 404 user not found' do
      before do
        stub_request(:post, users_url_pattern)
          .to_return(status: 201, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:post, stream_url_pattern)
          .to_return(status: 404, body: 'User not found')
      end

      it 'raises UserNotFoundError' do
        expect do
          service.stream_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          ) { |_c, _s| nil }
        end.to raise_error(described_class::UserNotFoundError)
      end
    end

    context 'when stream returns 404 agent system not found' do
      before do
        stub_request(:post, users_url_pattern)
          .to_return(status: 409, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:post, stream_url_pattern)
          .to_return(status: 404, body: 'Agent system not found')
      end

      it 'raises AgentSystemNotFoundError' do
        expect do
          service.stream_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          ) { |_c, _s| nil }
        end.to raise_error(described_class::AgentSystemNotFoundError)
      end
    end

    context 'when stream returns 400 validation error' do
      before do
        stub_request(:post, users_url_pattern)
          .to_return(status: 409, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:post, stream_url_pattern)
          .to_return(status: 400, body: 'Invalid request')
      end

      it 'raises ValidationError' do
        expect do
          service.stream_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          ) { |_c, _s| nil }
        end.to raise_error(described_class::ValidationError)
      end
    end

    context 'when stream returns 503 service unavailable' do
      before do
        stub_request(:post, users_url_pattern)
          .to_return(status: 409, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:post, stream_url_pattern)
          .to_return(status: 503, body: 'Service Unavailable')
      end

      it 'raises ServiceUnavailableError' do
        expect do
          service.stream_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          ) { |_c, _s| nil }
        end.to raise_error(described_class::ServiceUnavailableError)
      end
    end

    context 'when connection times out' do
      before do
        stub_request(:post, users_url_pattern)
          .to_return(status: 409, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:post, stream_url_pattern)
          .to_timeout
      end

      it 'raises ServiceUnavailableError' do
        expect do
          service.stream_message(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id,
            message: message
          ) { |_c, _s| nil }
        end.to raise_error(described_class::ServiceUnavailableError, /timeout/i)
      end
    end
  end

  # =============================================================================
  # #list_sessions
  # =============================================================================
  describe '#list_sessions' do
    let(:api_response) do
      {
        'chatSessions' => [
          {
            'chatSessionId' => 'sess-1',
            'externalId' => 'ext-1',
            'isActive' => true,
            'createdAt' => '2025-01-01T00:00:00Z',
            'updatedAt' => '2025-01-02T00:00:00Z'
          },
          {
            'chatSessionId' => 'sess-2',
            'externalId' => 'ext-2',
            'isActive' => true,
            'createdAt' => '2025-01-03T00:00:00Z',
            'updatedAt' => '2025-01-04T00:00:00Z'
          }
        ],
        'totalCount' => 2
      }
    end

    context 'when API call is successful' do
      before do
        stub_request(:get, sessions_url_pattern)
          .to_return(
            status: 200,
            body: api_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns sessions array with total_count' do
        result = service.list_sessions(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id
        )

        expect(result['sessions']).to be_an(Array)
        expect(result['sessions'].length).to eq(2)
        expect(result['total_count']).to eq(2)
      end

      it 'transforms camelCase to snake_case' do
        result = service.list_sessions(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id
        )

        session = result['sessions'].first
        expect(session['chat_session_id']).to eq('sess-1')
        expect(session['external_id']).to eq('ext-1')
        expect(session['is_active']).to be true
        expect(session['created_at']).to eq('2025-01-01T00:00:00Z')
        expect(session['updated_at']).to eq('2025-01-02T00:00:00Z')
      end

      it 'respects limit parameter' do
        result = service.list_sessions(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id,
          limit: 1
        )

        expect(result['sessions'].length).to eq(1)
      end

      it 'builds correct query params' do
        service.list_sessions(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id
        )

        expect(a_request(:get, sessions_url_pattern)
          .with(query: {
                  store_id: account.id.to_s,
                  user_id: user.id.to_s,
                  agent_system_id: agent_bot.id.to_s,
                  id_type: 'external'
                })).to have_been_made
      end
    end

    context 'when response has empty sessions' do
      before do
        stub_request(:get, sessions_url_pattern)
          .to_return(
            status: 200,
            body: { 'chatSessions' => [], 'totalCount' => 0 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns empty sessions array' do
        result = service.list_sessions(
          account_id: account.id,
          user_id: user.id,
          agent_bot_id: agent_bot.id
        )

        expect(result['sessions']).to eq([])
        expect(result['total_count']).to eq(0)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, sessions_url_pattern)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ServiceError' do
        expect do
          service.list_sessions(
            account_id: account.id,
            user_id: user.id,
            agent_bot_id: agent_bot.id
          )
        end.to raise_error(described_class::ServiceError)
      end
    end
  end

  # =============================================================================
  # #get_session_messages
  # =============================================================================
  describe '#get_session_messages' do
    let(:chat_session_id) { 'session-123' }
    let(:messages_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/sessions/#{chat_session_id}/messages(\?.*)?$} }

    let(:api_response) do
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

    context 'when API call is successful' do
      before do
        stub_request(:get, messages_url_pattern)
          .to_return(
            status: 200,
            body: api_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns messages array with total_count' do
        result = service.get_session_messages(chat_session_id: chat_session_id)

        expect(result['messages']).to be_an(Array)
        expect(result['messages'].length).to eq(2)
        expect(result['total_count']).to eq(2)
      end

      it 'transforms camelCase to snake_case' do
        result = service.get_session_messages(chat_session_id: chat_session_id)

        message = result['messages'].first
        expect(message['external_id']).to eq('msg-1')
        expect(message['message_role']).to eq('user')
        expect(message['content']).to eq('Hello')
        expect(message['sent_date']).to eq('2025-01-01T00:00:00Z')
        expect(message['has_media']).to be false
      end

      it 'passes limit to API when provided' do
        service.get_session_messages(chat_session_id: chat_session_id, limit: 10)

        expect(a_request(:get, messages_url_pattern)
          .with(query: hash_including(limit: '10'))).to have_been_made
      end

      it 'omits limit param when nil' do
        service.get_session_messages(chat_session_id: chat_session_id, limit: nil)

        expect(a_request(:get, messages_url_pattern)
          .with(query: { id_type: 'external' })).to have_been_made
      end
    end

    context 'when response has empty messages' do
      before do
        stub_request(:get, messages_url_pattern)
          .to_return(
            status: 200,
            body: { 'messages' => [], 'totalCount' => 0 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns empty messages array' do
        result = service.get_session_messages(chat_session_id: chat_session_id)

        expect(result['messages']).to eq([])
        expect(result['total_count']).to eq(0)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, messages_url_pattern)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ServiceError' do
        expect do
          service.get_session_messages(chat_session_id: chat_session_id)
        end.to raise_error(described_class::ServiceError)
      end
    end
  end

  # =============================================================================
  # #delete_session
  # =============================================================================
  describe '#delete_session' do
    let(:chat_session_id) { 'session-123' }
    let(:delete_url_pattern) { %r{#{ai_backend_url}/api/messaging/agent-systems/sessions/#{chat_session_id}(\?.*)?$} }

    context 'when deletion succeeds' do
      before do
        stub_request(:patch, delete_url_pattern)
          .to_return(
            status: 200,
            body: { success: true }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns true' do
        result = service.delete_session(chat_session_id: chat_session_id)

        expect(result).to be true
      end

      it 'sends PATCH with is_active: false' do
        service.delete_session(chat_session_id: chat_session_id)

        expect(a_request(:patch, delete_url_pattern)
          .with(
            query: { id_type: 'external' },
            body: { is_active: false }.to_json
          )).to have_been_made
      end
    end

    context 'when session not found (404)' do
      before do
        stub_request(:patch, delete_url_pattern)
          .to_return(status: 404, body: { error: 'Not found' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ServiceError' do
        expect do
          service.delete_session(chat_session_id: chat_session_id)
        end.to raise_error(described_class::ServiceError)
      end
    end

    context 'when API returns server error' do
      before do
        stub_request(:patch, delete_url_pattern)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ServiceError' do
        expect do
          service.delete_session(chat_session_id: chat_session_id)
        end.to raise_error(described_class::ServiceError)
      end
    end
  end
end
