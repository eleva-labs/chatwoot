# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::CreateStoreJob, type: :job do
  let(:account) { create(:account, id: 123, name: 'Test Store') }
  let(:user_email) { 'admin@example.com' }
  let(:service) { instance_double(AiBackendService::StoreService) }

  before do
    allow(AiBackendService::StoreService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when store creation succeeds' do
      it 'calls StoreService.create_store with correct params' do
        expect(service).to receive(:create_store).with(account, user_email).and_return(true)

        described_class.new.perform(account.id, user_email)
      end

      it 'logs success' do
        allow(service).to receive(:create_store).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(account.id, user_email)

        expect(Rails.logger).to have_received(:info).with(/Successfully created store for account_id: 123/)
      end
    end

    context 'when store creation fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:create_store)
          .and_raise(AiBackendService::StoreService::StoreError, 'API error')

        expect { described_class.new.perform(account.id, user_email) }
          .to raise_error(AiBackendService::StoreService::StoreError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:create_store)
          .and_raise(AiBackendService::StoreService::StoreError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(account.id, user_email)
        rescue AiBackendService::StoreService::StoreError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to create store for account_id: 123/)
      end
    end
  end
end
