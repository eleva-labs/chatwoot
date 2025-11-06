# Stripe Billing - Quick Testing Reference

## Quick Account Status Check

```bash
# Check current account and subscription status
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  puts '=' * 60
  puts 'ACCOUNT STATUS'
  puts '=' * 60
  puts 'Account ID: ' + account.id.to_s
  puts 'Name: ' + account.name
  puts 'Plan: ' + (account.custom_attributes&.dig('plan_name') || 'none')
  puts 'Subscription Status: ' + (account.custom_attributes&.dig('subscription_status') || 'none')
  puts 'Stripe Customer ID: ' + (account.custom_attributes&.dig('stripe_customer_id') || 'none')
  puts 'Extra Conversations: ' + (account.custom_attributes&.dig('extra_conversations_purchased')&.to_s || '0')
  puts '=' * 60
"
```

---

## Test Each Add-On Type

### 1. Test Extra Agents

```bash
# Check current agent add-ons
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :agent)
  puts 'Current quantity: ' + service.current_quantity.to_s
  info = service.add_on_info
  puts 'Price: ' + info[:unit_price_formatted]
  puts 'Lookup key: ' + info[:lookup_key]
  puts 'Can purchase: ' + info[:can_purchase].to_s
"

# Add 1 agent
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :agent)
  result = service.add_unit
  puts result[:success] ? '✅ Success: ' + result[:message] : '❌ Error: ' + result[:error]
  puts 'New quantity: ' + result[:quantity].to_s if result[:success]
"

# Remove 1 agent
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :agent)
  result = service.remove_unit
  puts result[:success] ? '✅ Success: ' + result[:message] : '❌ Error: ' + result[:error]
"

# Set specific quantity (e.g., 3 agents)
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :agent)
  result = service.set_quantity(3)
  puts result[:success] ? '✅ Success: ' + result[:message] : '❌ Error: ' + result[:error]
"
```

---

### 2. Test Extra Inboxes

```bash
# Check current inbox add-ons
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :inbox)
  puts 'Current quantity: ' + service.current_quantity.to_s
  info = service.add_on_info
  puts 'Price: ' + info[:unit_price_formatted]
  puts 'Lookup key: ' + info[:lookup_key]
"

# Add 1 inbox
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :inbox)
  result = service.add_unit
  puts result[:success] ? '✅ Success: ' + result[:message] : '❌ Error: ' + result[:error]
"
```

---

### 3. Test Conversation Packs

```bash
# Check conversation pack availability
docker compose exec rails bundle exec rails runner "
  service = Billing::ConversationLimitService.new(Account.find(2))
  pack_info = service.conversation_pack_info
  if pack_info
    puts 'Pack available: Yes'
    puts 'Conversations in pack: ' + pack_info[:conversations].to_s
    puts 'Price: ' + pack_info[:unit_price_formatted]
    puts 'Lookup key: ' + pack_info[:lookup_key]
  else
    puts 'Pack available: No'
  end
"

# Check current conversation limits
docker compose exec rails bundle exec rails runner "
  service = Billing::ConversationLimitService.new(Account.find(2))
  status = service.status
  puts 'Current conversations: ' + status[:current].to_s
  puts 'Monthly limit: ' + status[:limit].to_s
  puts 'Extra purchased: ' + status[:extra_purchased].to_s
  puts 'Total allowed: ' + status[:total_allowed].to_s
  puts 'Remaining: ' + status[:remaining].to_s
  puts 'Can create: ' + status[:can_create].to_s
"

# Purchase conversation pack
docker compose exec rails bundle exec rails runner "
  service = Billing::PurchaseConversationPackService.new(Account.find(2))
  result = service.perform
  if result[:success]
    puts '✅ Success: ' + result[:message]
    puts 'Conversations added: ' + result[:conversations_added].to_s
    puts 'New total: ' + result[:new_total].to_s
    puts 'Invoice ID: ' + result[:invoice_id]
    puts 'Amount: $' + (result[:amount] / 100.0).to_s
  else
    puts '❌ Error: ' + result[:error]
  end
"
```

---

### 4. Test Live Training

