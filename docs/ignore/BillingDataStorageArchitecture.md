# Billing Data Storage Architecture

## Overview

The Chatwoot billing system uses a **hybrid storage approach** where different pieces of billing data are stored in different places depending on their nature and purpose. This document explains where each type of billing data is stored when a client purchases agents, subscriptions, or add-ons.

---

## 🗄️ Storage Architecture Summary

| Data Type | Storage Location | Format | Source of Truth |
|-----------|-----------------|---------|-----------------|
| **Plan Name** | Account.custom_attributes | JSONB field | Chatwoot Database |
| **Stripe Customer ID** | Account.custom_attributes | JSONB field | Chatwoot Database |
| **Subscription Status** | Account.custom_attributes | JSONB field | Chatwoot Database |
| **Billing Period Info** | Account.custom_attributes | JSONB field | Chatwoot Database |
| **Purchased Add-ons** | Stripe Subscription Items | Stripe API | **Stripe** (queried dynamically) |
| **Plan Limits (Base)** | config/billing_plans.yml | YAML config | Static configuration file |
| **Extra Conversations** | Account.custom_attributes | JSONB field | Chatwoot Database |
| **Subscription Metadata** | Stripe Objects | Stripe metadata | **Stripe** |

---

## 📊 Database Schema: Account Model

### Table Structure

The `accounts` table contains a **JSONB column** called `custom_attributes` that stores all billing-related data:

```sql
CREATE TABLE accounts (
  id                    INTEGER PRIMARY KEY,
  name                  VARCHAR NOT NULL,
  custom_attributes     JSONB DEFAULT '{}',  -- ⭐ Billing data stored here
  limits                JSONB DEFAULT '{}',
  feature_flags         BIGINT DEFAULT 0,
  settings              JSONB DEFAULT '{}',
  -- ... other fields
);
```

### Custom Attributes Structure

The `custom_attributes` JSONB field stores billing information with this structure:

```json
{
  // Core Stripe Integration
  "stripe_customer_id": "cus_abc123",           // Links to Stripe customer
  
  // Plan Information
  "plan_name": "starter",                       // Current plan (starter, professional, etc.)
  "subscription_status": "active",              // active, inactive, past_due, trialing, etc.
  
  // Billing Period Tracking
  "current_period_start": 1706745600,           // Unix timestamp
  "current_period_end": 1709337600,             // Unix timestamp
  "subscription_ends_on": "2024-03-01",         // Human-readable date
  
  // Subscription Lifecycle
  "cancel_at_period_end": false,                // true if scheduled for cancellation
  "canceled_at": null,                          // Timestamp when cancelled
  "ended_at": null,                             // Timestamp when subscription ended
  
  // Payment Status
  "last_payment_status": "succeeded",           // succeeded, failed, pending
  "last_payment_date": "2024-02-01",
  "billing_status": "active",
  "billing_status_updated_at": "2024-02-01T10:00:00Z",
  
  // One-time Purchases (Conversation Packs)
  "extra_conversations_purchased": 10000,       // Extra conversations bought this period
  
  // Internal Flags
  "is_creating_billing_customer": false,
  "creating_billing_customer_since": null
}
```

### Database Query Examples

```ruby
# Find account by Stripe customer ID
account = Account.where("custom_attributes ->> 'stripe_customer_id' = ?", 'cus_abc123').first

# Get account's plan name
plan_name = account.custom_attributes['plan_name']
# => "starter"

# Get subscription status
status = account.custom_attributes['subscription_status']
# => "active"

# Check if cancellation is scheduled
will_cancel = account.custom_attributes['cancel_at_period_end']
# => false
```

---

## 💳 Stripe: Source of Truth for Add-Ons

### Important Concept: No Local Add-On Storage

**Purchased add-ons (extra agents, inboxes, channels) are NOT stored in Chatwoot's database.** 

Instead, they are stored as **Stripe Subscription Items** and queried dynamically when needed.

### How Add-Ons Are Stored in Stripe

When a customer purchases extra agents, inboxes, or channels, Chatwoot creates a **Subscription Item** in Stripe:

```ruby
# Example: Customer purchases 2 extra agents
Stripe::SubscriptionItem.create(
  subscription: 'sub_abc123',
  price: 'price_extra_agent_starter',      # From lookup_key in billing_plans.yml
  quantity: 2,
  proration_behavior: 'create_prorations'
)
```

### Stripe Subscription Structure

A typical Stripe subscription with add-ons looks like this:

