# Product Removal Guide - Stripe Subscription Items

**Purpose:** Complete guide for removing subscription items (Extra Agents, Extra Inboxes, Live Training, Live 1:1 Training)

## Overview

**Good News:** The Chatwoot billing system already implements product removal functionality! This guide explains how to use the existing API endpoints to remove subscription items correctly.

### What Can Be Removed

The following subscription items can be added and removed independently:

| Add-On Type | Description | Can Be Removed |
|------------|-------------|----------------|
| **Extra Agents** | Additional agent seats | ✅ Yes |
| **Extra Inboxes** | Additional inbox channels | ✅ Yes |
| **Live Training** | Group training sessions | ✅ Yes |
| **Live 1:1 Training** | One-on-one expert training | ✅ Yes |

### What Cannot Be Removed

- **Base Plan** - The core subscription cannot be removed (would cancel entire subscription)
- **Included Features** - Features included in the base plan (use plan downgrade instead)

---

## Current Implementation Status

✅ **Removal functionality is FULLY IMPLEMENTED**

The system includes:
- ✅ API endpoint for removing subscription items
- ✅ Multiple removal methods (decrement, set to zero, delete)
- ✅ Automatic proration handling
- ✅ Credit calculation for unused time
- ✅ Error handling for Stripe API calls
- ✅ Webhook event handling for subscription updates

**Implementation Location:**
- Service: `app/services/billing/manage_subscription_add_on_service.rb`
- Controller: `app/controllers/api/v2/accounts/billing/add_ons_controller.rb`
- Routes: `/api/v2/accounts/:account_id/billing/add_ons`

---

## How Product Removal Works

### Stripe Architecture

When you purchase an "Extra Agent" or "Live Training", it creates a **Subscription Item** within your main subscription:

```
Subscription (sub_123)
├── Subscription Item 1: Base Plan (Starter)
├── Subscription Item 2: Extra Agent × 2
├── Subscription Item 3: Extra Inbox × 1
└── Subscription Item 4: Live Training × 1
```

Each subscription item can be managed independently using the Stripe SubscriptionItem API.

### Removal Process

When a user removes a product:

1. **Identify Subscription Item** - Find the subscription item by lookup_key
2. **Update or Delete** - Either set quantity to 0 or delete the item
3. **Calculate Proration** - Stripe calculates credit for unused time
4. **Create Credit** - Credit added to account balance or next invoice
5. **Webhook Event** - `customer.subscription.updated` event sent
6. **Update Records** - Local database updated via webhook

---

## API Endpoints for Removal

### Endpoint Overview

**Base URL:** `/api/v2/accounts/:account_id/billing/add_ons`  
**Method:** `POST`  
**Authentication:** Required (account owner/administrator)

### Method 1: Remove One Unit

**Use Case:** Decrease quantity by 1 (e.g., remove 1 extra agent)

```bash
POST /api/v2/accounts/123/billing/add_ons

{
  "add_on_type": "agent",
  "action_type": "remove"
}
```

**Response:**
```json
{
  "success": true,
  "message": "agent quantity updated to 1",
  "data": {
    "add_on_type": "agent",
    "quantity": 1
  }
}
```

**What Happens:**
- Current quantity: 2 → New quantity: 1
- Credit issued for 1 agent for remaining billing period
- Next invoice shows reduced cost

---

### Method 2: Set Specific Quantity

**Use Case:** Set to exact quantity (including 0 to remove completely)

```bash
POST /api/v2/accounts/123/billing/add_ons

{
  "add_on_type": "live_training",
  "action_type": "set",
  "quantity": 0
}
```

**Response:**
```json
{
  "success": true,
  "message": "live_training add-on removed",
  "data": {
    "add_on_type": "live_training",
    "quantity": 0
  }
}
```

**What Happens:**
- Current quantity: 1 → New quantity: 0
- Subscription item deleted from Stripe
- Full credit issued for remaining billing period
- Next invoice no longer includes this add-on

---

### Method 3: Check Current Quantities

**Use Case:** View all current add-ons before removal

```bash
GET /api/v2/accounts/123/billing/add_ons
```

**Response:**
```json
{
  "success": true,
  "data": {
    "account_id": 123,
    "plan_name": "starter",
    "add_ons": {
      "agent": {
        "type": "agent",
        "current_quantity": 2,
        "unit_price_cents": 1000,
        "unit_price_formatted": "$10.00",
        "currency": "USD",
        "interval": "month"
      },
      "inbox": {
        "type": "inbox",
        "current_quantity": 1,
        "unit_price_cents": 1500,
        "unit_price_formatted": "$15.00",
        "currency": "USD",
        "interval": "month"
      }
    },
    "training_services": {
      "live_training": {
        "type": "live_training",
        "current_quantity": 1,
        "unit_price_cents": 5000,
        "unit_price_formatted": "$50.00",
        "currency": "USD",
        "interval": "month",
        "display_name": "Live Group Training",
        "description": "Monthly group training session",
        "max_quantity": 1,
        "is_owned": true,
        "category": "training"
      }
    }
  }
}
```

---

## Proration Behavior

### What is Proration?

**Proration** ensures customers receive credit for unused time when removing subscription items.

**Example:**
- Customer purchases Extra Agent on January 1 ($10/month)
- Customer removes Extra Agent on January 15 (halfway through month)
- Customer receives credit of $5 (half of $10)

### Proration Calculation

Stripe prorates **to the second** for accuracy:

```
Credit = (Price ÷ Billing Period) × Unused Time

Example:
Price: $10/month
Days in January: 31
Days used: 15
Days unused: 16

Credit = ($10 ÷ 31 days) × 16 days = $5.16
```

### Current Implementation

**Our System Uses:** `proration_behavior: 'create_prorations'`

**Location:** `app/services/billing/manage_subscription_add_on_service.rb:147,191`

```ruby
# When updating quantity
::Stripe::SubscriptionItem.update(
  item.id,
  quantity: new_quantity,
  proration_behavior: 'create_prorations'  # Creates credit invoice items
)

# When deleting item
::Stripe::SubscriptionItem.delete(
  item.id,
  proration_behavior: 'create_prorations'  # Creates credit invoice items
)
```

### Proration Behavior Options

Stripe supports three proration behaviors:

| Behavior | Description | When to Use | Current Usage |
|----------|-------------|-------------|---------------|
| `create_prorations` | Creates credit invoice items for unused time | Default - fair to customers | ✅ **Currently Used** |
| `always_invoice` | Creates credits AND immediately generates invoice | Immediate refund scenarios | ❌ Not used |
| `none` | No credits issued - customer pays full period | Never for removals - unfair | ❌ Not used |

**Recommendation:** Continue using `create_prorations` (current implementation is correct per Stripe best practices)

---

## Removal Strategies

Based on Stripe documentation, there are two main approaches for removing subscription items:

### Strategy 1: Immediate Removal (Current Implementation) ✅

**How it Works:**
- Subscription item deleted immediately
- Credit issued for unused time
- Credit applied to next invoice or account balance
- Customer stops being charged immediately

**Implementation:**
```ruby
# Set quantity to 0
service.set_quantity(0)

# Or remove one unit at a time
service.remove_unit
```

**When to Use:**
- Default for most removals
- Customer wants immediate cancellation
- Training services that are one-time purchases

