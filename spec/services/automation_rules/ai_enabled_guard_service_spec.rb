require 'rails_helper'

RSpec.describe AutomationRules::AiEnabledGuardService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }

  describe '#can_enable_ai?' do
    context 'when inbox has active agent-bot' do
      before { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active) }

      it 'returns true' do
        guard = described_class.new(conversation)
        expect(guard.can_enable_ai?).to be true
      end
    end

    context 'when inbox has no agent-bot' do
      it 'returns false' do
        guard = described_class.new(conversation)
        expect(guard.can_enable_ai?).to be false
      end
    end

    context 'when inbox has inactive agent-bot' do
      before { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :inactive) }

      it 'returns false' do
        guard = described_class.new(conversation)
        expect(guard.can_enable_ai?).to be false
      end
    end
  end

  describe '#enforce!' do
    let(:guard) { described_class.new(conversation) }

    context 'when AI enabled but no bot configured' do
      before do
        conversation.custom_attributes = { 'ai_enabled' => true }
        conversation.save!
      end

      it 'disables AI' do
        guard.enforce!
        expect(conversation.reload.custom_attributes['ai_enabled']).to be false
      end

      it 'returns true' do
        expect(guard.enforce!).to be true
      end
    end

    context 'when AI disabled and no bot configured' do
      before do
        conversation.custom_attributes = { 'ai_enabled' => false }
        conversation.save!
      end

      it 'keeps AI disabled' do
        guard.enforce!
        expect(conversation.reload.custom_attributes['ai_enabled']).to be false
      end

      it 'returns false' do
        expect(guard.enforce!).to be false
      end
    end

    context 'when AI enabled and bot configured' do
      before do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active)
        conversation.custom_attributes = { 'ai_enabled' => true }
        conversation.save!
      end

      it 'keeps AI enabled' do
        guard.enforce!
        expect(conversation.reload.custom_attributes['ai_enabled']).to be true
      end
    end

    context 'when AI not set and no bot configured' do
      before do
        conversation.custom_attributes = {}
        conversation.save!
      end

      it 'does not change AI status' do
        guard.enforce!
        expect(conversation.reload.custom_attributes['ai_enabled']).to be_nil
      end
    end
  end
end
