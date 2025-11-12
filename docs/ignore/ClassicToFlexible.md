# Migrating from Classic to Flexible Subscription Mode

**Document Version:** 1.0  
**Last Updated:** 2025-01-29  
**Based on:** Stripe API Documentation (Retrieved 2025-01-29)

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Understanding the Differences](#understanding-the-differences)
4. [Migration Steps](#migration-steps)
5. [Code Changes Required](#code-changes-required)
6. [Testing Strategy](#testing-strategy)
7. [Verification Checklist](#verification-checklist)
8. [Rollback Plan](#rollback-plan)
9. [References](#references)

---

## Overview

### What is Flexible Billing Mode?

Flexible billing mode is Stripe's **recommended** approach for subscription billing that provides:

✅ **More accurate billing** for prorations, usage-based pricing, and flexible invoicing  
✅ **Better trial handling** with preserved trial end dates  
✅ **Improved proration calculations** based on original debited amounts  
✅ **New capabilities** like mixed intervals on the same subscription  
✅ **Consistent behavior** across all billing scenarios

### Current State

- **API Version:** `2024-12-18.acacia`
- **Billing Mode:** Classic (implicit default)
- **Subscription Creation:** Via `Stripe::Subscription.create` and Checkout Sessions

### Target State

- **API Version:** `2025-06-30.basil` (or latest compatible)
- **Billing Mode:** Flexible with itemized proration discounts
- **Subscription Creation:** Explicit `billing_mode: { type: 'flexible' }` parameter

---

## Prerequisites

### ✅ Requirements

1. **Stripe API Version Support**
   - Flexible billing mode requires API version `2025-06-30.basil` or later
   - Your current version: `2024-12-18.acacia`
   - **Action Required:** Upgrade API version

2. **Test Environment Access**
   - Ensure you have access to Stripe test mode
   - Test subscription exists and can be deleted/recreated
   - No production subscriptions affected during testing

3. **Backup Current Configuration**
   - Document current subscription parameters
   - Note existing trial periods and proration settings
   - Record any custom metadata

4. **Payment Method Requirement**
   - Subscriptions being migrated must have a payment method attached
   - Without a payment method, migration may fail

### ⚠️ Important Considerations

- **Existing Test Subscription:** You have one test subscription that will be deleted/migrated
- **No Production Impact:** Changes only affect test environment initially
- **Backward Compatibility:** Flexible mode introduces behavior changes (see section below)

---

## Understanding the Differences

### Key Behavioral Changes

#### 1. **Credit Proration Calculations**

| Classic | Flexible |
|---------|----------|
| Credit prorations based on **current** subscription values (price, tax, quantity) | Credit prorations based on **original debited amount** |
| Can lead to incorrect credits if subscription was upgraded without prorations | More accurate - credits what customer actually paid |

**Example:**
- Customer pays $10/month on April 1
- Upgraded to $20/month on April 11 with `proration_behavior: none`
- Downgraded to $10/month on April 21 with prorations

**Classic:** Credits 1/3 of $20 = -$6.67 (even though customer never paid $20)  
**Flexible:** Credits 1/3 of $10 = -$3.33 (actual amount paid)

#### 2. **Trial Handling**

| Aspect | Classic | Flexible |
|--------|---------|----------|
| Trial end date with `cancel_at` | `trial_end` changes to match `cancel_at` | `trial_end` preserved regardless of `cancel_at` |
| Trial start for subsequent trials | Always first trial start date | Most recent trial start date |
| Line item descriptions | Inconsistent between licensed/usage-based | Consistent format for all types |

#### 3. **Proration Behavior**

**Discount Application:**
- **Classic:** Discounts distributed evenly across all items
- **Flexible:** Discounts applied proportionally based on item amount

**Usage-Based Billing:**
- **Classic:** Only bills usage since last price change
- **Flexible:** Bills all usage at price effective when reported

**Billing Cycle Anchor:**
- **Classic:** Automatically resets in certain scenarios
- **Flexible:** Never automatically resets (more predictable)

#### 4. **New Capabilities (Flexible Only)**

- **Mixed Interval Subscriptions:** Different items can have different billing intervals
- **Itemized Proration Discounts:** Show accurate discount amounts on invoices
- **Consolidated Invoicing:** Single invoice for phase transitions with usage items

---

## Migration Steps

### Phase 1: Upgrade Stripe API Version

#### Step 1.1: Review Current API Version

**Current File:** `config/initializers/stripe.rb`

```ruby
# Current configuration
Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)
Stripe.api_version = '2024-12-18.acacia'
```

#### Step 1.2: Update to Compatible API Version

**Action:** Change API version to `2025-06-30.basil` or later

```ruby
# Updated configuration
Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)
Stripe.api_version = '2025-06-30.basil'  # Required for flexible billing mode

# Log the version being used
Rails.logger.info "Stripe API version: #{Stripe.api_version}" if Stripe.api_key.present?
```

**⚠️ Important Notes:**
- Review the [Stripe API Changelog](https://docs.stripe.com/changelog) for breaking changes between versions
- Test thoroughly in test mode before upgrading production
- This change affects all Stripe API calls globally

#### Step 1.3: Verify API Version Upgrade

**Test Command:**
```ruby
# In Rails console
Stripe.api_version
# Should return: "2025-06-30.basil"
```

---

### Phase 2: Update Direct Subscription Creation

#### Step 2.1: Locate Subscription Creation Method

**File:** `app/services/billing/providers/stripe.rb`  
**Method:** `create_subscription` (lines 48-92)

#### Step 2.2: Add Flexible Billing Mode Parameter

**Current Code:**
```ruby
def create_subscription(customer_id, plan_id, quantity, trial_period_days: nil)
  return nil if plan_id.nil?
  
  idempotency_key = "subscription_create_#{customer_id}_#{plan_id}_#{Time.current.to_i}"
  
  subscription_params = {
    customer: customer_id,
    items: [{ price: plan_id, quantity: 1 }],
    collection_method: 'charge_automatically',
    payment_behavior: 'default_incomplete',
    expand: ['latest_invoice.payment_intent'],
    metadata: {
      plan_id: plan_id,
      quantity: quantity.to_s
    }
  }
  
  # Add trial if provided
  if trial_period_days.present? && trial_period_days > 0
    subscription_params[:trial_period_days] = trial_period_days
    Rails.logger.info "Creating trialing subscription with #{trial_period_days} days trial"
  end
  
  ::Stripe::Subscription.create(
    subscription_params,
    idempotency_key: idempotency_key
  )
end
```

**Updated Code (ADD these lines):**
```ruby
def create_subscription(customer_id, plan_id, quantity, trial_period_days: nil)
  return nil if plan_id.nil?
  
  idempotency_key = "subscription_create_#{customer_id}_#{plan_id}_#{Time.current.to_i}"
  
  subscription_params = {
    customer: customer_id,
    items: [{ price: plan_id, quantity: 1 }],
    collection_method: 'charge_automatically',
    payment_behavior: 'default_incomplete',
    expand: ['latest_invoice.payment_intent'],
    metadata: {
      plan_id: plan_id,
      quantity: quantity.to_s
    },
    # ✨ ADD THIS: Enable flexible billing mode (Stripe recommended)
    billing_mode: {
      type: 'flexible',
      flexible: {
        proration_discounts: 'itemized'  # Show accurate discount amounts
      }
    }
  }
  
  # Add trial if provided
  if trial_period_days.present? && trial_period_days > 0
    subscription_params[:trial_period_days] = trial_period_days
    Rails.logger.info "Creating trialing subscription with #{trial_period_days} days trial"
  end
  
  ::Stripe::Subscription.create(
    subscription_params,
    idempotency_key: idempotency_key
  )
end
```

**Key Changes:**
1. Added `billing_mode` hash with `type: 'flexible'`
2. Set `proration_discounts: 'itemized'` (Stripe recommended for accurate invoice display)

**⚠️ Note:** 
- `itemized` is the recommended setting for new implementations
- Shows gross amounts with accurate discount amounts
- More consistent with non-proration line items

---

### Phase 3: Update Checkout Session Subscription Creation

#### Step 3.1: Locate Checkout Session Method

**File:** `app/services/billing/create_checkout_session_service.rb`  
**Method:** `create_checkout_session` (lines 59-112)

#### Step 3.2: Add Billing Mode to Subscription Data

**Current Code:**
```ruby
def create_checkout_session
  session_params = {
    success_url: success_url,
    cancel_url: cancel_url,
    allow_promotion_codes: true,
    client_reference_id: @account.id.to_s,
    metadata: {
      account_id: @account.id.to_s,
      plan_name: @plan_name
    }
  }
  
  # ... existing customer logic ...
  
  # For paid plans
  if @plan_name != 'free_trial'
    price_id = self.class.plan_price_id(@plan_name)
    session_params[:mode] = 'subscription'
    session_params[:line_items] = [{
      price: price_id,
      quantity: 1
    }]
    
    session_params[:subscription_data] = {
      metadata: {
        account_id: @account.id.to_s,
        plan_name: @plan_name
      },
      trial_settings: {
        end_behavior: {
          missing_payment_method: 'cancel'
        }
      }
    }
  end
  
  @provider.create_checkout_session(session_params)
end
```

**Updated Code (ADD billing_mode to subscription_data):**
```ruby
def create_checkout_session
  session_params = {
    success_url: success_url,
    cancel_url: cancel_url,
    allow_promotion_codes: true,
    client_reference_id: @account.id.to_s,
    metadata: {
      account_id: @account.id.to_s,
      plan_name: @plan_name
    }
  }
  
  # ... existing customer logic ...
  
  # For paid plans
  if @plan_name != 'free_trial'
    price_id = self.class.plan_price_id(@plan_name)
    session_params[:mode] = 'subscription'
    session_params[:line_items] = [{
      price: price_id,
      quantity: 1
    }]
    
    session_params[:subscription_data] = {
      metadata: {
        account_id: @account.id.to_s,
        plan_name: @plan_name
      },
      # ✨ ADD THIS: Enable flexible billing mode for checkout subscriptions
      billing_mode: {
        type: 'flexible',
        flexible: {
          proration_discounts: 'itemized'
        }
      },
      trial_settings: {
        end_behavior: {
          missing_payment_method: 'cancel'
        }
      }
    }
  end
  
  @provider.create_checkout_session(session_params)
end
```

**Key Changes:**
1. Added `billing_mode` to `subscription_data` hash
2. Ensures checkout-created subscriptions also use flexible mode

---

### Phase 4: Enhance Subscription Update Method (Optional but Recommended)

#### Step 4.1: Review Current Update Method

**File:** `app/services/billing/providers/stripe.rb`  
**Method:** `update_subscription` (lines 295-324)

**Current Code:**
```ruby
def update_subscription(subscription_id, options = {})
  update_params = {}
  
  if options[:plan_id]
    update_params[:items] = [{
      id: get_subscription(subscription_id).items.data[0].id,
      price: options[:plan_id]
    }]
  end
  
  update_params[:quantity] = options[:quantity] if options[:quantity]
  update_params[:metadata] = options[:metadata] if options[:metadata]
  
  ::Stripe::Subscription.update(subscription_id, update_params)
end
```

#### Step 4.2: Add Proration Behavior Support

**Updated Code:**
```ruby
def update_subscription(subscription_id, options = {})
  update_params = {}
  
  if options[:plan_id]
    update_params[:items] = [{
      id: get_subscription(subscription_id).items.data[0].id,
      price: options[:plan_id]
    }]
  end
  
  update_params[:quantity] = options[:quantity] if options[:quantity]
  update_params[:metadata] = options[:metadata] if options[:metadata]
  
  # ✨ ADD THIS: Support explicit proration behavior control
  # Default to 'create_prorations' which is Stripe's default
  # But allow callers to override (e.g., 'none', 'always_invoice')
  if options[:proration_behavior].present?
    update_params[:proration_behavior] = options[:proration_behavior]
  end
  
  ::Stripe::Subscription.update(subscription_id, update_params)
end
```

**Why This Matters:**
- Gives explicit control over proration behavior
- Compatible with both classic and flexible modes
- Your add-on service (`app/services/billing/manage_subscription_add_on_service.rb`) already uses `proration_behavior: 'create_prorations'`, so this ensures consistency

---

### Phase 5: Migrate Existing Test Subscription

#### Step 5.1: Option A - Delete and Recreate (Recommended for Test)

Since you only have one test subscription and it's for testing purposes:

**Steps:**
1. Delete the existing test subscription in Stripe Dashboard
2. Create a new subscription using the updated code with flexible mode
3. This is the cleanest approach for test environments

**Dashboard Steps:**
1. Go to [Stripe Dashboard → Subscriptions](https://dashboard.stripe.com/test/subscriptions)
2. Find your test subscription
3. Click **Actions** → **Cancel subscription** → **Cancel now**
4. Create a new subscription using your application's signup flow

#### Step 5.2: Option B - Migrate Using API (If You Want to Preserve)

If you want to migrate the existing subscription without deleting:

**Ruby Code Example:**
```ruby
# In Rails console or create a migration script

# 1. Get your test subscription ID
subscription_id = 'sub_xxxxx'  # Replace with actual ID

# 2. Migrate to flexible billing mode
subscription = ::Stripe::Subscription.migrate(
  subscription_id,
  billing_mode: {
    type: 'flexible',
    flexible: {
      proration_discounts: 'itemized'
    }
  }
)

puts "Subscription migrated successfully!"
puts "Billing mode: #{subscription.billing_mode.type}"
puts "Updated at: #{Time.at(subscription.billing_mode.updated_at)}"
```

**⚠️ Important:**
- Migration only affects **future billing behavior**
- Past invoices and proration items are NOT recalculated
- Pending proration invoice items remain unchanged

**API Reference:**
- Endpoint: `POST /v1/subscriptions/:id/migrate`
- Documentation: https://docs.stripe.com/api/subscriptions/migrate

---

## Code Changes Required

### Summary of Files to Modify

| File | Lines | Change Required |
|------|-------|----------------|
| `config/initializers/stripe.rb` | 10 | Update API version to `2025-06-30.basil` or later |
| `app/services/billing/providers/stripe.rb` | 48-76 | Add `billing_mode` parameter to `create_subscription` |
| `app/services/billing/create_checkout_session_service.rb` | 98-108 | Add `billing_mode` to `subscription_data` |
| `app/services/billing/providers/stripe.rb` | 295-324 | Add `proration_behavior` support to `update_subscription` (optional) |

### Enterprise Considerations

**⚠️ Important:** The Enterprise edition has its own Stripe implementation:

**File:** `enterprise/app/services/enterprise/billing/create_stripe_customer_service.rb`

**Current Code (lines 10-14):**
```ruby
subscription = Stripe::Subscription.create(
  {
    customer: customer_id,
    items: [{ price: price_id, quantity: default_quantity }]
  }
)
```

**Note:** You **CANNOT** modify Enterprise code directly due to license restrictions. However, you should be aware that:
1. Enterprise subscriptions will continue using classic mode unless Enterprise team updates their code
2. OSS and Enterprise can coexist with different billing modes
3. If you need Enterprise to use flexible mode, contact the Enterprise team

---

## Testing Strategy

### Test Script 1: Verify API Version

**File:** `test_api_version.rb`

```ruby
# test_api_version.rb
# Purpose: Verify Stripe API version is correctly set

require 'stripe'

# Load environment
require_relative '../config/environment'

puts "=" * 60
puts "Stripe API Version Test"
puts "=" * 60

# Check configured version
configured_version = Stripe.api_version
puts "\n✓ Configured API Version: #{configured_version}"

# Verify it's the required version
required_version = '2025-06-30.basil'
if configured_version == required_version
  puts "✓ API version is correct (#{required_version})"
else
  puts "✗ WARNING: API version is #{configured_version}, expected #{required_version}"
end

# Make a test API call to verify
begin
  customer = Stripe::Customer.list(limit: 1)
  puts "\n✓ API connection successful"
  puts "✓ Test API call returned #{customer.data.length} customer(s)"
rescue Stripe::StripeError => e
  puts "\n✗ API Error: #{e.message}"
end

puts "\n" + "=" * 60
```

**Run Command:**
```bash
cd /Users/elevalabs/chatwoot
ruby test_api_version.rb
```

---

### Test Script 2: Create Flexible Subscription

**File:** `test_flexible_subscription.rb`

```ruby
# test_flexible_subscription.rb
# Purpose: Test creating a subscription with flexible billing mode

require 'stripe'
require_relative '../config/environment'

puts "=" * 60
puts "Flexible Subscription Creation Test"
puts "=" * 60

# Configuration
test_mode = true
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

puts "\nTest Configuration:"
puts "- API Key: #{Stripe.api_key&.[](0..10) || 'NOT SET'}..."
puts "- API Version: #{Stripe.api_version}"

# Verify API key is present
if Stripe.api_key.blank?
  puts "\n✗ ERROR: STRIPE_SECRET_KEY environment variable is not set"
  puts "Please set it with: export STRIPE_SECRET_KEY='sk_test_...'"
  exit 1
end

# Step 1: Create test customer
puts "\n[Step 1] Creating test customer..."
begin
  customer = Stripe::Customer.create({
    email: 'flexible-test@example.com',
    name: 'Flexible Mode Test Customer',
    metadata: {
      test_purpose: 'flexible_billing_mode_test'
    }
  })
  puts "✓ Customer created: #{customer.id}"
rescue Stripe::StripeError => e
  puts "✗ Error creating customer: #{e.message}"
  exit 1
end

# Step 2: Get a test price (you'll need to create this in Stripe Dashboard)
puts "\n[Step 2] Using test price..."
test_price_id = ENV['TEST_PRICE_ID'] || 'price_test_12345'  # Replace with actual test price
puts "- Price ID: #{test_price_id}"

# Step 3: Create subscription with flexible billing mode
puts "\n[Step 3] Creating subscription with flexible billing mode..."
subscription = nil  # Initialize to prevent NameError if exception occurs
begin
  subscription = Stripe::Subscription.create({
    customer: customer.id,
    items: [{ price: test_price_id, quantity: 1 }],
    payment_behavior: 'default_incomplete',
    collection_method: 'charge_automatically',
    billing_mode: {
      type: 'flexible',
      flexible: {
        proration_discounts: 'itemized'
      }
    },
    metadata: {
      test_purpose: 'flexible_billing_mode_test'
    }
  })
  
  puts "✓ Subscription created: #{subscription.id}"
  puts "\n[Verification]"
  puts "- Billing Mode Type: #{subscription.billing_mode['type']}"
  puts "- Proration Discounts: #{subscription.billing_mode.dig('flexible', 'proration_discounts')}"
  puts "- Status: #{subscription.status}"
  puts "- Current Period Start: #{Time.at(subscription.current_period_start)}"
  puts "- Current Period End: #{Time.at(subscription.current_period_end)}"
  
  # Verify billing mode is flexible
  if subscription.billing_mode['type'] == 'flexible'
    puts "\n✓ SUCCESS: Subscription created with flexible billing mode!"
  else
    puts "\n✗ ERROR: Subscription billing mode is '#{subscription.billing_mode['type']}' (expected 'flexible')"
  end
  
rescue Stripe::InvalidRequestError => e
  puts "✗ Invalid request: #{e.message}"
  puts "  This might indicate:"
  puts "  - API version is not compatible"
  puts "  - Test price ID is invalid"
  puts "  - Customer has no payment method"
rescue Stripe::StripeError => e
  puts "✗ Stripe error: #{e.message}"
end

# Step 4: Cleanup (optional)
puts "\n[Step 4] Cleanup (optional - delete test data)?"
puts "- Customer ID: #{customer.id}"
puts "- Subscription ID: #{subscription&.id || 'Not created'}"
puts "\nRun the following in Rails console to cleanup:"
if subscription
  puts "Stripe::Subscription.cancel('#{subscription.id}')"
end
puts "Stripe::Customer.delete('#{customer.id}')"

puts "\n" + "=" * 60
```

**Run Command:**
```bash
cd /Users/elevalabs/chatwoot
# First, set your test price ID
export TEST_PRICE_ID="price_1234567890"  # Get from Stripe Dashboard
ruby test_flexible_subscription.rb
```

---

### Test Script 3: Verify Checkout Session

**File:** `test_checkout_flexible.rb`

```ruby
# test_checkout_flexible.rb
# Purpose: Test creating a Checkout Session with flexible billing mode

require 'stripe'
require_relative '../config/environment'

puts "=" * 60
puts "Checkout Session with Flexible Billing Mode Test"
puts "=" * 60

Stripe.api_key = ENV['STRIPE_SECRET_KEY']

puts "\nTest Configuration:"
puts "- API Key: #{Stripe.api_key&.[](0..10) || 'NOT SET'}..."
puts "- API Version: #{Stripe.api_version}"

# Verify API key is present
if Stripe.api_key.blank?
  puts "\n✗ ERROR: STRIPE_SECRET_KEY environment variable is not set"
  puts "Please set it with: export STRIPE_SECRET_KEY='sk_test_...'"
  exit 1
end

# Step 1: Create test customer
puts "\n[Step 1] Creating test customer..."
customer = nil  # Initialize to prevent NameError if exception occurs
begin
  customer = Stripe::Customer.create({
    email: 'checkout-flex-test@example.com',
    name: 'Checkout Flexible Test'
  })
  puts "✓ Customer created: #{customer.id}"
rescue Stripe::StripeError => e
  puts "✗ Error creating customer: #{e.message}"
  exit 1
end

# Step 2: Get test price
test_price_id = ENV['TEST_PRICE_ID'] || 'price_test_12345'
puts "\n[Step 2] Using test price: #{test_price_id}"

# Step 3: Create Checkout Session with subscription_data.billing_mode
puts "\n[Step 3] Creating Checkout Session..."
session = nil  # Initialize to prevent NameError if exception occurs
begin
  session = Stripe::Checkout::Session.create({
    customer: customer.id,
    success_url: 'http://localhost:3000/success',
    cancel_url: 'http://localhost:3000/cancel',
    mode: 'subscription',
    line_items: [{
      price: test_price_id,
      quantity: 1
    }],
    subscription_data: {
      metadata: {
        test_purpose: 'flexible_checkout_test'
      },
      billing_mode: {
        type: 'flexible',
        flexible: {
          proration_discounts: 'itemized'
        }
      }
    }
  })
  
  puts "✓ Checkout Session created: #{session.id}"
  puts "- Mode: #{session.mode}"
  puts "- URL: #{session.url}"
  puts "\n✓ SUCCESS: Checkout Session configured for flexible billing mode!"
  puts "  When customer completes payment, subscription will use flexible mode."
  
rescue Stripe::InvalidRequestError => e
  puts "✗ Invalid request: #{e.message}"
rescue Stripe::StripeError => e
  puts "✗ Stripe error: #{e.message}"
end

puts "\n[Cleanup]"
puts "Customer ID: #{customer.id}"
puts "Session ID: #{session&.id || 'Not created'}"

puts "\n" + "=" * 60
```

**Run Command:**
```bash
cd /Users/elevalabs/chatwoot
ruby test_checkout_flexible.rb
```

---

### Test Script 4: Verify Existing Integration

**File:** `test_integration_compatibility.rb`

```ruby
# test_integration_compatibility.rb
# Purpose: Test that existing Chatwoot integration works with flexible mode

require_relative '../config/environment'

puts "=" * 60
puts "Chatwoot Integration Compatibility Test"
puts "=" * 60

# Test 1: Check BillingPlans module
puts "\n[Test 1] BillingPlans Module"
begin
  plans = Billing::CreateCheckoutSessionService.plans
  puts "✓ Available plans: #{plans.keys.join(', ')}"
rescue => e
  puts "✗ Error loading plans: #{e.message}"
end

# Test 2: Check provider factory
puts "\n[Test 2] Provider Factory"
begin
  provider = Billing::ProviderFactory.get_provider
  puts "✓ Provider: #{provider.provider_name}"
rescue => e
  puts "✗ Error getting provider: #{e.message}"
end

# Test 3: Test subscription creation service (without actually creating)
puts "\n[Test 3] Subscription Creation Service"
begin
  # Create a temporary account for testing
  account = Account.new(name: 'Test Account')
  account.save(validate: false)
  
  # Initialize the service
  service = Billing::CreateCheckoutSessionService.new(account, 'starter')
  puts "✓ Service initialized successfully"
  puts "✓ Plan: starter"
  
  # Cleanup
  account.destroy
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 4: Check Stripe provider methods
puts "\n[Test 4] Stripe Provider Methods"
provider = Billing::Providers::Stripe.new
methods_to_check = [
  :create_customer,
  :create_subscription,
  :create_checkout_session,
  :update_subscription,
  :cancel_subscription
]

methods_to_check.each do |method|
  if provider.respond_to?(method)
    puts "✓ Method exists: #{method}"
  else
    puts "✗ Method missing: #{method}"
  end
end

# Test 5: Check add-on service (uses proration_behavior)
puts "\n[Test 5] Add-on Service Compatibility"
begin
  # Check if the service accepts proration_behavior
  service_file = File.read('app/services/billing/manage_subscription_add_on_service.rb')
  if service_file.include?('proration_behavior')
    puts "✓ Add-on service uses proration_behavior (compatible)"
  else
    puts "⚠ Add-on service may need review"
  end
rescue => e
  puts "✗ Error checking add-on service: #{e.message}"
end

puts "\n" + "=" * 60
puts "Integration compatibility check complete!"
puts "=" * 60
```

**Run Command:**
```bash
cd /Users/elevalabs/chatwoot
RAILS_ENV=test rails runner test_integration_compatibility.rb
```

---

## Verification Checklist

### Pre-Migration Verification

- [ ] Current API version documented: `2024-12-18.acacia`
- [ ] Test environment accessible
- [ ] Existing test subscription documented (ID, price, status)
- [ ] Backup of current configuration created
- [ ] No active production subscriptions

### Post-Code-Change Verification

- [ ] API version updated in `config/initializers/stripe.rb`
- [ ] `billing_mode` added to `create_subscription` method
- [ ] `billing_mode` added to checkout session `subscription_data`
- [ ] `proration_behavior` support added to `update_subscription` (optional)
- [ ] Code changes reviewed and tested locally
- [ ] No syntax errors (run `rubocop -a` if available)

### Testing Verification

- [ ] Test Script 1 (API Version) passes
- [ ] Test Script 2 (Create Subscription) passes
- [ ] Test Script 3 (Checkout Session) passes
- [ ] Test Script 4 (Integration Compatibility) passes
- [ ] New subscription created successfully in test mode
- [ ] Subscription `billing_mode.type` is `'flexible'`
- [ ] Subscription `billing_mode.flexible.proration_discounts` is `'itemized'`

### Production Readiness

- [ ] All tests pass in test environment
- [ ] Existing test subscription migrated or recreated
- [ ] Trial functionality verified (if applicable)
- [ ] Proration behavior verified with test scenario
- [ ] Add-on purchases tested (if applicable)
- [ ] Webhook handlers tested
- [ ] Rollback plan documented
---

## References

### Official Stripe Documentation

1. **Flexible Billing Mode Overview**
   - https://docs.stripe.com/billing/subscriptions/billing-mode

2. **Compare Classic vs Flexible**
   - https://docs.stripe.com/billing/subscriptions/billing-mode/compare

3. **API Version Upgrade Guide**
   - https://docs.stripe.com/upgrades
   - https://docs.stripe.com/sdks/set-version

4. **Subscription API Reference**
   - https://docs.stripe.com/api/subscriptions/create
   - https://docs.stripe.com/api/subscriptions/migrate

5. **Checkout Session API Reference**
   - https://docs.stripe.com/api/checkout/sessions/create

6. **Prorations Documentation**
   - https://docs.stripe.com/billing/subscriptions/prorations

7. **Mixed Interval Subscriptions** (Flexible Only)
   - https://docs.stripe.com/billing/subscriptions/mixed-interval

### API Version Information

- **Current Version:** `2024-12-18.acacia`
- **Required Version:** `2025-06-30.basil` or later
- **Changelog:** https://docs.stripe.com/changelog

### Chatwoot Codebase References

- **Billing Provider:** `app/services/billing/providers/stripe.rb`
- **Checkout Service:** `app/services/billing/create_checkout_session_service.rb`
- **Customer Service:** `app/services/billing/create_customer_service.rb`
- **Add-on Management:** `app/services/billing/manage_subscription_add_on_service.rb`
- **Stripe Initializer:** `config/initializers/stripe.rb`

---

## Key Takeaways

### ✅ Why Flexible Mode?

1. **More Accurate Billing:** Prorations based on actual amounts paid
2. **Better Trial Handling:** Preserved trial dates, consistent behavior
3. **Future-Proof:** New features only available in flexible mode
4. **Stripe Recommended:** This is the direction Stripe is moving

### ⚠️ What to Watch

1. **Behavioral Changes:** Review proration calculation differences
2. **API Version:** Ensure compatibility with all Stripe calls
3. **Testing:** Thoroughly test all subscription flows
4. **Documentation:** Keep this document updated with any issues found

### 🎯 Success Criteria

- All new subscriptions created with `billing_mode: { type: 'flexible' }`
- Proration discounts set to `itemized` for accurate invoices
- No errors in test environment
- Clean migration of test subscription
- Ready to deploy to production with confidence

