# AI Filter Templates - Usage Guide

## Overview

These templates demonstrate how to use the custom AI conversation filter conditions:
- **has_agent_bot**: Check if inbox has an active agent-bot
- **entry_phrase**: Detect keywords/phrases in first N messages
- **random_chance**: Random percentage-based routing

## How to Create Templates for Your Account

### Via Rails Console

```bash
# Start Rails console
bundle exec rails console

# Find your account (replace 1 with your account ID)
account = Account.find(1)

# Create all templates
Seeds::AiFilterTemplates.create_for_account(account)

# Or create specific templates
Seeds::AiFilterTemplates.create_sales_intent_template(account)
Seeds::AiFilterTemplates.create_support_request_template(account)
```

### Via Rails Runner

```bash
# For a specific account
rails runner "Seeds::AiFilterTemplates.create_for_account(Account.find(1))"

# For all accounts
rails runner "Account.find_each { |a| Seeds::AiFilterTemplates.create_for_account(a) }"
```

## Template Descriptions

### 1. Sales Intent Detection
**Use case**: Automatically enable AI when customers show buying intent

**Keywords**: buy, comprar, purchase, price, precio, cost, costo, quote, cotización

**Configuration**:
- Checks first 3 messages
- Case-insensitive
- Requires active agent-bot

**Example conversation**:
```
Customer: "Hi, how much does the premium plan cost?"
→ AI enabled ✓ (keyword: "cost")
```

---

### 2. Support Request Detection
**Use case**: Enable AI for help requests and issue reports

**Keywords**: help, ayuda, problem, problema, issue, error, not working, no funciona

**Configuration**:
- Checks first 5 messages (longer window for support)
- Case-insensitive
- Requires active agent-bot

**Example conversation**:
```
Customer: "I'm having a problem with my order"
→ AI enabled ✓ (keyword: "problem")
```

---

### 3. Random A/B Testing (50%)
**Use case**: Test AI performance vs human agents

**Configuration**:
- 50% random selection
- Same conversation always gets same result (deterministic)
- Good for comparing metrics

**Example**:
```
Conversation ID 123 → Random: 45 < 50 → AI enabled ✓
Conversation ID 124 → Random: 73 > 50 → AI disabled ✗
```

---

### 4. WhatsApp Spanish Keywords
**Use case**: Per-channel configuration with localized keywords

**Keywords**: hola, buenos días, buenas tardes, ayuda, comprar, precio, información

**Configuration**:
- Checks first 3 messages
- **IMPORTANT**: Must set inbox_id to your WhatsApp inbox!
- Spanish-language focused

**How to configure**:
1. Create the template
2. Edit the automation rule
3. Select your WhatsApp inbox from the dropdown
4. Save

---

### 5. Smart Routing (Keywords + 60% Random)
**Use case**: Balance AI load while targeting specific intents

**Keywords**: start, comenzar, info, información, hi, hello, hola

**Configuration**:
- Checks first 2 messages only
- AND logic: Must have keyword AND pass 60% random check
- Reduces AI load while capturing important conversations

**Example**:
```
Conversation with "hello" + Random 35 → AI enabled ✓ (has keyword + 35 < 60)
Conversation with "hello" + Random 75 → AI disabled ✗ (has keyword but 75 > 60)
Conversation without keyword → AI disabled ✗ (no keyword match)
```

## Customization Tips

### Adding More Keywords

Edit the template and add to the `values` array:

```ruby
values: ['help', 'ayuda', 'YOUR_NEW_KEYWORD']
```

### Changing Message Limit

Modify the `message_limit` in `custom_filters`:

```ruby
custom_filters: { 'message_limit' => 5 }  # Check first 5 messages
```

### Making Case-Sensitive

```ruby
custom_filters: { 'case_sensitive' => true }
```

### Adjusting Random Percentage

```ruby
{
  attribute_key: 'random_chance',
  filter_operator: 'is_less_than',
  values: [75]  # 75% of conversations
}
```

## Important Notes

1. **Templates are INACTIVE by default** - You must activate them in the UI
2. **WhatsApp template requires inbox selection** - Edit and select your inbox
3. **Agent-bot must be active** - All templates check for active agent-bot
4. **Multiple phrases are OR logic** - Any matching phrase triggers the condition
5. **Entry phrase checks INCOMING messages only** - Agent messages are ignored
6. **Random selection is deterministic** - Same conversation ID always gets same result

## Testing Your Rules

After creating and activating a template:

1. Create a test conversation in the configured inbox
2. Send a message with one of the keywords
3. Check the contact's `custom_attributes`:
   ```ruby
   contact = Contact.last
   contact.custom_attributes['ai_enabled']  # Should be true
   ```
4. Check conversation cache:
   ```ruby
   conversation = Conversation.last
   conversation.custom_attributes  # Should show cache flags
   ```

## Troubleshooting

**AI not enabling:**
- ✓ Check automation rule is active
- ✓ Verify inbox has active agent-bot
- ✓ Confirm keyword matches (case-insensitive by default)
- ✓ Check message_limit (might be checking too few messages)

**Random not working:**
- ✓ Random is deterministic - same conversation always gets same %
- ✓ Check logs: `conversation.custom_attributes['ai_auto_random_passed']`

**WhatsApp template not working:**
- ✓ Did you set the inbox_id?
- ✓ Is the inbox a WhatsApp channel?
- ✓ Does the inbox have an active agent-bot?
