# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::CreateAgentSystemJob, type: :job do
  let(:account) { create(:account, id: 123) }
  let(:agent_bot) { create(:agent_bot, id: 456, name: 'Test Bot', account: account) }
  let(:store_id) { 123 }
  let(:service) { instance_double(AiBackendService::AgentSystemService) }
  let(:ai_backend_url) { 'https://test-ai-backend.com' }

  before do
    allow(AiBackendService::AgentSystemService).to receive(:new).and_return(service)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('AI_BACKEND_URL').and_return(ai_backend_url)
  end

  describe '#perform' do
    context 'when agent system creation succeeds' do
      before do
        allow(service).to receive(:create_agent_system).and_return(true)
      end

      it 'calls AgentSystemService.create_agent_system with correct params' do
        expect(service).to receive(:create_agent_system).with(agent_bot, store_id).and_return(true)

        described_class.new.perform(agent_bot.id, store_id)
      end

      it 'updates agent_bot outgoing_url with correct webhook URL' do
        described_class.new.perform(agent_bot.id, store_id)

        agent_bot.reload
        uri = URI.parse(agent_bot.outgoing_url)
        params = Rack::Utils.parse_query(uri.query)

        expect(uri.path).to eq('/api/webhooks/chatwoot/message')
        expect(params['store_id']).to eq(store_id.to_s)
        expect(params['agent_system_id']).to eq(agent_bot.id.to_s)
        expect(params['id_type']).to eq('external')
      end

      it 'logs success with webhook URL update' do
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(agent_bot.id, store_id)

        expect(Rails.logger).to have_received(:info).with(/Successfully created agent system and set webhook URL for agent_bot_id: 456/)
      end
    end

    context 'when agent system creation fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:create_agent_system)
          .and_raise(AiBackendService::AgentSystemService::AgentSystemError, 'API error')

        expect { described_class.new.perform(agent_bot.id, store_id) }
          .to raise_error(AiBackendService::AgentSystemService::AgentSystemError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:create_agent_system)
          .and_raise(AiBackendService::AgentSystemService::AgentSystemError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(agent_bot.id, store_id)
        rescue AiBackendService::AgentSystemService::AgentSystemError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to create agent system for agent_bot_id: 456/)
      end

      it 'does not update outgoing_url when creation fails' do
        allow(service).to receive(:create_agent_system)
          .and_raise(AiBackendService::AgentSystemService::AgentSystemError, 'API error')

        initial_url = agent_bot.outgoing_url

        begin
          described_class.new.perform(agent_bot.id, store_id)
        rescue AiBackendService::AgentSystemService::AgentSystemError
          # Expected
        end

        agent_bot.reload
        expect(agent_bot.outgoing_url).to eq(initial_url)
      end
    end
  end
end
