# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::DeleteChannelJob, type: :job do
  let(:inbox_id) { 789 }
  let(:account_id) { 456 }
  let(:service) { instance_double(AiBackendService::ChannelService) }

  before do
    allow(AiBackendService::ChannelService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when channel deletion succeeds' do
      it 'calls ChannelService.delete_channel with inbox_id and account_id' do
        expect(service).to receive(:delete_channel).with(inbox_id, account_id).and_return(true)

        described_class.new.perform(inbox_id, account_id)
      end

      it 'logs success' do
        allow(service).to receive(:delete_channel).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(inbox_id, account_id)

        expect(Rails.logger).to have_received(:info).with(/Successfully deleted channel for inbox_id: 789/)
      end
    end

    context 'when channel deletion fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:delete_channel)
          .and_raise(AiBackendService::ChannelService::ChannelError, 'API error')

        expect { described_class.new.perform(inbox_id, account_id) }
          .to raise_error(AiBackendService::ChannelService::ChannelError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:delete_channel)
          .and_raise(AiBackendService::ChannelService::ChannelError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(inbox_id, account_id)
        rescue AiBackendService::ChannelService::ChannelError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to delete channel for inbox_id: 789/)
      end
    end
  end
end
