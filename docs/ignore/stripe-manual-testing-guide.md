# Stripe Billing Implementation - Manual Testing Guide

## Current Setup Verification

✅ **Your Account Status:**
- **Account ID:** 2
- **Plan:** starter
- **Subscription Status:** active
- **Stripe Customer ID:** cus_TMHmLZpIomWphR

---

## Testing Environment

### Prerequisites
1. ✅ Docker environment running
2. ✅ Stripe configured with test mode keys
3. ✅ Starter plan subscription active
4. Access to Stripe Dashboard (test mode): https://dashboard.stripe.com/test/

### Access the Billing UI
1. Navigate to **Settings > Billing** in Chatwoot
2. You should see:
   - Current plan card (Starter)
   - Limits card showing usage/limits for agents, inboxes, conversations
   - Training services card
   - Manage subscription button

---

## Test Scenarios

### 1. Test: Buy Extra Seats (Agents)

#### What Happens
- Adds 1 extra agent to your subscription
- Creates a new subscription item in Stripe
- Prorates the charge for the current billing period
- Updates your monthly recurring amount

#### Steps to Test

**In Chatwoot UI:**
1. Go to **Settings > Billing**
2. Scroll to **"Limits & Usage"** card
3. Find the **"Agents"** section
4. Note the current usage (e.g., "2 / 5")
5. Click **"Purchase Extra Seat"** button
6. Wait for success message

**Expected Behavior:**
- Button shows loading state
- Success message appears
- Limits update immediately (e.g., "2 / 6")
- Purchase button remains enabled for buying more

#### Verify in Stripe Dashboard

1. Go to: https://dashboard.stripe.com/test/customers/cus_TMHmLZpIomWphR
2. Click on the **active subscription**
3. Check **Subscription Items:**
   ```
   ✓ Starter Base Plan (price_starter_base) × 1
   ✓ Extra Agent - Starter (extra_agent_starter) × 1  ← NEW ITEM
   ```
4. Check **Billing details:**
   - Should see prorated charge for current period
   - Monthly amount increased by agent price (e.g., $10/month)

#### API Verification (Optional)

```bash
# From your terminal
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :agent)
  puts 'Current agent add-ons: ' + service.current_quantity.to_s
  info = service.add_on_info
  puts 'Unit price: ' + info[:unit_price_formatted]
"
```

---

### 2. Test: Buy Extra Inboxes

#### What Happens
- Adds 1 extra inbox to your subscription
- Creates subscription item with lookup_key `extra_inbox_starter`
- Prorates and increases monthly bill

#### Steps to Test

**In Chatwoot UI:**
1. Go to **Settings > Billing**
2. In **"Limits & Usage"** card, find **"Inboxes"** section
3. Note current usage (e.g., "1 / 2")
4. Click **"Purchase Extra Inbox"** button
5. Wait for confirmation

**Expected Behavior:**
- Loading state on button
- Success message
- Limit updates (e.g., "1 / 3")

#### Verify in Stripe Dashboard

1. Customer page: https://dashboard.stripe.com/test/customers/cus_TMHmLZpIomWphR
2. Click subscription → **Items** tab:
   ```
   ✓ Starter Base Plan × 1
   ✓ Extra Agent - Starter × 1 (from previous test)
   ✓ Extra Inbox - Starter (extra_inbox_starter) × 1  ← NEW ITEM
   ```
3. Check **Upcoming Invoice:**
   - Base plan: $30
   - Extra agents: $10 × 1 = $10
   - Extra inboxes: $15 × 1 = $15
   - **Total: $55/month**

---

### 3. Test: Buy Extra Conversations

#### What Happens
- Purchases a **one-time conversation pack** (not recurring)
- Creates an immediate invoice (not added to subscription)
- Adds 10,000 conversations to your account quota
- Updates `custom_attributes.extra_conversations_purchased`

#### Steps to Test

**In Chatwoot UI:**
1. Go to **Settings > Billing**
2. In **"Limits & Usage"** card, find **"Conversations"** section
3. Note current usage (e.g., "150 / 4,000")
4. Click **"Buy Conversation Pack"** button
5. Confirm purchase

**Expected Behavior:**
- Success message: "10,000 Conversation Pack purchased successfully"
- Total allowed conversations increases (4,000 → 14,000)
- No change to monthly subscription amount (one-time purchase)

