# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::DeleteAgentSystemJob, type: :job do
  let(:agent_bot_id) { 456 }
  let(:account_id) { 789 }
  let(:service) { instance_double(AiBackendService::AgentSystemService) }

  before do
    allow(AiBackendService::AgentSystemService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when agent system deletion succeeds' do
      it 'calls AgentSystemService.delete_agent_system with bot ID' do
        expect(service).to receive(:delete_agent_system).with(agent_bot_id, account_id).and_return(true)

        described_class.new.perform(agent_bot_id, account_id)
      end

      it 'logs success' do
        allow(service).to receive(:delete_agent_system).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(agent_bot_id, account_id)

        expect(Rails.logger).to have_received(:info).with(/Successfully deleted agent system for agent_bot_id: 456/)
      end
    end

    context 'when agent system deletion fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:delete_agent_system)
          .and_raise(AiBackendService::AgentSystemService::AgentSystemError, 'API error')

        expect { described_class.new.perform(agent_bot_id, account_id) }
          .to raise_error(AiBackendService::AgentSystemService::AgentSystemError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:delete_agent_system)
          .and_raise(AiBackendService::AgentSystemService::AgentSystemError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(agent_bot_id, account_id)
        rescue AiBackendService::AgentSystemService::AgentSystemError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to delete agent system for agent_bot_id: 456/)
      end
    end
  end
end