```json
{
  "id": "sub_abc123",
  "customer": "cus_abc123",
  "status": "active",
  "items": {
    "data": [
      {
        "id": "si_base",
        "price": {
          "id": "price_starter_base",
          "lookup_key": null,
          "unit_amount": 3000       // $30.00
        },
        "quantity": 1
      },
      {
        "id": "si_agent_addon",
        "price": {
          "id": "price_agent_123",
          "lookup_key": "extra_agent_starter",
          "unit_amount": 1000       // $10.00 per agent
        },
        "quantity": 2               // 2 extra agents purchased
      },
      {
        "id": "si_inbox_addon",
        "price": {
          "id": "price_inbox_456",
          "lookup_key": "extra_inbox_starter",
          "unit_amount": 1500       // $15.00 per inbox
        },
        "quantity": 1               // 1 extra inbox purchased
      }
    ]
  }
}
```

### How Chatwoot Queries Add-Ons

When the system needs to know how many add-ons a customer has purchased, it queries Stripe dynamically:

```ruby
# app/services/billing/unified_limit_service.rb

def purchased_extra
  subscription = fetch_subscription  # Get from Stripe
  return 0 unless subscription
  
  # Find the subscription item for this add-on type
  lookup_key = @plan_config.dig('add_ons', @resource_type.to_s, 'lookup_key')
  # Example: 'extra_agent_starter'
  
  item = subscription.items.data.find { |i| i.price.lookup_key == lookup_key }
  
  item&.quantity || 0
  # Returns: 2 (if 2 extra agents purchased)
end
```

### Why This Approach?

**Advantages:**
1. ✅ **Single Source of Truth**: Stripe is authoritative for billing data
2. ✅ **Automatic Sync**: No risk of local data getting out of sync
3. ✅ **Proration Handling**: Stripe handles all billing calculations
4. ✅ **Audit Trail**: Complete history in Stripe dashboard
5. ✅ **Webhook Updates**: Changes propagate automatically

**Trade-offs:**
1. ⚠️ Requires Stripe API calls for limit checks (mitigated by caching)
2. ⚠️ Dependent on Stripe availability (has fallback to base limits)

---

## 📁 Configuration Files

### Base Plan Limits: billing_plans.yml

Base plan limits (before add-ons) are stored in `config/billing_plans.yml`:

```yaml
plans:
  starter:
    name: "Starter"
    price_id: "price_1RdbcC4TqKLiHbZ87crta9vQ"
    limits:
      agents: 5                    # Base: 5 agents included
      inboxes: 2                   # Base: 2 inboxes included
      conversations_monthly: 4000  # Base: 4,000 conversations/month
    add_ons:
      agent:
        lookup_key: 'extra_agent_starter'   # Used to find add-on in Stripe
      inbox:
        lookup_key: 'extra_inbox_starter'
      channel:
        lookup_key: 'extra_channel_starter'
    conversation_packs:
      lookup_key: 'conversation_pack_starter'
      conversations: 10000
```

This configuration file is:
- ✅ Version controlled
- ✅ Environment-independent
- ✅ Easy to update and deploy
- ✅ Human-readable documentation of plans

---

## 🔄 Data Flow: Complete Example

### Scenario: Customer purchases 2 extra agents

**Step 1: Customer clicks "Purchase 2 Extra Agents" in UI**

```javascript
// Frontend: app/javascript/dashboard/components/Billing.vue
POST /api/v2/accounts/:account_id/billing/add_ons
{
  "add_on_type": "agent",
  "action": "set",
  "quantity": 2
}
```

**Step 2: Backend processes request**

```ruby
# app/controllers/api/v2/accounts/billing/add_ons_controller.rb
def update
  service = Billing::ManageSubscriptionAddOnService.new(
    current_account, 
    params[:add_on_type]
  )
  
  result = service.set_quantity(params[:quantity].to_i)
  # Calls Stripe API to update subscription item
end
```

**Step 3: Service updates Stripe**

```ruby
# app/services/billing/manage_subscription_add_on_service.rb
def update_quantity(new_quantity)
  subscription = fetch_subscription  # Get from Account.custom_attributes['stripe_customer_id']
  item = find_subscription_item(subscription)
  
  if item
    # Update existing subscription item
    Stripe::SubscriptionItem.update(
      item.id,
      {
        quantity: new_quantity,  # Set to 2
        proration_behavior: 'create_prorations'
      }
    )
  else
    # Create new subscription item
    Stripe::SubscriptionItem.create(
      subscription: subscription.id,
      price: 'price_extra_agent_starter',  # From billing_plans.yml
      quantity: new_quantity,
      proration_behavior: 'create_prorations'
    )
  end
  
  # ⚠️ NO DATABASE UPDATE - data stays in Stripe
end
```

**Step 4: Stripe sends webhook confirmation**

```ruby
# app/controllers/webhooks/stripe_controller.rb
# Receives: customer.subscription.updated event

# app/services/billing/providers/stripe.rb
def handle_subscription_updated(subscription)
  account = find_account_by_customer_id(subscription['customer'])
  
  # Update account metadata (period, status, etc.)
  update_account_subscription_data(account, subscription)
  # This updates Account.custom_attributes with:
  # - current_period_start
  # - current_period_end
  # - subscription_status
  # But NOT the add-on quantities (those stay in Stripe)
end
```

