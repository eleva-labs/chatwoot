# Stripe Verification Checklist

Use this checklist while testing the billing implementation to ensure everything is correctly reflected in Stripe.

---

## Initial Setup Verification

- [ ] **Account has active starter plan**
  - Navigate to: https://dashboard.stripe.com/test/customers
  - Search for customer: `cus_TMHmLZpIomWphR`
  - Verify subscription status: **Active**
  - Verify base plan item exists

---

## Test 1: Extra Seats (Agents)

### In Chatwoot UI
- [ ] Clicked "Purchase Extra Seat" button
- [ ] Saw loading state on button
- [ ] Received success message
- [ ] Limits updated from "2 / 5" → "2 / 6"

### In Stripe Dashboard
Go to: [Customer Page](https://dashboard.stripe.com/test/customers/cus_TMHmLZpIomWphR)

- [ ] **Subscription Items** tab shows:
  - [ ] `Starter Base Plan` × 1
  - [ ] `Extra Agent - Starter` (lookup_key: `extra_agent_starter`) × 1

- [ ] **Upcoming Invoice** shows:
  - [ ] Base plan charge: ~$30
  - [ ] Extra agent charge: ~$10
  - [ ] Proration applied for current period

- [ ] **Events & logs** tab shows:
  - [ ] `customer.subscription.updated` event
  - [ ] Timestamp matches when you clicked "Purchase"

### Verification Command
```bash
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :agent)
  puts 'Agent add-ons: ' + service.current_quantity.to_s
"
```
- [ ] Output shows: `Agent add-ons: 1`

---

## Test 2: Extra Inboxes

### In Chatwoot UI
- [ ] Clicked "Purchase Extra Inbox" button
- [ ] Success message received
- [ ] Limits updated from "1 / 2" → "1 / 3"

### In Stripe Dashboard
- [ ] **Subscription Items** now includes:
  - [ ] `Extra Inbox - Starter` (lookup_key: `extra_inbox_starter`) × 1

- [ ] **Monthly amount increased** by inbox price (~$15)

- [ ] **Proration created** for remaining days in period

### Verification Command
```bash
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :inbox)
  puts 'Inbox add-ons: ' + service.current_quantity.to_s
"
```
- [ ] Output shows: `Inbox add-ons: 1`

---

## Test 3: Conversation Pack

### In Chatwoot UI
- [ ] Clicked "Buy Conversation Pack" button
- [ ] Success message: "10,000 Conversation Pack purchased"
- [ ] Total conversations increased: 4,000 → 14,000
- [ ] Monthly subscription amount **did NOT change** (one-time purchase)

### In Stripe Dashboard

**IMPORTANT:** Conversation packs create **invoices**, NOT subscription items!

- [ ] **Invoices** tab shows new invoice:
  - [ ] Description: "Conversation Pack Purchase" or "10,000 Conversation Pack"
  - [ ] Amount: ~$20 (one-time)
  - [ ] Status: **Paid** (or **Open** if payment processing)
  - [ ] NOT recurring

- [ ] **Subscription Items** tab shows:
  - [ ] NO conversation pack item added (correct behavior)
  - [ ] Only base plan + add-ons from previous tests

- [ ] **Payment history** shows separate payment for $20

### Verification Commands
```bash
# Check extra conversations in database
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  extra = account.custom_attributes['extra_conversations_purchased'] || 0
  puts 'Extra conversations: ' + extra.to_s
"
```
- [ ] Output shows: `Extra conversations: 10000`

```bash
# Check Stripe invoices
docker compose exec rails bundle exec rails runner "
  customer_id = Account.find(2).custom_attributes['stripe_customer_id']
  invoices = Stripe::Invoice.list(customer: customer_id, limit: 1)
  invoice = invoices.data.first
  puts 'Latest invoice: ' + invoice.description
  puts 'Amount: $' + (invoice.total / 100.0).to_s
"
```
- [ ] Output shows conversation pack invoice

---

## Test 4: Live Training

### In Chatwoot UI
- [ ] Clicked "Purchase" button under Live Training
- [ ] Success message received
- [ ] Button changed to "Purchased" and became **disabled**
- [ ] Cannot purchase again (max 1)

### In Stripe Dashboard
- [ ] **Subscription Items** includes:
  - [ ] `Live Training` (lookup_key: `live_training_pricing`) × 1

- [ ] **Monthly amount increased** by training price (~$499)

- [ ] **Metadata** on product shows:
  - [ ] `bullet_1`, `bullet_2`, etc. (feature bullets)
  - [ ] Name and description match UI

### Verification Command
```bash
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_training)
  info = service.add_on_info
  puts 'Current: ' + info[:current_quantity].to_s
  puts 'Max: ' + info[:max_quantity].to_s
  puts 'Can purchase: ' + info[:can_purchase].to_s
"
```
- [ ] Output shows:
  ```
  Current: 1
  Max: 1
  Can purchase: false
  ```

### Attempt Duplicate Purchase
```bash
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_training)
  result = service.add_unit
  puts result[:error]
"
```
- [ ] Output shows: `Cannot add more of this add-on`

---

## Test 5: Live 1:1 Training

### In Chatwoot UI
- [ ] Clicked "Purchase" under Live 1:1 Training
- [ ] Success message received
- [ ] Button disabled after purchase

### In Stripe Dashboard
- [ ] **Subscription Items** includes:
  - [ ] `Live 1:1 Training` (lookup_key: `live_1_1_training_pricing`) × 1

- [ ] **Monthly amount increased** by 1:1 training price (~$799)

- [ ] **Distinct from Live Training** (separate item)

### Verification Command
```bash
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_1_1_training)
  info = service.add_on_info
  puts 'Current: ' + info[:current_quantity].to_s
  puts 'Can purchase: ' + info[:can_purchase].to_s
"
```
- [ ] Output shows:
  ```
  Current: 1
  Can purchase: false
  ```

---

## Final Subscription Verification

### In Stripe Dashboard

Navigate to: [Subscription Details](https://dashboard.stripe.com/test/customers/cus_TMHmLZpIomWphR)

- [ ] **All 5 subscription items present:**
  1. [ ] Starter Base Plan × 1 (~$30/month)
  2. [ ] Extra Agent - Starter × 1 (~$10/month)
  3. [ ] Extra Inbox - Starter × 1 (~$15/month)
  4. [ ] Live Training × 1 (~$499/month)
  5. [ ] Live 1:1 Training × 1 (~$799/month)

- [ ] **Total monthly amount:** ~$1,353/month

- [ ] **Upcoming invoice preview** shows all items

- [ ] **Payment schedule** shows next billing date

### In Stripe Invoices Tab

- [ ] **Separate one-time invoice** for Conversation Pack (~$20)

- [ ] **Recurring invoice** includes all subscription items

- [ ] **Both invoices paid successfully**

---

## Metadata Verification

### Check Product Metadata in Stripe

For each product, verify metadata exists:

#### Base Plan (Starter)
Navigate to: https://dashboard.stripe.com/test/products

- [ ] Find "Starter" product
- [ ] Check **Metadata** tab:
  - [ ] `plan_name`: "starter"
  - [ ] `agents_limit`: "5"
  - [ ] `inboxes_limit`: "2"
  - [ ] `conversations_monthly_limit`: "4000"

#### Extra Agent Add-On
- [ ] Find "Extra Agent - Starter" product
- [ ] Verify price has `lookup_key`: `extra_agent_starter`

#### Extra Inbox Add-On
- [ ] Find "Extra Inbox - Starter" product
- [ ] Verify price has `lookup_key`: `extra_inbox_starter`

#### Live Training
- [ ] Find "Live Training" product
- [ ] Check **Metadata** tab:
  - [ ] `bullet_1`: (first feature)
  - [ ] `bullet_2`: (second feature)
  - [ ] etc.
- [ ] Verify price has `lookup_key`: `live_training_pricing`

#### Live 1:1 Training
- [ ] Find "Live 1:1 Training" product
- [ ] Check metadata for bullet points
- [ ] Verify price has `lookup_key`: `live_1_1_training_pricing`

#### Conversation Pack
- [ ] Find "Conversation Pack - Starter" product
- [ ] Verify price has `lookup_key`: `conversation_pack_starter`
- [ ] Price is **one-time** (not recurring)

---

## Proration Verification

### Check Prorations Applied

- [ ] Navigate to **Upcoming Invoice** for customer

- [ ] Verify prorations for each add-on purchase:
  - [ ] Extra Agent: Prorated from purchase date to period end
  - [ ] Extra Inbox: Prorated charge
  - [ ] Live Training: Prorated charge
  - [ ] Live 1:1 Training: Prorated charge

- [ ] Calculation is correct:
  ```
  Proration = (Item Price) × (Days Remaining / Total Days in Period)
  ```

### Example Verification
```bash
docker compose exec rails bundle exec rails runner "
  customer_id = Account.find(2).custom_attributes['stripe_customer_id']
  sub = Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1).data.first
  
  upcoming = Stripe::Invoice.upcoming(customer: customer_id)
  
  puts 'Proration lines:'
  upcoming.lines.data.each do |line|
    if line.proration
      puts '  ' + line.description + ': $' + (line.amount / 100.0).to_s
    end
  end
"
```
- [ ] Shows proration amounts for each add-on

---

## Events Verification in Stripe

Navigate to: https://dashboard.stripe.com/test/events

- [ ] Find recent events (sorted by newest):

### Expected Events
- [ ] `customer.subscription.updated` (for each add-on purchase)
- [ ] `invoice.created` (for conversation pack)
- [ ] `invoice.finalized` (for conversation pack)
- [ ] `invoice.paid` (for conversation pack)
- [ ] `charge.succeeded` (for each payment)

### Verify Event Data
Click on each `customer.subscription.updated` event:

- [ ] Check `data.object.items.data[]`:
  - [ ] Correct number of items
  - [ ] Each has correct `price.id` and `quantity`

---

## Edge Cases Verification

### Test 6: Cannot Re-Purchase Training

- [ ] Try clicking "Purchase" on Live Training again
- [ ] Button should be **disabled**
- [ ] UI shows "Purchased" state

### Test 7: Can Purchase Multiple Agents

- [ ] Can click "Purchase Extra Seat" multiple times
- [ ] Each click increments subscription item quantity
- [ ] Verify in Stripe: `Extra Agent - Starter × N` (where N > 1)

### Test 8: Remove Add-On Works

Run command:
```bash
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :agent)
  result = service.remove_unit
  puts result[:message]
"
```

Then verify in Stripe:
- [ ] Subscription item quantity decremented
- [ ] If quantity = 0, item removed entirely
- [ ] Proration credit applied

---

## Database Verification

Run this comprehensive check:

```bash
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  
  puts '=' * 60
  puts 'DATABASE VERIFICATION'
  puts '=' * 60
  
  puts 'Account ID: ' + account.id.to_s
  puts 'Plan: ' + account.custom_attributes['plan_name']
  puts 'Subscription Status: ' + account.custom_attributes['subscription_status']
  puts 'Stripe Customer ID: ' + account.custom_attributes['stripe_customer_id']
  puts 'Extra Conversations: ' + (account.custom_attributes['extra_conversations_purchased'] || 0).to_s
  puts 'Last Conversation Reset: ' + (account.custom_attributes['conversations_last_reset'] || 'never').to_s
  
  puts ''
  puts 'VERIFICATION PASSED ✅' if account.custom_attributes['plan_name'] == 'starter'
"
```

Expected output:
```
============================================================
DATABASE VERIFICATION
============================================================
Account ID: 2
Plan: starter
Subscription Status: active
Stripe Customer ID: cus_TMHmLZpIomWphR
Extra Conversations: 10000
Last Conversation Reset: 1234567890

VERIFICATION PASSED ✅
```

- [ ] All values correct

---

## Cleanup (Optional)

If you want to reset and test again:

```bash
# Remove all add-ons
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  
  # Remove agent add-ons
  service = Billing::ManageSubscriptionAddOnService.new(account, :agent)
  service.set_quantity(0) if service.current_quantity > 0
  
  # Remove inbox add-ons
  service = Billing::ManageSubscriptionAddOnService.new(account, :inbox)
  service.set_quantity(0) if service.current_quantity > 0
  
  # Remove trainings
  service = Billing::ManageSubscriptionAddOnService.new(account, :live_training)
  service.set_quantity(0) if service.current_quantity > 0
  
  service = Billing::ManageSubscriptionAddOnService.new(account, :live_1_1_training)
  service.set_quantity(0) if service.current_quantity > 0
  
  # Reset extra conversations
  attrs = account.custom_attributes
  attrs['extra_conversations_purchased'] = 0
  account.update!(custom_attributes: attrs)
  
  puts 'Cleanup complete. Subscription reset to base plan only.'
"
```

Then verify in Stripe:
- [ ] Only "Starter Base Plan" remains in subscription items
- [ ] Monthly total back to ~$30

---

## Summary

After completing all tests, you should have verified:

✅ **5 successful purchases:**
1. Extra Seats (Agents)
2. Extra Inboxes
3. Conversation Pack (one-time)
4. Live Training
5. Live 1:1 Training

✅ **In Stripe Dashboard:**
- 5 subscription items for recurring add-ons
- 1 separate invoice for conversation pack
- Correct metadata on all products
- Prorations applied correctly
- Events logged properly

✅ **In Chatwoot Database:**
- Plan: starter
- Subscription Status: active
- Extra conversations: 10,000
- All custom_attributes correct

✅ **In Chatwoot UI:**
- All limits updated correctly
- Training buttons show "Purchased" state
- Can purchase more agents/inboxes
- Cannot re-purchase trainings

---

## Need Help?

If any checkbox fails:
1. Check Rails logs: `docker compose logs rails -f`
2. Check Stripe Dashboard events/logs
3. Verify Stripe product metadata
4. Ensure lookup_keys match between Stripe and `billing_plans.yml`
5. See `stripe-manual-testing-guide.md` for detailed troubleshooting

---

**Testing Complete! 🎉**

Print this checklist and mark off each item as you test to ensure comprehensive coverage.

