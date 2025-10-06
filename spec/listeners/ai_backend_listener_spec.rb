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

    it 'creates store in AI backend' do
      store_service = instance_double(AiBackendService::StoreService)
      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(store_service).to receive(:create_store)

      listener.account_created(event)

      expect(store_service).to have_received(:create_store).with(account, 'admin@example.com')
    end

    it 'uses account support_email when no users' do
      allow(account).to receive(:users).and_return([])
      allow(account).to receive(:support_email).and_return('support@example.com')

      store_service = instance_double(AiBackendService::StoreService)
      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(store_service).to receive(:create_store)

      listener.account_created(event)

      expect(store_service).to have_received(:create_store).with(account, 'support@example.com')
    end

    it 'logs success message' do
      store_service = instance_double(AiBackendService::StoreService)
      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(store_service).to receive(:create_store)
      allow(Rails.logger).to receive(:info)

      listener.account_created(event)

      expect(Rails.logger).to have_received(:info).with(/AI Backend: Store created for account 123/)
    end

    it 'logs error on failure' do
      allow(AiBackendService::StoreService).to receive(:new).and_raise(
        AiBackendService::StoreService::StoreError.new('API error')
      )
      allow(Rails.logger).to receive(:error)

      listener.account_created(event)

      expect(Rails.logger).to have_received(:error).with(/Store creation failed for account 123/)
    end

    it 'does not raise error on failure' do
      allow(AiBackendService::StoreService).to receive(:new).and_raise(
        AiBackendService::StoreService::StoreError.new('API error')
      )

      expect { listener.account_created(event) }.not_to raise_error
    end
  end

  describe '#agent_bot_created' do
    let(:account) { create(:account, id: 123) }
    let(:agent_bot) { create(:agent_bot, id: 456, account: account) }
    let(:event) { double(data: { agent_bot: agent_bot }) }
    let(:store_response) { double(id: 'store-uuid-123') }

    it 'creates agent system in AI backend' do
      store_service = instance_double(AiBackendService::StoreService)
      agent_system_service = instance_double(AiBackendService::AgentSystemService)

      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(AiBackendService::AgentSystemService).to receive(:new).and_return(agent_system_service)
      allow(store_service).to receive(:get_store).with(123).and_return(store_response)
      allow(agent_system_service).to receive(:create_agent_system)

      listener.agent_bot_created(event)

      expect(agent_system_service).to have_received(:create_agent_system).with(agent_bot, 'store-uuid-123')
    end

    it 'skips system bots' do
      agent_bot.update(account: nil)

      expect(AiBackendService::StoreService).not_to receive(:new)

      listener.agent_bot_created(event)
    end

    it 'logs success message' do
      store_service = instance_double(AiBackendService::StoreService)
      agent_system_service = instance_double(AiBackendService::AgentSystemService)

      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(AiBackendService::AgentSystemService).to receive(:new).and_return(agent_system_service)
      allow(store_service).to receive(:get_store).and_return(store_response)
      allow(agent_system_service).to receive(:create_agent_system)
      allow(Rails.logger).to receive(:info)

      listener.agent_bot_created(event)

      expect(Rails.logger).to have_received(:info).with(/Agent system created for bot 456/)
    end

    it 'logs error on failure' do
      allow(AiBackendService::StoreService).to receive(:new).and_raise(
        AiBackendService::StoreService::StoreError.new('Store not found')
      )
      allow(Rails.logger).to receive(:error)

      listener.agent_bot_created(event)

      expect(Rails.logger).to have_received(:error).with(/Agent system creation failed for bot 456/)
    end
  end

  describe '#agent_added' do
    let(:account) { create(:account, id: 123) }
    let(:user) { create(:user, id: 789, email: 'user@example.com') }
    let(:account_user) { create(:account_user, account: account, user: user) }
    let(:event) { double(data: { account: account, account_user: account_user }) }
    let(:store_response) { double(id: 'store-uuid-123') }

    it 'creates user in AI backend' do
      store_service = instance_double(AiBackendService::StoreService)
      user_service = instance_double(AiBackendService::UserService)

      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(AiBackendService::UserService).to receive(:new).and_return(user_service)
      allow(store_service).to receive(:get_store).with(123).and_return(store_response)
      allow(user_service).to receive(:create_user)

      listener.agent_added(event)

      expect(user_service).to have_received(:create_user).with(user, 'store-uuid-123')
    end

    it 'returns early when user is nil' do
      event = double(data: { account: account, account_user: nil })

      expect(AiBackendService::StoreService).not_to receive(:new)

      listener.agent_added(event)
    end

    it 'logs success message' do
      store_service = instance_double(AiBackendService::StoreService)
      user_service = instance_double(AiBackendService::UserService)

      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(AiBackendService::UserService).to receive(:new).and_return(user_service)
      allow(store_service).to receive(:get_store).and_return(store_response)
      allow(user_service).to receive(:create_user)
      allow(Rails.logger).to receive(:info)

      listener.agent_added(event)

      expect(Rails.logger).to have_received(:info).with(/User created for user 789 in account 123/)
    end

    it 'logs error on failure' do
      allow(AiBackendService::StoreService).to receive(:new).and_raise(
        AiBackendService::StoreService::StoreError.new('Store not found')
      )
      allow(Rails.logger).to receive(:error)

      listener.agent_added(event)

      expect(Rails.logger).to have_received(:error).with(/User creation failed/)
    end
  end
end
