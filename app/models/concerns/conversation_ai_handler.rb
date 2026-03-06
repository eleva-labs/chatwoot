# frozen_string_literal: true

module ConversationAiHandler
  extend ActiveSupport::Concern

  included do
    before_create :initialize_ai_enabled
    before_validation :ensure_custom_attributes_hash
  end

  # Query if AI is enabled for this conversation
  def ai_enabled?
    custom_attributes&.dig('ai_enabled') == true
  end

  # Query if AI is explicitly disabled
  def ai_disabled?
    custom_attributes&.dig('ai_enabled') == false
  end

  # Enable AI for conversation (with prerequisite check)
  # @return [Boolean] true if successful, false if prerequisites not met
  def enable_ai!
    Rails.logger.info "[AI_TOGGLE] enable_ai! called. ai_enabled?=#{ai_enabled?}, Current.user=#{Current.user&.class}:#{Current.user&.id}"
    return true if ai_enabled?
    return false unless inbox_has_active_bot?

    self.custom_attributes ||= {}
    self.custom_attributes['ai_enabled'] = true
    save!
    create_ai_toggle_activity('enabled')
    true
  end

  # Disable AI for conversation
  # @return [Boolean] true if successful
  def disable_ai!
    Rails.logger.info "[AI_TOGGLE] disable_ai! called. ai_disabled?=#{ai_disabled?}, Current.user=#{Current.user&.class}:#{Current.user&.id}"
    return true if ai_disabled?

    self.custom_attributes ||= {}
    self.custom_attributes['ai_enabled'] = false
    save!
    create_ai_toggle_activity('disabled')
    true
  end

  private

  def ensure_custom_attributes_hash
    self.custom_attributes ||= {}
  end

  def initialize_ai_enabled
    return if custom_attributes.key?('ai_enabled')

    self.custom_attributes['ai_enabled'] = inbox_has_active_bot?
  end

  def inbox_has_active_bot?
    inbox&.agent_bot_inbox&.active? || false
  end

  def create_ai_toggle_activity(change_type)
    return unless Current.user

    content = I18n.t("conversations.activity.ai.#{change_type}", user_name: Current.user.name)
    ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content)) if content
  end
end

ConversationAiHandler.prepend_mod_with('ConversationAiHandler')
