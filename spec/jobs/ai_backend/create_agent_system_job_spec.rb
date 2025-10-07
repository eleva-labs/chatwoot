# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::CreateAgentSystemJob, type: :job do
  let(:account) { create(:account, id: 123) }
  let(:agent_bot) { create(:agent_bot, id: 456, name: 'Test Bot', account: account) }
  let(:store_id) { 123 }
  let(:service) { instance_double(AiBackendService::AgentSystemService) }

  before do
    allow(AiBackendService::AgentSystemService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when agent system creation succeeds' do
      it 'calls AgentSystemService.create_agent_system with correct params' do
        expect(service).to receive(:create_agent_system).with(agent_bot, store_id).and_return(true)

        described_class.new.perform(agent_bot.id, store_id)
      end

      it 'logs success' do
        allow(service).to receive(:create_agent_system).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(agent_bot.id, store_id)

        expect(Rails.logger).to have_received(:info).with(/Successfully created agent system for agent_bot_id: 456/)
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
    end
  end
end
