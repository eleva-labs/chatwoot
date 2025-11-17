require 'rails_helper'

RSpec.describe 'AI Filter Automation', type: :integration do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_bot) { create(:agent_bot) }
  let!(:agent_bot_inbox) { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active) }
  let(:contact) { create(:contact, account: account) }

  describe 'has_agent_bot condition' do
    it 'passes when inbox has active agent-bot' do
      conversation = create(:conversation, inbox: inbox, contact: contact)

      rule = create(:automation_rule,
                    account: account,
                    event_name: 'conversation_created',
                    conditions: [
                      { attribute_key: 'has_agent_bot', filter_operator: 'equal_to', values: [true], query_operator: nil }
                    ],
                    actions: [
                      { action_name: 'add_label', action_params: ['ai-enabled'] }
                    ])

      service = AutomationRules::ConditionsFilterService.new(rule, conversation)
      result = service.perform

      expect(result).to be true
      expect(conversation.reload.custom_attributes['ai_auto_agentbot_checked']).to be true
      expect(conversation.custom_attributes['ai_auto_agentbot_passed']).to be true
    end
  end

  describe 'random_chance condition' do
    it 'evaluates and caches result' do
      conversation = create(:conversation, inbox: inbox, contact: contact)

      rule = create(:automation_rule,
                    account: account,
                    event_name: 'conversation_created',
                    conditions: [
                      { attribute_key: 'random_chance', filter_operator: 'is_less_than', values: [100], query_operator: nil }
                    ],
                    actions: [])

      service = AutomationRules::ConditionsFilterService.new(rule, conversation)
      result1 = service.perform

      # Call again - should use cache
      result2 = service.perform

      expect(result1).to eq(result2)
      expect(conversation.reload.custom_attributes['ai_auto_random_checked']).to be true
      expect(conversation.custom_attributes['ai_auto_random_passed']).to be true
    end
  end

  describe 'entry_phrase condition' do
    it 'finds phrase in first message' do
      conversation = create(:conversation, inbox: inbox, contact: contact)
      create(:message, conversation: conversation, content: 'I need help', message_type: :incoming)

      condition = {
        attribute_key: 'entry_phrase',
        filter_operator: 'contains',
        values: ['help'],
        custom_filters: { 'message_limit' => 3, 'case_sensitive' => false },
        query_operator: nil
      }

      rule = create(:automation_rule,
                    account: account,
                    event_name: 'message_created',
                    conditions: [condition],
                    actions: [])

      # Calculate expected cache key hash (matches implementation)
      condition_hash = Digest::MD5.hexdigest(
        "#{condition[:values].sort.join('|')}|#{condition[:custom_filters]}"
      )
      cache_key = "ai_auto_phrase_#{condition_hash}_checked"
      result_key = "ai_auto_phrase_#{condition_hash}_passed"

      service = AutomationRules::ConditionsFilterService.new(rule, conversation, message: conversation.messages.first)
      result = service.perform

      expect(result).to be true
      expect(conversation.reload.custom_attributes[cache_key]).to be true
      expect(conversation.custom_attributes[result_key]).to be true
    end
  end
end
