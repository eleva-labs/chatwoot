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
      it 'dispatches AGENT_BOT_CREATED event' do
        # Allow account.created event to be dispatched (from factory creating account)
        allow(Rails.configuration.dispatcher).to receive(:dispatch).with('account.created', anything, anything)

        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          'agent_bot.created',
          anything,
          hash_including(agent_bot: instance_of(AgentBot))
        )

        create(:agent_bot, account: account)
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
          hash_including(agent_bot: agent_bot)
        )

        agent_bot.destroy
      end

      it 'includes agent_bot in event data' do
        agent_bot = create(:agent_bot, account: account)
        received_data = nil

        allow(Rails.configuration.dispatcher).to receive(:dispatch) do |_event, _time, data|
          received_data = data
        end

        agent_bot.destroy

        expect(received_data[:agent_bot]).to eq(agent_bot)
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
end
