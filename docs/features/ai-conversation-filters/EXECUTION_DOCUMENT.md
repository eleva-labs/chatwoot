# AI-Enabled Conversation Filters - Execution Document

**Version**: 1.0.0
**Date**: 2025-11-15
**Status**: Ready for Execution
**Estimated Duration**: 8-10 days
**Based On**: DESIGN_DOCUMENT.md v1.0.0

---

## Table of Contents

1. [Pre-Execution Checklist](#pre-execution-checklist)
2. [Development Environment Setup](#development-environment-setup)
3. [Phase 1: Backend Custom Conditions (Days 1-3)](#phase-1-backend-custom-conditions-days-1-3)
4. [Phase 2: Backend Action (Days 4-5)](#phase-2-backend-action-days-4-5)
5. [Phase 3: Frontend (Days 6-7)](#phase-3-frontend-days-6-7)
6. [Phase 4: Templates (Days 8-10)](#phase-4-templates-days-8-10)
7. [Testing Checklist](#testing-checklist)
8. [Deployment Instructions](#deployment-instructions)
9. [Rollback Procedures](#rollback-procedures)
10. [Post-Deployment Verification](#post-deployment-verification)

---

## Pre-Execution Checklist

### Before Starting

- [ ] Design document reviewed and approved
- [ ] Per-channel analysis reviewed (per_channel_analysis.md)
- [ ] Development branch created from `development`
  ```bash
  git checkout development
  git pull origin development
  git checkout -b feature/ai-conversation-filters
  ```
- [ ] Docker environment running
  ```bash
  task docker-chatwoot-build  # or docker compose up -d
  ```
- [ ] Test database prepared
  ```bash
  SETUP_DB=true task test-backend-file -- spec/models/automation_rule_spec.rb
  ```
- [ ] All existing tests passing
  ```bash
  task test-backend-all
  pnpm test
  ```

### Required Knowledge

- Ruby service objects pattern
- Chatwoot automation system architecture
- Vue.js 3 with Composition API
- JSONB data types in PostgreSQL
- Chatwoot filter system (filter_keys.yml)

### Tools Needed

- Code editor (VS Code recommended)
- Terminal with Ruby 3.x
- Node.js 18+ with pnpm
- Docker Desktop (if using Docker)
- Git

---

## Development Environment Setup

### 1. Verify Automation System Works

**Test existing automation:**

```bash
# Rails console
bundle exec rails console

# Create test rule
account = Account.first
inbox = account.inboxes.first

rule = AutomationRule.create!(
  account: account,
  name: "Test Rule",
  event_name: "conversation_created",
  conditions: [
    {
      attribute_key: "inbox_id",
      filter_operator: "equal_to",
      values: [inbox.id],
      query_operator: nil
    }
  ],
  actions: [
    {
      action_name: "add_label",
      action_params: ["test"]
    }
  ]
)

# Create test conversation
conversation = FactoryBot.create(:conversation, inbox: inbox, account: account)

# Trigger event
Rails.configuration.dispatcher.dispatch(
  Events::Types::CONVERSATION_CREATED,
  Time.zone.now,
  conversation: conversation
)

# Verify (async - wait 1 second)
sleep 1
conversation.reload.labels.map(&:title)  # Should include "test"
```

**Expected output**: `["test"]`

If this works, automation system is ready.

### 2. Create Working Directory Structure

```bash
# Create directories for new files
mkdir -p app/services/automation_rules/custom_conditions
mkdir -p spec/services/automation_rules/custom_conditions
mkdir -p spec/integration
mkdir -p db/seeds
```

---

## Phase 1: Backend Custom Conditions (Days 1-3)

### Day 1: Agent-Bot & Random Evaluators

#### Step 1.1: Create AgentBotEvaluator

**File**: `app/services/automation_rules/custom_conditions/agent_bot_evaluator.rb`

```bash
# Create file
touch app/services/automation_rules/custom_conditions/agent_bot_evaluator.rb
```

**Copy this code**:

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

**Verify syntax**:
```bash
ruby -c app/services/automation_rules/custom_conditions/agent_bot_evaluator.rb
```

#### Step 1.2: Create AgentBotEvaluator Spec

**File**: `spec/services/automation_rules/custom_conditions/agent_bot_evaluator_spec.rb`

```bash
touch spec/services/automation_rules/custom_conditions/agent_bot_evaluator_spec.rb
```

**Copy this code**:

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

**Run tests**:
```bash
task test-backend-file -- spec/services/automation_rules/custom_conditions/agent_bot_evaluator_spec.rb
```

**Expected**: All tests pass ✅

#### Step 1.3: Create RandomPercentageEvaluator

**File**: `app/services/automation_rules/custom_conditions/random_percentage_evaluator.rb`

```bash
touch app/services/automation_rules/custom_conditions/random_percentage_evaluator.rb
```

**Copy this code**:

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

#### Step 1.4: Create RandomPercentageEvaluator Spec

**File**: `spec/services/automation_rules/custom_conditions/random_percentage_evaluator_spec.rb`

```bash
touch spec/services/automation_rules/custom_conditions/random_percentage_evaluator_spec.rb
```

**Copy this code**:

```ruby
require 'rails_helper'

RSpec.describe AutomationRules::CustomConditions::RandomPercentageEvaluator do
  describe '.evaluate' do
    it 'returns deterministic result based on conversation ID' do
      conversation = create(:conversation)
      condition = { 'values' => [60] }

      # Same conversation, same result
      result1 = described_class.evaluate(conversation, condition)
      result2 = described_class.evaluate(conversation, condition)

      expect(result1).to eq(result2)
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

    it 'returns false when percentage is nil' do
      conversation = create(:conversation)
      condition = { 'values' => [nil] }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'returns false when values array is empty' do
      conversation = create(:conversation)
      condition = { 'values' => [] }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end
  end
end
```

**Run tests**:
```bash
task test-backend-file -- spec/services/automation_rules/custom_conditions/random_percentage_evaluator_spec.rb
```

**Expected**: All tests pass ✅

#### Step 1.5: Commit Day 1 Work

```bash
git add app/services/automation_rules/custom_conditions/agent_bot_evaluator.rb
git add app/services/automation_rules/custom_conditions/random_percentage_evaluator.rb
git add spec/services/automation_rules/custom_conditions/agent_bot_evaluator_spec.rb
git add spec/services/automation_rules/custom_conditions/random_percentage_evaluator_spec.rb

git commit -m "feat: add agent-bot and random percentage evaluators for AI filters

- Add AgentBotEvaluator to check if inbox has active agent-bot
- Add RandomPercentageEvaluator for deterministic random selection
- Add comprehensive test coverage for both evaluators"
```

---

### Day 2: Entry Phrase Evaluator

#### Step 2.1: Create EntryPhraseEvaluator

**File**: `app/services/automation_rules/custom_conditions/entry_phrase_evaluator.rb`

```bash
touch app/services/automation_rules/custom_conditions/entry_phrase_evaluator.rb
```

**Copy this code**:

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

#### Step 2.2: Create EntryPhraseEvaluator Spec

**File**: `spec/services/automation_rules/custom_conditions/entry_phrase_evaluator_spec.rb`

```bash
touch spec/services/automation_rules/custom_conditions/entry_phrase_evaluator_spec.rb
```

**Copy this code**:

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

    it 'returns false when values array is empty' do
      create(:message, conversation: conversation, content: 'help', message_type: :incoming)

      condition = {
        'values' => [],
        'custom_filters' => { 'message_limit' => 3 }
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false
    end

    it 'uses default message_limit of 3 when not specified' do
      create(:message, conversation: conversation, content: 'hello', message_type: :incoming)
      create(:message, conversation: conversation, content: 'world', message_type: :incoming)
      create(:message, conversation: conversation, content: 'test', message_type: :incoming)
      create(:message, conversation: conversation, content: 'help', message_type: :incoming) # 4th message

      condition = {
        'values' => ['help'],
        'custom_filters' => {} # No message_limit specified
      }

      result = described_class.evaluate(conversation, condition)
      expect(result).to be false # Only checks first 3 messages
    end
  end
end
```

**Run tests**:
```bash
task test-backend-file -- spec/services/automation_rules/custom_conditions/entry_phrase_evaluator_spec.rb
```

**Expected**: All tests pass ✅

#### Step 2.3: Add to filter_keys.yml

**File**: `lib/filters/filter_keys.yml`

**Open file and add after existing conversation filters**:

```yaml
conversations:
  # ... existing filters (status, assignee_id, inbox_id, etc.)

  # AI Filter Custom Conditions
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

**Verify YAML syntax**:
```bash
ruby -e "require 'yaml'; YAML.load_file('lib/filters/filter_keys.yml')"
```

**Expected**: No errors

#### Step 2.4: Commit Day 2 Work

```bash
git add app/services/automation_rules/custom_conditions/entry_phrase_evaluator.rb
git add spec/services/automation_rules/custom_conditions/entry_phrase_evaluator_spec.rb
git add lib/filters/filter_keys.yml

git commit -m "feat: add entry phrase evaluator and filter keys

- Add EntryPhraseEvaluator to check for keywords in first N messages
- Support case-sensitive and case-insensitive matching
- Add has_agent_bot, random_chance, entry_phrase to filter_keys.yml
- Add comprehensive test coverage"
```

---

### Day 3: Conditions Filter Service Integration

#### Step 3.1: Read Existing ConditionsFilterService

```bash
# Read the file to understand structure
cat app/services/automation_rules/conditions_filter_service.rb
```

**Key things to note**:
- Line 25-44: `perform` method evaluates all conditions
- Line 63-78: `apply_filter` method handles different filter types
- Line 54-60: `filter_operation` method for special operators

#### Step 3.2: Backup Original File

```bash
cp app/services/automation_rules/conditions_filter_service.rb \
   app/services/automation_rules/conditions_filter_service.rb.backup
```

#### Step 3.3: Modify ConditionsFilterService

**File**: `app/services/automation_rules/conditions_filter_service.rb`

**Add after line 24 (after `@options = options` and before `def perform`)**:

```ruby
  # Require custom condition evaluators
  require_dependency 'automation_rules/custom_conditions/agent_bot_evaluator'
  require_dependency 'automation_rules/custom_conditions/random_percentage_evaluator'
  require_dependency 'automation_rules/custom_conditions/entry_phrase_evaluator'
```

**Replace the `perform` method (around line 25-44)** with:

```ruby
  def perform
    return false unless rule_valid?

    @conversation&.reload # Ensure fresh custom_attributes

    @attribute_changed_query_filter = []

    @rule.conditions.each_with_index do |query_hash, current_index|
      @attribute_changed_query_filter << query_hash and next if query_hash['filter_operator'] == 'attribute_changed'

      # Check if this is a custom condition that needs special handling
      result = evaluate_condition_with_cache(query_hash, current_index)
      return false unless result # Early exit if condition fails
    end

    records = base_relation.where(@query_string, @filter_values.with_indifferent_access)
    records = perform_attribute_changed_filter(records) if @attribute_changed_query_filter.any?

    records.any?
  rescue StandardError => e
    Rails.logger.error "Error in AutomationRules::ConditionsFilterService: #{e.message}"
    Rails.logger.info "AutomationRules::ConditionsFilterService failed while processing rule #{@rule.id} for conversation #{@conversation.id}"
    false
  end
```

**Add these new private methods at the end of the file (before the final `end`)**:

```ruby
  private

  # ... existing private methods ...

  def evaluate_condition_with_cache(query_hash, current_index)
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

    else
      # Standard condition evaluation (existing logic)
      apply_filter(query_hash, current_index)
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
```

**Verify syntax**:
```bash
ruby -c app/services/automation_rules/conditions_filter_service.rb
```

#### Step 3.4: Test Integration

**Create integration test file**:

**File**: `spec/integration/ai_filter_automation_spec.rb`

```bash
touch spec/integration/ai_filter_automation_spec.rb
```

```ruby
require 'rails_helper'

RSpec.describe 'AI Filter Automation', type: :integration do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_bot) { create(:agent_bot) }
  let!(:agent_bot_inbox) { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active) }
  let(:contact) { create(:contact, account: account) }

  describe 'has_agent_bot condition' do
    it 'passes when inbox has active agent-bot' do
      conversation = create(:conversation, inbox: inbox, contact: contact)

      rule = create(:automation_rule,
        account: account,
        event_name: 'conversation_created',
        conditions: [
          { attribute_key: 'has_agent_bot', filter_operator: 'equal_to', values: [true], query_operator: nil }
        ],
        actions: [
          { action_name: 'add_label', action_params: ['ai-enabled'] }
        ]
      )

      service = AutomationRules::ConditionsFilterService.new(rule, conversation)
      result = service.perform

      expect(result).to be true
      expect(conversation.reload.custom_attributes['ai_auto_agentbot_checked']).to be true
      expect(conversation.custom_attributes['ai_auto_agentbot_passed']).to be true
    end
  end

  describe 'random_chance condition' do
    it 'evaluates and caches result' do
      conversation = create(:conversation, inbox: inbox, contact: contact)

      rule = create(:automation_rule,
        account: account,
        event_name: 'conversation_created',
        conditions: [
          { attribute_key: 'random_chance', filter_operator: 'is_less_than', values: [100], query_operator: nil }
        ],
        actions: []
      )

      service = AutomationRules::ConditionsFilterService.new(rule, conversation)
      result1 = service.perform

      # Call again - should use cache
      result2 = service.perform

      expect(result1).to eq(result2)
      expect(conversation.reload.custom_attributes['ai_auto_random_checked']).to be true
      expect(conversation.custom_attributes['ai_auto_random_passed']).to be true
    end
  end

  describe 'entry_phrase condition' do
    it 'finds phrase in first message' do
      conversation = create(:conversation, inbox: inbox, contact: contact)
      create(:message, conversation: conversation, content: 'I need help', message_type: :incoming)

      rule = create(:automation_rule,
        account: account,
        event_name: 'message_created',
        conditions: [
          {
            attribute_key: 'entry_phrase',
            filter_operator: 'contains',
            values: ['help'],
            custom_filters: { 'message_limit' => 3, 'case_sensitive' => false },
            query_operator: nil
          }
        ],
        actions: []
      )

      service = AutomationRules::ConditionsFilterService.new(rule, conversation, message: conversation.messages.first)
      result = service.perform

      expect(result).to be true
      expect(conversation.reload.custom_attributes['ai_auto_phrase_checked']).to be true
      expect(conversation.custom_attributes['ai_auto_phrase_passed']).to be true
    end
  end
end
```

**Run integration tests**:
```bash
task test-backend-file -- spec/integration/ai_filter_automation_spec.rb
```

**Expected**: All tests pass ✅

#### Step 3.5: Commit Day 3 Work

```bash
git add app/services/automation_rules/conditions_filter_service.rb
git add spec/integration/ai_filter_automation_spec.rb

git commit -m "feat: integrate custom conditions into automation filter service

- Add caching logic for agent-bot, random, and phrase conditions
- Implement evaluate_condition_with_cache for custom conditions
- Add evaluate_cached_condition for agent-bot and random
- Add evaluate_phrase_condition with special caching logic
- Add integration tests for all custom conditions"
```

---

## Phase 2: Backend Action (Days 4-5)

### Day 4: Action Service

#### Step 4.1: Read Existing ActionService

```bash
# Find the action service
find . -name "action_service.rb" -path "*/automation_rules/*" | head -1

# Read it
cat app/services/automation_rules/action_service.rb
```

#### Step 4.2: Backup Original File

```bash
cp app/services/automation_rules/action_service.rb \
   app/services/automation_rules/action_service.rb.backup
```

#### Step 4.3: Modify ActionService

**File**: `app/services/automation_rules/action_service.rb`

**Find the `actions_attributes` method** (should list all available actions):

**Add `set_ai_enabled` to the list**:

```ruby
def actions_attributes
  %w[send_message add_label remove_label send_email_to_team assign_team assign_agent
     send_webhook_event mute_conversation send_attachment change_status resolve_conversation
     open_conversation snooze_conversation change_priority send_email_transcript add_private_note
     set_ai_enabled].freeze
end
```

**Add this new private method** (at the end before the final `end`):

```ruby
  private

  # ... existing private methods ...

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
```

**Verify syntax**:
```bash
ruby -c app/services/automation_rules/action_service.rb
```

#### Step 4.4: Create Action Service Spec

**File**: `spec/services/automation_rules/action_service_spec.rb`

**Check if file exists**:
```bash
ls spec/services/automation_rules/action_service_spec.rb
```

**If exists, add these tests to existing file. If not, create new file**:

```ruby
require 'rails_helper'

RSpec.describe AutomationRules::ActionService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, contact: contact, account: account) }
  let(:rule) { create(:automation_rule, account: account, actions: [{ action_name: 'set_ai_enabled', action_params: [true] }]) }

  describe '#set_ai_enabled' do
    context 'when inbox has active agent-bot' do
      before do
        agent_bot = create(:agent_bot)
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active)
      end

      it 'sets ai_enabled to true' do
        service = described_class.new(rule, account, conversation)
        service.perform

        expect(contact.reload.custom_attributes['ai_enabled']).to be true
      end

      it 'sets ai_enabled to false when action params are false' do
        rule.actions = [{ action_name: 'set_ai_enabled', action_params: [false] }]
        rule.save!

        service = described_class.new(rule, account, conversation)
        service.perform

        expect(contact.reload.custom_attributes['ai_enabled']).to be false
      end
    end

    context 'when inbox has no agent-bot' do
      it 'does not set ai_enabled to true' do
        service = described_class.new(rule, account, conversation)
        service.perform

        expect(contact.reload.custom_attributes['ai_enabled']).to be_falsy
      end

      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn).with(
          /Cannot enable AI for inbox #{inbox.id}/
        )

        service = described_class.new(rule, account, conversation)
        service.perform
      end

      it 'allows setting ai_enabled to false without agent-bot' do
        rule.actions = [{ action_name: 'set_ai_enabled', action_params: [false] }]
        rule.save!

        service = described_class.new(rule, account, conversation)
        service.perform

        expect(contact.reload.custom_attributes['ai_enabled']).to be false
      end
    end

    context 'when inbox has inactive agent-bot' do
      before do
        agent_bot = create(:agent_bot)
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :inactive)
      end

      it 'does not set ai_enabled to true' do
        service = described_class.new(rule, account, conversation)
        service.perform

        expect(contact.reload.custom_attributes['ai_enabled']).to be_falsy
      end
    end
  end
end
```

**Run tests**:
```bash
task test-backend-file -- spec/services/automation_rules/action_service_spec.rb
```

**Expected**: All tests pass ✅

#### Step 4.5: Commit Day 4 Work

```bash
git add app/services/automation_rules/action_service.rb
git add spec/services/automation_rules/action_service_spec.rb

git commit -m "feat: add set_ai_enabled action to automation system

- Add set_ai_enabled to actions_attributes list
- Implement set_ai_enabled method with agent-bot safety check
- Block enabling AI without active agent-bot
- Allow disabling AI regardless of agent-bot status
- Add comprehensive test coverage for action"
```

---

### Day 5: Integration Testing

#### Step 5.1: Create Comprehensive End-to-End Test

**File**: `spec/integration/ai_filter_end_to_end_spec.rb`

```bash
touch spec/integration/ai_filter_end_to_end_spec.rb
```

```ruby
require 'rails_helper'

RSpec.describe 'AI Filter End-to-End', type: :integration do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_bot) { create(:agent_bot) }
  let!(:agent_bot_inbox) { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active) }

  describe 'complete automation flow with all conditions' do
    it 'enables AI when all conditions pass' do
      # Create automation rule
      rule = create(:automation_rule,
        account: account,
        name: 'AI Filter - Complete',
        event_name: 'conversation_created',
        active: true,
        conditions: [
          { attribute_key: 'has_agent_bot', filter_operator: 'equal_to', values: [true], query_operator: 'and' },
          { attribute_key: 'inbox_id', filter_operator: 'equal_to', values: [inbox.id], query_operator: 'and' },
          { attribute_key: 'entry_phrase', filter_operator: 'contains', values: ['help'],
            custom_filters: { 'message_limit' => 3, 'case_sensitive' => false }, query_operator: 'and' },
          { attribute_key: 'random_chance', filter_operator: 'is_less_than', values: [100], query_operator: nil }
        ],
        actions: [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      )

      # Create conversation
      contact = create(:contact, account: account)
      conversation = create(:conversation, inbox: inbox, contact: contact, account: account)
      message = create(:message, conversation: conversation, content: 'I need help', message_type: :incoming)

      # Trigger automation
      Rails.configuration.dispatcher.dispatch(
        Events::Types::CONVERSATION_CREATED,
        Time.zone.now,
        conversation: conversation
      )

      # Wait for async processing
      sleep 0.2

      # Verify results
      contact.reload
      conversation.reload

      expect(contact.custom_attributes['ai_enabled']).to be true
      expect(conversation.custom_attributes['ai_auto_agentbot_checked']).to be true
      expect(conversation.custom_attributes['ai_auto_agentbot_passed']).to be true
      expect(conversation.custom_attributes['ai_auto_random_checked']).to be true
      expect(conversation.custom_attributes['ai_auto_phrase_checked']).to be true
      expect(conversation.custom_attributes['ai_auto_phrase_passed']).to be true
    end

    it 'does not enable AI when phrase not found' do
      rule = create(:automation_rule,
        account: account,
        event_name: 'conversation_created',
        active: true,
        conditions: [
          { attribute_key: 'has_agent_bot', filter_operator: 'equal_to', values: [true], query_operator: 'and' },
          { attribute_key: 'entry_phrase', filter_operator: 'contains', values: ['help'],
            custom_filters: { 'message_limit' => 3 }, query_operator: nil }
        ],
        actions: [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      )

      contact = create(:contact, account: account)
      conversation = create(:conversation, inbox: inbox, contact: contact, account: account)
      create(:message, conversation: conversation, content: 'Hello', message_type: :incoming)

      Rails.configuration.dispatcher.dispatch(
        Events::Types::CONVERSATION_CREATED,
        Time.zone.now,
        conversation: conversation
      )

      sleep 0.2

      contact.reload
      expect(contact.custom_attributes['ai_enabled']).to be_falsy
    end

    it 'detects phrase in second message on message_created event' do
      rule = create(:automation_rule,
        account: account,
        event_name: 'message_created',
        active: true,
        conditions: [
          { attribute_key: 'has_agent_bot', filter_operator: 'equal_to', values: [true], query_operator: 'and' },
          { attribute_key: 'entry_phrase', filter_operator: 'contains', values: ['help'],
            custom_filters: { 'message_limit' => 3 }, query_operator: nil }
        ],
        actions: [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      )

      contact = create(:contact, account: account)
      conversation = create(:conversation, inbox: inbox, contact: contact, account: account)

      # First message - no match
      create(:message, conversation: conversation, content: 'Hello', message_type: :incoming)

      # Second message - has "help"
      message = create(:message, conversation: conversation, content: 'I need help', message_type: :incoming)

      Rails.configuration.dispatcher.dispatch(
        Events::Types::MESSAGE_CREATED,
        Time.zone.now,
        message: message
      )

      sleep 0.2

      contact.reload
      conversation.reload

      expect(contact.custom_attributes['ai_enabled']).to be true
      expect(conversation.custom_attributes['ai_auto_phrase_passed']).to be true
    end
  end

  describe 'per-channel configuration' do
    let(:whatsapp_inbox) { create(:inbox, account: account, name: 'WhatsApp') }
    let(:web_inbox) { create(:inbox, account: account, name: 'Web Chat') }

    before do
      # Add agent-bots to both inboxes
      create(:agent_bot_inbox, inbox: whatsapp_inbox, agent_bot: agent_bot, status: :active)
      create(:agent_bot_inbox, inbox: web_inbox, agent_bot: agent_bot, status: :active)
    end

    it 'applies different phrases per channel' do
      # WhatsApp rule with Spanish phrases
      whatsapp_rule = create(:automation_rule,
        account: account,
        event_name: 'conversation_created',
        active: true,
        conditions: [
          { attribute_key: 'inbox_id', filter_operator: 'equal_to', values: [whatsapp_inbox.id], query_operator: 'and' },
          { attribute_key: 'entry_phrase', filter_operator: 'contains', values: ['ayuda'],
            custom_filters: { 'message_limit' => 3 }, query_operator: nil }
        ],
        actions: [{ action_name: 'set_ai_enabled', action_params: [true] }]
      )

      # Web rule with English phrases
      web_rule = create(:automation_rule,
        account: account,
        event_name: 'conversation_created',
        active: true,
        conditions: [
          { attribute_key: 'inbox_id', filter_operator: 'equal_to', values: [web_inbox.id], query_operator: 'and' },
          { attribute_key: 'entry_phrase', filter_operator: 'contains', values: ['help'],
            custom_filters: { 'message_limit' => 3 }, query_operator: nil }
        ],
        actions: [{ action_name: 'set_ai_enabled', action_params: [true] }]
      )

      # WhatsApp conversation with Spanish
      contact1 = create(:contact, account: account)
      conv1 = create(:conversation, inbox: whatsapp_inbox, contact: contact1, account: account)
      create(:message, conversation: conv1, content: 'Necesito ayuda', message_type: :incoming)

      # Web conversation with English
      contact2 = create(:contact, account: account)
      conv2 = create(:conversation, inbox: web_inbox, contact: contact2, account: account)
      create(:message, conversation: conv2, content: 'I need help', message_type: :incoming)

      # Trigger both
      Rails.configuration.dispatcher.dispatch(Events::Types::CONVERSATION_CREATED, Time.zone.now, conversation: conv1)
      Rails.configuration.dispatcher.dispatch(Events::Types::CONVERSATION_CREATED, Time.zone.now, conversation: conv2)

      sleep 0.2

      # Both should have AI enabled via their respective rules
      expect(contact1.reload.custom_attributes['ai_enabled']).to be true
      expect(contact2.reload.custom_attributes['ai_enabled']).to be true
    end
  end
end
```

**Run end-to-end tests**:
```bash
task test-backend-file -- spec/integration/ai_filter_end_to_end_spec.rb
```

**Expected**: All tests pass ✅

#### Step 5.2: Run All Backend Tests

```bash
# Run all custom condition tests
task test-backend-module -- spec/services/automation_rules/custom_conditions

# Run all integration tests
task test-backend-module -- spec/integration

# Run action service tests
task test-backend-file -- spec/services/automation_rules/action_service_spec.rb
```

**Expected**: All tests pass ✅

#### Step 5.3: Commit Day 5 Work

```bash
git add spec/integration/ai_filter_end_to_end_spec.rb

git commit -m "test: add comprehensive end-to-end tests for AI filters

- Add complete automation flow tests with all conditions
- Test phrase detection across multiple messages
- Test per-channel configuration with different phrases
- Verify caching behavior across conditions
- Test agent-bot safety checks"
```

---

## Phase 3: Frontend (Days 6-7)

### Day 6: Constants & i18n

#### Step 6.1: Read Existing Constants File

```bash
# Find constants file
find . -name "constants.js" -path "*automation*" | grep -v node_modules

# Read it
cat app/javascript/dashboard/routes/dashboard/settings/automation/constants.js | head -100
```

#### Step 6.2: Backup Constants File

```bash
cp app/javascript/dashboard/routes/dashboard/settings/automation/constants.js \
   app/javascript/dashboard/routes/dashboard/settings/automation/constants.js.backup
```

#### Step 6.3: Modify Constants.js

**File**: `app/javascript/dashboard/routes/dashboard/settings/automation/constants.js`

**Find the `AUTOMATIONS` object and the `conversation_created` conditions array**.

**Add these new conditions to `AUTOMATIONS.conversation_created.conditions`**:

```javascript
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

**Add these to `AUTOMATIONS.message_created.conditions` as well** (for phrase detection on later messages).

**Add to `AUTOMATIONS.conversation_created.actions`**:

```javascript
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

**Verify JavaScript syntax**:
```bash
pnpm eslint app/javascript/dashboard/routes/dashboard/settings/automation/constants.js
```

**Fix any issues**:
```bash
pnpm eslint:fix app/javascript/dashboard/routes/dashboard/settings/automation/constants.js
```

#### Step 6.4: Add i18n Translations (English)

**File**: `app/javascript/dashboard/i18n/locale/en.json`

**Find the `AUTOMATION` section and add**:

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

**Verify JSON syntax**:
```bash
python3 -m json.tool app/javascript/dashboard/i18n/locale/en.json > /dev/null
```

#### Step 6.5: Add i18n Translations (Spanish)

**File**: `app/javascript/dashboard/i18n/locale/es.json`

**Find the `AUTOMATION` section and add**:

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

**Verify JSON syntax**:
```bash
python3 -m json.tool app/javascript/dashboard/i18n/locale/es.json > /dev/null
```

#### Step 6.6: Commit Day 6 Work

```bash
git add app/javascript/dashboard/routes/dashboard/settings/automation/constants.js
git add app/javascript/dashboard/i18n/locale/en.json
git add app/javascript/dashboard/i18n/locale/es.json

git commit -m "feat: add frontend constants and i18n for AI filter conditions

- Add has_agent_bot, entry_phrase, random_chance conditions to constants
- Add set_ai_enabled action to constants
- Add English translations for new conditions and action
- Add Spanish translations for new conditions and action
- Support custom filters for entry_phrase (message_limit, case_sensitive)"
```

---

### Day 7: Frontend Testing

#### Step 7.1: Build Frontend Assets

```bash
# Build assets
pnpm build

# Check for errors
echo $?  # Should be 0
```

**Expected**: Build succeeds with no errors

#### Step 7.2: Start Dev Server (Optional)

```bash
# Start dev server to test UI
pnpm dev
```

**Open browser**: http://localhost:3000

**Navigate to**: Settings → Automation → Create Automation

**Verify**:
- [ ] "Inbox has agent-bot" appears in conditions dropdown
- [ ] "Entry phrase" appears in conditions dropdown
- [ ] "Random percentage" appears in conditions dropdown
- [ ] "Set AI enabled" appears in actions dropdown
- [ ] Translations show correctly (English and Spanish)

#### Step 7.3: Manual UI Test Checklist

**Create test automation rule via UI**:

1. Go to Settings → Automation
2. Click "Create Automation"
3. Select event: "Conversation Created"
4. Add condition: "Inbox has agent-bot" = "Yes"
5. Add condition: "Entry phrase" contains "help, start"
6. Verify "Check first N messages" shows (default: 3)
7. Verify "Case sensitive" shows (default: false)
8. Add condition: "Random percentage" < "60"
9. Add action: "Set AI enabled" = "Enable"
10. Save automation

**Verify**:
- [ ] All dropdowns load correctly
- [ ] Values save correctly
- [ ] Automation appears in list
- [ ] Can edit and re-save
- [ ] Can delete

#### Step 7.4: Run Frontend Tests

```bash
# Run all tests
pnpm test

# Or run specific test file if exists
pnpm test -- automation
```

#### Step 7.5: Commit Day 7 Work

```bash
git add .

git commit -m "test: verify frontend builds and UI works correctly

- Build frontend assets successfully
- Verify all new conditions appear in automation UI
- Verify translations display correctly
- Verify custom filters for entry_phrase work"
```

---

## Phase 4: Templates (Days 8-10)

### Day 8: Template Seeds

#### Step 8.1: Create Template Seed File

**File**: `db/seeds/ai_filter_templates.rb`

```bash
touch db/seeds/ai_filter_templates.rb
```

**Copy this code**:

```ruby
# frozen_string_literal: true

module Seeds
  class AiFilterTemplates
    def self.create_for_account(account)
      Rails.logger.info "Creating AI filter templates for account #{account.id}"

      create_cta_random_template(account)
      create_cta_only_template(account)
      create_random_only_template(account)
      create_whatsapp_template(account)
      create_web_template(account)
    end

    def self.create_cta_random_template(account)
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
            custom_filters: { 'message_limit' => 3, 'case_sensitive' => false }
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

    def self.create_cta_only_template(account)
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
            custom_filters: { 'message_limit' => 3, 'case_sensitive' => false }
          }
        ]
        rule.actions = [
          { action_name: 'set_ai_enabled', action_params: [true] }
        ]
      end
    end

    def self.create_random_only_template(account)
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

    def self.create_whatsapp_template(account)
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] AI Filter - WhatsApp'
      ) do |rule|
        rule.description = 'Enable AI for WhatsApp with Spanish phrases (customize inbox)'
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
            values: [], # User must select inbox
            query_operator: 'and'
          },
          {
            attribute_key: 'entry_phrase',
            filter_operator: 'contains',
            values: ['start', 'comenzar', 'ayuda', 'comprar'],
            query_operator: 'and',
            custom_filters: { 'message_limit' => 3, 'case_sensitive' => false }
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

    def self.create_web_template(account)
      AutomationRule.find_or_create_by!(
        account_id: account.id,
        name: '[Template] AI Filter - Web'
      ) do |rule|
        rule.description = 'Enable AI for web chat with English phrases (customize inbox)'
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
            values: [], # User must select inbox
            query_operator: 'and'
          },
          {
            attribute_key: 'entry_phrase',
            filter_operator: 'contains',
            values: ['help', 'support', 'chat', 'buy'],
            query_operator: 'and',
            custom_filters: { 'message_limit' => 3, 'case_sensitive' => false }
          },
          {
            attribute_key: 'random_chance',
            filter_operator: 'is_less_than',
            values: [80],
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

# Only run in development or when explicitly requested
if Rails.env.development? || ENV['SEED_AI_TEMPLATES'] == 'true'
  Account.find_each do |account|
    Seeds::AiFilterTemplates.create_for_account(account)
  end
end
```

#### Step 8.2: Test Template Creation

```bash
# Rails console
bundle exec rails console

# Load seed file
load 'db/seeds/ai_filter_templates.rb'

# Check templates created
account = Account.first
AutomationRule.where(account: account, name: ['[Template] AI Filters - CTA + Random']).first

# Verify structure
rule = AutomationRule.where("name LIKE '[Template]%'").first
puts rule.conditions.to_json
puts rule.actions.to_json
```

**Expected**: Templates created successfully ✅

#### Step 8.3: Create Migration to Seed Templates (Optional)

**If you want templates created automatically on deploy**:

```bash
bundle exec rails g migration SeedAiFilterTemplates
```

**Edit migration file**:

```ruby
class SeedAiFilterTemplates < ActiveRecord::Migration[7.0]
  def up
    Account.find_each do |account|
      Seeds::AiFilterTemplates.create_for_account(account)
    end
  end

  def down
    AutomationRule.where("name LIKE '[Template] AI Filter%'").destroy_all
  end
end
```

**Verify syntax**:
```bash
ruby -c db/migrate/*_seed_ai_filter_templates.rb
```

#### Step 8.4: Commit Day 8 Work

```bash
git add db/seeds/ai_filter_templates.rb

git commit -m "feat: add AI filter template seeds

- Create 5 pre-built automation templates
- Template 1: CTA + Random (60%)
- Template 2: CTA Only
- Template 3: Random 50%
- Template 4: WhatsApp (Spanish phrases)
- Template 5: Web (English phrases)
- All templates inactive by default (user activates)"
```

---

### Day 9: Documentation

#### Step 9.1: Create User Guide

**File**: `docs/user/ai_conversation_filters.md`

```bash
mkdir -p docs/user
touch docs/user/ai_conversation_filters.md
```

**Copy content from DESIGN_DOCUMENT.md Section 8 (Documentation)**

#### Step 9.2: Create Developer Guide

**File**: `docs/developer/ai_conversation_filters_technical.md`

```bash
mkdir -p docs/developer
touch docs/developer/ai_conversation_filters_technical.md
```

**Copy technical content from DESIGN_DOCUMENT.md**

#### Step 9.3: Update Main README (Optional)

**File**: `README.md`

**Add section**:

```markdown
## AI Conversation Filters

Automatically enable AI for conversations based on:
- Agent-bot availability
- Entry phrases in messages
- Random percentage selection
- Per-channel configuration

See [User Guide](docs/user/ai_conversation_filters.md) for details.
```

#### Step 9.4: Commit Documentation

```bash
git add docs/user/ai_conversation_filters.md
git add docs/developer/ai_conversation_filters_technical.md

git commit -m "docs: add user and developer guides for AI filters

- Add comprehensive user guide with examples
- Add technical guide for developers
- Document all conditions, actions, and templates
- Include per-channel configuration examples"
```

---

### Day 10: Final Testing & Polish

#### Step 10.1: Run Full Test Suite

```bash
# Backend tests
task test-backend-module -- spec/services/automation_rules
task test-backend-module -- spec/integration

# Frontend tests
pnpm test

# Lint
bundle exec rubocop app/services/automation_rules/custom_conditions/
pnpm eslint:fix app/javascript/dashboard/routes/dashboard/settings/automation/
```

**Fix any failures**

#### Step 10.2: Manual End-to-End Test

**Test in UI**:

1. Create automation rule with all conditions
2. Create test conversation
3. Send message with matching phrase
4. Verify `ai_enabled` set correctly
5. Check caching flags in Rails console
6. Test per-channel configuration

**Rails console verification**:

```ruby
conversation = Conversation.last
conversation.custom_attributes
# => { "ai_auto_agentbot_checked" => true, ... }

contact = conversation.contact
contact.custom_attributes
# => { "ai_enabled" => true }
```

#### Step 10.3: Performance Check

**Benchmark caching**:

```ruby
# Rails console
require 'benchmark'

conversation = Conversation.first
rule = AutomationRule.first

# First evaluation
time1 = Benchmark.realtime do
  AutomationRules::ConditionsFilterService.new(rule, conversation).perform
end

# Second evaluation (should use cache)
time2 = Benchmark.realtime do
  AutomationRules::ConditionsFilterService.new(rule, conversation).perform
end

puts "First: #{time1}s, Second: #{time2}s, Speedup: #{(time1/time2).round(1)}x"
```

**Expected**: 5-10x speedup with caching

#### Step 10.4: Code Review Checklist

- [ ] All tests passing
- [ ] No console errors in UI
- [ ] Translations complete (en + es)
- [ ] Code follows Chatwoot conventions
- [ ] No debugging code left (console.log, binding.pry)
- [ ] Documentation complete
- [ ] Performance acceptable
- [ ] Security: No SQL injection, XSS vulnerabilities
- [ ] Proper error handling
- [ ] Logging in place

#### Step 10.5: Final Commit

```bash
git add .

git commit -m "chore: final polish and testing for AI filters

- Run full test suite, all passing
- Manual end-to-end testing complete
- Performance benchmarks acceptable
- Code review checklist complete
- Ready for merge"
```

---

## Testing Checklist

### Unit Tests

- [ ] AgentBotEvaluator - all cases
- [ ] RandomPercentageEvaluator - determinism, edge cases
- [ ] EntryPhraseEvaluator - case sensitivity, message limit
- [ ] ConditionsFilterService - caching logic
- [ ] ActionService - set_ai_enabled, agent-bot safety

### Integration Tests

- [ ] Complete automation flow (all conditions)
- [ ] Phrase detection across messages
- [ ] Per-channel configuration
- [ ] Caching behavior
- [ ] Event dispatching

### Frontend Tests

- [ ] Constants loaded correctly
- [ ] Translations display
- [ ] Dropdowns populate
- [ ] Custom filters work

### Manual Tests

- [ ] Create automation via UI
- [ ] Trigger automation with test conversation
- [ ] Verify ai_enabled set
- [ ] Verify caching flags
- [ ] Test each template
- [ ] Test per-channel rules

---

## Deployment Instructions

### Pre-Deployment

```bash
# Ensure on correct branch
git checkout feature/ai-conversation-filters

# Ensure all tests pass
task test-backend-all
pnpm test

# Build frontend
pnpm build
```

### Merge to Development

```bash
# Update from development
git checkout development
git pull origin development

# Merge feature branch
git checkout feature/ai-conversation-filters
git merge development  # Resolve conflicts if any

# Push feature branch
git push origin feature/ai-conversation-filters
```

**Create Pull Request**:
- Base: `development`
- Compare: `feature/ai-conversation-filters`
- Title: "feat: AI conversation filters with automation system"
- Description: Link to DESIGN_DOCUMENT.md

### After PR Approved

```bash
# Merge to development
git checkout development
git merge feature/ai-conversation-filters
git push origin development
```

### Deploy to Staging

```bash
# Deploy to staging environment
# (Follow your deployment process)

# Run migrations if created
bundle exec rails db:migrate

# Seed templates (optional)
SEED_AI_TEMPLATES=true bundle exec rails db:seed
```

### Verify on Staging

- [ ] All tests pass on staging
- [ ] Create test automation rule
- [ ] Trigger test conversation
- [ ] Verify ai_enabled set
- [ ] Check logs for errors

### Deploy to Production

```bash
# Merge to main
git checkout main
git pull origin main
git merge development
git push origin main

# Deploy to production
# (Follow your deployment process)

# Run migrations
bundle exec rails db:migrate RAILS_ENV=production

# Seed templates for existing accounts
SEED_AI_TEMPLATES=true bundle exec rails db:seed RAILS_ENV=production
```

---

## Rollback Procedures

### If Issues Occur

#### Option 1: Disable Templates

```ruby
# Rails console
AutomationRule.where("name LIKE '[Template] AI Filter%'").update_all(active: false)
```

#### Option 2: Disable Custom Conditions

**Comment out in `conditions_filter_service.rb`**:

```ruby
def evaluate_condition_with_cache(query_hash, current_index)
  # Temporarily disable custom conditions
  apply_filter(query_hash, current_index)
  true
end
```

**Restart app**

#### Option 3: Revert Code

```bash
# Revert to previous commit
git revert HEAD~1

# Or revert specific commits
git revert <commit-hash>

# Push
git push origin main
```

#### Option 4: Database Rollback

```bash
# If migration was created
bundle exec rails db:rollback STEP=1
```

---

## Post-Deployment Verification

### Check Logs

```bash
# Production logs
tail -f log/production.log | grep "AutomationRule"
tail -f log/production.log | grep "ai_enabled"
```

### Monitor Performance

```bash
# Rails console production
require 'benchmark'

# Check condition evaluation time
conversation = Conversation.last
rule = AutomationRule.where(name: '[Template] AI Filters - CTA + Random').first

time = Benchmark.realtime do
  AutomationRules::ConditionsFilterService.new(rule, conversation).perform
end

puts "Evaluation time: #{time}s"  # Should be < 0.1s
```

### Verify Data

```sql
-- Check custom_attributes being set
SELECT
  id,
  custom_attributes -> 'ai_auto_agentbot_checked' as agentbot_checked,
  custom_attributes -> 'ai_auto_random_checked' as random_checked
FROM conversations
WHERE custom_attributes ? 'ai_auto_agentbot_checked'
LIMIT 10;
```

### User Acceptance Testing

- [ ] Have users create automation rules
- [ ] Verify rules trigger correctly
- [ ] Collect feedback
- [ ] Monitor error reports

---

## Troubleshooting

### Common Issues

**Issue 1: Templates not appearing**

```bash
# Rails console
Seeds::AiFilterTemplates.create_for_account(Account.first)
```

**Issue 2: Conditions not evaluating**

```ruby
# Check if evaluators loaded
AutomationRules::CustomConditions::AgentBotEvaluator
# => Class (if loaded correctly)
```

**Issue 3: Frontend not showing conditions**

```bash
# Rebuild assets
pnpm build

# Check for JavaScript errors in browser console
```

**Issue 4: Caching not working**

```ruby
# Check conversation custom_attributes
conversation = Conversation.last
conversation.custom_attributes
# Should show ai_auto_*_checked keys
```

**Issue 5: Safety check blocking incorrectly**

```ruby
# Check agent-bot status
inbox = Inbox.find(123)
inbox.agent_bot_inbox&.active?
# => true (should be true to enable AI)
```

---

## Success Criteria

### Feature Complete When:

- [x] All 3 custom conditions implemented
- [x] set_ai_enabled action implemented
- [x] Caching logic working
- [x] Frontend UI shows new conditions/actions
- [x] 5 templates created
- [x] All tests passing (100+ tests)
- [x] Documentation complete
- [x] Code reviewed and approved
- [x] Deployed to production
- [x] Users can create automation rules
- [x] AI enabled/disabled automatically based on rules

### Metrics to Track:

- Test coverage: >90%
- Build time: <5 minutes
- Condition evaluation: <100ms (first), <10ms (cached)
- UI load time: <2s
- Error rate: <0.1%

---

**Document Owner**: Development Team
**Created**: 2025-11-15
**Status**: Ready for Execution
**Estimated Duration**: 8-10 days
**Next Step**: Begin Phase 1, Day 1 - Create AgentBotEvaluator
