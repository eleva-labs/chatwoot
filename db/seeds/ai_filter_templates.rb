# frozen_string_literal: true

# AI Conversation Filter Templates
# These are example automation rules that demonstrate how to use custom AI filter conditions
# To create these templates for an account, run:
#   rails runner "Seeds::AiFilterTemplates.create_for_account(Account.find(YOUR_ACCOUNT_ID))"

module Seeds
  class AiFilterTemplates
    def self.create_for_account(account)
      Rails.logger.info "Creating AI filter templates for account #{account.id}"

      create_sales_intent_template(account)
      create_support_request_template(account)
      create_random_ab_test_template(account)
      create_whatsapp_spanish_template(account)
      create_combined_smart_routing_template(account)

      Rails.logger.info 'AI filter templates created successfully'
    end

    # Template 1: Detect sales intent keywords
    # Enables AI when customer shows buying intent
    def self.create_sales_intent_template(account)
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] Enable AI for Sales Intent'
      ) do |rule|
        rule.description = 'Automatically enable AI when customer mentions buying keywords (works in any language)'
        rule.event_name = 'conversation_created'
        rule.active = false
        rule.conditions = [
          {
            attribute_key: 'has_agent_bot',
            filter_operator: 'equal_to',
            values: [true],
            query_operator: 'and'
          },
          {
            attribute_key: 'entry_phrase',
            filter_operator: 'contains',
            values: %w[buy comprar purchase price precio cost costo quote cotización],
            query_operator: nil,
            custom_filters: { 'message_limit' => 3, 'case_sensitive' => false }
          }
        ]
        rule.actions = [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      end
    end

    # Template 2: Detect support requests
    # Enables AI when customer needs help
    def self.create_support_request_template(account)
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] Enable AI for Support Requests'
      ) do |rule|
        rule.description = 'Automatically enable AI when customer asks for help or reports issues'
        rule.event_name = 'conversation_created'
        rule.active = false
        rule.conditions = [
          {
            attribute_key: 'has_agent_bot',
            filter_operator: 'equal_to',
            values: [true],
            query_operator: 'and'
          },
          {
            attribute_key: 'entry_phrase',
            filter_operator: 'contains',
            values: ['help', 'ayuda', 'problem', 'problema', 'issue', 'error', 'not working', 'no funciona'],
            query_operator: nil,
            custom_filters: { 'message_limit' => 5, 'case_sensitive' => false }
          }
        ]
        rule.actions = [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      end
    end

    # Template 3: Random A/B testing (50% of conversations)
    # Good for testing AI performance
    def self.create_random_ab_test_template(account)
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] Enable AI for 50% (A/B Test)'
      ) do |rule|
        rule.description = 'Enable AI for 50% of conversations randomly - useful for testing AI effectiveness'
        rule.event_name = 'conversation_created'
        rule.active = false
        rule.conditions = [
          {
            attribute_key: 'has_agent_bot',
            filter_operator: 'equal_to',
            values: [true],
            query_operator: 'and'
          },
          {
            attribute_key: 'random_chance',
            filter_operator: 'is_less_than',
            values: [50],
            query_operator: nil
          }
        ]
        rule.actions = [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      end
    end

    # Template 4: WhatsApp channel with Spanish phrases
    # Shows how to configure per-channel rules
    def self.create_whatsapp_spanish_template(account)
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] WhatsApp - Spanish Keywords'
      ) do |rule|
        rule.description = 'Enable AI for WhatsApp conversations with Spanish sales/support keywords (customize inbox ID)'
        rule.event_name = 'conversation_created'
        rule.active = false
        rule.conditions = [
          {
            attribute_key: 'has_agent_bot',
            filter_operator: 'equal_to',
            values: [true],
            query_operator: 'and'
          },
          {
            attribute_key: 'inbox_id',
            filter_operator: 'equal_to',
            values: [], # User must select their WhatsApp inbox
            query_operator: 'and'
          },
          {
            attribute_key: 'entry_phrase',
            filter_operator: 'contains',
            values: ['hola', 'buenos días', 'buenas tardes', 'ayuda', 'comprar', 'precio', 'información'],
            query_operator: nil,
            custom_filters: { 'message_limit' => 3, 'case_sensitive' => false }
          }
        ]
        rule.actions = [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      end
    end

    # Template 5: Combined smart routing
    # Shows how to combine entry phrase + random for balanced load
    def self.create_combined_smart_routing_template(account)
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] Smart Routing - Keywords + 60% Random'
      ) do |rule|
        rule.description = 'Enable AI for conversations with specific keywords AND 60% random chance - balances AI usage'
        rule.event_name = 'conversation_created'
        rule.active = false
        rule.conditions = [
          {
            attribute_key: 'has_agent_bot',
            filter_operator: 'equal_to',
            values: [true],
            query_operator: 'and'
          },
          {
            attribute_key: 'entry_phrase',
            filter_operator: 'contains',
            values: %w[start comenzar info información hi hello hola],
            query_operator: 'and',
            custom_filters: { 'message_limit' => 2, 'case_sensitive' => false }
          },
          {
            attribute_key: 'random_chance',
            filter_operator: 'is_less_than',
            values: [60],
            query_operator: nil
          }
        ]
        rule.actions = [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      end
    end
  end
end