```bash
# Check live training status
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_training)
  info = service.add_on_info
  puts 'Current quantity: ' + info[:current_quantity].to_s
  puts 'Max quantity: ' + info[:max_quantity].to_s
  puts 'Can purchase: ' + info[:can_purchase].to_s
  puts 'Price: ' + info[:unit_price_formatted]
  puts 'Category: ' + info[:category]
  puts 'Name: ' + info[:name]
  puts 'Feature bullets:'
  info[:feature_bullets].each_with_index { |bullet, i| puts '  ' + (i+1).to_s + '. ' + bullet }
"

# Purchase live training
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_training)
  result = service.add_unit
  if result[:success]
    puts '✅ Success: ' + result[:message]
    puts 'Quantity: ' + result[:quantity].to_s
  else
    puts '❌ Error: ' + result[:error]
  end
"

# Try to purchase again (should fail - max 1)
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_training)
  result = service.add_unit
  puts result[:success] ? '✅ Success (unexpected!)' : '❌ Expected error: ' + result[:error]
"
```

---

### 5. Test Live 1:1 Training

```bash
# Check live 1:1 training status
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_1_1_training)
  info = service.add_on_info
  puts 'Current quantity: ' + info[:current_quantity].to_s
  puts 'Max quantity: ' + info[:max_quantity].to_s
  puts 'Can purchase: ' + info[:can_purchase].to_s
  puts 'Price: ' + info[:unit_price_formatted]
  puts 'Name: ' + info[:name]
"

# Purchase live 1:1 training
docker compose exec rails bundle exec rails runner "
  service = Billing::ManageSubscriptionAddOnService.new(Account.find(2), :live_1_1_training)
  result = service.add_unit
  puts result[:success] ? '✅ Success: ' + result[:message] : '❌ Error: ' + result[:error]
"
```

---

## Check All Limits at Once

```bash
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  
  puts '=' * 60
  puts 'AGENT LIMITS'
  puts '=' * 60
  service = Billing::UnifiedLimitService.new(account, :agent)
  status = service.status
  puts 'Current: ' + status[:current].to_s
  puts 'Base limit: ' + status[:base_limit].to_s
  puts 'Purchased: ' + status[:purchased].to_s
  puts 'Total allowed: ' + status[:total_allowed].to_s
  puts 'Can create: ' + status[:can_create].to_s
  
  puts ''
  puts '=' * 60
  puts 'INBOX LIMITS'
  puts '=' * 60
  service = Billing::UnifiedLimitService.new(account, :inbox)
  status = service.status
  puts 'Current: ' + status[:current].to_s
  puts 'Base limit: ' + status[:base_limit].to_s
  puts 'Purchased: ' + status[:purchased].to_s
  puts 'Total allowed: ' + status[:total_allowed].to_s
  puts 'Can create: ' + status[:can_create].to_s
  
  puts ''
  puts '=' * 60
  puts 'CONVERSATION LIMITS'
  puts '=' * 60
  service = Billing::ConversationLimitService.new(account)
  status = service.status
  puts 'Current: ' + status[:current].to_s
  puts 'Monthly limit: ' + status[:limit].to_s
  puts 'Extra purchased: ' + status[:extra_purchased].to_s
  puts 'Total allowed: ' + status[:total_allowed].to_s
  puts 'Remaining: ' + status[:remaining].to_s
  puts 'Can create: ' + status[:can_create].to_s
"
```

---

## Get Full Subscription Breakdown

```bash
docker compose exec rails bundle exec rails runner "
  service = Billing::SubscriptionBreakdownService.new(Account.find(2))
  breakdown = service.breakdown
  
  puts '=' * 60
  puts 'SUBSCRIPTION BREAKDOWN'
  puts '=' * 60
  puts 'Plan: ' + breakdown[:plan_name]
  puts 'Subscription Status: ' + breakdown[:subscription_status]
  puts 'Stripe Subscription ID: ' + (breakdown[:subscription_id] || 'N/A')
  
  puts ''
  puts 'BASE PLAN:'
  base = breakdown[:base_plan]
  puts '  Name: ' + base[:name]
  puts '  Price: ' + base[:formatted_price]
  
  if breakdown[:add_ons].any?
    puts ''
    puts 'ADD-ONS:'
    breakdown[:add_ons].each do |addon|
      puts '  - ' + addon[:name]
      puts '    Quantity: ' + addon[:quantity].to_s
      puts '    Unit Price: ' + addon[:unit_price_formatted]
      puts '    Total: ' + addon[:total_formatted]
    end
  end
  
  puts ''
  puts 'TOTALS:'
  puts '  Subtotal: ' + breakdown[:total_formatted]
  puts '  Currency: ' + breakdown[:currency]
  puts '  Interval: ' + breakdown[:interval]
"
```

---

## Fetch Stripe Subscription Directly