**Step 5: System checks limits**

```ruby
# app/models/account_user.rb
before_create :check_agent_limit

def check_agent_limit
  limit_service = Billing::UnifiedLimitService.new(account, :agent)
  
  unless limit_service.can_create?
    errors.add(:base, 'Agent limit reached.')
    throw :abort
  end
end

# app/services/billing/unified_limit_service.rb
def total_allowed
  base_limit + purchased_extra
  # base_limit: 5 (from billing_plans.yml)
  # purchased_extra: 2 (queried from Stripe API)
  # total_allowed: 7
end
```

---

## 🔍 Query Patterns

### Pattern 1: Get Current Plan Information

```ruby
account = Account.find(123)

# Stored in custom_attributes (fast - no API call)
plan_name = account.custom_attributes['plan_name']
# => "starter"

subscription_status = account.custom_attributes['subscription_status']
# => "active"

stripe_customer_id = account.custom_attributes['stripe_customer_id']
# => "cus_abc123"
```

### Pattern 2: Get Base Plan Limits

```ruby
# From config file (fast - no API call)
plan_config = BillingPlans.plan_details('starter')
base_agent_limit = plan_config['limits']['agents']
# => 5

base_inbox_limit = plan_config['limits']['inboxes']
# => 2
```

### Pattern 3: Get Purchased Add-Ons

```ruby
# Requires Stripe API call
service = Billing::ManageSubscriptionAddOnService.new(account, :agent)
purchased_agents = service.current_quantity
# Makes Stripe API call
# => 2
```

### Pattern 4: Calculate Total Allowed

```ruby
# Combines config + Stripe data
service = Billing::UnifiedLimitService.new(account, :agent)

base = service.base_limit              # 5 (from billing_plans.yml)
purchased = service.purchased_extra    # 2 (from Stripe API)
total = service.total_allowed          # 7 (base + purchased)
current = service.current_count        # 4 (from database: account.users.count)
remaining = service.remaining          # 3 (total - current)
```

---

## 📊 Data Lifecycle

### When Account is Created

```ruby
# app/builders/account_builder.rb
account = Account.create!(
  name: "Customer Name",
  custom_attributes: {}  # Empty initially
)
```

### When Customer Subscribes (First Time)

```ruby
# app/services/billing/create_customer_service.rb
def perform
  # 1. Create Stripe customer
  customer = Stripe::Customer.create(
    email: account.users.first.email,
    name: account.name,
    metadata: {
      account_id: account.id.to_s,
      plan: @plan_name
    }
  )
  
  # 2. Save customer ID immediately
  account.update!(
    custom_attributes: {
      'stripe_customer_id' => customer.id
    }
  )
  
  # 3. Create subscription
  subscription = Stripe::Subscription.create(
    customer: customer.id,
    items: [{ price: price_id, quantity: 1 }]
  )
  
  # 4. Update account with subscription details
  account.update!(
    custom_attributes: {
      'stripe_customer_id' => customer.id,
      'plan_name' => @plan_name,
      'subscription_status' => subscription.status,
      'current_period_start' => subscription.current_period_start,
      'current_period_end' => subscription.current_period_end
    }
  )
end
```

### When Customer Purchases Add-Ons

```ruby
# NO DATABASE CHANGES
# Only Stripe subscription items are updated
Stripe::SubscriptionItem.create(
  subscription: subscription_id,
  price: 'price_extra_agent_starter',
  quantity: 2
)
```

### When Webhook Received

```ruby
# app/services/billing/providers/stripe.rb
def handle_subscription_updated(subscription)
  account = find_account_by_customer_id(subscription['customer'])
  
  # Update billing period and status
  account.custom_attributes.merge!(
    'current_period_start' => subscription.current_period_start,
    'current_period_end' => subscription.current_period_end,
    'subscription_status' => subscription.status,
    'cancel_at_period_end' => subscription.cancel_at_period_end
  )
  
  account.save!
  
  # ⚠️ Add-on quantities are NOT saved - they stay in Stripe
end
```

### When Billing Period Resets

```ruby
# Happens automatically via Stripe webhooks
# When new billing period starts:
# - Stripe updates current_period_start and current_period_end
# - Webhook updates Account.custom_attributes
# - extra_conversations_purchased is reset to 0 (if used)

account.custom_attributes.merge!(
  'current_period_start' => new_period_start,
  'current_period_end' => new_period_end,
  'extra_conversations_purchased' => 0  # Reset monthly conversations
)
account.save!
```

---

## 🎯 Key Takeaways

### What IS Stored in Database