**Stripe Documentation:** 
- ["Delete a subscription item"](https://docs.stripe.com/api/subscription_items/delete)
- "Deletes an item from the subscription. Removing a subscription item from a subscription will not cancel the subscription."

---

## Complete Examples

### Example 1: Remove Extra Agent

**Scenario:** Customer has 3 extra agents, wants to remove 1

```bash
# Step 1: Check current quantity
GET /api/v2/accounts/123/billing/add_ons

Response:
{
  "data": {
    "add_ons": {
      "agent": {
        "current_quantity": 3,
        "unit_price_formatted": "$10.00"
      }
    }
  }
}

# Step 2: Remove one agent
POST /api/v2/accounts/123/billing/add_ons
{
  "add_on_type": "agent",
  "action_type": "remove"
}

Response:
{
  "success": true,
  "message": "agent quantity updated to 2",
  "data": {
    "add_on_type": "agent",
    "quantity": 2
  }
}

# Step 3: Verify in Stripe Dashboard
# - Subscription updated event logged
# - Credit proration created for 1 agent
# - Next invoice shows 2 agents instead of 3
```

**What Customer Sees:**
```
Next Invoice Preview:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Starter Plan                          $30.00
Extra Agent Seats × 2                 $20.00
Credit (Unused time - 1 agent)        -$5.16
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total                                 $44.84
```

---

### Example 2: Remove All Extra Inboxes

**Scenario:** Customer has 2 extra inboxes, wants to remove all

```bash
# Step 1: Set quantity to 0 (removes all)
POST /api/v2/accounts/123/billing/add_ons
{
  "add_on_type": "inbox",
  "action_type": "set",
  "quantity": 0
}

Response:
{
  "success": true,
  "message": "inbox add-on removed",
  "data": {
    "add_on_type": "inbox",
    "quantity": 0
  }
}

# Stripe Actions:
# 1. Subscription item deleted
# 2. Credit issued: 2 inboxes × $15 × (unused days / total days)
# 3. Subscription updated (base plan only)
```

**What Happens in Stripe:**
```
Before Removal:
Subscription Items:
├── Starter Plan
└── Extra Inboxes × 2

After Removal:
Subscription Items:
└── Starter Plan

Invoice Items:
└── Credit: -$15.48 (prorated refund for 2 inboxes)
```

---

### Example 3: Cancel Live Training

**Scenario:** Customer purchased Live Training, wants to cancel

```bash
# Training add-ons have max_quantity: 1
# So they're either owned (1) or not owned (0)

POST /api/v2/accounts/123/billing/add_ons
{
  "add_on_type": "live_training",
  "action_type": "set",
  "quantity": 0
}

Response:
{
  "success": true,
  "message": "live_training add-on removed",
  "data": {
    "add_on_type": "live_training",
    "quantity": 0
  }
}

# Customer receives credit for unused portion of training subscription
# If training was $50/month and removed halfway through:
# Credit: ~$25
```

---

### Example 5: Error Handling - Remove Below Zero

**Scenario:** Customer tries to remove when quantity is already 0

```bash
POST /api/v2/accounts/123/billing/add_ons
{
  "add_on_type": "agent",
  "action_type": "remove"
}

Response (422 Unprocessable Entity):
{
  "success": false,
  "error": "Cannot remove below 0"
}

# Frontend should:
# 1. Check current quantity before allowing removal
# 2. Disable "Remove" button when quantity is 0
# 3. Show clear error message to user
```

---

## Webhook Events

### Events Triggered by Removal

When a subscription item is removed, Stripe sends webhook events:

| Event | When Fired | What to Do |
|-------|-----------|------------|
| `customer.subscription.updated` | Subscription modified (item removed) | Update local subscription record |
| `invoice.updated` | Credit proration added | Update invoice display |
| `invoice.finalized` | Next invoice ready | Show customer new total |

### Current Webhook Handler

**Location:** `app/services/billing/providers/stripe.rb:133-167`

```ruby
case event_type
when 'customer.subscription.updated'
  handle_subscription_updated(event_object)
  # Updates account's custom_attributes with new subscription data
  # Reflects removed items in local database
end
```

**What Gets Updated:**
- Subscription metadata in `account.custom_attributes`
- Subscription status
- Current period dates
- Subscription items (automatically reflects removals)

### Webhook Testing

To test webhook handling for removals:

```bash
# Use Stripe CLI to trigger test event
stripe trigger customer.subscription.updated

# Or use Stripe Dashboard:
# 1. Go to Developers > Webhooks > Test in Dashboard
# 2. Select "customer.subscription.updated"
# 3. Modify subscription items in payload
# 4. Send test event
```

---

## Best Practices from Stripe

Based on Stripe official documentation and Discord support responses:

### ✅ DO

1. **Always Use Proration for Removals**
   - `proration_behavior: 'create_prorations'` (current implementation)
   - Ensures fair credit calculation
   - Better customer experience

2. **Delete Subscription Items When Quantity = 0**
   - Keeps subscription clean
   - Prevents confusion
   - Current implementation does this correctly (line 188-193 in service)

3. **Handle Errors Gracefully**
   - Check for InvalidRequestError (item doesn't exist)
   - Check for RateLimitError (too many updates)
   - Provide clear error messages to users
   - Current implementation includes comprehensive error handling

4. **Log All Removals**
   - Track who removed what and when
   - Helps with customer support
   - Current implementation logs to Rails logger

5. **Update Local Database via Webhooks**
   - Don't trust local state after API calls
   - Wait for webhook confirmation
   - Current implementation handles this correctly

### ❌ DON'T

1. **Don't Use `proration_behavior: 'none'` for Removals**
   - Unfair to customers
   - They paid for time they won't use
   - Only use for very specific edge cases

2. **Don't Delete Base Subscription Item**
   - Would cancel entire subscription
   - Use subscription cancellation flow instead
   - Current implementation protects against this (only handles add-ons)

3. **Don't Allow Removal Without Checking Quantity**
   - Leads to errors and poor UX
   - Current implementation prevents (line 27 check)

4. **Don't Modify Subscription Items Directly in Stripe Dashboard During Testing**
   - Can desync local database
   - Use API calls so webhooks fire properly

5. **Don't Forget to Handle Webhook Events**
   - Local database can become stale
   - Current implementation handles subscription.updated events

---

## Testing Checklist

### Functional Testing

- [ ] **Test Remove One Unit**
  - Add 3 extra agents
  - Remove 1 agent
  - Verify quantity becomes 2
  - Check credit appears on next invoice

- [ ] **Test Remove All (Set to Zero)**
  - Add 2 extra inboxes
  - Set quantity to 0
  - Verify subscription item deleted in Stripe
  - Check full credit issued

- [ ] **Test Remove When Already Zero**
  - Ensure no extra agents exist
  - Try to remove agent
  - Verify error message: "Cannot remove below 0"

- [ ] **Test Training Add-On Removal**
  - Purchase Live Training
  - Remove Live Training (set to 0)
  - Verify is_owned becomes false
  - Check credit issued

- [ ] **Test Multiple Removals in Sequence**
  - Remove agent, then inbox, then training
  - Verify all credits combine correctly
  - Check subscription only has base plan remaining

### Proration Testing

- [ ] **Test Mid-Period Removal**
  - Add item on day 1 of month
  - Remove on day 15
  - Verify ~50% credit issued

- [ ] **Test End-of-Period Removal**
  - Remove item on last day of billing period
  - Verify minimal credit issued

- [ ] **Test Beginning-of-Period Removal**
  - Add item
  - Remove immediately (same day)
  - Verify ~100% credit issued

### Error Handling Testing

- [ ] **Test Invalid Add-On Type**
  - Try to remove "invalid_type"
  - Verify 400 Bad Request error

- [ ] **Test Missing Customer**
  - Mock account without stripe_customer_id
  - Try to remove add-on
  - Verify appropriate error message

- [ ] **Test Stripe API Failure**
  - Mock Stripe::InvalidRequestError
  - Verify error caught and returned properly

- [ ] **Test Rate Limiting**
  - Mock Stripe::RateLimitError
  - Verify retry logic or clear error message

### Webhook Testing

- [ ] **Test Subscription Updated Event**
  - Remove add-on via API
  - Verify webhook received
  - Check local database updated

- [ ] **Test Invoice Updated Event**
  - Verify credit proration appears
  - Check invoice totals recalculated

### UI/UX Testing (Frontend)

- [ ] **Disable Remove When Quantity = 0**
  - Show "Remove" button only when quantity > 0
  - Or disable button with tooltip

- [ ] **Show Confirmation Dialog**
  - "Are you sure you want to remove X?"
  - Show expected credit amount

- [ ] **Display Loading State**
  - Show spinner during API call
  - Disable button to prevent double-clicks

- [ ] **Show Success Message**
  - "Successfully removed X"
  - Show new quantity

- [ ] **Show Error Messages**
  - Network errors
  - Stripe errors
  - Validation errors

---

## Frontend Implementation Guide

### Overview

This section provides complete implementation instructions for adding removal controls to the billing UI. The backend API already exists and works perfectly - we just need to expose it in the frontend.

### Implementation Locations

Three Vue components need to be updated:

| Component | Path | Purpose |
|-----------|------|---------|
| **BillingLimitsCard.vue** | `app/javascript/dashboard/routes/dashboard/settings/billing/components/` | Add removal for agents/inboxes |
| **BillingTrainingCard.vue** | `app/javascript/dashboard/routes/dashboard/settings/billing/components/` | Add removal for training services |
| **BillingSubscriptionCard.vue** | `app/javascript/dashboard/routes/dashboard/settings/billing/components/` | Optional: Add removal controls to breakdown view |

---

### 1. Add Removal Controls for Agents/Inboxes

**Component:** `BillingLimitsCard.vue`

**Current State:**
- Shows usage statistics and "Purchase Extra Agent/Inbox" buttons
- No way to remove purchased add-ons

**Required Changes:**

#### A. Add Removal Method

Add this method after the existing `purchaseAddOn` function (around line 102):

```javascript
/**
 * Remove one unit of an add-on
 * @param {string} addOnType - The add-on type ('agent' or 'inbox')
 */
const removeAddOn = async addOnType => {
  try {
    isPurchasing.value = true;
    
    // Call existing store action with 'remove' action
    await store.dispatch('accounts/purchaseAddOn', {
      add_on_type: addOnType,
      action: 'remove',
    });

    // Refresh limits and add-ons after removal
    await Promise.all([fetchLimits(), fetchAddOns()]);

    // Show success notification
    useAlert(
      t('BILLING_SETTINGS.LIMITS.REMOVE_SUCCESS', {
        item: getAddOnDisplayName(addOnType),
      }),
      { duration: 5000 }
    );
  } catch (error) {
    // Show error notification
    const errorMessage = error?.response?.data?.error || error?.message;
    useAlert(
      t('BILLING_SETTINGS.LIMITS.REMOVE_ERROR', {
        item: getAddOnDisplayName(addOnType),
        error: errorMessage || t('BILLING_SETTINGS.LIMITS.GENERIC_ERROR'),
      }),
      { duration: 5000 }
    );
  } finally {
    isPurchasing.value = false;
  }
};

/**
 * Remove all units of an add-on (set quantity to 0)
 * @param {string} addOnType - The add-on type ('agent' or 'inbox')
 */
const removeAllAddOns = async addOnType => {
  try {
    isPurchasing.value = true;
    
    // Call existing store action with 'set' action and quantity 0
    await store.dispatch('accounts/purchaseAddOn', {
      add_on_type: addOnType,
      action: 'set',
      quantity: 0,
    });

    // Refresh limits and add-ons after removal
    await Promise.all([fetchLimits(), fetchAddOns()]);

    // Show success notification
    useAlert(
      t('BILLING_SETTINGS.LIMITS.REMOVE_ALL_SUCCESS', {
        item: getAddOnDisplayName(addOnType),
      }),
      { duration: 5000 }
    );
  } catch (error) {
    // Show error notification
    const errorMessage = error?.response?.data?.error || error?.message;
    useAlert(
      t('BILLING_SETTINGS.LIMITS.REMOVE_ERROR', {
        item: getAddOnDisplayName(addOnType),
        error: errorMessage || t('BILLING_SETTINGS.LIMITS.GENERIC_ERROR'),
      }),
      { duration: 5000 }
    );
  } finally {
    isPurchasing.value = false;
  }
};

/**
 * Show confirmation modal before removing one unit
 */
const confirmRemove = async addOnType => {
  const addOnInfo = addOns.value[addOnType];
  
  // Fetch accurate credit amount from Stripe
  let estimatedCredit = null;
  try {
    const previewResponse = await store.dispatch('accounts/previewAddOnRemoval', {
      add_on_type: addOnType,
      action: 'remove',
    });
    
    if (previewResponse?.data?.estimated_credit) {
      estimatedCredit = previewResponse.data.estimated_credit;
    }
  } catch (error) {
    // If preview fails, continue without credit amount
    // Better to show confirmation than block the removal
  }
  
  pendingPurchase.value = {
    type: addOnType,
    name: getAddOnDisplayName(addOnType),
    price: addOnInfo?.unit_price_formatted || '',
    action: 'remove',
    estimatedCredit: estimatedCredit || 'calculating...',
  };

  const confirmed = await confirmationModal.value.showConfirmation();

  if (confirmed) {
    await removeAddOn(addOnType);
  }
};

/**
 * Show confirmation modal before removing all units
 */
const confirmRemoveAll = async addOnType => {
  const addOnInfo = addOns.value[addOnType];
  const currentPurchased = 
    addOnType === 'agent' ? agentLimit.value.purchased : inboxLimit.value.purchased;
  
  // Fetch accurate credit amount from Stripe
  let estimatedCredit = null;
  try {
    const previewResponse = await store.dispatch('accounts/previewAddOnRemoval', {
      add_on_type: addOnType,
      action: 'set',
      quantity: 0,
    });
    
    if (previewResponse?.data?.estimated_credit) {
      estimatedCredit = previewResponse.data.estimated_credit;
    }
  } catch (error) {
    // If preview fails, continue without credit amount
    // Better to show confirmation than block the removal
  }
  
  pendingPurchase.value = {
    type: addOnType,
    name: getAddOnDisplayName(addOnType),
    price: addOnInfo?.unit_price_formatted || '',
    action: 'remove_all',
    quantity: currentPurchased,
    estimatedCredit: estimatedCredit || 'calculating...',
  };

  const confirmed = await confirmationModal.value.showConfirmation();

  if (confirmed) {
    await removeAllAddOns(addOnType);
  }
};
```

#### B. Update Template - Agent Section

Replace the "Purchase Button" section (around line 353-375) with:

```vue
<!-- Purchase/Remove Buttons -->
<div class="flex justify-between items-center gap-2 pt-2 border-t border-n-weak">
  <!-- Remove Buttons (show only if purchased > 0) -->
  <div v-if="agentLimit.purchased > 0" class="flex gap-2">
    <ButtonV4
      sm
      outline
      red
      :disabled="isPurchasing || !canPurchaseAddOns"
      @click="confirmRemove('agent')"
    >
      {{ t('BILLING_SETTINGS.LIMITS.REMOVE_ONE') }}
    </ButtonV4>
    <ButtonV4
      sm
      outline
      red
      :disabled="isPurchasing || !canPurchaseAddOns"
      @click="confirmRemoveAll('agent')"
    >
      {{ t('BILLING_SETTINGS.LIMITS.REMOVE_ALL') }}
    </ButtonV4>
  </div>
  
  <!-- Spacer when no remove buttons -->
  <div v-else></div>

  <!-- Purchase Button -->
  <ButtonV4
    sm
    solid
    blue
    :disabled="isPurchasing || !canPurchaseAddOns"
    @click="confirmPurchase('agent')"
  >
    <template v-if="canPurchaseAddOns">
      {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_AGENT') }}
      <span v-if="agentAddOn.unit_price_formatted" class="text-xs">
        {{ t('BILLING_SETTINGS.LIMITS.SEPARATOR')
        }}{{ agentAddOn.unit_price_formatted
        }}{{ t('BILLING_SETTINGS.LIMITS.SLASH')
        }}{{ t('BILLING_SETTINGS.LIMITS.MONTH') }}
      </span>
    </template>
    <template v-else>
      {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_AGENT') }}
    </template>
  </ButtonV4>
</div>
```

#### C. Update Template - Inbox Section

Replace the "Purchase Button" section for inboxes (around line 491-513) with the same pattern:

```vue
<!-- Purchase/Remove Buttons -->
<div class="flex justify-between items-center gap-2 pt-2 border-t border-n-weak">
  <!-- Remove Buttons (show only if purchased > 0) -->
  <div v-if="inboxLimit.purchased > 0" class="flex gap-2">
    <ButtonV4
      sm
      outline
      red
      :disabled="isPurchasing || !canPurchaseAddOns"
      @click="confirmRemove('inbox')"
    >
      {{ t('BILLING_SETTINGS.LIMITS.REMOVE_ONE') }}
    </ButtonV4>
    <ButtonV4
      sm
      outline
      red
      :disabled="isPurchasing || !canPurchaseAddOns"
      @click="confirmRemoveAll('inbox')"
    >
      {{ t('BILLING_SETTINGS.LIMITS.REMOVE_ALL') }}
    </ButtonV4>
  </div>
  
  <!-- Spacer when no remove buttons -->
  <div v-else></div>

  <!-- Purchase Button -->
  <ButtonV4
    sm
    solid
    blue
    :disabled="isPurchasing || !canPurchaseAddOns"
    @click="confirmPurchase('inbox')"
  >
    <template v-if="canPurchaseAddOns">
      {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_INBOX') }}
      <span v-if="inboxAddOn.unit_price_formatted" class="text-xs">
        {{ t('BILLING_SETTINGS.LIMITS.SEPARATOR')
        }}{{ inboxAddOn.unit_price_formatted
        }}{{ t('BILLING_SETTINGS.LIMITS.SLASH')
        }}{{ t('BILLING_SETTINGS.LIMITS.MONTH') }}
      </span>
    </template>
    <template v-else>
      {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_INBOX') }}
    </template>
  </ButtonV4>
</div>
```

#### D. Update Confirmation Modal

Update the confirmation modal at the bottom to handle removal actions:

```vue
<!-- Confirmation Modal -->
<ConfirmationModal
  ref="confirmationModal"
  :title="
    pendingPurchase.action === 'remove' || pendingPurchase.action === 'remove_all'
      ? t('BILLING_SETTINGS.LIMITS.CONFIRM_REMOVE_TITLE')
      : t('BILLING_SETTINGS.LIMITS.CONFIRM_PURCHASE_TITLE')
  "
  :description="
    pendingPurchase.action === 'remove'
      ? t('BILLING_SETTINGS.LIMITS.CONFIRM_REMOVE_DESCRIPTION', {
          item: pendingPurchase.name,
          credit: pendingPurchase.estimatedCredit,
        })
      : pendingPurchase.action === 'remove_all'
        ? t('BILLING_SETTINGS.LIMITS.CONFIRM_REMOVE_ALL_DESCRIPTION', {
            quantity: pendingPurchase.quantity,
            item: pendingPurchase.name,
            credit: pendingPurchase.estimatedCredit,
          })
        : t('BILLING_SETTINGS.LIMITS.CONFIRM_PURCHASE_DESCRIPTION', {
            item: pendingPurchase.name,
            price: pendingPurchase.price,
          })
  "
  :confirm-label="
    pendingPurchase.action === 'remove' || pendingPurchase.action === 'remove_all'
      ? t('BILLING_SETTINGS.LIMITS.CONFIRM_REMOVE_BUTTON')
      : t('BILLING_SETTINGS.LIMITS.CONFIRM_PURCHASE_BUTTON')
  "
  :cancel-label="t('BILLING_SETTINGS.LIMITS.CANCEL_BUTTON')"
/>
```

---

### 2. Add Removal Controls for Training Services

**Component:** `BillingTrainingCard.vue`

**Current State:**
- Shows "Purchase" button when not owned
- Shows "✓ Already Purchased" text when owned
- No way to cancel/remove training

**Required Changes:**

#### A. Add Removal Method

Add this method after the existing `purchaseTraining` function (around line 156):

```javascript
/**
 * Remove/cancel a training add-on
 * @param {string} trainingType - The training type (e.g., 'live_training')
 */
const removeTraining = async trainingType => {
  try {
    isPurchasing.value[trainingType] = true;

    // Call existing purchaseAddOn action with 'set' action and quantity 0
    const response = await store.dispatch('accounts/purchaseAddOn', {
      add_on_type: trainingType,
      action: 'set',
      quantity: 0,
    });

    // Verify success before refreshing
    if (response?.data?.success) {
      // Refresh training add-ons to reflect removal
      await fetchTrainingAddOns();

      // Show success notification
      useAlert(t('BILLING_SETTINGS.TRAINING.REMOVE_SUCCESS'), {
        duration: 5000,
      });
    } else {
      throw new Error('Removal failed - no success flag in response');
    }
  } catch (error) {
    Sentry.captureException(error, {
      tags: {
        component: 'BillingTrainingCard',
        action: 'removeTraining',
        trainingType,
      },
    });

    // Show error notification
    useAlert(t('BILLING_SETTINGS.TRAINING.REMOVE_ERROR'), {
      duration: 5000,
    });
  } finally {
    isPurchasing.value[trainingType] = false;
  }
};

/**
 * Show confirmation modal before removing training
 * @param {string} trainingType - The training type (e.g., 'live_training')
 * @param {object} service - The service object containing details
 */
const confirmRemoveTraining = async (trainingType, service) => {
  // Fetch accurate credit amount from Stripe
  let estimatedCredit = null;
  try {
    const previewResponse = await store.dispatch('accounts/previewAddOnRemoval', {
      add_on_type: trainingType,
      action: 'set',
      quantity: 0,
    });
    
    if (previewResponse?.data?.estimated_credit) {
      estimatedCredit = previewResponse.data.estimated_credit;
    }
  } catch (error) {
    // If preview fails, continue without credit amount
    // Better to show confirmation than block the removal
  }
  
  // Set pending purchase details for confirmation modal
  pendingPurchase.value = {
    type: trainingType,
    name: service.display_name,
    price: service.unit_price_formatted,
    action: 'remove',
    estimatedCredit: estimatedCredit || 'calculating...',
  };

  // Show confirmation modal
  const confirmed = await confirmationModal.value.showConfirmation();

  if (confirmed) {
    await removeTraining(trainingType);
  }
};
```

#### B. Update Template - Purchase/Remove Button Section

Replace the "Purchase Button / Ownership Status" section (around lines 313-335) with:

```vue
<!-- ====================================================================
     PURCHASE BUTTON / OWNERSHIP STATUS / REMOVE BUTTON
     ==================================================================== -->
<div class="flex items-center justify-between pt-3 border-t border-n-weak">
  <!-- Already Owned Status + Remove Button -->
  <div v-if="service.is_owned" class="flex items-center justify-between w-full">
    <!-- Ownership Status -->
    <div class="flex items-center">
      <span class="text-n-teal-9 mr-2">{{
        t('BILLING_SETTINGS.TRAINING.CHECK_MARK')
      }}</span>
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('BILLING_SETTINGS.TRAINING.ALREADY_PURCHASED') }}
      </span>
    </div>
    
    <!-- Cancel/Remove Button -->
    <ButtonV4
      sm
      outline
      red
      :loading="isTrainingPurchasing(service.type)"
      @click="confirmRemoveTraining(service.type, service)"
    >
      {{ t('BILLING_SETTINGS.TRAINING.CANCEL_BUTTON') }}
    </ButtonV4>
  </div>

  <!-- Purchase Button (when not owned) -->
  <ButtonV4
    v-else
    sm
    solid
    blue
    class="ml-auto"
    :loading="isTrainingPurchasing(service.type)"
    @click="confirmPurchaseTraining(service.type, service)"
  >
    {{ t('BILLING_SETTINGS.TRAINING.PURCHASE_BUTTON') }}
  </ButtonV4>
</div>
```

#### C. Update Confirmation Modal

Update the confirmation modal at the bottom to handle removal:

```vue
<!-- Confirmation Modal -->
<ConfirmationModal
  ref="confirmationModal"
  :title="
    pendingPurchase.action === 'remove'
      ? t('BILLING_SETTINGS.TRAINING.CONFIRM_REMOVE_TITLE')
      : t('BILLING_SETTINGS.TRAINING.CONFIRM_PURCHASE_TITLE')
  "
  :description="
    pendingPurchase.action === 'remove'
      ? t('BILLING_SETTINGS.TRAINING.CONFIRM_REMOVE_DESCRIPTION', {
          item: pendingPurchase.name,
          credit: pendingPurchase.estimatedCredit,
        })
      : t('BILLING_SETTINGS.TRAINING.CONFIRM_PURCHASE_DESCRIPTION', {
          item: pendingPurchase.name,
          price: pendingPurchase.price,
        })
  "
  :confirm-label="
    pendingPurchase.action === 'remove'
      ? t('BILLING_SETTINGS.TRAINING.CONFIRM_REMOVE_BUTTON')
      : t('BILLING_SETTINGS.TRAINING.CONFIRM_PURCHASE_BUTTON')
  "
  :cancel-label="
    pendingPurchase.action === 'remove'
      ? t('BILLING_SETTINGS.TRAINING.CANCEL_REMOVE_BUTTON')
      : t('BILLING_SETTINGS.TRAINING.CANCEL_PURCHASE_BUTTON')
  "
/>
```

---

### 3. Add i18n Translation Keys

**Files to Update:**
- `app/javascript/dashboard/i18n/locale/en/settings.json`
- `config/locales/en.yml` (for backend, if needed)

#### English Translations (settings.json)

Add these keys to the `BILLING_SETTINGS.LIMITS` section:

```json
{
  "BILLING_SETTINGS": {
    "LIMITS": {
      "REMOVE_ONE": "Remove 1",
      "REMOVE_ALL": "Remove All",
      "REMOVE_SUCCESS": "Successfully removed 1 {item}",
      "REMOVE_ALL_SUCCESS": "Successfully removed all {item}s",
      "REMOVE_ERROR": "Failed to remove {item}: {error}",
      "CONFIRM_REMOVE_TITLE": "Remove Add-on",
      "CONFIRM_REMOVE_DESCRIPTION": "Remove 1 {item}? You'll receive approximately {credit} credit for the unused time on your next invoice.",
      "CONFIRM_REMOVE_ALL_TITLE": "Remove All Add-ons",
      "CONFIRM_REMOVE_ALL_DESCRIPTION": "Remove all {quantity} {item}(s)? You'll receive approximately {credit} credit for the unused time on your next invoice.",
      "CONFIRM_REMOVE_BUTTON": "Yes, Remove",
      "CANCEL_BUTTON": "Cancel"
    },
    "TRAINING": {
      "CANCEL_BUTTON": "Cancel Training",
      "REMOVE_SUCCESS": "Training service cancelled successfully. You'll receive a credit for unused time.",
      "REMOVE_ERROR": "Failed to cancel training service. Please try again.",
      "CONFIRM_REMOVE_TITLE": "Cancel Training Service",
      "CONFIRM_REMOVE_DESCRIPTION": "Cancel {item}? You'll receive approximately {credit} credit for the unused time on your next invoice. This action cannot be undone, but you can re-purchase the service later.",
      "CONFIRM_REMOVE_BUTTON": "Yes, Cancel Training",
      "CANCEL_REMOVE_BUTTON": "Keep Training"
    }
  }
}
```

#### Spanish Translations (settings.json)

Add corresponding Spanish translations to `es/settings.json`:

```json
{
  "BILLING_SETTINGS": {
    "LIMITS": {
      "REMOVE_ONE": "Eliminar 1",
      "REMOVE_ALL": "Eliminar Todo",
      "REMOVE_SUCCESS": "Se eliminó exitosamente 1 {item}",
      "REMOVE_ALL_SUCCESS": "Se eliminaron exitosamente todos los {item}s",
      "REMOVE_ERROR": "Error al eliminar {item}: {error}",
      "CONFIRM_REMOVE_TITLE": "Eliminar Complemento",
      "CONFIRM_REMOVE_DESCRIPTION": "¿Eliminar 1 {item}? Recibirás aproximadamente {credit} de crédito por el tiempo no utilizado en tu próxima factura.",
      "CONFIRM_REMOVE_ALL_TITLE": "Eliminar Todos los Complementos",
      "CONFIRM_REMOVE_ALL_DESCRIPTION": "¿Eliminar los {quantity} {item}(s)? Recibirás aproximadamente {credit} de crédito por el tiempo no utilizado en tu próxima factura.",
      "CONFIRM_REMOVE_BUTTON": "Sí, Eliminar",
      "CANCEL_BUTTON": "Cancelar"
    },
    "TRAINING": {
      "CANCEL_BUTTON": "Cancelar Capacitación",
      "REMOVE_SUCCESS": "Servicio de capacitación cancelado exitosamente. Recibirás un crédito por el tiempo no utilizado.",
      "REMOVE_ERROR": "Error al cancelar el servicio de capacitación. Por favor intenta de nuevo.",
      "CONFIRM_REMOVE_TITLE": "Cancelar Servicio de Capacitación",
      "CONFIRM_REMOVE_DESCRIPTION": "¿Cancelar {item}? Recibirás aproximadamente {credit} de crédito por el tiempo no utilizado en tu próxima factura. Esta acción no se puede deshacer, pero puedes volver a comprar el servicio más tarde.",
      "CONFIRM_REMOVE_BUTTON": "Sí, Cancelar Capacitación",
      "CANCEL_REMOVE_BUTTON": "Mantener Capacitación"
    }
  }
}
```

---

### 4. Vuex Store Actions

#### A. Existing Action (Already Works!)

**Great News:** The `accounts/purchaseAddOn` action already supports removal!

**Current Implementation** (`app/javascript/dashboard/store/modules/accounts.js:254-269`):

```javascript
purchaseAddOn: async (_, { add_on_type, action, quantity = null }) => {
  try {
    const response = await BillingAPI.updateAddOn(
      add_on_type,
      action,
      quantity
    );
    if (response.data.success) {
      return response;
    }
    throw new Error(response.data.error || 'Failed to purchase add-on');
  } catch (error) {
    throwErrorMessage(error);
    throw error;
  }
},
```

**Actions supported:**
- `action: 'add'` - Add 1 unit
- `action: 'remove'` - Remove 1 unit  ✅ (we'll use this)
- `action: 'set'` - Set to specific quantity ✅ (we'll use this with quantity: 0)

---

#### B. New Action Required: Preview Removal

**Add this new action** to `app/javascript/dashboard/store/modules/accounts.js`:

```javascript
/**
 * Preview add-on removal to get accurate credit amount from Stripe
 * Uses Stripe Invoice Preview API for exact proration calculations
 */
previewAddOnRemoval: async (_, { add_on_type, action, quantity = null }) => {
  try {
    const response = await BillingAPI.previewAddOnRemoval(
      add_on_type,
      action,
      quantity
    );
    if (response.data.success) {
      return response;
    }
    throw new Error(response.data.error || 'Failed to preview removal');
  } catch (error) {
    // Don't show error toast for preview failures
    // Just log and let the component handle it gracefully
    console.error('Preview add-on removal failed:', error);
    throw error;
  }
},
```

---

#### C. Add BillingAPI Method

**Add this method** to `app/javascript/dashboard/api/v2/billing.js`:

```javascript
// Preview add-on removal (for credit calculation)
previewAddOnRemoval(addOnType, action, quantity = null) {
  const payload = {
    add_on_type: addOnType,
    action: action,
  };
  if (quantity !== null) {
    payload.quantity = quantity;
  }
  return axios.post(`${this.url}billing/add_ons/preview`, payload);
}
```

---

### 5. Backend: Add Preview Endpoint

**Create new endpoint** `POST /api/v2/accounts/:account_id/billing/add_ons/preview`

**File:** `app/controllers/api/v2/accounts/billing/add_ons_controller.rb`

**Add this method:**

```ruby
# POST /api/v2/accounts/:account_id/billing/add_ons/preview
# Preview removal to calculate exact credit amount using Stripe Invoice Preview API
def preview
  add_on_type = params[:add_on_type]
  action_type = params[:action] || params[:action_type]
  quantity = params[:quantity]&.to_i

  # Validate add-on type
  unless Billing::ManageSubscriptionAddOnService::ADD_ON_TYPES.include?(add_on_type)
    return render json: { 
      success: false, 
      error: 'Invalid add-on type' 
    }, status: :bad_request
  end

  service = Billing::PreviewAddOnRemovalService.new(
    Current.account,
    add_on_type,
    action_type,
    quantity
  )

  result = service.preview_removal

  if result[:success]
    render json: {
      success: true,
      estimated_credit: result[:estimated_credit],
      details: result[:details]
    }
  else
    render json: {
      success: false,
      error: result[:error]
    }, status: :unprocessable_entity
  end
rescue StandardError => e
  Rails.logger.error "Preview add-on removal error: #{e.message}"
  Sentry.capture_exception(e) if defined?(Sentry)
  
  render json: {
    success: false,
    error: 'Failed to preview removal'
  }, status: :internal_server_error
end
```

**Update routes** in `config/routes.rb`:

```ruby
namespace :billing do
  resource :add_ons, only: [:index, :update] do
    get :index, on: :collection
    post :update, on: :collection
    post :preview, on: :collection  # Add this line
    get :limits, on: :collection
    get :breakdown, on: :collection
  end
end
```

---

### 6. Backend: Create Preview Service

**Create new file:** `app/services/billing/preview_add_on_removal_service.rb`

```ruby
# frozen_string_literal: true

class Billing::PreviewAddOnRemovalService
  def initialize(account, add_on_type, action_type, quantity = nil)
    @account = account
    @add_on_type = add_on_type
    @action_type = action_type
    @quantity = quantity
  end

  def preview_removal
    # Get current subscription
    stripe_subscription_id = @account.custom_attributes&.dig('stripe_subscription_id')
    
    unless stripe_subscription_id
      return { success: false, error: 'No active subscription found' }
    end

    # Fetch current subscription from Stripe
    subscription = ::Stripe::Subscription.retrieve(stripe_subscription_id)
    
    # Find the subscription item for this add-on
    add_on_service = Billing::ManageSubscriptionAddOnService.new(@account, @add_on_type)
    config = add_on_service.send(:add_on_config)
    lookup_key = config['lookup_key']
    
    subscription_item = subscription.items.data.find do |item|
      item.price.lookup_key == lookup_key
    end

    unless subscription_item
      return { success: false, error: 'Add-on not found in subscription' }
    end

    # Calculate new quantity
    current_quantity = subscription_item.quantity
    new_quantity = calculate_new_quantity(current_quantity)

    # Preview the invoice with the change
    credit_amount = preview_invoice_with_removal(
      subscription_id: subscription.id,
      subscription_item_id: subscription_item.id,
      new_quantity: new_quantity
    )

    {
      success: true,
      estimated_credit: format_currency(credit_amount),
      details: {
        current_quantity: current_quantity,
        new_quantity: new_quantity,
        credit_amount_cents: credit_amount
      }
    }
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Stripe error previewing removal: #{e.message}"
    { success: false, error: e.message }
  rescue StandardError => e
    Rails.logger.error "Error previewing removal: #{e.message}"
    { success: false, error: 'Failed to calculate credit' }
  end

  private

  def calculate_new_quantity(current_quantity)
    case @action_type
    when 'remove'
      [current_quantity - 1, 0].max
    when 'set'
      @quantity || 0
    else
      current_quantity
    end
  end

  def preview_invoice_with_removal(subscription_id:, subscription_item_id:, new_quantity:)
    # Use Stripe Invoice Preview API to get exact proration
    preview_invoice = if new_quantity.zero?
                        # Preview with item deleted
                        ::Stripe::Invoice.create_preview(
                          subscription: subscription_id,
                          subscription_items: [
                            {
                              id: subscription_item_id,
                              deleted: true
                            }
                          ],
                          subscription_details: {
                            proration_behavior: 'create_prorations',
                            proration_date: Time.current.to_i
                          }
                        )
                      else
                        # Preview with reduced quantity
                        ::Stripe::Invoice.create_preview(
                          subscription: subscription_id,
                          subscription_items: [
                            {
                              id: subscription_item_id,
                              quantity: new_quantity
                            }
                          ],
                          subscription_details: {
                            proration_behavior: 'create_prorations',
                            proration_date: Time.current.to_i
                          }
                        )
                      end

    # Find credit proration line items (negative amounts)
    credit_lines = preview_invoice.lines.data.select do |line|
      line.proration && line.amount.negative?
    end

    # Sum up all credit amounts (they're negative, so we'll make them positive)
    total_credit = credit_lines.sum { |line| line.amount.abs }
    
    total_credit
  end

  def format_currency(amount_cents)
    return '$0.00' if amount_cents.zero?

    # Convert cents to dollars
    dollars = amount_cents / 100.0
    format('$%.2f', dollars)
  end
end
```

**Key Points:**

1. **Uses Stripe Invoice Preview API** - Gets exact proration from Stripe
2. **Handles actual billing cycle** - No hardcoded 30-day months
3. **Prorates to the second** - Just like actual Stripe proration
4. **Handles discounts/taxes** - Included in Stripe's calculation
5. **Graceful fallback** - If preview fails, removal still works (just no credit preview)

---

### 7. UI Mockup Examples

#### Before (Current State)

```
┌─────────────────────────────────────────────┐
│ Agents                                      │
│                                             │
│ Base Included: 5                            │
│ Extra Purchased: 3                          │
│ Currently Using: 7                          │
│ Available: 1                                │
│                                             │
│               [Purchase Extra Agent - $10/month] │
└─────────────────────────────────────────────┘
```

#### After (With Removal Controls)

```
┌─────────────────────────────────────────────┐
│ Agents                                      │
│                                             │
│ Base Included: 5                            │
│ Extra Purchased: 3                          │
│ Currently Using: 7                          │
│ Available: 1                                │
│                                             │
│ [Remove 1] [Remove All]   [Purchase Extra Agent - $10/month] │
└─────────────────────────────────────────────┘
```

#### Training Services - Before

```
┌─────────────────────────────────────────────┐
│ Live Group Training                 $299/month │
│ Monthly group training session              │
│                                             │
│ ✓ Already Purchased                         │
└─────────────────────────────────────────────┘
```

#### Training Services - After

```
┌─────────────────────────────────────────────┐
│ Live Group Training                 $299/month │
│ Monthly group training session              │
│                                             │
│ ✓ Already Purchased     [Cancel Training]  │
└─────────────────────────────────────────────┘
```

#### Confirmation Modal (with credit preview)

```
┌───────────────────────────────────────────┐
│ Remove Add-on                             │
│                                           │
│ Remove 1 Agent? You'll receive            │
│ approximately $5.16 credit for the        │
│ unused time on your next invoice.         │
│                                           │
│         [Cancel]    [Yes, Remove]         │
└───────────────────────────────────────────┘
```

---

### 8. Implementation Checklist

Use this checklist to track implementation progress:

#### BillingLimitsCard.vue
- [ ] Add `removeAddOn` method
- [ ] Add `removeAllAddOns` method
- [ ] Add `confirmRemove` method
- [ ] Add `confirmRemoveAll` method
- [ ] Update agent section template with remove buttons
- [ ] Update inbox section template with remove buttons
- [ ] Update confirmation modal to handle removal actions
- [ ] Test: Remove 1 agent works
- [ ] Test: Remove all agents works
- [ ] Test: Remove 1 inbox works
- [ ] Test: Remove all inboxes works
- [ ] Test: Buttons disabled when purchased = 0
- [ ] Test: Buttons disabled during loading
- [ ] Test: Credit calculation shows in modal
- [ ] Test: Success notifications appear
- [ ] Test: Error notifications appear

#### BillingTrainingCard.vue
- [ ] Add `removeTraining` method
- [ ] Add `confirmRemoveTraining` method
- [ ] Update template to show cancel button when owned
- [ ] Update confirmation modal to handle removal
- [ ] Test: Cancel live training works
- [ ] Test: Cancel 1:1 training works
- [ ] Test: Button shows loading state
- [ ] Test: Credit calculation shows in modal
- [ ] Test: Success notifications appear
- [ ] Test: Error notifications appear
- [ ] Test: Can re-purchase after removal

#### i18n Translations
- [ ] Add English translations to `en/settings.json`
- [ ] Add Spanish translations to `es/settings.json`
- [ ] Test: All labels display correctly in English
- [ ] Test: All labels display correctly in Spanish
- [ ] Test: Confirmation modals use correct translations
- [ ] Test: Notifications use correct translations

#### Vuex Store & API
- [ ] Add `previewAddOnRemoval` action to Vuex store
- [ ] Add `previewAddOnRemoval` method to BillingAPI
- [ ] Test: Preview action returns credit amount
- [ ] Test: Preview action handles errors gracefully

#### Backend Preview Endpoint
- [ ] Create `Billing::PreviewAddOnRemovalService`
- [ ] Add `preview` action to `AddOnsController`
- [ ] Add route for preview endpoint
- [ ] Test: Preview returns accurate credit amounts
- [ ] Test: Preview handles missing subscription
- [ ] Test: Preview handles Stripe API errors
- [ ] Test: Credit calculation matches actual removal

#### Integration Testing
- [ ] Remove agent → verify subscription updated in Stripe
- [ ] Remove agent → verify credit appears on next invoice
- [ ] Remove all inboxes → verify subscription items deleted
- [ ] Cancel training → verify webhook updates local database
- [ ] Remove when quantity = 0 → verify error handled gracefully
- [ ] Remove during network error → verify error notification
- [ ] Multiple rapid clicks → verify request deduplication works
- [ ] Remove → refresh page → verify state persists correctly

#### Edge Cases
- [ ] User has 0 purchased add-ons → remove buttons hidden
- [ ] User removes last agent → verify can still re-purchase
- [ ] User removes during billing period transition → verify proration correct
- [ ] User removes immediately after purchase → verify ~100% credit
- [ ] User removes at end of period → verify minimal credit
- [ ] Stripe API returns error → verify user sees friendly message
- [ ] Webhook delayed → verify UI eventually syncs
- [ ] User in trial period → verify removal works correctly

---

### 9. Testing Strategy

#### Manual Testing

**Test 1: Remove Single Agent**
1. Navigate to Billing Settings → Usage Limits
2. Verify you have at least 1 extra agent purchased
3. Click "Remove 1" button under Agents section
4. Verify confirmation modal shows:
   - Title: "Remove Add-on"
   - Description includes estimated credit amount
5. Click "Yes, Remove"
6. Verify success notification appears
7. Verify "Extra Purchased" count decreases by 1
8. Check Stripe Dashboard → verify subscription item quantity reduced
9. Check next invoice → verify credit line item appears

**Test 2: Remove All Inboxes**
1. Navigate to Billing Settings → Usage Limits
2. Purchase 2 extra inboxes (if not already owned)
3. Click "Remove All" button under Inboxes section
4. Verify confirmation modal shows:
   - Quantity (e.g., "Remove all 2 Inbox(es)")
   - Total estimated credit
5. Click "Yes, Remove"
6. Verify success notification appears
7. Verify "Extra Purchased" shows 0
8. Verify "Remove 1" and "Remove All" buttons disappear
9. Check Stripe Dashboard → verify subscription item deleted
10. Check next invoice → verify credit line item appears

**Test 3: Cancel Training Service**
1. Navigate to Billing Settings → scroll to Training Services
2. Purchase "Live Group Training" (if not already owned)
3. Verify it shows "✓ Already Purchased" with "Cancel Training" button
4. Click "Cancel Training"
5. Verify confirmation modal shows:
   - Warning about action being permanent
   - Estimated credit amount
6. Click "Yes, Cancel Training"
7. Verify success notification appears
8. Verify button changes back to "Purchase" button
9. Check Stripe Dashboard → verify subscription item removed
10. Check next invoice → verify credit line item appears

**Test 4: Credit Preview Accuracy**
1. Purchase 1 extra agent on the 1st of the month
2. Wait until the 15th (halfway through month)
3. Click "Remove 1" button
4. Verify confirmation modal shows credit ~50% of monthly price
5. Cancel the removal
6. Wait until the last day of the month
7. Click "Remove 1" button again
8. Verify confirmation modal shows much smaller credit (only 1-2 days remaining)
9. Complete the removal
10. Check Stripe invoice → verify actual credit matches preview

**Test 5: Error Handling**
1. Attempt to remove when quantity is already 0
2. Verify error notification appears
3. Verify user-friendly message (not technical error)

#### Automated Testing (Optional)

If you want to add Vitest tests:

```javascript
// BillingLimitsCard.spec.js
import { mount } from '@vue/test-utils';
import { describe, it, expect, vi } from 'vitest';
import BillingLimitsCard from './BillingLimitsCard.vue';

describe('BillingLimitsCard - Removal', () => {
  it('shows remove buttons when purchased > 0', async () => {
    const wrapper = mount(BillingLimitsCard, {
      // ... setup with purchased: 2
    });
    
    expect(wrapper.find('[data-testid="remove-one-agent"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="remove-all-agent"]').exists()).toBe(true);
  });
  
  it('hides remove buttons when purchased = 0', async () => {
    const wrapper = mount(BillingLimitsCard, {
      // ... setup with purchased: 0
    });
    
    expect(wrapper.find('[data-testid="remove-one-agent"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="remove-all-agent"]').exists()).toBe(false);
  });
  
  it('calls removeAddOn with correct parameters', async () => {
    const mockDispatch = vi.fn();
    const wrapper = mount(BillingLimitsCard, {
      // ... setup with mocked store
    });
    
    await wrapper.find('[data-testid="remove-one-agent"]').trigger('click');
    await wrapper.find('[data-testid="confirm-button"]').trigger('click');
    
    expect(mockDispatch).toHaveBeenCalledWith('accounts/purchaseAddOn', {
      add_on_type: 'agent',
      action: 'remove',
    });
  });
});
```

---

### 10. Common Issues & Solutions

#### Issue 1: Remove buttons not showing

**Symptoms:** Buttons never appear even when purchased > 0

**Solution:**
- Check that `limits.value.agent.purchased` or `limits.value.inbox.purchased` has correct value
- Verify `fetchLimits()` is called successfully on mount
- Check browser console for API errors

#### Issue 2: "Cannot remove below 0" error

**Symptoms:** User clicks remove and gets error even though purchased > 0

**Solution:**
- Backend validates current quantity before removal
- Ensure `fetchLimits()` is called AFTER each purchase/removal to sync state
- Check if multiple clicks triggered multiple removals

#### Issue 3: Credit amount not appearing on invoice

**Symptoms:** Item removed but no credit on next invoice

**Solution:**
- Verify `proration_behavior: 'create_prorations'` is set in backend
- Check Stripe Dashboard → Invoice → verify credit line item exists
- Credits might be applied to account balance instead of invoice (check customer balance)

#### Issue 4: Remove button still enabled after removing all

**Symptoms:** Can still click remove when purchased = 0

**Solution:**
- Ensure `v-if="agentLimit.purchased > 0"` wraps the remove buttons
- Force re-render by adding `:key="agentLimit.purchased"` to parent div

#### Issue 5: Confirmation modal shows wrong text

**Symptoms:** Modal shows purchase text when removing

**Solution:**
- Ensure `pendingPurchase.value.action` is set to 'remove' or 'remove_all'
- Check ternary operators in modal props use correct conditions

#### Issue 6: Credit preview shows "calculating..." forever

**Symptoms:** Modal shows "calculating..." instead of credit amount

**Solution:**
- Check browser console for API errors
- Verify `POST /api/v2/accounts/:id/billing/add_ons/preview` endpoint exists
- Verify `Billing::PreviewAddOnRemovalService` is created
- Check Stripe API key is valid
- If preview fails, removal still works (just without credit preview)

#### Issue 7: Preview credit doesn't match actual credit

**Symptoms:** Preview shows $5 but actual invoice shows $4.83

**Solution:**
- Small differences are normal due to timing (Stripe prorates to the second)
- Preview uses `proration_date: Time.current.to_i` 
- Actual removal happens seconds/minutes later
- Difference should be < $0.50 for monthly items
- If difference is large, check Stripe Dashboard for discounts/taxes

---

## Enhancements
### 1. Removal Reason Tracking

**Feature:** Track why users remove add-ons

```ruby
{
  "add_on_type": "live_training",
  "action_type": "set",
  "quantity": 0,
  "reason": "too_expensive",  # or "not_needed", "switching_plans", etc.
  "feedback": "Would reconsider if price was lower"
}
```

**Benefit:** Product insights, customer feedback, churn analysis

---

## Related Documentation

**Internal Documentation:**
- [StripeImprovements.md](./StripeImprovements.md) - Original audit and improvements
- [StripeImplementationAudit.md](./StripeImplementationAudit.md) - Implementation verification
- [billing_plans.yml](../../config/billing_plans.yml) - Plan and add-on configuration

**Stripe Official Documentation:**
- [Delete a subscription item](https://docs.stripe.com/api/subscription_items/delete)
- [Update a subscription item](https://docs.stripe.com/api/subscription_items/update)
- [Proration behavior](https://docs.stripe.com/billing/subscriptions/prorations)
- [Cancel subscriptions](https://docs.stripe.com/billing/subscriptions/cancel)
- [Subscription schedules](https://docs.stripe.com/billing/subscriptions/subscription-schedules)

**Code References:**
- Service: `app/services/billing/manage_subscription_add_on_service.rb`
- Controller: `app/controllers/api/v2/accounts/billing/add_ons_controller.rb`
- Routes: `config/routes.rb` (lines 403-414)
- Webhook Handler: `app/services/billing/providers/stripe.rb` (lines 133-167)

---

## Conclusion

### Key Takeaways

✅ **Product removal is already fully functional** in the Chatwoot billing system

✅ **Implementation follows Stripe best practices:**
- Uses `proration_behavior: 'create_prorations'`
- Deletes subscription items when quantity = 0
- Comprehensive error handling
- Webhook-driven database updates
- **Uses Stripe Invoice Preview API for accurate credit calculations**

✅ **Three removal methods available:**
- `action_type: 'remove'` - Decrement by 1
- `action_type: 'set', quantity: 0` - Remove all
- `action_type: 'set', quantity: N` - Set to specific amount

✅ **Automatic proration ensures fair credits** for unused time

✅ **Credit preview powered by Stripe:**
- No hardcoded 30-day months
- Handles actual billing cycle length
- Prorates to the second (just like actual removal)
- Includes discounts, taxes, and other adjustments

### What Users Need

**For immediate use:**
1. **Backend:** Create `PreviewAddOnRemovalService` and add preview endpoint
2. **Frontend:** Add Vuex action and BillingAPI method for preview
3. **Frontend:** Implement removal controls in BillingLimitsCard & BillingTrainingCard
4. **Frontend:** Update confirmation modals to show Stripe-calculated credits
5. **i18n:** Add translation keys for removal UI
6. **Testing:** Verify credit preview accuracy matches actual credits