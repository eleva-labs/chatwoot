# AI-Enabled Conversation Filters - Design Document

**Version**: 1.0.0 (Final)
**Date**: 2025-11-15
**Status**: Ready for Implementation
**Approach**: Pure Automation with Templates (Simplified v4.0)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Requirements](#requirements)
3. [Architecture Overview](#architecture-overview)
4. [Technical Design](#technical-design)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Deployment Plan](#deployment-plan)
8. [Documentation](#documentation)

---

## Executive Summary

### Goal

Implement a channel-level configuration system that automatically controls the `ai_enabled` custom attribute on conversations based on configurable conditions using Chatwoot's existing automation system.

### Approach

**100% leverage existing automation infrastructure** with:
- 3 new custom condition types (entry phrase, random %, agent-bot)
- 1 new action type (set_ai_enabled)
- Pre-built templates for one-click activation
- Simple boolean flags for persistence

### Key Design Principles

1. **Single Source of Truth**: `ai_enabled` is the only flag that matters
2. **Simple Caching**: Use boolean flags to cache condition evaluations
3. **No Manual Override Tracking**: User and automation can both set `ai_enabled` (last write wins)
4. **Template-First**: Provide pre-built templates with best practices
5. **Performance**: Cache evaluations to avoid re-computation

### Effort Estimation

**Total: 8-10 days**
- Backend: 5-6 days (conditions + action + caching)
- Frontend: 2 days (constants + i18n)
- Templates: 2-3 days (templates + UI)
- Testing: 1-2 days

---

## Requirements

### Functional Requirements

1. **Agent-Bot Prerequisite**
   - Only enable AI if inbox has an active agent-bot
   - Checked as a condition in automation rules
   - Action safety check prevents enabling without agent-bot

2. **CTA Filters / Entry Phrases**
   - Check first N messages (configurable, default: 3) for keywords
   - If ANY phrase matches, condition passes
   - Case-insensitive matching (default)
   - Keeps checking until match found or limit reached
   - Result cached after decision

3. **Random Percentage**
   - Deterministic random selection based on conversation ID
   - Percentage configurable (0-100)
   - Evaluated once per conversation, result cached
   - Same conversation always gets same result

4. **Extensibility**
   - Easy to add new condition types in future
   - Template system supports multiple variations

5. **User Control**
   - User can manually toggle `ai_enabled` anytime
   - Manual toggle and automation both modify same flag
   - Last write wins (simple semantics)

### Non-Functional Requirements

1. **Performance**
   - Condition results cached in conversation.custom_attributes
   - No re-evaluation after decision made
   - Early exit if agent-bot missing

2. **Data Integrity**
   - Use existing JSONB columns (no migration)
   - Backward compatible with existing data

3. **User Experience**
   - One-click template activation
   - Visual condition builder (existing automation UI)
   - Clear labels and i18n support

4. **Enterprise Compatibility**
   - Works in both CE and Enterprise editions
   - Uses existing extension patterns

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                        │
│  Settings → Automation → Templates → AI Filters          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│              Automation Rules System (Existing)          │
│  ┌─────────────────┐  ┌──────────────────┐             │
│  │ AutomationRule  │  │ Template Gallery │             │
│  │  - conditions   │  │  - AI Filter #1  │             │
│  │  - actions      │  │  - AI Filter #2  │             │
│  │  - event_name   │  │  - AI Filter #3  │             │
│  └─────────────────┘  └──────────────────┘             │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│              Event System (Existing)                     │
│  conversation.created → AutomationRuleListener           │
│  message.created      → AutomationRuleListener           │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│         Condition Evaluation (NEW + Existing)            │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ConditionsFilterService (EXTENDED)              │   │
│  │  ├─ Standard Conditions (existing)              │   │
│  │  └─ Custom Conditions (NEW):                    │   │
│  │      ├─ has_agent_bot (NEW)                     │   │
│  │      ├─ entry_phrase (NEW)                      │   │
│  │      └─ random_chance (NEW)                     │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│        Caching Layer (conversation.custom_attributes)    │
│  ai_auto_agentbot_checked: true                          │
│  ai_auto_agentbot_passed: true                           │
│  ai_auto_random_checked: true                            │
│  ai_auto_random_passed: false                            │
│  ai_auto_phrase_checked: true                            │
│  ai_auto_phrase_passed: true                             │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│           Action Execution (NEW + Existing)              │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ActionService (EXTENDED)                        │   │
│  │  ├─ Standard Actions (existing)                 │   │
│  │  └─ set_ai_enabled (NEW)                        │   │
│  │      ├─ Safety: Check agent-bot exists          │   │
│  │      └─ Set: contact.ai_enabled = true/false    │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│        Single Source of Truth (contact.custom_attributes)│
│  ai_enabled: true/false ← THE ONLY FLAG THAT MATTERS     │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
1. Conversation Created
   ↓
2. Event: conversation.created dispatched
   ↓
3. AutomationRuleListener receives event
   ↓
4. Load active automation rules with event_name = 'conversation_created'
   ↓
5. For each rule:
   ├─ ConditionsFilterService evaluates conditions
   │  ├─ Check: has_agent_bot? (cache result)
   │  ├─ Check: entry_phrase? (cache if found or limit reached)
   │  └─ Check: random_chance? (cache result)
   ↓
6. If ALL conditions pass:
   └─ ActionService.set_ai_enabled(true)
      ├─ Safety check: inbox has agent-bot?
      └─ Set: contact.custom_attributes['ai_enabled'] = true
   ↓
7. Next message arrives
   ↓
8. Event: message.created dispatched
   ↓
9. AutomationRuleListener receives event
   ↓
10. ConditionsFilterService evaluates
    ├─ has_agent_bot: Use cached result ✓
    ├─ random_chance: Use cached result ✓
    ├─ entry_phrase: Check if cached
    │  ├─ If cached → Use result
    │  └─ If not cached → Evaluate again (until found or limit)
    ↓
11. If conditions pass → set_ai_enabled (already set, no-op)
```

---

## Technical Design

### 1. Custom Condition Evaluators

#### 1.1 Agent-Bot Evaluator

**File**: `app/services/automation_rules/custom_conditions/agent_bot_evaluator.rb`

```ruby
# frozen_string_literal: true

module AutomationRules
  module CustomConditions
    class AgentBotEvaluator
      # Evaluates if inbox has an active agent-bot
      #
      # @param conversation [Conversation] The conversation to check
      # @param condition [Hash] The condition configuration
      # @return [Boolean] True if condition passes
      def self.evaluate(conversation, condition)
        inbox = conversation.inbox
        has_bot = inbox.agent_bot_inbox&.active?

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
  end
end
```

**Test**: `spec/services/automation_rules/custom_conditions/agent_bot_evaluator_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe AutomationRules::CustomConditions::AgentBotEvaluator do
  describe '.evaluate' do
    let(:inbox) { create(:inbox) }
    let(:conversation) { create(:conversation, inbox: inbox) }

    context 'when inbox has active agent-bot' do
      before do
        agent_bot = create(:agent_bot)
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active)
      end

      it 'returns true when condition expects true' do
        condition = { 'values' => [true] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be true
      end

      it 'returns false when condition expects false' do
        condition = { 'values' => [false] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be false
      end
    end

    context 'when inbox has no agent-bot' do
      it 'returns false when condition expects true' do
        condition = { 'values' => [true] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be false
      end

      it 'returns true when condition expects false' do
        condition = { 'values' => [false] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be true
      end
    end

    context 'when inbox has inactive agent-bot' do
      before do
        agent_bot = create(:agent_bot)
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :inactive)
      end

      it 'returns false when condition expects true' do
        condition = { 'values' => [true] }
        result = described_class.evaluate(conversation, condition)
        expect(result).to be false
      end
    end
  end
end
```

#### 1.2 Random Percentage Evaluator

**File**: `app/services/automation_rules/custom_conditions/random_percentage_evaluator.rb`

```ruby
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
```

**Test**: `spec/services/automation_rules/custom_conditions/random_percentage_evaluator_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe AutomationRules::CustomConditions::RandomPercentageEvaluator do
  describe '.evaluate' do
    it 'returns deterministic result based on conversation ID' do
      conversation = create(:conversation, id: 1000)
      condition = { 'values' => [60] }

      # Same conversation, same result
      result1 = described_class.evaluate(conversation, condition)
      result2 = described_class.evaluate(conversation, condition)

      expect(result1).to eq(result2)
    end

    it 'returns different results for different conversations' do
      conversation1 = create(:conversation)
      conversation2 = create(:conversation)
      condition = { 'values' => [60] }

      result1 = described_class.evaluate(conversation1, condition)
      result2 = described_class.evaluate(conversation2, condition)

      # Statistically likely to be different (not guaranteed)
      # Test multiple times or use fixed IDs
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
  end
end
```

#### 1.3 Entry Phrase Evaluator

**File**: `app/services/automation_rules/custom_conditions/entry_phrase_evaluator.rb`

```ruby
# frozen_string_literal: true

module AutomationRules
  module CustomConditions
    class EntryPhraseEvaluator
      # Evaluates if entry phrases are found in first N incoming messages
      #
      # @param conversation [Conversation] The conversation to check
      # @param condition [Hash] The condition configuration
      # @return [Boolean] True if any phrase found
      def self.evaluate(conversation, condition)
        message_limit = condition.dig('custom_filters', 'message_limit')&.to_i || 3
        case_sensitive = condition.dig('custom_filters', 'case_sensitive') || false
        phrases = condition['values'] || []

        return false if phrases.empty?

        # Get first N incoming messages
        messages = conversation.messages.incoming
                               .order(:created_at)
                               .limit(message_limit)

        # Check if any message contains any phrase
        messages.any? do |message|
          content = case_sensitive ? message.content : message.content.to_s.downcase

          phrases.any? do |phrase|
            search_phrase = case_sensitive ? phrase : phrase.to_s.downcase
            content.include?(search_phrase)
          end
        end
      end
    end
  end
end
```

**Test**: `spec/services/automation_rules/custom_conditions/entry_phrase_evaluator_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe AutomationRules::CustomConditions::EntryPhraseEvaluator do
  describe '.evaluate' do
    let(:conversation) { create(:conversation) }

    it 'returns true when phrase is found in first message' do
      create(:message, conversation: conversation, content: 'I need help', message_type: :incoming)

      condition = {
        'values' => ['help'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true
    end

    it 'returns true when phrase is found in second message' do
      create(:message, conversation: conversation, content: 'Hello', message_type: :incoming)
      create(:message, conversation: conversation, content: 'I want to start', message_type: :incoming)

      condition = {
        'values' => ['start'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true
    end

    it 'returns false when phrase is not found in first N messages' do
      create(:message, conversation: conversation, content: 'Hello', message_type: :incoming)
      create(:message, conversation: conversation, content: 'Thanks', message_type: :incoming)

      condition = {
        'values' => ['help', 'start'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'is case-insensitive by default' do
      create(:message, conversation: conversation, content: 'HELP ME', message_type: :incoming)

      condition = {
        'values' => ['help'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be true
    end

    it 'can be case-sensitive when configured' do
      create(:message, conversation: conversation, content: 'HELP ME', message_type: :incoming)

      condition = {
        'values' => ['help'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => true }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'checks only incoming messages' do
      create(:message, conversation: conversation, content: 'help', message_type: :outgoing)
      create(:message, conversation: conversation, content: 'hello', message_type: :incoming)

      condition = {
        'values' => ['help'],
        'custom_filters' => { 'message_limit' => 3, 'case_sensitive' => false }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false # Outgoing doesn't count
    end
  end
end
```

### 2. Conditions Filter Service Extension

**File**: `app/services/automation_rules/conditions_filter_service.rb` (MODIFY)

**Add caching logic:**

```ruby
class AutomationRules::ConditionsFilterService < FilterService
  def perform
    return false unless rule_valid?

    @conversation&.reload # Ensure fresh custom_attributes

    # Evaluate each condition
    all_pass = @rule.conditions.all? do |condition|
      evaluate_condition_with_cache(condition)
    end

    all_pass
  end

  private

  def evaluate_condition_with_cache(query_hash)
    case query_hash['attribute_key']
    when 'has_agent_bot'
      evaluate_cached_condition(
        query_hash,
        'ai_auto_agentbot',
        -> { AutomationRules::CustomConditions::AgentBotEvaluator.evaluate(@conversation, query_hash) }
      )

    when 'random_chance'
      evaluate_cached_condition(
        query_hash,
        'ai_auto_random',
        -> { AutomationRules::CustomConditions::RandomPercentageEvaluator.evaluate(@conversation, query_hash) }
      )

    when 'entry_phrase'
      evaluate_phrase_condition(query_hash)

    when 'attribute_changed'
      # Existing special handling
      @attribute_changed_query_filter << query_hash
      true

    else
      # Standard condition evaluation (existing logic)
      apply_filter(query_hash, @current_index)
      true
    end
  end

  def evaluate_cached_condition(condition, cache_prefix, evaluator)
    return true unless @conversation # No conversation context

    cache_key = "#{cache_prefix}_checked"
    result_key = "#{cache_prefix}_passed"

    # Check cache
    if @conversation.custom_attributes&.dig(cache_key)
      return @conversation.custom_attributes[result_key]
    end

    # Evaluate
    result = evaluator.call

    # Store result
    @conversation.custom_attributes ||= {}
    @conversation.custom_attributes[cache_key] = true
    @conversation.custom_attributes[result_key] = result
    @conversation.save!

    result
  end

  def evaluate_phrase_condition(condition)
    return true unless @conversation

    cache_key = 'ai_auto_phrase_checked'
    result_key = 'ai_auto_phrase_passed'

    # Check cache
    if @conversation.custom_attributes&.dig(cache_key)
      return @conversation.custom_attributes[result_key]
    end

    # Check message limit
    message_limit = condition.dig('custom_filters', 'message_limit')&.to_i || 3
    incoming_count = @conversation.messages.incoming.count

    if incoming_count > message_limit
      # Reached limit without finding phrase
      @conversation.custom_attributes ||= {}
      @conversation.custom_attributes[cache_key] = true
      @conversation.custom_attributes[result_key] = false
      @conversation.save!
      return false
    end

    # Evaluate
    result = AutomationRules::CustomConditions::EntryPhraseEvaluator.evaluate(@conversation, condition)

    if result
      # Found phrase! Cache it
      @conversation.custom_attributes ||= {}
      @conversation.custom_attributes[cache_key] = true
      @conversation.custom_attributes[result_key] = true
      @conversation.save!
    else
      # Not found yet - DON'T cache (keep checking on next message)
    end

    result
  end
end
```

### 3. Action Service Extension

**File**: `app/services/automation_rules/action_service.rb` (MODIFY)

**Add set_ai_enabled action:**

```ruby
class AutomationRules::ActionService < ActionService
  # ... existing actions

  private

  def set_ai_enabled(ai_enabled_value)
    contact = @conversation.contact
    inbox = @conversation.inbox

    enabled = ai_enabled_value.first == 'true' || ai_enabled_value.first == true
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
```

**Update actions_attributes method:**

```ruby
def actions_attributes
  %w[send_message add_label remove_label send_email_to_team assign_team assign_agent
     send_webhook_event mute_conversation send_attachment change_status resolve_conversation
     open_conversation snooze_conversation change_priority send_email_transcript add_private_note
     set_ai_enabled].freeze
end
```

### 4. Filter Keys Configuration

**File**: `lib/filters/filter_keys.yml` (MODIFY)

**Add custom conditions:**

```yaml
conversations:
  # ... existing filters

  has_agent_bot:
    attribute_type: "computed"
    data_type: "boolean"
    filter_operators:
      - "equal_to"
      - "not_equal_to"

  random_chance:
    attribute_type: "computed"
    data_type: "number"
    filter_operators:
      - "is_less_than"

  entry_phrase:
    attribute_type: "computed"
    data_type: "text"
    filter_operators:
      - "contains"
    custom_filters:
      - "message_limit"
      - "case_sensitive"
```

### 5. Frontend Constants

**File**: `app/javascript/dashboard/routes/dashboard/settings/automation/constants.js` (MODIFY)

**Add to AUTOMATIONS.conversation_created.conditions:**

```javascript
// ... existing conditions

{
  key: 'has_agent_bot',
  name: 'HAS_AGENT_BOT',
  inputType: 'search_select',
  filterOperators: OPERATOR_TYPES_1, // equal_to, not_equal_to
  dropdownValues: [
    { id: true, name: 'Yes' },
    { id: false, name: 'No' }
  ]
},
{
  key: 'entry_phrase',
  name: 'ENTRY_PHRASE_MATCH',
  inputType: 'comma_separated_plain_text',
  filterOperators: OPERATOR_TYPES_2, // contains, does_not_contain
  customFilters: {
    message_limit: {
      type: 'number',
      default: 3,
      label: 'MESSAGE_LIMIT',
      min: 1,
      max: 10
    },
    case_sensitive: {
      type: 'boolean',
      default: false,
      label: 'CASE_SENSITIVE'
    }
  }
},
{
  key: 'random_chance',
  name: 'RANDOM_PERCENTAGE',
  inputType: 'number',
  filterOperators: OPERATOR_TYPES_4, // is_less_than, is_greater_than
}
```

**Add to AUTOMATIONS.conversation_created.actions:**

```javascript
// ... existing actions

{
  key: 'set_ai_enabled',
  name: 'SET_AI_ENABLED',
  inputType: 'search_select',
  dropdownValues: [
    { id: true, name: 'Enable' },
    { id: false, name: 'Disable' }
  ]
}
```

**Also add to message_created event conditions** (for phrase detection on later messages).

### 6. i18n Translations

**File**: `app/javascript/dashboard/i18n/locale/en.json` (MODIFY)

```json
{
  "AUTOMATION": {
    "CONDITIONS": {
      "HAS_AGENT_BOT": "Inbox has agent-bot",
      "ENTRY_PHRASE_MATCH": "Entry phrase",
      "RANDOM_PERCENTAGE": "Random percentage",
      "MESSAGE_LIMIT": "Check first N messages",
      "CASE_SENSITIVE": "Case sensitive"
    },
    "ACTIONS": {
      "SET_AI_ENABLED": "Set AI enabled"
    }
  }
}
```

**File**: `app/javascript/dashboard/i18n/locale/es.json` (MODIFY)

```json
{
  "AUTOMATION": {
    "CONDITIONS": {
      "HAS_AGENT_BOT": "El canal tiene agente-bot",
      "ENTRY_PHRASE_MATCH": "Frase de entrada",
      "RANDOM_PERCENTAGE": "Porcentaje aleatorio",
      "MESSAGE_LIMIT": "Verificar primeros N mensajes",
      "CASE_SENSITIVE": "Sensible a mayúsculas"
    },
    "ACTIONS": {
      "SET_AI_ENABLED": "Establecer IA habilitada"
    }
  }
}
```

### 7. Pre-Built Templates

**File**: `db/seeds/ai_filter_templates.rb` (NEW) or migration

```ruby
# frozen_string_literal: true

module Seeds
  class AiFilterTemplates
    def self.create_for_account(account)
      # Template 1: CTA + Random
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] AI Filters - CTA + Random'
      ) do |rule|
        rule.description = 'Enable AI for conversations with specific entry phrases (60% random)'
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
            values: ['start', 'comprar', 'help'],
            query_operator: 'and',
            custom_filters: { message_limit: 3, case_sensitive: false }
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

      # Template 2: CTA Only
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] AI Filters - CTA Only'
      ) do |rule|
        rule.description = 'Enable AI for conversations with specific entry phrases'
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
            values: ['start', 'comprar', 'help'],
            query_operator: nil,
            custom_filters: { message_limit: 3, case_sensitive: false }
          }
        ]
        rule.actions = [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      end

      # Template 3: Random Only
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] AI Filters - Random 50%'
      ) do |rule|
        rule.description = 'Enable AI for 50% of conversations (random)'
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
  end
end

# Run for existing accounts
Account.find_each do |account|
  Seeds::AiFilterTemplates.create_for_account(account)
end
```

---

## Implementation Plan

### Phase 1: Backend Custom Conditions (Days 1-3)

**Day 1: Agent-Bot & Random Evaluators**
- [ ] Create `AgentBotEvaluator` with tests
- [ ] Create `RandomPercentageEvaluator` with tests
- [ ] Add to `filter_keys.yml`

**Day 2: Entry Phrase Evaluator**
- [ ] Create `EntryPhraseEvaluator` with tests
- [ ] Handle case sensitivity
- [ ] Handle message limit
- [ ] Add to `filter_keys.yml`

**Day 3: Conditions Filter Service Integration**
- [ ] Extend `ConditionsFilterService`
- [ ] Add caching logic
- [ ] Add `evaluate_cached_condition` method
- [ ] Add `evaluate_phrase_condition` method
- [ ] Integration tests

### Phase 2: Backend Action (Days 4-5)

**Day 4: Action Service**
- [ ] Extend `ActionService`
- [ ] Add `set_ai_enabled` method
- [ ] Add agent-bot safety check
- [ ] Unit tests

**Day 5: Integration Testing**
- [ ] End-to-end automation tests
- [ ] Test caching behavior
- [ ] Test phrase detection across messages
- [ ] Test random persistence

### Phase 3: Frontend (Days 6-7)

**Day 6: Constants & i18n**
- [ ] Update `constants.js`
- [ ] Add condition definitions
- [ ] Add action definition
- [ ] Add `en.json` translations
- [ ] Add `es.json` translations

**Day 7: Testing**
- [ ] Test in automation UI
- [ ] Verify dropdowns work
- [ ] Verify condition builder works
- [ ] Fix any UI bugs

### Phase 4: Templates (Days 8-10)

**Day 8: Template Seeds**
- [ ] Create `ai_filter_templates.rb`
- [ ] Create 3 templates
- [ ] Test template creation

**Day 9: Template UI (Optional)**
- [ ] Add "Templates" button to automation UI
- [ ] Create template gallery (optional)
- [ ] Create template customizer (optional)
- [ ] Or just use existing clone feature

**Day 10: Testing & Documentation**
- [ ] End-to-end template testing
- [ ] User documentation
- [ ] Developer documentation
- [ ] Code review

---

## Testing Strategy

### Unit Tests

**Evaluators (3 files):**
- `spec/services/automation_rules/custom_conditions/agent_bot_evaluator_spec.rb`
- `spec/services/automation_rules/custom_conditions/random_percentage_evaluator_spec.rb`
- `spec/services/automation_rules/custom_conditions/entry_phrase_evaluator_spec.rb`

**Coverage:**
- ✅ All condition variations
- ✅ Edge cases (nil, empty, invalid)
- ✅ Case sensitivity
- ✅ Message limits

**Services (2 files):**
- `spec/services/automation_rules/conditions_filter_service_spec.rb` (modify existing)
- `spec/services/automation_rules/action_service_spec.rb` (modify existing)

**Coverage:**
- ✅ Caching behavior
- ✅ Safety checks
- ✅ Agent-bot validation

### Integration Tests

**Automation Flow:**
```ruby
# spec/integration/ai_filter_automation_spec.rb
RSpec.describe 'AI Filter Automation', type: :integration do
  it 'enables AI when all conditions pass' do
    # Setup
    account = create(:account)
    inbox = create(:inbox, account: account)
    agent_bot = create(:agent_bot)
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active)

    rule = create(:automation_rule,
      account: account,
      event_name: 'conversation_created',
      conditions: [
        { attribute_key: 'has_agent_bot', filter_operator: 'equal_to', values: [true], query_operator: 'and' },
        { attribute_key: 'entry_phrase', filter_operator: 'contains', values: ['help'], query_operator: 'and',
          custom_filters: { message_limit: 3 } },
        { attribute_key: 'random_chance', filter_operator: 'is_less_than', values: [100] }
      ],
      actions: [
        { action_name: 'set_ai_enabled', action_params: [true] }
      ]
    )

    # Create conversation
    contact = create(:contact, account: account)
    conversation = create(:conversation, inbox: inbox, contact: contact)
    create(:message, conversation: conversation, content: 'I need help', message_type: :incoming)

    # Trigger event
    Rails.configuration.dispatcher.dispatch(
      Events::Types::MESSAGE_CREATED,
      Time.zone.now,
      message: conversation.messages.last
    )

    # Wait for async processing
    sleep 0.1

    # Verify
    expect(contact.reload.custom_attributes['ai_enabled']).to be true
    expect(conversation.reload.custom_attributes['ai_auto_phrase_checked']).to be true
    expect(conversation.custom_attributes['ai_auto_phrase_passed']).to be true
    expect(conversation.custom_attributes['ai_auto_random_checked']).to be true
  end
end
```

### Performance Tests

**Caching Efficiency:**
```ruby
it 'does not re-evaluate random on subsequent messages' do
  conversation = create(:conversation)
  rule = create_ai_filter_rule

  # First message
  time1 = Benchmark.realtime do
    ConditionsFilterService.new(rule, conversation).perform
  end

  # Second message (should use cache)
  create(:message, conversation: conversation, message_type: :incoming)
  time2 = Benchmark.realtime do
    ConditionsFilterService.new(rule, conversation).perform
  end

  expect(time2).to be < (time1 * 0.5) # At least 50% faster
end
```

---

## Deployment Plan

### Pre-Deployment Checklist

- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Code reviewed
- [ ] Documentation complete
- [ ] i18n translations complete (en + es)
- [ ] No console errors in UI
- [ ] Performance benchmarks acceptable

### Deployment Steps

**Step 1: Database (No Migration Needed)**
- Uses existing JSONB columns
- No schema changes required

**Step 2: Backend Deployment**
```bash
# Deploy backend code
git push production main

# Verify services loaded
bundle exec rails runner "puts AutomationRules::CustomConditions::AgentBotEvaluator"
```

**Step 3: Seed Templates (Optional)**
```bash
# Run template seeds for existing accounts
bundle exec rails runner "
  Account.find_each do |account|
    Seeds::AiFilterTemplates.create_for_account(account)
  end
"
```

**Step 4: Frontend Deployment**
```bash
# Build assets
pnpm build

# Verify i18n loaded
# Check browser console for translation keys
```

**Step 5: Smoke Testing**
- [ ] Create test automation rule
- [ ] Add custom conditions
- [ ] Save and activate
- [ ] Create test conversation
- [ ] Verify `ai_enabled` set correctly
- [ ] Verify caching works (check conversation.custom_attributes)

### Rollback Plan

**If issues occur:**

1. **Disable automation rules** (set active = false)
```ruby
AutomationRule.where("name LIKE '[Template] AI Filters%'").update_all(active: false)
```

2. **No database rollback needed** (no schema changes)

3. **Frontend rollback** (revert constants.js changes)

4. **Backend rollback** (revert code deployment)

---

## Documentation

### User Documentation

**Title**: "Automatically Enable AI for Conversations"

**Content**:

#### What is this feature?

Automatically control when AI is enabled for conversations based on:
- Whether the inbox has an agent-bot
- Keywords in first messages ("start", "help", etc.)
- Random percentage selection

#### How to use:

**Option 1: Use a Template (Recommended)**

1. Go to Settings → Automation
2. Click "Templates" dropdown
3. Select "AI Filters - CTA + Random"
4. Customize phrases and percentage
5. Save

**Option 2: Create from Scratch**

1. Go to Settings → Automation
2. Click "Add Automation"
3. Event: Conversation Created
4. Add Conditions:
   - Inbox has agent-bot = Yes
   - Entry phrase contains [your phrases]
   - Random chance < 60
5. Add Action:
   - Set AI enabled = Enable
6. Save and activate

#### Understanding the conditions:

**Inbox has agent-bot:**
- Checks if channel has an active agent-bot assigned
- Required for AI to work
- Recommended: Always include this condition first

**Entry phrase:**
- Checks first N messages for keywords
- Case-insensitive by default
- Keeps checking until phrase found or limit reached
- Examples: "start", "comprar", "help", "ayuda"

**Random chance:**
- Randomly selects percentage of conversations
- Based on conversation ID (deterministic)
- Same conversation always gets same result
- Example: 60 means 60% of conversations enabled

#### How conditions combine:

ALL conditions must pass (AND logic):
- Has agent-bot: YES
- AND entry phrase found: YES
- AND random passes: YES
= AI enabled: TRUE

### Developer Documentation

**Title**: "AI Filter Automation - Technical Guide"

**Content**:

#### Architecture

Uses existing Chatwoot automation system with:
- 3 custom condition evaluators
- 1 custom action
- Caching in conversation.custom_attributes

#### Custom Conditions

**has_agent_bot**
- Class: `AutomationRules::CustomConditions::AgentBotEvaluator`
- Checks: `inbox.agent_bot_inbox&.active?`
- Cached: Yes (ai_auto_agentbot_*)

**entry_phrase**
- Class: `AutomationRules::CustomConditions::EntryPhraseEvaluator`
- Checks: First N incoming messages for keywords
- Cached: Yes, when found or limit reached (ai_auto_phrase_*)

**random_chance**
- Class: `AutomationRules::CustomConditions::RandomPercentageEvaluator`
- Logic: `Random.new(conversation.id).rand(100) < percentage`
- Cached: Yes (ai_auto_random_*)

#### Custom Action

**set_ai_enabled**
- Class: `AutomationRules::ActionService#set_ai_enabled`
- Sets: `contact.custom_attributes['ai_enabled']`
- Safety: Blocks enabling without agent-bot

#### Caching Strategy

**Purpose**: Avoid re-evaluation on every message

**Flags** (conversation.custom_attributes):
```ruby
{
  'ai_auto_agentbot_checked': true,  # Evaluated?
  'ai_auto_agentbot_passed': true,   # Result

  'ai_auto_random_checked': true,
  'ai_auto_random_passed': false,

  'ai_auto_phrase_checked': false,   # Not yet found
  'ai_auto_phrase_passed': false
}
```

**Logic**:
- If `_checked = true`, use cached result
- If `_checked = false`, evaluate and cache
- Phrase: Only cache when found or limit reached

#### Adding New Conditions

1. Create evaluator in `app/services/automation_rules/custom_conditions/`
2. Add to `filter_keys.yml`
3. Add caching logic to `ConditionsFilterService`
4. Add to frontend `constants.js`
5. Add i18n translations

#### Testing

Run tests:
```bash
bundle exec rspec spec/services/automation_rules/custom_conditions/
bundle exec rspec spec/integration/ai_filter_automation_spec.rb
```

---

## Appendix

### A. File Checklist

**New Files (5):**
- [ ] `app/services/automation_rules/custom_conditions/agent_bot_evaluator.rb`
- [ ] `app/services/automation_rules/custom_conditions/random_percentage_evaluator.rb`
- [ ] `app/services/automation_rules/custom_conditions/entry_phrase_evaluator.rb`
- [ ] `spec/services/automation_rules/custom_conditions/agent_bot_evaluator_spec.rb`
- [ ] `spec/services/automation_rules/custom_conditions/random_percentage_evaluator_spec.rb`
- [ ] `spec/services/automation_rules/custom_conditions/entry_phrase_evaluator_spec.rb`
- [ ] `db/seeds/ai_filter_templates.rb`
- [ ] `spec/integration/ai_filter_automation_spec.rb`

**Modified Files (6):**
- [ ] `app/services/automation_rules/conditions_filter_service.rb`
- [ ] `app/services/automation_rules/action_service.rb`
- [ ] `lib/filters/filter_keys.yml`
- [ ] `app/javascript/dashboard/routes/dashboard/settings/automation/constants.js`
- [ ] `app/javascript/dashboard/i18n/locale/en.json`
- [ ] `app/javascript/dashboard/i18n/locale/es.json`

**Total: 14 files**

### B. Data Dictionary

**conversation.custom_attributes:**
| Key | Type | Description |
|-----|------|-------------|
| `ai_auto_agentbot_checked` | Boolean | Has agent-bot condition been evaluated? |
| `ai_auto_agentbot_passed` | Boolean | Did agent-bot condition pass? |
| `ai_auto_random_checked` | Boolean | Has random condition been evaluated? |
| `ai_auto_random_passed` | Boolean | Did random condition pass? |
| `ai_auto_phrase_checked` | Boolean | Has phrase been found or limit reached? |
| `ai_auto_phrase_passed` | Boolean | Was phrase found? |

**contact.custom_attributes:**
| Key | Type | Description |
|-----|------|-------------|
| `ai_enabled` | Boolean | **SINGLE SOURCE OF TRUTH** - Is AI enabled for this contact? |

### C. Performance Benchmarks

**Target Metrics:**

| Metric | Target | Measurement |
|--------|--------|-------------|
| First evaluation | < 50ms | Benchmark test |
| Cached evaluation | < 5ms | Benchmark test |
| Database writes | 1-2 per decision | Count queries |
| Memory overhead | < 1KB per conversation | Object size |

---

**Document Owner**: Development Team
**Created**: 2025-11-15
**Status**: Ready for Implementation
**Version**: 1.0.0 (Final)
**Estimated Effort**: 8-10 days