#### Verify in Stripe Dashboard

**Important:** Conversation packs create **invoices**, not subscription items.

1. Go to: https://dashboard.stripe.com/test/customers/cus_TMHmLZpIomWphR
2. Click **Invoices** tab
3. Find the latest invoice:
   ```
   Invoice: "Conversation Pack Purchase"
   Description: "10,000 Conversation Pack"
   Amount: $20.00 (one-time)
   Status: Paid
   ```
4. **Verify subscription NOT affected:**
   - Monthly amount stays same ($55 from previous tests)
   - No new subscription item added

#### Verify in Database

```bash
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  extra = account.custom_attributes['extra_conversations_purchased'] || 0
  puts 'Extra conversations purchased: ' + extra.to_s
  puts 'Last reset: ' + (account.custom_attributes['conversations_last_reset'] || 'never').to_s
"
```

---

### 4. Test: Buy Live Training

#### What Happens
- Purchases **Live Training** service (max 1 per account)
- Adds to subscription as recurring item
- Product metadata from Stripe populates UI details

#### Steps to Test

**In Chatwoot UI:**
1. Go to **Settings > Billing**
2. Scroll to **"Training Services"** card
3. Find **"Live Training"** section
4. Should show:
   - Name from Stripe product metadata
   - Price (e.g., $499/month)
   - Feature bullets from Stripe metadata
   - "Purchase" button (enabled)
5. Click **"Purchase"** button

**Expected Behavior:**
- Button shows loading state
- Success message appears
- Button changes to **"Purchased"** and becomes disabled
- Cannot purchase again (max_quantity: 1)

#### Verify in Stripe Dashboard

1. Customer subscription: https://dashboard.stripe.com/test/customers/cus_TMHmLZpIomWphR
2. Check **Subscription Items:**
   ```
   ✓ Starter Base Plan × 1
   ✓ Extra Agent - Starter × 1
   ✓ Extra Inbox - Starter × 1
   ✓ Live Training (live_training_pricing) × 1  ← NEW ITEM
   ```
3. Check **Monthly Amount:**
   - Previous: $55
   - Live Training: +$499
   - **New Total: $554/month**

#### Verify Product Metadata

1. Go to: https://dashboard.stripe.com/test/products
2. Search for "Live Training"
3. Click product → **Product Details**
4. Check **Metadata** tab for:
   ```
   bullet_1: "2 hour live session"
   bullet_2: "Team onboarding"
   bullet_3: "Best practices"
   ... etc
   ```

---

### 5. Test: Buy Live 1:1 Training

#### What Happens
- Purchases **Live 1:1 Training** service (max 1 per account)
- Separate from regular Live Training
- Adds to subscription

#### Steps to Test

**In Chatwoot UI:**
1. Go to **Settings > Billing**
2. In **"Training Services"** card, find **"Live 1:1 Training"** section
3. Note the price (e.g., $799/month)
4. Click **"Purchase"** button

**Expected Behavior:**
- Loading state
- Success message
- Button disabled after purchase
- Shows "Purchased" state

#### Verify in Stripe Dashboard

1. Subscription items should now show:
   ```
   ✓ Starter Base Plan × 1
   ✓ Extra Agent - Starter × 1
   ✓ Extra Inbox - Starter × 1
   ✓ Live Training × 1
   ✓ Live 1:1 Training (live_1_1_training_pricing) × 1  ← NEW ITEM
   ```

2. **Final Monthly Total:**
   - Base: $30
   - Extra agent: $10
   - Extra inbox: $15
   - Live Training: $499
   - Live 1:1 Training: $799
   - **Grand Total: $1,353/month**

---

## Verification Checklist

After completing all 5 tests, verify:

### In Chatwoot UI (Settings > Billing)

- [ ] **Agents:** Limit increased by 1 (5 → 6)
- [ ] **Inboxes:** Limit increased by 1 (2 → 3)
- [ ] **Conversations:** Total allowed increased by 10,000 (4,000 → 14,000)
- [ ] **Live Training:** Shows "Purchased" (button disabled)
- [ ] **Live 1:1 Training:** Shows "Purchased" (button disabled)

### In Stripe Dashboard

