# frozen_string_literal: true

class AutomationRules::CustomConditions::EntryPhraseEvaluator
  # Evaluates if entry phrases are found in first N incoming messages
  #
  # @param conversation [Conversation] The conversation to check
  # @param condition [Hash] The condition configuration
  # @return [Boolean] True if any phrase found
  def self.evaluate(conversation, condition)
    phrases = condition['values'] || []
    return false if phrases.empty?

    message_limit = condition.dig('custom_filters', 'message_limit')&.to_i || 3
    case_sensitive = condition.dig('custom_filters', 'case_sensitive') || false

    messages = fetch_messages(conversation, message_limit)
    message_contains_phrase?(messages, phrases, case_sensitive)
  end

  def self.fetch_messages(conversation, limit)
    conversation.messages.incoming.order(:created_at).limit(limit)
  end
  private_class_method :fetch_messages

  def self.message_contains_phrase?(messages, phrases, case_sensitive)
    messages.any? do |message|
      content = normalize_text(message.content, case_sensitive)
      phrases.any? { |phrase| content.include?(normalize_text(phrase, case_sensitive)) }
    end
  end
  private_class_method :message_contains_phrase?

  def self.normalize_text(text, case_sensitive)
    case_sensitive ? text : text.to_s.downcase
  end
  private_class_method :normalize_text
end
