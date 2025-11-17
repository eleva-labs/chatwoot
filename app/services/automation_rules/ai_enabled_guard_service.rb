# frozen_string_literal: true

module AutomationRules
  class AiEnabledGuardService
    def initialize(conversation)
      @conversation = conversation
    end

    def can_enable_ai?
      @conversation.send(:inbox_has_active_bot?)
    end

    def enforce!
      return false unless @conversation.ai_enabled? && !can_enable_ai?

      @conversation.disable_ai!
      true
    end
  end
end
