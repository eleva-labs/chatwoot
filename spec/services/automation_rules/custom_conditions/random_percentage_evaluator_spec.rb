require 'rails_helper'

RSpec.describe AutomationRules::CustomConditions::RandomPercentageEvaluator do
  describe '.evaluate' do
    it 'returns deterministic result based on conversation ID' do
      conversation = create(:conversation)
      condition = { 'values' => [60] }

      # Same conversation, same result
      result1 = described_class.evaluate(conversation, condition)
      result2 = described_class.evaluate(conversation, condition)

      expect(result1).to eq(result2)
    end

    it 'returns false when percentage is 0' do
      conversation = create(:conversation)
      condition = { 'values' => [0] }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'returns true when percentage is 100' do
      conversation = create(:conversation)
      condition = { 'values' => [100] }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true
    end

    it 'returns false when percentage is nil' do
      conversation = create(:conversation)
      condition = { 'values' => [nil] }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'returns false when values array is empty' do
      conversation = create(:conversation)
      condition = { 'values' => [] }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end
  end
end
