require 'rails_helper'
require Rails.root.join 'spec/models/concerns/access_tokenable_shared.rb'
require Rails.root.join 'spec/models/concerns/avatarable_shared.rb'

RSpec.describe AgentBot do
  describe 'associations' do
    it { is_expected.to have_many(:agent_bot_inboxes) }
    it { is_expected.to have_many(:inboxes) }
  end

  describe 'concerns' do
    it_behaves_like 'access_tokenable'
    it_behaves_like 'avatarable'
  end

  context 'when it validates outgoing_url length' do
    let(:agent_bot) { create(:agent_bot) }

    it 'valid when within limit' do
      agent_bot.outgoing_url = 'a' * Limits::URL_LENGTH_LIMIT
      expect(agent_bot.valid?).to be true
    end

    it 'invalid when crossed the limit' do
      agent_bot.outgoing_url = 'a' * (Limits::URL_LENGTH_LIMIT + 1)
      agent_bot.valid?
      expect(agent_bot.errors[:outgoing_url]).to include("is too long (maximum is #{Limits::URL_LENGTH_LIMIT} characters)")
    end
  end

  context 'when agent bot is deleted' do
    let(:agent_bot) { create(:agent_bot) }
    let(:message) { create(:message, sender: agent_bot) }

    it 'nullifies the message sender key' do
      expect(message.sender).to eq agent_bot
      agent_bot.destroy!

      expect(message.reload.sender).to be_nil
    end
  end

  describe '#system_bot?' do
    context 'when account_id is nil' do
      let(:agent_bot) { create(:agent_bot, account_id: nil) }

      it 'returns true' do
        expect(agent_bot.system_bot?).to be true
      end
    end

    context 'when account_id is present' do
      let(:account) { create(:account) }
      let(:agent_bot) { create(:agent_bot, account: account) }

      it 'returns false' do
        expect(agent_bot.system_bot?).to be false
      end
    end
  end

  describe 'event dispatch' do
    let(:account) { create(:account) }

    context 'when creating agent bot with account' do
      it 'dispatches AGENT_BOT_CREATED event followed by BOT_TOKEN_UPDATED event' do
        # Allow account.created event to be dispatched (from factory creating account)
        allow(Rails.configuration.dispatcher).to receive(:dispatch).with('account.created', anything, anything)

        # Verify events are dispatched in correct order using ordered expectations
        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          'agent_bot.created',
          anything,
          hash_including(agent_bot: instance_of(AgentBot))
        ).ordered

        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          'bot_token.updated',
          anything,
          hash_including(
            agent_bot: instance_of(AgentBot),
            account: instance_of(Account),
            token: instance_of(String)
          )
        ).ordered

        agent_bot = create(:agent_bot, account: account)

        # Verify access token was created
        expect(agent_bot.access_token).to be_present
      end
    end

    context 'when creating system bot (no account)' do
      it 'does not dispatch AGENT_BOT_CREATED event' do
        expect(Rails.configuration.dispatcher).not_to receive(:dispatch)

        create(:agent_bot, account: nil)
      end
    end

    context 'when deleting agent bot with account' do
      it 'dispatches AGENT_BOT_DELETED event after destroy' do
        agent_bot = create(:agent_bot, account: account)

        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          'agent_bot.deleted',
          anything,
          hash_including(agent_bot_id: agent_bot.id)
        )

        agent_bot.destroy
      end

      it 'includes agent_bot_id in event data' do
        agent_bot = create(:agent_bot, account: account)
        received_data = nil

        allow(Rails.configuration.dispatcher).to receive(:dispatch) do |_event, _time, data|
          received_data = data
        end

        agent_bot.destroy

        expect(received_data[:agent_bot_id]).to eq(agent_bot.id)
      end
    end

    context 'when deleting system bot (no account)' do
      it 'does not dispatch AGENT_BOT_DELETED event' do
        agent_bot = create(:agent_bot, account: nil)

        expect(Rails.configuration.dispatcher).not_to receive(:dispatch)

        agent_bot.destroy
      end
    end
  end

  context 'when generating webhook URL' do
    let(:account) { create(:account, id: 123) }
    let(:agent_bot) { create(:agent_bot, id: 456, account: account) }
    let(:ai_backend_url) { 'https://test-ai-backend.com' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('AI_BACKEND_URL').and_return(ai_backend_url)
    end

    describe '#generate_webhook_url' do
      it 'generates correct webhook URL with required parameters' do
        url = agent_bot.generate_webhook_url
        uri = URI.parse(url)
        params = Rack::Utils.parse_query(uri.query)

        expect(uri.scheme).to match(/https?/) # Allow both http and https
        expect(uri.path).to eq('/api/webhooks/chatwoot/message')
        expect(params['store_id']).to eq('123')
        expect(params['agent_system_id']).to eq('456')
        expect(params['id_type']).to eq('external')
      end

      it 'returns nil for system bots (no account)' do
        system_bot = create(:agent_bot, account: nil)
        expect(system_bot.generate_webhook_url).to be_nil
      end

      it 'uses account_id as store_id parameter' do
        url = agent_bot.generate_webhook_url
        params = Rack::Utils.parse_query(URI.parse(url).query)
        expect(params['store_id']).to eq(agent_bot.account_id.to_s)
      end

      it 'uses agent_bot.id as agent_system_id parameter' do
        url = agent_bot.generate_webhook_url
        params = Rack::Utils.parse_query(URI.parse(url).query)
        expect(params['agent_system_id']).to eq(agent_bot.id.to_s)
      end

      it 'uses external id_type' do
        url = agent_bot.generate_webhook_url
        params = Rack::Utils.parse_query(URI.parse(url).query)
        expect(params['id_type']).to eq('external')
      end
    end
  end
end
