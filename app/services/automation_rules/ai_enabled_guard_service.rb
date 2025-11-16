module AutomationRules
  class AiEnabledGuardService
    def initialize(conversation)
      @conversation = conversation
      @inbox = conversation.inbox
    end

    def can_enable_ai?
      # Prerequisite 1: Must have active agent-bot
      return false unless has_active_bot?

      # Prerequisite 2: Add more checks here in the future
      # - Business hours check?
      # - Subscription level check?
      # - Account-level AI enabled flag?

      true
    end

    def enforce!
      # If AI is enabled but prerequisites not met, disable it
      return unless ai_enabled? && !can_enable_ai?

      disable_ai!
      Rails.logger.warn "AI force-disabled for conversation #{@conversation.id}: prerequisites not met (inbox: #{@inbox.id})"
    end

    private

    def has_active_bot?
      @inbox.agent_bot_inbox&.active? || false
    rescue StandardError => e
      Rails.logger.error "Error checking agent_bot: #{e.message}"
      false
    end

    def ai_enabled?
      @conversation.custom_attributes&.dig('ai_enabled') == true
    end

    def disable_ai!
      @conversation.custom_attributes ||= {}
      @conversation.custom_attributes['ai_enabled'] = false
      @conversation.save!
    end
  end
end
