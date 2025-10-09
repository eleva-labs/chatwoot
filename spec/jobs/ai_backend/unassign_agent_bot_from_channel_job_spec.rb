# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::UnassignAgentBotFromChannelJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:job) { described_class.new }

  describe '#perform' do
    let(:service) { instance_double(AiBackendService::ChannelService) }

    before do
      allow(AiBackendService::ChannelService).to receive(:new).and_return(service)
      allow(service).to receive(:unassign_agent_system).and_return(true)
    end

    it 'calls unassign_agent_system on ChannelService' do
      expect(service).to receive(:unassign_agent_system).with(inbox.id, account.id)

      job.perform(inbox.id, account.id)
    end

    it 'logs success' do
      expect(Rails.logger).to receive(:info).with(
        "AI Backend: Successfully unassigned agent bot from channel #{inbox.id}"
      )

      job.perform(inbox.id, account.id)
    end

    context 'when service raises ChannelError' do
      before do
        allow(service).to receive(:unassign_agent_system).and_raise(
          AiBackendService::ChannelService::ChannelError.new('404 Not Found')
        )
      end

      it 'logs error and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          /Failed to unassign agent bot.*404/
        )

        expect do
          job.perform(inbox.id, account.id)
        end.to raise_error(AiBackendService::ChannelService::ChannelError)
      end
    end

    context 'when service raises generic error' do
      before do
        allow(service).to receive(:unassign_agent_system).and_raise(StandardError.new('Unexpected'))
      end

      it 'logs error and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          /Unexpected error.*Unexpected/
        )

        expect do
          job.perform(inbox.id, account.id)
        end.to raise_error(StandardError)
      end
    end
  end

  describe 'configuration' do
    it 'is configured with correct queue' do
      expect(described_class.queue_name).to eq('default')
    end
  end
end
