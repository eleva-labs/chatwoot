# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::CreateStoreJob, type: :job do
  let(:account) { create(:account, id: 123, name: 'Test Store') }
  let(:user_email) { 'admin@example.com' }
  let(:service) { instance_double(AiBackendService::StoreService) }
  let(:store_response) do
    AiBackendService::Schemas::StoreResponse.new(
      id: 'store-uuid-123',
      external_id: account.id.to_s,
      name: account.name,
      email: user_email,
      is_active: true,
      custom_attributes: {}
    )
  end

  before do
    allow(AiBackendService::StoreService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when store creation succeeds' do
      it 'calls StoreService.create_store with correct params and persists mapping' do
        expect(service).to receive(:create_store).with(account, user_email).and_return(store_response)

        described_class.new.perform(account.id, user_email)

        expect(account.reload.ai_backend_store_id).to eq('store-uuid-123')
      end

      it 'logs success' do
        allow(service).to receive(:create_store).and_return(store_response)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(account.id, user_email)

        expect(Rails.logger).to have_received(:info).with(/Successfully created store for account_id: 123/)
      end
    end

    context 'when store creation fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:create_store)
          .and_raise(AiBackendService::StoreService::StoreError, 'API error')
        allow(service).to receive(:get_store)
          .with(account.id)
          .and_raise(AiBackendService::StoreService::StoreError, 'Not found')

        expect { described_class.new.perform(account.id, user_email) }
          .to raise_error(AiBackendService::StoreService::StoreError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:create_store)
          .and_raise(AiBackendService::StoreService::StoreError, 'API error')
        allow(service).to receive(:get_store)
          .with(account.id)
          .and_raise(AiBackendService::StoreService::StoreError, 'Not found')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(account.id, user_email)
        rescue AiBackendService::StoreService::StoreError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to create store for account_id: 123/)
      end

      it 'recovers and persists an existing store mapping by external id' do
        allow(service).to receive(:create_store)
          .and_raise(AiBackendService::StoreService::StoreError, 'Duplicate store')
        expect(service).to receive(:get_store).with(account.id).and_return(store_response)

        described_class.new.perform(account.id, user_email)

        expect(account.reload.ai_backend_store_id).to eq('store-uuid-123')
      end
    end
  end
end
