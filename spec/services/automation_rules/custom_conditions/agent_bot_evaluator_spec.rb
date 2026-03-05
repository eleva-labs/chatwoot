require 'rails_helper'

RSpec.describe AutomationRules::CustomConditions::AgentBotEvaluator do
  describe '.evaluate' do
    let(:inbox) { create(:inbox) }
    let(:conversation) { create(:conversation, inbox: inbox) }

    context 'when inbox has active agent-bot' do
      before do
        agent_bot = create(:agent_bot)
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active)
      end

      it 'returns true when condition expects true' do
        condition = { 'values' => [true] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be true
      end

      it 'returns false when condition expects false' do
        condition = { 'values' => [false] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be false
      end
    end

    context 'when inbox has no agent-bot' do
      it 'returns false when condition expects true' do
        condition = { 'values' => [true] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be false
      end

      it 'returns true when condition expects false' do
        condition = { 'values' => [false] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be true
      end
    end

    context 'when inbox has inactive agent-bot' do
      before do
        agent_bot = create(:agent_bot)
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :inactive)
      end

      it 'returns false when condition expects true' do
        condition = { 'values' => [true] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be false
      end
    end

    context 'when condition value is a hash (from frontend dropdown)' do
      before do
        agent_bot = create(:agent_bot)
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active)
      end

      it 'extracts boolean from hash with string key' do
        condition = { 'values' => [{ 'id' => true, 'name' => 'Yes' }] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be true
      end

      it 'extracts boolean from hash with symbol key' do
        condition = { 'values' => [{ id: false, name: 'No' }] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be false
      end
    end
  end
end
