# frozen_string_literal: true

class AutomationRules::CustomConditions::AgentBotEvaluator
  # Evaluates if inbox has an active agent-bot
  #
  # @param conversation [Conversation] The conversation to check
  # @param condition [Hash] The condition configuration
  # @return [Boolean] True if condition passes
  def self.evaluate(conversation, condition)
    inbox = conversation.inbox
    has_bot = inbox.agent_bot_inbox&.active? || false

    expected = condition['values']&.first

    case expected
    when true, 'true'
      has_bot
    when false, 'false'
      !has_bot
    else
      true # No requirement
    end
  end
end