**Subscription Items:**
- [ ] 1× Starter Base Plan
- [ ] 1× Extra Agent - Starter
- [ ] 1× Extra Inbox - Starter
- [ ] 1× Live Training
- [ ] 1× Live 1:1 Training

**Invoices:**
- [ ] Latest recurring invoice shows all subscription items
- [ ] Separate one-time invoice for "10,000 Conversation Pack"

**Metadata:**
- [ ] All prices have correct `lookup_key` metadata
- [ ] Training products have `bullet_1`, `bullet_2`, etc. metadata

---

## Edge Cases to Test

### 6. Test: Try to Buy Live Training Again

**Expected Behavior:**
- Button should be **disabled** after first purchase
- Shows "Purchased" state
- UI prevents duplicate purchase

**Verify:**
```bash
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_training)
  info = service.add_on_info
  puts 'Max quantity: ' + info[:max_quantity].to_s
  puts 'Current quantity: ' + service.current_quantity.to_s
  puts 'Can purchase: ' + info[:can_purchase].to_s
"
```

Should output:
```
Max quantity: 1
Current quantity: 1
Can purchase: false
```

---

### 7. Test: Remove an Extra Agent

**Via API:**
```bash
# Get current account ID and access token from browser DevTools
# Then use curl or Postman:

curl -X POST 'http://localhost:3000/api/v2/accounts/2/billing/add_ons' \
  -H 'Content-Type: application/json' \
  -H 'api_access_token: YOUR_TOKEN' \
  -d '{
    "add_on_type": "agent",
    "action": "remove"
  }'
```

**Expected in Stripe:**
- Subscription item quantity: 1 → 0 (item removed)
- Prorated credit applied
- Monthly total reduced

---

### 8. Test: Set Specific Quantity (Multiple Agents at Once)

**Via API:**
```bash
curl -X POST 'http://localhost:3000/api/v2/accounts/2/billing/add_ons' \
  -H 'Content-Type: application/json' \
  -H 'api_access_token: YOUR_TOKEN' \
  -d '{
    "add_on_type": "agent",
    "action": "set",
    "quantity": 5
  }'
```

**Verify in Stripe:**
- Extra Agent item quantity jumps to 5
- Proration applied for difference
- Monthly total: Base + (5 × $10) + other items

---

### 9. Test: Payment Failure (Card Decline)

**Setup:**
1. Go to Stripe Dashboard → **Customer**
2. Click **Payment Methods**
3. Add test card: `4000 0000 0000 0341` (card_declined)
4. Set as default payment method

**Test:**
- Try purchasing any add-on
- **Expected:** Error message displayed in UI
- Invoice shows "Payment Failed"

**Cleanup:**
- Remove declined card
- Re-add working test card: `4242 4242 4242 4242`

---

### 10. Test: Subscription Prorations

**Verify Prorations are Created:**

1. Go to Stripe subscription
2. Click **"Billing" tab**
3. Check **"Upcoming Invoice"**
4. Should show:
   ```
   Proration for Extra Agent (Jan 15 - Jan 31): $5.00
   Remaining period for Starter Plan: $25.00
   ...
   ```

**Key Points:**
- Prorations calculated based on days remaining in billing period
- `proration_behavior: 'create_prorations'` is set in service
- Credits/charges appear immediately on invoice preview

---

## API Endpoints Reference

### Get Add-On Status

```bash
# GET /api/v2/accounts/:account_id/billing/add_ons
curl -H "api_access_token: TOKEN" \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons
```

**Response:**
```json
{
  "success": true,
  "data": {
    "account_id": 2,
    "plan_name": "starter",
    "add_ons": {
      "agent": {
        "current_quantity": 1,
        "unit_price_formatted": "$10.00",
        "unit_price_cents": 1000,
        "currency": "USD",
        "lookup_key": "extra_agent_starter"
      },
      "inbox": { ... },
      "channel": { ... }
    },
    "training_services": {
      "live_training": {
        "current_quantity": 1,
        "max_quantity": 1,
        "can_purchase": false,
        "unit_price_formatted": "$499.00",
        ...
      }
    }
  }
}
```

---

### Get Current Limits

```bash
# GET /api/v2/accounts/:account_id/billing/add_ons/limits
curl -H "api_access_token: TOKEN" \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons/limits
```