✅ **Stripe Customer ID** - Links to Stripe  
✅ **Current Plan Name** - "starter", "professional", etc.  
✅ **Subscription Status** - "active", "past_due", etc.  
✅ **Billing Period** - Start/end timestamps  
✅ **Cancellation Info** - cancel_at_period_end, canceled_at, ended_at  
✅ **Payment Status** - Last payment status and date  
✅ **One-time Purchases** - Extra conversations bought this period  

### What is NOT Stored in Database

❌ **Purchased Add-on Quantities** - Stored in Stripe subscription items  
❌ **Add-on Prices** - Stored in Stripe prices  
❌ **Payment History** - Stored in Stripe invoices  
❌ **Base Plan Limits** - Stored in billing_plans.yml config file  

### Why This Architecture?

**Database (Account.custom_attributes):**
- Fast lookups for plan name, status, billing periods
- Essential for account management
- Persisted across Stripe API failures

**Stripe (Subscription Items):**
- Source of truth for purchased add-ons
- Handles all billing calculations automatically
- Provides complete audit trail
- Ensures data consistency

**Config Files (billing_plans.yml):**
- Easy to update plan configurations
- Version controlled
- Environment-independent
- Documentation and code in one place

---

## 🔧 Maintenance and Debugging

### Check Account's Billing Data

```ruby
account = Account.find(123)

# Print all billing attributes
puts account.custom_attributes.slice(
  'stripe_customer_id',
  'plan_name',
  'subscription_status',
  'current_period_start',
  'current_period_end',
  'cancel_at_period_end'
)
```

### Check Purchased Add-Ons

```ruby
account = Account.find(123)
customer_id = account.custom_attributes['stripe_customer_id']

# Fetch subscription from Stripe
subscriptions = Stripe::Subscription.list(
  customer: customer_id, 
  status: 'active'
)
subscription = subscriptions.data.first

# List all subscription items
subscription.items.data.each do |item|
  puts "Price: #{item.price.lookup_key}"
  puts "Quantity: #{item.quantity}"
  puts "Unit Amount: #{item.price.unit_amount}"
end
```

### Sync Account with Stripe

```ruby
# app/services/billing/sync_subscription_service.rb
# This service can be called to sync local data with Stripe

service = Billing::SyncSubscriptionService.new(account)
service.perform
# Fetches latest data from Stripe and updates custom_attributes
```

---

## 📝 Summary Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      CLIENT PURCHASES                        │
│                    2 Extra Agent Seats                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│           CHATWOOT API CONTROLLER                            │
│  POST /api/v2/accounts/:id/billing/add_ons                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│     ManageSubscriptionAddOnService                           │
│  - Looks up add-on lookup_key from billing_plans.yml        │
│  - Calls Stripe API to update subscription item             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    STRIPE API                                │
│  ✅ Subscription Item Created/Updated                       │
│  ✅ Proration Invoice Generated                             │
│  ✅ Payment Charged                                          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              STRIPE WEBHOOK                                  │
│  customer.subscription.updated                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         StripeController → Webhook Handler                   │
│  - Updates Account.custom_attributes with:                   │
│    * current_period_start                                    │
│    * current_period_end                                      │
│    * subscription_status                                     │
│  - Does NOT store add-on quantities                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  DATA STORAGE                                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  DATABASE (accounts.custom_attributes):                      │
│  ├─ stripe_customer_id: "cus_abc123"                        │
│  ├─ plan_name: "starter"                                    │
│  ├─ subscription_status: "active"                           │
│  ├─ current_period_start: 1706745600                        │
│  └─ current_period_end: 1709337600                          │
│                                                               │
│  STRIPE (subscription.items):                                │
│  ├─ Base Plan: price_starter_base × 1                       │
│  ├─ Extra Agents: price_extra_agent_starter × 2  ⬅ HERE    │
│  └─ Extra Inboxes: price_extra_inbox_starter × 1            │
│                                                               │
│  CONFIG (billing_plans.yml):                                 │
│  ├─ starter.limits.agents: 5                                │
│  ├─ starter.limits.inboxes: 2                               │
│  └─ starter.add_ons.agent.lookup_key: extra_agent_starter   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              LIMIT CHECKING                                  │
│  When user tries to add new agent:                           │
│  1. UnifiedLimitService.total_allowed                        │
│     = base_limit (5 from config)                            │
│     + purchased_extra (2 from Stripe API)                   │
│     = 7 agents allowed                                       │
│  2. current_count = 4 (from database query)                 │
│  3. Can create? Yes (4 < 7)                                 │
└─────────────────────────────────────────────────────────────┘
```

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-29  
**Author:** AI Assistant  
**Related Documents:**
- `docs/ignore/StripeImprovements.md`
- `docs/ignore/StripeImplementationAudit.md`
- `config/billing_plans.yml`

