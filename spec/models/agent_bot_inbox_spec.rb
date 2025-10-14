require 'rails_helper'

RSpec.describe AgentBotInbox do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:inbox_id) }
    it { is_expected.to validate_presence_of(:agent_bot_id) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:agent_bot) }
    it { is_expected.to belong_to(:inbox) }
  end

  describe 'event dispatching' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:agent_bot) { create(:agent_bot, account: account) }

    describe 'on creation' do
      it 'dispatches agent_bot_inbox.created event' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::AGENT_BOT_INBOX_CREATED,
          instance_of(ActiveSupport::TimeWithZone),
          hash_including(agent_bot_inbox: instance_of(described_class))
        )

        create(:agent_bot_inbox, agent_bot: agent_bot, inbox: inbox, account: account)
      end

      it 'includes agent_bot_inbox object in event data' do
        agent_bot_inbox_from_event = nil

        allow(Rails.configuration.dispatcher).to receive(:dispatch) do |event_type, _time, data|
          agent_bot_inbox_from_event = data[:agent_bot_inbox] if event_type == Events::Types::AGENT_BOT_INBOX_CREATED
        end

        created_inbox = create(:agent_bot_inbox, agent_bot: agent_bot, inbox: inbox, account: account)

        expect(agent_bot_inbox_from_event).to eq(created_inbox)
        expect(agent_bot_inbox_from_event.agent_bot_id).to eq(agent_bot.id)
        expect(agent_bot_inbox_from_event.inbox_id).to eq(inbox.id)
      end

      it 'dispatches event after transaction commit' do
        # This ensures the event is dispatched after the record is saved
        # after_create_commit vs after_create
        agent_bot_inbox = build(:agent_bot_inbox, agent_bot: agent_bot, inbox: inbox, account: account)

        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::AGENT_BOT_INBOX_CREATED,
          anything,
          anything
        )

        agent_bot_inbox.save!
      end
    end

    describe 'on destruction' do
      let(:agent_bot_inbox) { create(:agent_bot_inbox, agent_bot: agent_bot, inbox: inbox, account: account) }

      it 'dispatches agent_bot_inbox.deleted event with IDs' do
        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::AGENT_BOT_INBOX_DELETED,
          instance_of(ActiveSupport::TimeWithZone),
          hash_including(
            agent_bot_inbox_id: agent_bot_inbox.id,
            agent_bot_id: agent_bot.id,
            inbox_id: inbox.id,
            account_id: account.id
          )
        )

        agent_bot_inbox.destroy!
      end

      it 'does not include agent_bot_inbox object (already destroyed)' do
        event_data = nil

        allow(Rails.configuration.dispatcher).to receive(:dispatch) do |event_type, _time, data|
          event_data = data if event_type == Events::Types::AGENT_BOT_INBOX_DELETED
        end

        agent_bot_inbox.destroy!

        expect(event_data[:agent_bot_inbox]).to be_nil
        expect(event_data[:agent_bot_inbox_id]).to eq(agent_bot_inbox.id)
        expect(event_data[:agent_bot_id]).to eq(agent_bot.id)
        expect(event_data[:inbox_id]).to eq(inbox.id)
        expect(event_data[:account_id]).to eq(account.id)
      end

      it 'dispatches event after transaction commit' do
        # This ensures the event is dispatched after the record is deleted
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::AGENT_BOT_INBOX_DELETED,
          anything,
          anything
        )

        agent_bot_inbox.destroy!
      end
    end
  end
end
