# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccessToken do
  let(:dispatcher) { double('dispatcher') }

  before do
    allow(Rails.configuration).to receive(:dispatcher).and_return(dispatcher)
    # Stub all dispatcher calls by default, specific expectations will override
    allow(dispatcher).to receive(:dispatch)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:owner) }
  end

  describe 'callbacks' do
    describe '#notify_token_change after_create' do
      context 'when owner is a User' do
        let(:account) { create(:account) }
        let(:user) { create(:user) }

        before do
          # Make user the account owner (first admin with no inviter)
          create(:account_user, account: account, user: user, role: :administrator, inviter_id: nil)
        end

        it 'dispatches OWNER_TOKEN_UPDATED event on creation' do
          expect(dispatcher).to receive(:dispatch).with(
            'owner_token.updated',
            kind_of(Time),
            hash_including(
              account: account,
              user: user,
              token: kind_of(String)
            )
          )

          user.reload.create_access_token
        end
      end

      context 'when owner is an AgentBot' do
        let(:account) { create(:account) }
        let(:agent_bot) { create(:agent_bot, account: account) }

        it 'dispatches BOT_TOKEN_UPDATED event on creation' do
          expect(dispatcher).to receive(:dispatch).with(
            'bot_token.updated',
            kind_of(Time),
            hash_including(
              agent_bot: agent_bot,
              account: account,
              token: kind_of(String)
            )
          )

          agent_bot.reload.create_access_token
        end
      end
    end

    describe '#notify_token_change after_update' do
      context 'when owner is a User' do
        let(:account) { create(:account) }
        let(:user) { create(:user) }
        let!(:access_token) { user.access_token }

        before do
          create(:account_user, account: account, user: user, role: :administrator, inviter_id: nil)
          user.reload
        end

        it 'dispatches OWNER_TOKEN_UPDATED event when token changes' do
          expect(dispatcher).to receive(:dispatch).with(
            'owner_token.updated',
            kind_of(Time),
            hash_including(
              account: account,
              user: user,
              token: kind_of(String)
            )
          )

          access_token.regenerate_token
        end

        it 'does not dispatch event when other attributes change' do
          expect(dispatcher).not_to receive(:dispatch)

          access_token.update(updated_at: Time.zone.now)
        end
      end

      context 'when owner is an AgentBot' do
        let(:account) { create(:account) }
        let(:agent_bot) { create(:agent_bot, account: account) }
        let!(:access_token) { agent_bot.access_token }

        it 'dispatches BOT_TOKEN_UPDATED event when token changes' do
          expect(dispatcher).to receive(:dispatch).with(
            'bot_token.updated',
            kind_of(Time),
            hash_including(
              agent_bot: agent_bot,
              account: account,
              token: kind_of(String)
            )
          )

          access_token.regenerate_token
        end
      end
    end
  end

  describe '#notify_owner_token_change' do
    context 'when user owns multiple accounts' do
      let(:account1) { create(:account) }
      let(:account2) { create(:account) }
      let(:user) { create(:user) }
      let!(:access_token) { user.access_token }

      before do
        # User is owner of account1
        create(:account_user, account: account1, user: user, role: :administrator, inviter_id: nil)
        # User is owner of account2
        create(:account_user, account: account2, user: user, role: :administrator, inviter_id: nil)
        user.reload
      end

      it 'dispatches event for each owned account' do
        expect(dispatcher).to receive(:dispatch).twice

        access_token.regenerate_token
      end

      it 'includes correct account in each event' do
        events = []

        allow(dispatcher).to receive(:dispatch) do |_event_name, _time, data|
          events << data[:account]
        end

        access_token.regenerate_token

        expect(events).to contain_exactly(account1, account2)
      end
    end

    context 'when user is invited admin (not owner)' do
      let(:account) { create(:account) }
      let(:owner) { create(:user) }
      let(:invited_user) { create(:user) }
      let!(:access_token) { invited_user.access_token }

      before do
        # Owner creates the account
        create(:account_user, account: account, user: owner, role: :administrator, inviter_id: nil)
        # Invited user is admin but not owner
        create(:account_user, account: account, user: invited_user, role: :administrator, inviter_id: owner.id)
      end

      it 'does not dispatch event' do
        expect(dispatcher).not_to receive(:dispatch)

        access_token.regenerate_token
      end
    end

    context 'when user is agent (not admin)' do
      let(:account) { create(:account) }
      let(:user) { create(:user) }
      let!(:access_token) { user.access_token }

      before do
        create(:account_user, account: account, user: user, role: :agent)
      end

      it 'does not dispatch event' do
        expect(dispatcher).not_to receive(:dispatch)

        access_token.regenerate_token
      end
    end

    context 'when user has no accounts' do
      let(:user) { create(:user) }
      let!(:access_token) { user.access_token }

      it 'does not dispatch event' do
        expect(dispatcher).not_to receive(:dispatch)

        access_token.regenerate_token
      end
    end
  end

  describe '#notify_bot_token_change' do
    context 'when bot belongs to account' do
      let(:account) { create(:account) }
      let(:agent_bot) { create(:agent_bot, account: account) }
      let!(:access_token) { agent_bot.access_token }

      it 'dispatches BOT_TOKEN_UPDATED event' do
        expect(dispatcher).to receive(:dispatch).with(
          'bot_token.updated',
          kind_of(Time),
          hash_including(
            agent_bot: agent_bot,
            account: account,
            token: kind_of(String)
          )
        )

        access_token.regenerate_token
      end
    end

    context 'when bot is system bot (no account)' do
      let(:agent_bot) { create(:agent_bot, account: nil) }
      let!(:access_token) { agent_bot.access_token }

      it 'does not dispatch event' do
        expect(dispatcher).not_to receive(:dispatch)

        access_token.regenerate_token
      end
    end
  end
end
