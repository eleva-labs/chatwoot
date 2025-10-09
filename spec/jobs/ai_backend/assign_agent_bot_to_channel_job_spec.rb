# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::AssignAgentBotToChannelJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:job) { described_class.new }

  describe '#perform' do
    let(:service) { instance_double(AiBackendService::ChannelService) }

    before do
      allow(AiBackendService::ChannelService).to receive(:new).and_return(service)
      allow(service).to receive(:assign_agent_system).and_return(true)
    end

    it 'calls assign_agent_system on ChannelService' do
      expect(service).to receive(:assign_agent_system).with(
        inbox.id,
        agent_bot.id
      )

      job.perform(agent_bot.id, inbox.id)
    end

    it 'logs success' do
      expect(Rails.logger).to receive(:info).with(
        "AI Backend: Successfully assigned agent bot #{agent_bot.id} to channel #{inbox.id}"
      )

      job.perform(agent_bot.id, inbox.id)
    end

    context 'when service raises ChannelError' do
      before do
        allow(service).to receive(:assign_agent_system).and_raise(
          AiBackendService::ChannelService::ChannelError.new('AI Backend timeout')
        )
      end

      it 'logs error and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          /Failed to assign agent bot.*timeout/
        )

        expect do
          job.perform(agent_bot.id, inbox.id)
        end.to raise_error(AiBackendService::ChannelService::ChannelError)
      end
    end

    context 'when service raises generic error' do
      before do
        allow(service).to receive(:assign_agent_system).and_raise(StandardError.new('Unexpected'))
      end

      it 'logs error and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          /Unexpected error.*Unexpected/
        )

        expect do
          job.perform(agent_bot.id, inbox.id)
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