```bash
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  customer_id = account.custom_attributes&.dig('stripe_customer_id')
  
  if customer_id
    subscriptions = Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
    
    if subscriptions.data.any?
      sub = subscriptions.data.first
      puts '=' * 60
      puts 'STRIPE SUBSCRIPTION DATA'
      puts '=' * 60
      puts 'Subscription ID: ' + sub.id
      puts 'Status: ' + sub.status
      puts 'Current Period Start: ' + Time.at(sub.current_period_start).to_s
      puts 'Current Period End: ' + Time.at(sub.current_period_end).to_s
      puts 'Cancel at Period End: ' + sub.cancel_at_period_end.to_s
      
      puts ''
      puts 'SUBSCRIPTION ITEMS:'
      sub.items.data.each do |item|
        puts '  - ID: ' + item.id
        puts '    Price ID: ' + item.price.id
        puts '    Lookup Key: ' + (item.price.lookup_key || 'N/A')
        puts '    Quantity: ' + item.quantity.to_s
        puts '    Amount: $' + (item.price.unit_amount / 100.0).to_s + '/' + item.price.recurring.interval
        puts ''
      end
      
      puts 'TOTAL MONTHLY AMOUNT: $' + (sub.items.data.sum { |item| item.price.unit_amount * item.quantity } / 100.0).to_s
    else
      puts 'No active subscription found'
    end
  else
    puts 'No Stripe customer ID found'
  end
"
```

---

## Check Stripe Invoices

```bash
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  customer_id = account.custom_attributes&.dig('stripe_customer_id')
  
  if customer_id
    invoices = Stripe::Invoice.list(customer: customer_id, limit: 5)
    
    puts '=' * 60
    puts 'RECENT INVOICES'
    puts '=' * 60
    
    invoices.data.each do |invoice|
      puts 'Invoice ID: ' + invoice.id
      puts 'Description: ' + (invoice.description || 'N/A')
      puts 'Amount: $' + (invoice.total / 100.0).to_s
      puts 'Status: ' + invoice.status
      puts 'Created: ' + Time.at(invoice.created).to_s
      puts 'Paid: ' + invoice.paid.to_s
      puts 'PDF: ' + (invoice.invoice_pdf || 'N/A')
      puts '-' * 60
    end
  else
    puts 'No Stripe customer ID found'
  end
"
```

---

## Reset All Add-Ons (Cleanup)

```bash
# WARNING: This removes ALL add-ons from subscription
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  
  puts 'Removing all add-ons...'
  
  # Remove agents
  service = Billing::ManageSubscriptionAddOnService.new(account, :agent)
  if service.current_quantity > 0
    result = service.set_quantity(0)
    puts 'Agents: ' + (result[:success] ? '✅ Removed' : '❌ ' + result[:error])
  end
  
  # Remove inboxes
  service = Billing::ManageSubscriptionAddOnService.new(account, :inbox)
  if service.current_quantity > 0
    result = service.set_quantity(0)
    puts 'Inboxes: ' + (result[:success] ? '✅ Removed' : '❌ ' + result[:error])
  end
  
  # Remove live training
  service = Billing::ManageSubscriptionAddOnService.new(account, :live_training)
  if service.current_quantity > 0
    result = service.set_quantity(0)
    puts 'Live Training: ' + (result[:success] ? '✅ Removed' : '❌ ' + result[:error])
  end
  
  # Remove live 1:1 training
  service = Billing::ManageSubscriptionAddOnService.new(account, :live_1_1_training)
  if service.current_quantity > 0
    result = service.set_quantity(0)
    puts 'Live 1:1 Training: ' + (result[:success] ? '✅ Removed' : '❌ ' + result[:error])
  end
  
  puts ''
  puts 'Done! Subscription now has only base plan.'
"
```

---

## API Testing with curl

### Get your API token first:

```bash
# In browser DevTools Console (logged in to Chatwoot):
localStorage.getItem('auth_access_token')
```

Or in Rails:

```bash
docker compose exec rails bundle exec rails runner "
  user = Account.find(2).users.first
  puts user.access_token.token
"
```

### Then use curl:

```bash
# Replace YOUR_TOKEN with actual token from above
TOKEN="YOUR_TOKEN_HERE"

# Get add-ons status
curl -H "api_access_token: $TOKEN" \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons

# Get limits
curl -H "api_access_token: $TOKEN" \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons/limits

# Get subscription breakdown
curl -H "api_access_token: $TOKEN" \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons/breakdown

# Purchase extra agent
curl -X POST \
  -H "api_access_token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"add_on_type": "agent", "action": "add"}' \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons

# Purchase live training
curl -X POST \
  -H "api_access_token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"add_on_type": "live_training", "action": "add"}' \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons

# Purchase conversation pack
curl -X POST \
  -H "api_access_token: $TOKEN" \
  http://localhost:3000/api/v2/accounts/2/billing/conversation_packs/purchase

# Remove agent
curl -X POST \
  -H "api_access_token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"add_on_type": "agent", "action": "remove"}' \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons

# Set specific quantity
curl -X POST \
  -H "api_access_token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"add_on_type": "agent", "action": "set", "quantity": 3}' \
  http://localhost:3000/api/v2/accounts/2/billing/add_ons
```

---

## Rails Console Testing

```bash
# Open Rails console
docker compose exec rails bundle exec rails console

# Then run these commands:
```

```ruby
# Get account
account = Account.find(2)

# Check plan
account.custom_attributes['plan_name']
# => "starter"

# Get add-on service
service = Billing::ManageSubscriptionAddOnService.new(account, :agent)

# Check current quantity
service.current_quantity
# => 0

# Get info
info = service.add_on_info
# => { current_quantity: 0, unit_price_formatted: "$10.00", ... }

# Add an agent
result = service.add_unit
# => { success: true, message: "agent quantity updated to 1", ... }

# Check limits
limit_service = Billing::UnifiedLimitService.new(account, :agent)
status = limit_service.status
# => { current: 2, base_limit: 5, purchased: 1, total_allowed: 6, ... }

# Purchase conversation pack
pack_service = Billing::PurchaseConversationPackService.new(account)
result = pack_service.perform
# => { success: true, conversations_added: 10000, ... }

# Get subscription breakdown
breakdown_service = Billing::SubscriptionBreakdownService.new(account)
breakdown = breakdown_service.breakdown
# => { plan_name: "starter", base_plan: { ... }, add_ons: [ ... ], ... }
```

---

## Common Error Codes

| Error | Meaning | Solution |
|-------|---------|----------|
| `No active subscription found` | Account doesn't have active Stripe subscription | Check subscription status in Stripe |
| `Price not found in Stripe for lookup_key` | Lookup key mismatch | Verify price lookup_key in Stripe matches config |
| `Cannot add more of this add-on` | Hit max_quantity limit | Training add-ons limited to 1 each |
| `Add-ons not available for plan` | Plan doesn't support add-ons | Only starter/professional support add-ons |
| `Conversation packs not available for this plan` | Plan doesn't support packs | Only starter/professional support packs |
| `Rate limited - please try again` | Too many Stripe API calls | Wait a moment and retry |
| `Payment failed` | Card declined or payment issue | Check payment method in Stripe |

---

## Monitoring & Logs

```bash
# Watch Rails logs
docker compose logs rails -f

# Filter for billing-related logs
docker compose logs rails -f | grep -i "billing\|stripe\|subscription"

# Check recent errors
docker compose logs rails --tail=100 | grep -i "error"
```

---

## Stripe CLI (Advanced)

If you have Stripe CLI installed:

```bash
# Listen to webhooks locally
stripe listen --forward-to localhost:3000/webhooks/stripe

# Trigger test events
stripe trigger customer.subscription.updated

stripe trigger invoice.payment_succeeded

stripe trigger charge.succeeded
```

---

## Quick Verification After Testing

```bash
docker compose exec rails bundle exec rails runner "
  account = Account.find(2)
  
  # Get current state
  puts '✅ Account ID: 2'
  puts '✅ Plan: ' + account.custom_attributes['plan_name']
  puts '✅ Stripe Customer: ' + account.custom_attributes['stripe_customer_id']
  
  # Get subscription from Stripe
  customer_id = account.custom_attributes['stripe_customer_id']
  subscriptions = Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
  
  if subscriptions.data.any?
    sub = subscriptions.data.first
    puts ''
    puts 'SUBSCRIPTION ITEMS IN STRIPE:'
    sub.items.data.each do |item|
      puts '  ✓ ' + (item.price.lookup_key || item.price.id) + ' × ' + item.quantity.to_s
    end
    
    total = sub.items.data.sum { |item| item.price.unit_amount * item.quantity }
    puts ''
    puts 'Monthly Total: $' + (total / 100.0).to_s
  end
"
```

---

**Quick Start:**
1. Copy and run the "Quick Account Status Check" to verify setup
2. Pick a test from Tests 1-5 above
3. Run the command
4. Verify in Stripe Dashboard
5. Run "Quick Verification" to confirm

**Need detailed steps?** See `stripe-manual-testing-guide.md`

