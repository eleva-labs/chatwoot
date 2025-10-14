# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::CreateChannelJob, type: :job do
  let(:account) { create(:account, id: 456) }
  let(:inbox) { create(:inbox, id: 789, account: account, name: 'Test Channel') }
  let(:service) { instance_double(AiBackendService::ChannelService) }

  before do
    allow(AiBackendService::ChannelService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when channel creation succeeds' do
      it 'calls ChannelService.create_channel with correct params' do
        expect(service).to receive(:create_channel).with(inbox, account.id).and_return(true)

        described_class.new.perform(inbox.id, account.id)
      end

      it 'logs success' do
        allow(service).to receive(:create_channel).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(inbox.id, account.id)

        expect(Rails.logger).to have_received(:info).with(/Successfully created channel for inbox_id: 789/)
      end
    end

    context 'when channel creation fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:create_channel)
          .and_raise(AiBackendService::ChannelService::ChannelError, 'API error')

        expect { described_class.new.perform(inbox.id, account.id) }
          .to raise_error(AiBackendService::ChannelService::ChannelError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:create_channel)
          .and_raise(AiBackendService::ChannelService::ChannelError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(inbox.id, account.id)
        rescue AiBackendService::ChannelService::ChannelError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to create channel for inbox_id: 789/)
      end
    end

    context 'when inbox is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect { described_class.new.perform(99_999, account.id) }
          .to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
