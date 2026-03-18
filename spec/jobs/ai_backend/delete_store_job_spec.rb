# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::DeleteStoreJob, type: :job do
  let(:account_id) { 123 }
  let(:service) { instance_double(AiBackendService::StoreService) }

  before do
    allow(AiBackendService::StoreService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when store deletion succeeds' do
      it 'calls StoreService.delete_store with account ID' do
        expect(service).to receive(:delete_store).with(account_id).and_return(true)

        described_class.new.perform(account_id)
      end

      it 'logs success' do
        allow(service).to receive(:delete_store).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(account_id)

        expect(Rails.logger).to have_received(:info).with(/Successfully deleted store for account_id: 123/)
      end
    end

    context 'when store deletion fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:delete_store)
          .and_raise(AiBackendService::StoreService::StoreError, 'API error')

        expect { described_class.new.perform(account_id) }
          .to raise_error(AiBackendService::StoreService::StoreError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:delete_store)
          .and_raise(AiBackendService::StoreService::StoreError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(account_id)
        rescue AiBackendService::StoreService::StoreError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to delete store for account_id: 123/)
      end
    end
  end
end