**Response:**
```json
{
  "success": true,
  "data": {
    "limits": {
      "agent": {
        "current": 2,
        "base_limit": 5,
        "purchased": 1,
        "total_allowed": 6,
        "can_create": true
      },
      "conversation": {
        "current": 150,
        "limit": 4000,
        "extra_purchased": 10000,
        "total_allowed": 14000,
        "remaining": 13850
      }
    }
  }
}
```

---

### Purchase Add-On

```bash
# POST /api/v2/accounts/:account_id/billing/add_ons
curl -X POST \
  -H "api_access_token: TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"add_on_type": "agent", "action": "add"}' \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons
```

---

### Purchase Conversation Pack

```bash
# POST /api/v2/accounts/:account_id/billing/conversation_packs/purchase
curl -X POST \
  -H "api_access_token: TOKEN" \
  http://localhost:3000/api/v2/accounts/2/billing/conversation_packs/purchase
```

---

## Stripe Webhook Testing (Optional)

### Test Subscription Updated Event

1. Go to: https://dashboard.stripe.com/test/webhooks
2. Find your webhook endpoint (if configured)
3. Click **"Send test webhook"**
4. Select: `customer.subscription.updated`
5. Verify your app receives and processes the event

**Expected:**
- Account `custom_attributes` updated
- Logs show: "Processing Stripe event: customer.subscription.updated"

---

## Troubleshooting

### Issue: "No Stripe customer found"

**Cause:** Account doesn't have `stripe_customer_id` in custom_attributes

**Fix:**
```bash
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  puts account.custom_attributes&.dig('stripe_customer_id') || 'MISSING'
"
```

---

### Issue: "Price not found in Stripe for lookup_key"

**Cause:** Stripe price doesn't exist or lookup_key mismatch

**Fix:**
1. Go to Stripe Dashboard → **Products**
2. Find the product (e.g., "Extra Agent - Starter")
3. Click **Prices**
4. Edit price → **Additional options**
5. Set **Lookup key** to: `extra_agent_starter` (from billing_plans.yml)

---

### Issue: Add-on button disabled but not purchased

**Cause:** Plan doesn't support add-ons (e.g., free_trial, community)

**Check:**
```bash
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  plan = account.custom_attributes&.dig('plan_name')
  puts 'Plan: ' + plan
  puts 'Add-ons available: ' + (!['free_trial', 'community', 'enterprise'].include?(plan)).to_s
"
```

---

### Issue: Training add-on shows wrong metadata

**Cause:** Stripe product metadata missing or misconfigured

**Fix:**
1. Go to: https://dashboard.stripe.com/test/products
2. Find training product
3. Add metadata:
   - `bullet_1`: "First feature"
   - `bullet_2`: "Second feature"
   - etc.
4. Refresh Chatwoot UI

---

## Summary

### What Gets Added to Stripe Subscription:
✅ Extra Seats (agents) - recurring
✅ Extra Inboxes - recurring  
✅ Live Training - recurring
✅ Live 1:1 Training - recurring

### What Creates One-Time Invoices:
✅ Conversation Packs - one-time invoice, not subscription item

### Subscription Structure After All Tests:

```
Stripe Subscription (cus_TMHmLZpIomWphR)
├── Starter Base Plan × 1 ($30/month)
├── Extra Agent - Starter × 1 ($10/month)
├── Extra Inbox - Starter × 1 ($15/month)
├── Live Training × 1 ($499/month)
└── Live 1:1 Training × 1 ($799/month)

Total Recurring: $1,353/month

Separate One-Time Invoices:
└── 10,000 Conversation Pack ($20 one-time)
```

---

## Next Steps

1. ✅ Run through all 5 test scenarios
2. ✅ Verify each item in Stripe Dashboard
3. ✅ Test at least 2-3 edge cases
4. Document any issues found
5. Test payment method updates
6. Test subscription cancellation flow

---

## Need Help?

- Check Rails logs: `docker compose logs rails -f`
- Check Stripe Dashboard: https://dashboard.stripe.com/test/
- Check API responses in browser DevTools → Network tab
- Run service directly in Rails console for debugging

```bash
docker compose exec rails bundle exec rails console

# Then in console:
account = Account.find(2)
service = Billing::ManageSubscriptionAddOnService.new(account, :agent)
info = service.add_on_info
puts JSON.pretty_generate(info)
```

---

**Happy Testing! 🎉**

