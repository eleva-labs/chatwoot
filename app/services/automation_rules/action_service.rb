class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    @rule.actions.each do |action|
      @conversation.reload
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
    end
  end

  def set_ai_enabled(ai_enabled_params)
    contact = @conversation.contact
    inbox = @conversation.inbox

    # Extract the boolean value from the params
    # Frontend sends [{ id: true/false, name: 'Enable'/'Disable' }]
    param_value = ai_enabled_params[0]
    enabled = if param_value.is_a?(Hash)
                param_value['id'] || param_value[:id]
              else
                param_value == 'true' || param_value == true
              end

    has_agent_bot = inbox.agent_bot_inbox&.active?

    # Safety check: Cannot enable AI without agent-bot
    if enabled && !has_agent_bot
      Rails.logger.warn(
        "[AutomationRule #{@rule.id}] Cannot enable AI for inbox #{inbox.id} " \
        "(no agent-bot). Conversation: #{@conversation.id}"
      )
      return
    end

    # Set ai_enabled
    contact.custom_attributes ||= {}
    contact.custom_attributes['ai_enabled'] = enabled
    contact.save!

    Rails.logger.info(
      "[AutomationRule #{@rule.id}] Set ai_enabled=#{enabled} for contact #{contact.id}, " \
      "conversation #{@conversation.id}"
    )
  end
end
