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

    it 'uses default message_limit of 3 when not specified' do
      create(:message, conversation: conversation, content: 'hello', message_type: :incoming)
      create(:message, conversation: conversation, content: 'world', message_type: :incoming)
      create(:message, conversation: conversation, content: 'test', message_type: :incoming)
      create(:message, conversation: conversation, content: 'help', message_type: :incoming) # 4th message

      condition = {
        'values' => ['help'],
        'custom_filters' => {} # No message_limit specified
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false # Only checks first 3 messages
    end
  end
end
