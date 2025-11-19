# frozen_string_literal: true

class AutomationRules::CustomConditions::EntryPhraseEvaluator
  # Evaluates if entry phrases match the condition in first N incoming messages
  #
  # @param conversation [Conversation] The conversation to check
  # @param condition [Hash] The condition configuration
  # @return [Boolean] True if condition matches
  def self.evaluate(conversation, condition)
    phrases = condition['values'] || []
    return false if phrases.empty?

    message_limit = condition.dig('custom_filters', 'message_limit')&.to_i || 2
    case_sensitive = condition.dig('custom_filters', 'case_sensitive') || false
    operator = condition['filter_operator'] || 'contains'

    messages = fetch_messages(conversation, message_limit)

    case operator
    when 'equal_to'
      message_equals_phrase?(messages, phrases, case_sensitive)
    when 'not_equal_to'
      !message_equals_phrase?(messages, phrases, case_sensitive)
    when 'contains'
      message_contains_phrase?(messages, phrases, case_sensitive)
    when 'does_not_contain'
      !message_contains_phrase?(messages, phrases, case_sensitive)
    else
      # Default to contains for backward compatibility
      message_contains_phrase?(messages, phrases, case_sensitive)
    end
  end

  def self.fetch_messages(conversation, limit)
    conversation.messages.incoming.order(:created_at).limit(limit)
  end
  private_class_method :fetch_messages

  def self.message_equals_phrase?(messages, phrases, case_sensitive)
    messages.any? do |message|
      content = normalize_text(message.content, case_sensitive)
      phrases.any? { |phrase| content == normalize_text(phrase, case_sensitive) }
    end
  end
  private_class_method :message_equals_phrase?

  def self.message_contains_phrase?(messages, phrases, case_sensitive)
    messages.any? do |message|
      content = normalize_text(message.content, case_sensitive)
      phrases.any? { |phrase| content.include?(normalize_text(phrase, case_sensitive)) }
    end
  end
  private_class_method :message_contains_phrase?

  def self.normalize_text(text, case_sensitive)
    normalized = text.to_s.strip
    case_sensitive ? normalized : normalized.downcase
  end
  private_class_method :normalize_text
end
