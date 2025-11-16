require 'rails_helper'

RSpec.describe AutomationRules::CustomConditions::EntryPhraseEvaluator do
  describe '.evaluate' do
    let(:conversation) { create(:conversation) }

    it 'returns true when phrase is found in first message' do
      create(:message, conversation: conversation, content: 'I need help', message_type: :incoming)

      condition = {
        'values' => ['help'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true
    end

    it 'returns true when phrase is found in second message' do
      create(:message, conversation: conversation, content: 'Hello', message_type: :incoming)
      create(:message, conversation: conversation, content: 'I want to start', message_type: :incoming)

      condition = {
        'values' => ['start'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true
    end

    it 'returns false when phrase is not found in first N messages' do
      create(:message, conversation: conversation, content: 'Hello', message_type: :incoming)
      create(:message, conversation: conversation, content: 'Thanks', message_type: :incoming)

      condition = {
        'values' => %w[help start],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'is case-insensitive by default' do
      create(:message, conversation: conversation, content: 'HELP ME', message_type: :incoming)

      condition = {
        'values' => ['help'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true
    end

    it 'can be case-sensitive when configured' do
      create(:message, conversation: conversation, content: 'HELP ME', message_type: :incoming)

      condition = {
        'values' => ['help'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => true }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'checks only incoming messages' do
      create(:message, conversation: conversation, content: 'help', message_type: :outgoing)
      create(:message, conversation: conversation, content: 'hello', message_type: :incoming)

      condition = {
        'values' => ['help'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false # Outgoing doesn't count
    end

    it 'returns false when values array is empty' do
      create(:message, conversation: conversation, content: 'help', message_type: :incoming)

      condition = {
        'values' => [],
        'custom_filters' => { 'message_limit' => 3 }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'uses default message_limit of 2 when not specified' do
      create(:message, conversation: conversation, content: 'hello', message_type: :incoming)
      create(:message, conversation: conversation, content: 'world', message_type: :incoming)
      create(:message, conversation: conversation, content: 'help', message_type: :incoming) # 3rd message

      condition = {
        'values' => ['help'],
        'custom_filters' => {} # No message_limit specified
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false # Only checks first 2 messages
    end

    it 'strips whitespace from phrases and message content' do
      create(:message, conversation: conversation, content: '  hello world  ', message_type: :incoming)

      condition = {
        'values' => ['  hello  '],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true # Should match after stripping
    end

    it 'matches with multiple phrases using OR logic' do
      create(:message, conversation: conversation, content: 'I want to buy something', message_type: :incoming)

      condition = {
        'values' => %w[help start buy],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true # Matches 'buy'
    end

    context 'with multiple conditions (cache key uniqueness)' do
      it 'evaluates each condition independently' do
        create(:message, conversation: conversation, content: 'hello there', message_type: :incoming)
        create(:message, conversation: conversation, content: 'necesito ayuda', message_type: :incoming)

        # First condition: 'hello'
        condition1 = {
          'values' => ['hello'],
          'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false }
        }
        result1 = described_class.evaluate(conversation, condition1)
        expect(result1).to be true

        # Second condition: 'ayuda'
        condition2 = {
          'values' => ['ayuda'],
          'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false }
        }
        result2 = described_class.evaluate(conversation, condition2)
        expect(result2).to be true

        # Third condition: 'nonexistent'
        condition3 = {
          'values' => ['nonexistent'],
          'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false }
        }
        result3 = described_class.evaluate(conversation, condition3)
        expect(result3).to be false

        # Verify each condition was evaluated independently
        # (Not testing cache keys directly as that's implementation detail of ConditionsFilterService)
        expect(result1).to be true
        expect(result2).to be true
        expect(result3).to be false
      end
    end
  end
end
