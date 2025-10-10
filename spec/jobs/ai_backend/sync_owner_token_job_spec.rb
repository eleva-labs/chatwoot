# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::SyncOwnerTokenJob, type: :job do
  let(:account) { create(:account, id: 123) }
  let(:user) { create(:user, id: 456) }
  let(:token) { 'test_token_abc123' }
  let(:config_service) { instance_double(AiBackendService::ConfigurationService) }

  before do
    allow(AiBackendService::ConfigurationService).to receive(:new).and_return(config_service)
  end

  describe '#perform' do
    context 'when token sync succeeds' do
      it 'calls ConfigurationService with correct params' do
        expect(config_service).to receive(:save_configuration).with(
          scope: AiBackendService::Constants::Scope::STORE,
          resource_id: 123,
          config_key: AiBackendService::Constants::ConfigKey::GENERAL_STORE_CONFIG,
          config_data: { chatwoot_app_api_token: token },
          partial: true
        )

        described_class.new.perform(account.id, user.id, token)
      end

      it 'logs success' do
        allow(config_service).to receive(:save_configuration)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(account.id, user.id, token)

        expect(Rails.logger).to have_received(:info).with(/Successfully synced owner token for account_id: 123/)
      end
    end

    context 'when account is not found' do
      it 'does not raise error' do
        allow(Account).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound)

        expect { described_class.new.perform(999, user.id, token) }.not_to raise_error
      end

      it 'logs error' do
        allow(Account).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound, 'Account not found')
        allow(Rails.logger).to receive(:error)

        described_class.new.perform(999, user.id, token)

        expect(Rails.logger).to have_received(:error).with(/Record not found when syncing owner token/)
      end

      it 'does not call ConfigurationService' do
        allow(Account).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound)

        expect(config_service).not_to receive(:save_configuration)

        described_class.new.perform(999, user.id, token)
      end
    end

    context 'when user is not found' do
      it 'does not raise error' do
        allow(User).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound)

        expect { described_class.new.perform(account.id, 999, token) }.not_to raise_error
      end

      it 'logs error' do
        allow(User).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound, 'User not found')
        allow(Rails.logger).to receive(:error)

        described_class.new.perform(account.id, 999, token)

        expect(Rails.logger).to have_received(:error).with(/Record not found when syncing owner token/)
      end
    end

    context 'when configuration service fails' do
      it 'raises error for Sidekiq retry' do
        allow(config_service).to receive(:save_configuration)
          .and_raise(StandardError, 'API error')

        expect { described_class.new.perform(account.id, user.id, token) }
          .to raise_error(StandardError, 'API error')
      end

      it 'logs error before raising' do
        allow(config_service).to receive(:save_configuration)
          .and_raise(StandardError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(account.id, user.id, token)
        rescue StandardError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to sync owner token for account_id: 123/)
      end
    end

    context 'when network error occurs' do
      it 'raises error for retry' do
        allow(config_service).to receive(:save_configuration)
          .and_raise(Net::ReadTimeout, 'Request timeout')

        expect { described_class.new.perform(account.id, user.id, token) }
          .to raise_error(Net::ReadTimeout)
      end
    end
  end

  describe 'job configuration' do
    it 'uses default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    # NOTE: retry_on StandardError configuration is set in the job class
  end
end
