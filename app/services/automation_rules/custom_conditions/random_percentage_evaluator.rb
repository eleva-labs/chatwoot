# frozen_string_literal: true

module AutomationRules
  module CustomConditions
    class RandomPercentageEvaluator
      # Evaluates random percentage condition
      # Uses conversation ID as seed for deterministic results
      #
      # @param conversation [Conversation] The conversation to check
      # @param condition [Hash] The condition configuration
      # @return [Boolean] True if random passes
      def self.evaluate(conversation, condition)
        percentage = condition['values']&.first&.to_i
        return false if percentage.nil? || percentage <= 0

        # Deterministic random based on conversation ID
        # Same conversation always gets same result
        Random.new(conversation.id).rand(100) < percentage
      end
    end
  end
end
