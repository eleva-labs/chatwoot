# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::SyncBotTokenJob, type: :job do
  let(:account) { create(:account, id: 123) }
  let(:agent_bot) { create(:agent_bot, id: 456, account: account) }
  let(:token) { 'test_bot_token_xyz789' }
  let(:config_service) { instance_double(AiBackendService::ConfigurationService) }

  before do
    allow(AiBackendService::ConfigurationService).to receive(:new).and_return(config_service)
  end

  describe '#perform' do
    context 'when token sync succeeds' do
      it 'calls ConfigurationService with correct params' do
        expect(config_service).to receive(:save_configuration).with(
          scope: AiBackendService::Constants::Scope::AGENT_SYSTEM,
          resource_id: 456,
          config_key: AiBackendService::Constants::ConfigKey::AGENT_SYSTEM_CONFIG,
          config_data: { chatwoot_access_token: token }
        )

        described_class.new.perform(agent_bot.id, account.id, token)
      end

      it 'logs success' do
        allow(config_service).to receive(:save_configuration)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(agent_bot.id, account.id, token)

        expect(Rails.logger).to have_received(:info).with(/Successfully synced bot token for agent_bot_id: 456/)
      end
    end

    context 'when agent_bot is not found' do
      it 'does not raise error' do
        allow(AgentBot).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound)

        expect { described_class.new.perform(999, account.id, token) }.not_to raise_error
      end

      it 'logs error' do
        allow(AgentBot).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound, 'AgentBot not found')
        allow(Rails.logger).to receive(:error)

        described_class.new.perform(999, account.id, token)

        expect(Rails.logger).to have_received(:error).with(/Record not found when syncing bot token/)
      end

      it 'does not call ConfigurationService' do
        allow(AgentBot).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound)

        expect(config_service).not_to receive(:save_configuration)

        described_class.new.perform(999, account.id, token)
      end
    end

    context 'when account is not found' do
      it 'does not raise error' do
        allow(Account).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound)

        expect { described_class.new.perform(agent_bot.id, 999, token) }.not_to raise_error
      end

      it 'logs error' do
        allow(Account).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound, 'Account not found')
        allow(Rails.logger).to receive(:error)

        described_class.new.perform(agent_bot.id, 999, token)

        expect(Rails.logger).to have_received(:error).with(/Record not found when syncing bot token/)
      end
    end

    context 'when configuration service fails' do
      it 'raises error for Sidekiq retry' do
        allow(config_service).to receive(:save_configuration)
          .and_raise(StandardError, 'API error')

        expect { described_class.new.perform(agent_bot.id, account.id, token) }
          .to raise_error(StandardError, 'API error')
      end

      it 'logs error before raising' do
        allow(config_service).to receive(:save_configuration)
          .and_raise(StandardError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(agent_bot.id, account.id, token)
        rescue StandardError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to sync bot token for agent_bot_id: 456/)
      end
    end

    context 'when network error occurs' do
      it 'raises error for retry' do
        allow(config_service).to receive(:save_configuration)
          .and_raise(Net::ReadTimeout, 'Request timeout')

        expect { described_class.new.perform(agent_bot.id, account.id, token) }
          .to raise_error(Net::ReadTimeout)
      end
    end
  end

  describe 'job configuration' do
    it 'uses default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    # NOTE: retry_on StandardError configuration is set in the job class (line 6)
  end
end
