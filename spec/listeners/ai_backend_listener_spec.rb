# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendListener do
  let(:listener) { described_class.instance }

  describe '#account_created' do
    let(:account) { create(:account, id: 123) }
    let(:user) { create(:user, email: 'admin@example.com') }
    let(:event) { double(data: { account: account }) }

    before do
      allow(account).to receive(:users).and_return([user])
    end

    it 'enqueues CreateStoreJob with account ID and email' do
      expect(AiBackend::CreateStoreJob).to receive(:perform_later).with(123, 'admin@example.com')

      listener.account_created(event)
    end

    it 'uses account support_email when no users' do
      allow(account).to receive(:users).and_return([])
      allow(account).to receive(:support_email).and_return('support@example.com')

      expect(AiBackend::CreateStoreJob).to receive(:perform_later).with(123, 'support@example.com')

      listener.account_created(event)
    end

    it 'logs job enqueue' do
      allow(AiBackend::CreateStoreJob).to receive(:perform_later)
      allow(Rails.logger).to receive(:info)

      listener.account_created(event)

      expect(Rails.logger).to have_received(:info).with(/Enqueued store creation for account 123/)
    end

    it 'logs error on failure' do
      allow(AiBackend::CreateStoreJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')
      allow(Rails.logger).to receive(:error)

      listener.account_created(event)

      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue store creation for account 123/)
    end

    it 'does not raise error on failure' do
      allow(AiBackend::CreateStoreJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')

      expect { listener.account_created(event) }.not_to raise_error
    end
  end

  describe '#agent_bot_created' do
    let(:account) { create(:account, id: 123) }
    let(:agent_bot) { create(:agent_bot, id: 456, account: account) }
    let(:event) { double(data: { agent_bot: agent_bot }) }

    it 'enqueues CreateAgentSystemJob with bot ID and store ID' do
      expect(AiBackend::CreateAgentSystemJob).to receive(:perform_later).with(456, 123)

      listener.agent_bot_created(event)
    end

    it 'skips system bots' do
      agent_bot.update(account: nil)

      expect(AiBackend::CreateAgentSystemJob).not_to receive(:perform_later)

      listener.agent_bot_created(event)
    end

    it 'logs job enqueue' do
      allow(AiBackend::CreateAgentSystemJob).to receive(:perform_later)
      allow(Rails.logger).to receive(:info)

      listener.agent_bot_created(event)

      expect(Rails.logger).to have_received(:info).with(/Enqueued agent system creation for bot 456/)
    end

    it 'logs error on failure' do
      allow(AiBackend::CreateAgentSystemJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')
      allow(Rails.logger).to receive(:error)

      listener.agent_bot_created(event)

      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue agent system creation for bot 456/)
    end
  end

  describe '#agent_added' do
    let(:account) { create(:account, id: 123) }
    let(:user) { create(:user, id: 789, email: 'user@example.com') }
    let(:account_user) { create(:account_user, account: account, user: user) }
    let(:event) { double(data: { account: account, account_user: account_user }) }

    it 'enqueues CreateUserJob with user ID and store ID' do
      expect(AiBackend::CreateUserJob).to receive(:perform_later).with(789, 123)

      listener.agent_added(event)
    end

    it 'returns early when user is nil' do
      event = double(data: { account: account, account_user: nil })

      expect(AiBackend::CreateUserJob).not_to receive(:perform_later)

      listener.agent_added(event)
    end

    it 'logs job enqueue' do
      allow(AiBackend::CreateUserJob).to receive(:perform_later)
      allow(Rails.logger).to receive(:info)

      listener.agent_added(event)

      expect(Rails.logger).to have_received(:info).with(/Enqueued user creation for user 789 in account 123/)
    end

    it 'logs error on failure' do
      allow(AiBackend::CreateUserJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')
      allow(Rails.logger).to receive(:error)

      listener.agent_added(event)

      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue user creation/)
    end
  end

  describe '#account_deleted' do
    let(:event) { double(data: { account_id: 123 }) }

    it 'enqueues DeleteStoreJob with account ID' do
      expect(AiBackend::DeleteStoreJob).to receive(:perform_later).with(123)

      listener.account_deleted(event)
    end

    it 'logs job enqueue' do
      allow(AiBackend::DeleteStoreJob).to receive(:perform_later)
      allow(Rails.logger).to receive(:info)

      listener.account_deleted(event)

      expect(Rails.logger).to have_received(:info).with(/Enqueued store deletion for account 123/)
    end

    it 'logs error on failure' do
      allow(AiBackend::DeleteStoreJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')
      allow(Rails.logger).to receive(:error)

      listener.account_deleted(event)

      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue store deletion for account 123/)
    end

    it 'does not raise error on failure' do
      allow(AiBackend::DeleteStoreJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')

      expect { listener.account_deleted(event) }.not_to raise_error
    end
  end

  describe '#agent_bot_deleted' do
    let(:event) { double(data: { agent_bot_id: 456 }) }

    it 'enqueues DeleteAgentSystemJob with bot ID' do
      expect(AiBackend::DeleteAgentSystemJob).to receive(:perform_later).with(456)

      listener.agent_bot_deleted(event)
    end

    it 'logs job enqueue' do
      allow(AiBackend::DeleteAgentSystemJob).to receive(:perform_later)
      allow(Rails.logger).to receive(:info)

      listener.agent_bot_deleted(event)

      expect(Rails.logger).to have_received(:info).with(/Enqueued agent system deletion for bot 456/)
    end

    it 'logs error on failure' do
      allow(AiBackend::DeleteAgentSystemJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')
      allow(Rails.logger).to receive(:error)

      listener.agent_bot_deleted(event)

      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue agent system deletion for bot 456/)
    end
  end

  describe '#agent_removed' do
    let(:event) { double(data: { user_id: 789, account_id: 123 }) }

    it 'enqueues DeleteUserJob with user ID' do
      expect(AiBackend::DeleteUserJob).to receive(:perform_later).with(789)

      listener.agent_removed(event)
    end

    it 'returns early when user_id is nil' do
      event = double(data: { user_id: nil, account_id: 123 })

      expect(AiBackend::DeleteUserJob).not_to receive(:perform_later)

      listener.agent_removed(event)
    end

    it 'logs job enqueue' do
      allow(AiBackend::DeleteUserJob).to receive(:perform_later)
      allow(Rails.logger).to receive(:info)

      listener.agent_removed(event)

      expect(Rails.logger).to have_received(:info).with(/Enqueued user deletion for user 789/)
    end

    it 'logs error on failure' do
      allow(AiBackend::DeleteUserJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')
      allow(Rails.logger).to receive(:error)

      listener.agent_removed(event)

      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue user deletion/)
    end
  end
end
