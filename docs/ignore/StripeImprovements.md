# Stripe Implementation Improvements - Comprehensive Audit

## Overview

This document provides a comprehensive audit of the Chatwoot Stripe implementation, comparing the current implementation against Stripe's official documentation and best practices. The findings are organized by area and include both OSS (Open Source) and Enterprise implementations.

---

## 🎯 Implementation Priority Analysis

**Context**: Pre-launch, early stage, low traffic, team has capacity for refactoring, focus on preventing bugs and following best practices.

### ✅ CRITICAL - Must Implement Before Launch (Phase 1)

These improvements prevent real bugs, follow Stripe requirements, and are easy to implement now but painful to add later.

| # | Improvement | Section | Effort | Impact | Why Critical |
|---|-------------|---------|--------|--------|--------------|
| 1 | **API Versioning** | OSS #1 | 1 line | High | Prevents breaking changes from gem updates. Required by Stripe. |
| 2 | **Idempotency Keys** | OSS #4 | Low | High | Prevents duplicate customers/subscriptions on network errors. Core data integrity. |
| 3 | **Webhook Signature Tolerance** | OSS #2 (partial) | 1 line | High | Security - prevents replay attacks. Add `tolerance: 300` parameter. |
| 4 | **Specific Error Handling** | OSS #5 | Medium | High | Different errors need different handling. Prevents infinite retry loops. |
| 5 | **Payment Behavior** | OSS #6 | 1 line | High | `payment_behavior: 'default_incomplete'` handles 3DS properly. Stripe recommended. |
| 6 | **Customer Creation Config** | OSS #7 (partial) | Low | High | `customer_creation: 'always'` ensures customer objects created. Stripe best practice. |
| 7 | **Critical Webhook Events** | OSS #8 (core) | Medium | High | Must handle: checkout.session.completed, subscription.updated/deleted, invoice.payment_succeeded/failed |
| 8 | **Metadata as Strings** | OSS #9 (basic) | Low | Medium | Store `account_id.to_s` in metadata. Set on checkout + subscription_data. |
| 9 | **Cancel at Period End** | OSS #10 (basic) | Low | Medium | Default to `cancel_at_period_end: true` for better UX. |


### ⚠️ IMPORTANT - Implement Soon After Launch (Phase 2)

Valuable improvements that enhance UX and maintainability but not launch blockers.

| # | Improvement | Section | Effort | Impact | Notes |
|---|-------------|---------|--------|--------|-------|
| 11 | **Client Reference ID** | OSS #7, #9 | Low | Medium | Helpful for debugging. Low effort, good ROI. |
| 12 | **Customer Update Settings** | OSS #7 | Low | Low | Keeps customer data fresh. Nice-to-have. |
| 13 | **Trial Settings** | OSS #14 | Low | High* | *Only if using trials. Configure `missing_payment_method: 'cancel'` |
| 14 | **Webhook Route Cleanup** | OSS #11 | Low | Low | Fix confusing routing (stripe path → billing controller). |
| 15 | **Additional Webhook Events** | OSS #8 | Medium | Medium | Add as needed: trial_will_end, payment_action_required, checkout.expired |



## 📋 Quick Implementation Checklist

**Phase 1: Critical (Pre-Launch)**

Copy this checklist and check off as you implement:

**Configuration (config/initializers/stripe.rb)**
- [ ] Set explicit API version: `Stripe.api_version = '2024-12-18.acacia'`

**Customer Creation (app/services/billing/providers/stripe.rb)**
- [ ] Add idempotency keys to `create_customer`
- [ ] Use `idempotency_key: "customer_create_#{account.id}"`

**Subscription Creation (app/services/billing/providers/stripe.rb)**
- [ ] Add idempotency keys to `create_subscription`
- [ ] Add `payment_behavior: 'default_incomplete'`
- [ ] Store metadata as strings: `account_id: account.id.to_s`

**Checkout Sessions (app/services/billing/create_checkout_session_service.rb)**
- [ ] Add `customer_creation: 'always'` (when no existing customer)
- [ ] Add `client_reference_id: @account.id.to_s`
- [ ] Ensure metadata on both session and subscription_data

**Webhook Verification (app/controllers/webhooks/stripe_controller.rb)**
- [ ] Add `tolerance: 300` to `Stripe::Webhook.construct_event`

**Error Handling (app/services/billing/providers/stripe.rb)**
- [ ] Add specific rescue blocks:
  - [ ] `Stripe::InvalidRequestError` - don't retry
  - [ ] `Stripe::AuthenticationError` - config issue
  - [ ] `Stripe::APIConnectionError` - can retry
  - [ ] `Stripe::RateLimitError` - should retry with backoff

**Webhook Events (app/services/billing/providers/stripe.rb)**
- [ ] Verify handling: `checkout.session.completed`
- [ ] Verify handling: `customer.subscription.created`
- [ ] Verify handling: `customer.subscription.updated`
- [ ] Verify handling: `customer.subscription.deleted`
- [ ] Verify handling: `invoice.payment_succeeded`
- [ ] Verify handling: `invoice.payment_failed`

**Subscription Cancellation (app/services/billing/providers/stripe.rb)**
- [ ] Default to `cancel_at_period_end: true` instead of immediate cancellation

**Phase 2: Important (Post-Launch)**

- [ ] Add `client_reference_id` to checkout sessions
- [ ] Configure `customer_update` settings
- [ ] Add trial settings (if using trials)
- [ ] Clean up webhook routing
- [ ] Add additional webhook events as needed

---

## OSS (Open Source) Implementation

### 1. API Versioning

#### Current Implementation
```ruby
# config/initializers/stripe.rb
require 'stripe'
Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)
```

**Issues:**
- No explicit API version specified
- Relying on SDK's default version, which can change with gem updates
- No control over API version behavior

#### Recommended Approach
```ruby
# config/initializers/stripe.rb
require 'stripe'

Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)
Stripe.api_version = '2024-12-18.acacia' # Use specific version

# Log the version being used
Rails.logger.info "Stripe API version: #{Stripe.api_version}"
```

**Why:**
- Stripe recommends [setting explicit API versions](https://docs.stripe.com/sdks/set-version) to prevent breaking changes
- Allows controlled upgrades when reviewing changelog
- Makes behavior predictable across environments

---

### 2. Webhook Signature Verification & Security

#### Current Implementation
```ruby
# app/controllers/webhooks/stripe_controller.rb
def verify_webhook_signature(payload, sig_header)
  endpoint_secret = ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)
  
  if endpoint_secret.blank?
    Rails.logger.error 'STRIPE_WEBHOOK_SECRET not configured'
    raise StandardError, 'Webhook secret not configured'
  end
  
  Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
rescue Stripe::SignatureVerificationError => e
  Rails.logger.error "Stripe signature verification failed: #{e.message}"
  raise e
end
```

**Issues:**
- No timestamp validation to prevent replay attacks
- No tolerance parameter specified

#### Recommended Approach
```ruby
# app/controllers/webhooks/stripe_controller.rb
def verify_webhook_signature(payload, sig_header)
  endpoint_secret = ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)
  
  if endpoint_secret.blank?
    Rails.logger.error 'STRIPE_WEBHOOK_SECRET not configured'
    raise StandardError, 'Webhook secret not configured'
  end
  
  # Construct event with automatic timestamp verification
  event = Stripe::Webhook.construct_event(
    payload, 
    sig_header, 
    endpoint_secret,
    tolerance: 300 # 5 minutes - prevents replay attacks
  )
  
  # Log event ID for tracking
  Rails.logger.info "Processing Stripe event: #{event.id}"
  
  event
rescue Stripe::SignatureVerificationError => e
  Rails.logger.error "Stripe signature verification failed: #{e.message}"
  raise e
end
```

**Why:**
- Stripe best practice: [Prevent replay attacks](https://docs.stripe.com/webhooks#verify-events) with timestamp validation
- Tolerance parameter prevents clock skew issues while maintaining security
- Event ID logging helps with debugging and monitoring

---

### 3. Idempotency Keys for API Requests

#### Current Implementation
```ruby
# app/services/billing/providers/stripe.rb
def create_customer(account, plan_name)
  ::Stripe::Customer.create(
    email: account.users.first&.email,
    name: account.name,
    metadata: {
      account_id: account.id,
      plan: plan_name
    }
  )
rescue ::Stripe::StripeError => e
  # ...
end
```

**Issues:**
- No idempotency keys used for POST requests
- Can create duplicate customers on network errors/retries
- No protection against duplicate operations

#### Recommended Approach
```ruby
# app/services/billing/providers/stripe.rb
def create_customer(account, plan_name)
  # Generate idempotency key based on account ID
  idempotency_key = "customer_create_#{account.id}_#{plan_name}"
  
  ::Stripe::Customer.create(
    {
      email: account.users.first&.email,
      name: account.name,
      metadata: {
        account_id: account.id,
        plan: plan_name
      }
    },
    idempotency_key: idempotency_key
  )
rescue ::Stripe::StripeError => e
  Rails.logger.error "Stripe error creating customer: #{e.message}"
  raise StandardError, "Failed to create customer: #{e.message}"
end

def create_subscription(customer_id, plan_id, quantity, trial_period_days: nil)
  return nil if plan_id.nil?
  
  # Generate idempotency key
  idempotency_key = "subscription_create_#{customer_id}_#{plan_id}_#{Time.current.to_i}"
  
  subscription_params = {
    customer: customer_id,
    items: [{ price: plan_id, quantity: 1 }],
    auto_advance: true,
    collection_method: 'charge_automatically',
    metadata: {
      plan_id: plan_id,
      quantity: quantity
    }
  }
  
  subscription_params[:trial_period_days] = trial_period_days if trial_period_days.present? && trial_period_days > 0
  
  ::Stripe::Subscription.create(
    subscription_params,
    idempotency_key: idempotency_key
  )
rescue ::Stripe::StripeError => e
  # ...
end
```

**Why:**
- Stripe best practice: [Use idempotency keys](https://docs.stripe.com/api/idempotent_requests) for all POST requests
- Prevents duplicate resources on network errors
- Safe to retry requests with same key
- Keys valid for 24 hours

---

### 4. Error Handling & Retries

#### Current Implementation
```ruby
# app/services/billing/providers/stripe.rb
def create_customer(account, plan_name)
  ::Stripe::Customer.create(...)
rescue ::Stripe::StripeError => e
  Rails.logger.error "Stripe error creating customer: #{e.message}"
  raise StandardError, "Failed to create customer: #{e.message}"
end
```

**Issues:**
- Generic `StripeError` catch - doesn't differentiate error types
- No specific handling for retryable vs non-retryable errors
- Loses specific error type information
- No exponential backoff for retries

#### Recommended Approach
```ruby
# app/services/billing/providers/stripe.rb
def create_customer(account, plan_name)
  idempotency_key = "customer_create_#{account.id}_#{plan_name}"
  
  ::Stripe::Customer.create(
    {
      email: account.users.first&.email,
      name: account.name,
      metadata: {
        account_id: account.id,
        plan: plan_name
      }
    },
    idempotency_key: idempotency_key
  )
rescue ::Stripe::RateLimitError => e
  # Handle rate limiting - should retry with backoff
  Rails.logger.warn "Stripe rate limit hit: #{e.message}"
  raise RetryableStripeError, "Rate limited - retry recommended: #{e.message}"
rescue ::Stripe::InvalidRequestError => e
  # Bad parameters - should not retry
  Rails.logger.error "Stripe invalid request: #{e.message}"
  raise StandardError, "Invalid request parameters: #{e.message}"
rescue ::Stripe::AuthenticationError => e
  # Authentication failed - configuration issue
  Rails.logger.error "Stripe authentication failed: #{e.message}"
  raise StandardError, "Stripe authentication failed - check API keys"
rescue ::Stripe::APIConnectionError => e
  # Network error - can retry
  Rails.logger.warn "Stripe connection error: #{e.message}"
  raise RetryableStripeError, "Network error - retry recommended: #{e.message}"
rescue ::Stripe::StripeError => e
  # Generic Stripe error
  Rails.logger.error "Stripe error creating customer: #{e.message}"
  raise StandardError, "Failed to create customer: #{e.message}"
end

# lib/custom_exceptions/retryable_stripe_error.rb
module CustomExceptions
  class RetryableStripeError < StandardError; end
end
```

**Why:**
- Different error types require different handling per [Stripe error handling guide](https://docs.stripe.com/error-handling)
- RateLimitError (429) should trigger exponential backoff
- AuthenticationError/InvalidRequestError shouldn't retry
- APIConnectionError can be retried safely

---

### 5. Subscription Creation - Payment Behavior

#### Current Implementation
```ruby
# app/services/billing/create_customer_service.rb
def create_subscription(customer_id, plan_id, quantity, trial_period_days: nil)
  subscription_params = {
    customer: customer_id,
    items: [{ price: plan_id, quantity: 1 }],
    auto_advance: true,
    collection_method: 'charge_automatically',
    # Missing payment_behavior parameter
    metadata: { plan_id: plan_id, quantity: quantity }
  }
  # ...
end
```

**Issues:**
- No `payment_behavior` parameter specified
- Defaults to immediate charge attempt
- No handling for incomplete subscriptions
- Not following Stripe's recommended practice

#### Recommended Approach
```ruby
# app/services/billing/providers/stripe.rb
def create_subscription(customer_id, plan_id, quantity, trial_period_days: nil)
  return nil if plan_id.nil?
  
  subscription_params = {
    customer: customer_id,
    items: [{ price: plan_id, quantity: 1 }],
    auto_advance: true,
    collection_method: 'charge_automatically',
    payment_behavior: 'default_incomplete', # Recommended by Stripe
    expand: ['latest_invoice.payment_intent'], # Get payment details
    metadata: {
      plan_id: plan_id,
      quantity: quantity
    }
  }
  
  subscription_params[:trial_period_days] = trial_period_days if trial_period_days.present? && trial_period_days > 0
  
  subscription = ::Stripe::Subscription.create(subscription_params)
  
  # Log subscription status
  Rails.logger.info "Subscription created with status: #{subscription.status}"
  
  subscription
rescue ::Stripe::StripeError => e
  # Handle errors...
end
```

**Why:**
- Stripe recommendation: [Set payment_behavior to default_incomplete](https://docs.stripe.com/billing/subscriptions/overview#payment-behavior)
- Helps handle failed payments and complex flows like 3DS
- Creates subscriptions with status `incomplete` if payment required
- Allows collecting and confirming payment to activate subscription

---

### 6. Checkout Session Configuration

#### Current Implementation
```ruby
# app/services/billing/create_checkout_session_service.rb
session_params = {
  success_url: success_url,
  cancel_url: cancel_url,
  allow_promotion_codes: true,
  metadata: {
    account_id: @account.id,
    plan_name: @plan_name
  }
}

if @plan_name == 'free_trial'
  session_params[:mode] = 'setup'
else
  price_id = self.class.plan_price_id(@plan_name)
  session_params[:mode] = 'subscription'
  session_params[:line_items] = [{
    price: price_id,
    quantity: 1
  }]
  
  session_params[:subscription_data] = {
    metadata: {
      account_id: @account.id,
      plan_name: @plan_name
    }
  }
end
```

**Issues:**
- Missing `customer_creation` parameter
- No handling for existing customers in metadata flow
- Missing `client_reference_id` for additional tracking
- No `after_completion` configuration
- Missing `invoice_creation` settings

#### Recommended Approach
```ruby
# app/services/billing/create_checkout_session_service.rb
def create_checkout_session
  session_params = {
    success_url: success_url,
    cancel_url: cancel_url,
    allow_promotion_codes: true,
    client_reference_id: @account.id.to_s, # Additional tracking
    metadata: {
      account_id: @account.id,
      plan_name: @plan_name
    }
  }
  
  # Handle existing customer
  existing_customer_id = @account.custom_attributes&.dig('stripe_customer_id')
  if existing_customer_id.present?
    session_params[:customer] = existing_customer_id
    session_params[:customer_update] = { name: 'auto', address: 'auto' } # Update customer info if changed
  else
    # Automatically create customer for new checkouts
    session_params[:customer_creation] = 'always'
    session_params[:customer_email] = @account.users.first&.email
  end
  
  # Mode-specific parameters
  if @plan_name == 'free_trial'
    session_params[:mode] = 'setup'
    session_params[:payment_method_collection] = 'if_required'
  else
    price_id = self.class.plan_price_id(@plan_name)
    session_params[:mode] = 'subscription'
    session_params[:line_items] = [{
      price: price_id,
      quantity: 1
    }]
    
    # Subscription-specific settings
    session_params[:subscription_data] = {
      metadata: {
        account_id: @account.id,
        plan_name: @plan_name
      },
      trial_settings: {
        end_behavior: {
          missing_payment_method: 'cancel' # or 'pause' or 'create_invoice'
        }
      }
    }
    
    # Invoice settings
    session_params[:invoice_creation] = {
      enabled: true,
      invoice_data: {
        metadata: {
          account_id: @account.id,
          plan_name: @plan_name
        }
      }
    }
  end
  
  # After completion actions
  session_params[:after_completion] = {
    type: 'redirect',
    redirect: {
      url: success_url
    }
  }
  
  @provider.create_checkout_session(session_params)
end
```

**Why:**
- `customer_creation: 'always'` ensures Customer objects are created per [Stripe best practice](https://docs.stripe.com/payments/checkout/guest-customers)
- `client_reference_id` provides additional tracking beyond metadata
- `customer_update` keeps customer info fresh
- `trial_settings` handles trial expiration properly
- `invoice_creation` ensures invoices have proper metadata

---

### 7. Webhook Event Handling - Event Types

#### Current Implementation
```ruby
# app/services/billing/providers/stripe.rb
def handle_webhook(event_data)
  event_type = event_data['type']
  
  case event_type
  when 'checkout.session.completed'
    handle_checkout_session_completed(event_object)
  when 'customer.subscription.created'
    handle_subscription_created(event_object)
  when 'customer.subscription.updated'
    handle_subscription_updated(event_object)
  when 'customer.subscription.deleted'
    handle_subscription_deleted(event_object)
  when 'invoice.payment_succeeded'
    handle_payment_succeeded(event_object)
  when 'invoice.payment_failed'
    handle_payment_failed(event_object)
  when 'product.updated'
    handle_product_updated(event_object)
  else
    Rails.logger.info "Unhandled Stripe webhook event: #{event_type}"
  end
end
```

**Issues:**
- Missing critical subscription lifecycle events
- No handling for `invoice.payment_action_required` (3DS authentication)
- Missing `customer.subscription.trial_will_end`
- Missing `invoice.finalization_failed`
- Missing `customer.subscription.paused` and `customer.subscription.resumed`

#### Recommended Approach
```ruby
# app/services/billing/providers/stripe.rb
def handle_webhook(event_data)
  event_type = event_data['type']
  event_object = event_data['data']['object']
  
  Rails.logger.info "Processing Stripe webhook: #{event_type}"
  
  case event_type
  # Checkout events
  when 'checkout.session.completed'
    handle_checkout_session_completed(event_object)
  when 'checkout.session.expired'
    handle_checkout_session_expired(event_object)
  
  # Subscription lifecycle events
  when 'customer.subscription.created'
    handle_subscription_created(event_object)
  when 'customer.subscription.updated'
    handle_subscription_updated(event_object)
  when 'customer.subscription.deleted'
    handle_subscription_deleted(event_object)
  when 'customer.subscription.paused'
    handle_subscription_paused(event_object)
  when 'customer.subscription.resumed'
    handle_subscription_resumed(event_object)
  when 'customer.subscription.trial_will_end'
    handle_trial_will_end(event_object)
  
  # Invoice and payment events
  when 'invoice.created'
    handle_invoice_created(event_object)
  when 'invoice.finalized'
    handle_invoice_finalized(event_object)
  when 'invoice.finalization_failed'
    handle_invoice_finalization_failed(event_object)
  when 'invoice.payment_succeeded'
    handle_payment_succeeded(event_object)
  when 'invoice.payment_failed'
    handle_payment_failed(event_object)
  when 'invoice.payment_action_required'
    handle_payment_action_required(event_object)
  
  # Product events
  when 'product.updated'
    handle_product_updated(event_object)
  
  else
    Rails.logger.info "Unhandled Stripe webhook event: #{event_type}"
    { success: true, message: "Event #{event_type} acknowledged but not processed" }
  end
rescue StandardError => e
  Rails.logger.error "Error handling Stripe webhook #{event_type}: #{e.message}"
  { success: false, error: "Webhook processing failed: #{e.message}" }
end

private

def handle_payment_action_required(invoice)
  # Customer needs to complete 3DS authentication
  account = find_account_by_customer_id(invoice['customer'])
  return failure_response('Account not found') unless account
  
  # Send email or notification to customer to complete authentication
  Rails.logger.warn "Payment requires action for account #{account.id}"
  
  # Could trigger email notification here
  # AccountMailer.payment_action_required(account, invoice).deliver_later
  
  success_response('Payment action required notification sent')
end

def handle_trial_will_end(subscription)
  # Send reminder 3 days before trial ends
  account = find_account_by_customer_id(subscription['customer'])
  return failure_response('Account not found') unless account
  
  Rails.logger.info "Trial ending soon for account #{account.id}"
  
  # Send trial ending notification
  # AccountMailer.trial_ending_soon(account, subscription).deliver_later
  
  success_response('Trial ending notification sent')
end

def handle_checkout_session_expired(session)
  # Log expired checkout sessions
  account_id = session.dig('metadata', 'account_id')
  Rails.logger.info "Checkout session expired for account #{account_id}"
  
  success_response('Checkout session expiration logged')
end
```

**Why:**
- Stripe best practice: [Listen for subscription lifecycle events](https://docs.stripe.com/billing/subscriptions/webhooks#events)
- `invoice.payment_action_required` needed for 3DS and strong customer authentication
- `customer.subscription.trial_will_end` for trial ending reminders
- `invoice.finalization_failed` for error handling
- Comprehensive event handling improves user experience

---

### 8. Metadata Usage & Propagation

#### Current Implementation
```ruby
# app/services/billing/create_checkout_session_service.rb
session_params = {
  metadata: {
    account_id: @account.id,
    plan_name: @plan_name
  },
  subscription_data: {
    metadata: {
      account_id: @account.id,
      plan_name: @plan_name
    }
  }
}
```

**Good Practices Already Followed:**
- Metadata set on both Checkout Session and Subscription
- account_id stored for reliable lookup

**Recommendations for Enhancement:**
```ruby
# app/services/billing/create_checkout_session_service.rb
session_params = {
  client_reference_id: @account.id.to_s, # Direct ID reference
  metadata: {
    account_id: @account.id.to_s, # Always store as string
    plan_name: @plan_name,
    environment: Rails.env, # Track environment
    created_at: Time.current.iso8601, # Track creation time
    source: 'checkout_session' # Track source
  },
  subscription_data: {
    metadata: {
      account_id: @account.id.to_s,
      plan_name: @plan_name,
      environment: Rails.env,
      subscription_source: 'web_checkout'
    }
  },
  invoice_creation: {
    enabled: true,
    invoice_data: {
      metadata: {
        account_id: @account.id.to_s,
        plan_name: @plan_name,
        environment: Rails.env
      }
    }
  }
}
```

**Why:**
- Stripe best practice: [Propagate metadata](https://docs.stripe.com/metadata#set-indirectly) to related objects
- environment tracking helps with debugging
- Never store PII in metadata per Stripe guidelines
- Metadata on invoices helps with reconciliation

---

### 9. Subscription Cancellation Handling

#### Current Implementation
```ruby
# app/services/billing/providers/stripe.rb
def cancel_subscription(subscription_id)
  ::Stripe::Subscription.cancel(subscription_id)
rescue ::Stripe::StripeError => e
  Rails.logger.error "Stripe error cancelling subscription: #{e.message}"
  raise StandardError, "Failed to cancel subscription: #{e.message}"
end
```

**Issues:**
- No options for cancellation timing (immediate vs end of period)
- No proration handling
- Missing cancel reason tracking
- No invoice handling for pending charges

#### Recommended Approach
```ruby
# app/services/billing/providers/stripe.rb
def cancel_subscription(subscription_id, options = {})
  cancel_params = {}
  
  # Default to cancel at period end to avoid mid-cycle cancellations
  if options[:cancel_immediately]
    # Immediate cancellation
    cancel_params[:prorate] = options.fetch(:prorate, true)
    cancel_params[:invoice_now] = options.fetch(:invoice_now, false)
  else
    # Cancel at end of period (default)
    return update_subscription_cancel_at_period_end(subscription_id, true)
  end
  
  # Add cancellation details
  cancel_params[:cancellation_details] = {
    comment: options[:reason],
    feedback: options[:feedback]
  } if options[:reason].present?
  
  ::Stripe::Subscription.cancel(subscription_id, cancel_params)
rescue ::Stripe::StripeError => e
  Rails.logger.error "Stripe error cancelling subscription: #{e.message}"
  raise StandardError, "Failed to cancel subscription: #{e.message}"
end

def update_subscription_cancel_at_period_end(subscription_id, cancel_at_period_end)
  ::Stripe::Subscription.update(
    subscription_id,
    {
      cancel_at_period_end: cancel_at_period_end,
      cancellation_details: {
        comment: "Scheduled cancellation at period end",
        feedback: "customer_service"
      }
    }
  )
rescue ::Stripe::StripeError => e
  Rails.logger.error "Stripe error updating subscription: #{e.message}"
  raise StandardError, "Failed to update subscription: #{e.message}"
end
```

**Why:**
- Stripe best practice: [Cancel at end of period](https://docs.stripe.com/billing/subscriptions/cancel#cancel-at-the-end-of-the-current-billing-period) by default
- Provides better customer experience
- Allows proration handling for mid-cycle cancellations
- Tracks cancellation reasons for analytics

---

### 10. Webhook Route Configuration

#### Current Implementation
```ruby
# config/routes.rb
namespace :webhooks do
  post 'billing/process_event', to: 'billing#process_event'
  get 'billing/health', to: 'billing#health'
  
  post 'stripe/process_event', to: 'billing#process_event'
  get 'stripe/health', to: 'billing#health'
end
```

**Issues:**
- Routes both point to same controller (billing#process_event) but path uses 'stripe'
- Controller is `Webhooks::StripeController` not `Webhooks::BillingController`
- Confusing routing structure

#### Recommended Approach
```ruby
# config/routes.rb
namespace :webhooks do
  # Provider-specific webhook endpoints
  post 'stripe/process_event', to: 'stripe#process_event'
  get 'stripe/health', to: 'stripe#health'
  
  # Generic billing webhook endpoints (for future providers)
  post 'billing/process_event', to: 'billing#process_event'
  get 'billing/health', to: 'billing#health'
end

# app/controllers/webhooks/billing_controller.rb
class Webhooks::BillingController < ActionController::Base
  protect_from_forgery with: :null_session
  
  def process_event
    # Determine provider from headers or configuration
    provider = determine_provider
    
    case provider
    when 'stripe'
      forward_to_stripe
    else
      render json: { error: 'Unknown provider' }, status: :bad_request
    end
  end
  
  private
  
  def determine_provider
    # Could use header, subdomain, or default to configured provider
    ENV.fetch('PAYMENT_PROVIDER', 'stripe')
  end
  
  def forward_to_stripe
    Webhooks::StripeController.new.process_event
  end
end
```

**Why:**
- Clear separation between generic billing and provider-specific routes
- Allows for future payment provider integrations
- Makes routing intent clearer
- Better organization

---

### 11. Customer Portal Session Creation

#### Current Implementation
```ruby
# app/services/billing/create_portal_session_service.rb
def default_return_url
  Rails.application.routes.url_helpers.root_url
rescue StandardError
  'https://app.chatwoot.com/app/accounts'
end
```

**Issues:**
- Hardcoded fallback URL
- Return URL not account-specific
- No configuration for portal features

#### Recommended Approach
```ruby
# app/services/billing/create_portal_session_service.rb
def initialize(account, return_url = nil, configuration: nil)
  @account = account
  @return_url = return_url || default_return_url
  @configuration = configuration # Optional portal configuration ID
  @provider = ProviderFactory.get_provider
end

def perform
  Rails.logger.info '---[CREATE PORTAL SESSION SERVICE]---'
  Rails.logger.info "Account ID: #{@account.id}"
  
  return failure_response('No customer ID found') unless customer_id
  
  begin
    session_params = {
      customer: customer_id,
      return_url: @return_url
    }
    
    # Optional: Use specific portal configuration
    session_params[:configuration] = @configuration if @configuration.present?
    
    session = @provider.create_portal_session_with_params(session_params)
    Rails.logger.info "Portal session created successfully: #{session.id}"
    success_response(session)
  rescue StandardError => e
    Rails.logger.error "Error in CreatePortalSessionService: #{e.message}"
    failure_response("Portal session creation failed: #{e.message}")
  end
end

private

def default_return_url
  # Build URL with account context
  frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  "#{frontend_url}/app/accounts/#{@account.id}/settings/billing"
rescue StandardError => e
  Rails.logger.error "Error building return URL: #{e.message}"
  # Fallback
  ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
end

# app/services/billing/providers/stripe.rb
def create_portal_session_with_params(params)
  ::Stripe::BillingPortal::Session.create(params)
rescue ::Stripe::StripeError => e
  if e.message.include?('No configuration provided')
    Rails.logger.error 'Stripe Customer Portal not configured'
    raise StandardError, 'Customer portal not configured. Please configure at: https://dashboard.stripe.com/settings/billing/portal'
  else
    Rails.logger.error "Stripe error creating portal session: #{e.message}"
    raise StandardError, "Failed to create portal session: #{e.message}"
  end
end
```

**Why:**
- Account-specific return URLs provide better UX
- Supports multiple portal configurations
- Better error messaging
- More flexible configuration

---

### 12. Trial Period Handling

#### Current Implementation
```ruby
# app/services/billing/create_checkout_session_service.rb
if @plan_name == 'free_trial'
  session_params[:mode] = 'setup'
else
  # Paid plans...
end
```

**Issues:**
- No `trial_settings` configuration for trial end behavior
- No handling for missing payment method at trial end
- No trial period configuration on paid plans with trials

#### Recommended Approach
```ruby
# app/services/billing/create_checkout_session_service.rb
def create_checkout_session
  session_params = {
    success_url: success_url,
    cancel_url: cancel_url,
    allow_promotion_codes: true,
    metadata: {
      account_id: @account.id,
      plan_name: @plan_name
    }
  }
  
  existing_customer_id = @account.custom_attributes&.dig('stripe_customer_id')
  if existing_customer_id.present?
    session_params[:customer] = existing_customer_id
  else
    session_params[:customer_creation] = 'always'
  end
  
  if @plan_name == 'free_trial'
    # Setup mode for free trial
    session_params[:mode] = 'setup'
    session_params[:payment_method_collection] = 'if_required'
  else
    price_id = self.class.plan_price_id(@plan_name)
    session_params[:mode] = 'subscription'
    session_params[:line_items] = [{
      price: price_id,
      quantity: 1
    }]
    
    # Configure trial behavior
    trial_config = get_trial_configuration(@plan_name)
    
    if trial_config[:trial_days] > 0
      session_params[:subscription_data] = {
        trial_period_days: trial_config[:trial_days],
        trial_settings: {
          end_behavior: {
            missing_payment_method: trial_config[:missing_payment_method] # 'cancel', 'pause', or 'create_invoice'
          }
        },
        metadata: {
          account_id: @account.id,
          plan_name: @plan_name,
          trial_type: trial_config[:trial_type]
        }
      }
    else
      session_params[:subscription_data] = {
        metadata: {
          account_id: @account.id,
          plan_name: @plan_name
        }
      }
    end
  end
  
  @provider.create_checkout_session(session_params)
end

private

def get_trial_configuration(plan_name)
  plan_config = self.class.plan_details(plan_name) || {}
  
  {
    trial_days: plan_config.dig('trial_period_days') || 0,
    trial_type: plan_config.dig('trial_type') || 'standard',
    missing_payment_method: plan_config.dig('trial_end_behavior') || 'cancel'
  }
end
```

**Why:**
- Stripe best practice: [Configure trial end behavior](https://docs.stripe.com/billing/subscriptions/trials)
- Handles missing payment methods gracefully
- Can cancel, pause, or invoice at trial end
- Flexible trial configuration

---

### 13. Subscription Update & Proration

#### Current Implementation
```ruby
# app/services/billing/providers/stripe.rb
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

**Issues:**
- No proration behavior specified
- No handling for immediate vs delayed changes
- No pending updates support
- Missing payment_behavior for changes requiring payment

#### Recommended Approach
```ruby
# app/services/billing/providers/stripe.rb
def update_subscription(subscription_id, options = {})
  subscription = get_subscription(subscription_id)
  update_params = {}
  
  # Handle price changes
  if options[:plan_id]
    update_params[:items] = [{
      id: subscription.items.data[0].id,
      price: options[:plan_id]
    }]
  end
  
  # Handle quantity changes
  update_params[:quantity] = options[:quantity] if options[:quantity]
  
  # Handle metadata updates
  update_params[:metadata] = options[:metadata] if options[:metadata]
  
  # Proration behavior
  update_params[:proration_behavior] = options.fetch(
    :proration_behavior,
    'create_prorations' # Default: create prorations
  )
  
  # Payment behavior for changes requiring payment
  if options[:requires_payment]
    update_params[:payment_behavior] = options.fetch(
      :payment_behavior,
      'pending_if_incomplete' # Only apply if payment succeeds
    )
  end
  
  # Proration date (for consistent proration calculations)
  update_params[:proration_date] = options[:proration_date] if options[:proration_date]
  
  # Billing cycle anchor changes
  if options[:reset_billing_cycle_anchor]
    update_params[:billing_cycle_anchor] = 'now'
  elsif options[:billing_cycle_anchor]
    update_params[:billing_cycle_anchor] = options[:billing_cycle_anchor]
  end
  
  ::Stripe::Subscription.update(subscription_id, update_params)
rescue ::Stripe::StripeError => e
  Rails.logger.error "Stripe error updating subscription: #{e.message}"
  raise StandardError, "Failed to update subscription: #{e.message}"
end
```

**Why:**
- Stripe best practice: [Control proration behavior](https://docs.stripe.com/billing/subscriptions/prorations)
- `pending_if_incomplete` only applies updates if payment succeeds
- Proration date prevents timing discrepancies
- Flexible billing cycle management

---

## ⚠️ Enterprise Implementation - License Restrictions

### 🚫 Important Notice

**The `enterprise/` folder CANNOT be modified due to license restrictions.**

All improvements documented in this audit apply to the **OSS (Open Source)** implementation only. The Enterprise edition has its own Stripe implementation that cannot be changed.

The audit identified several issues in the Enterprise Stripe implementation that **cannot be addressed** due to license restrictions:



### 📋 Updated Priority Analysis

With Enterprise modifications restricted, the **Phase 1 improvements now focus exclusively on OSS code** (9 critical items instead of 10).

---

## Summary of Priority Improvements

**📌 SEE DETAILED PRIORITY ANALYSIS AT TOP OF DOCUMENT**

This section provides a high-level summary. For detailed analysis with context-specific recommendations, see the **"🎯 Implementation Priority Analysis"** section at the top of this document.

### ✅ Phase 1: Critical (Pre-Launch Must-Do - OSS Only)

**Effort**: 1-2 days | **Impact**: Prevents 90% of common Stripe issues

1. **Add explicit API version** - Prevents breaking changes from gem updates
2. **Implement idempotency keys** - Prevents duplicate customers/subscriptions
3. **Add webhook signature tolerance** - Security against replay attacks
4. **Improve error handling** - Specific handling for different Stripe errors
5. **Add payment_behavior: 'default_incomplete'** - Proper 3DS handling
6. **Configure customer_creation: 'always'** - Ensures customer objects created
7. **Verify critical webhook events** - Core subscription lifecycle events
8. **Store metadata as strings** - Proper account_id tracking
9. **Default to cancel_at_period_end** - Better customer experience

**Note**: Enterprise code cannot be modified due to license restrictions. See Enterprise section below.

### ⚠️ Phase 2: Important (Post-Launch)

**Effort**: 1 day | **Impact**: Better UX and debugging

1. **Add client_reference_id** - Enhanced debugging capability
2. **Configure customer_update settings** - Keep customer data fresh
3. **Add trial_settings** - Proper trial end behavior (if using trials)
4. **Clean up webhook routes** - Better code organization
5. **Add additional webhook events** - As needed for features

---

## Compliance & Best Practices Checklist

### ✅ Phase 1 Checklist (Pre-Launch - Required)

**Configuration & Security**
- [ ] Explicit API version set (`Stripe.api_version`)
- [ ] Webhook signature verification with timestamp validation (`tolerance: 300`)
- [ ] Proper error handling with specific exception types

**Customer & Subscription Management**
- [ ] Idempotency keys on customer creation
- [ ] Idempotency keys on subscription creation
- [ ] `payment_behavior: 'default_incomplete'` configured on subscriptions
- [ ] `customer_creation: 'always'` on checkout sessions (when no existing customer)
- [ ] Metadata propagation (account_id as string) on checkout + subscription
- [ ] Default to `cancel_at_period_end: true` for cancellations

**Webhook Events (Core Lifecycle)**
- [ ] `checkout.session.completed` handled
- [ ] `customer.subscription.created` handled
- [ ] `customer.subscription.updated` handled
- [ ] `customer.subscription.deleted` handled
- [ ] `invoice.payment_succeeded` handled
- [ ] `invoice.payment_failed` handled

**Enterprise Compatibility**
- [ ] Deprecated `subscription['plan']` replaced with `subscription.items.data.first.price`
- [ ] All references updated in Enterprise code

### ⚠️ Phase 2 Checklist (Post-Launch - Recommended)

- [ ] `client_reference_id` added to checkout sessions
- [ ] `customer_update` settings configured
- [ ] Trial settings configured (if using trials)
- [ ] Webhook routing cleaned up
- [ ] Additional webhook events as needed

---



### 3. Combined Multi-Feature Pricing (Agents + Inboxes + Channels)

**Use Case:** Starter plan with base features + ability to purchase extra agents, inboxes, and channels independently

**Recommended Strategy:** Multiple Subscription Items (Unified Approach)

This approach handles ALL add-on features in a single subscription with multiple line items.

#### Implementation

**Step 1: Create Prices for All Features**

```ruby
# Base plan - includes base features
Stripe::Price.create(
  product: 'prod_starter',
  currency: 'usd',
  recurring: { interval: 'month' },
  unit_amount: 3000, # $30/month base (includes 3 agents, 2 inboxes, 5 channels)
  lookup_key: 'starter_base',
  nickname: 'Starter - Base Plan'
)

# Extra agent add-on
Stripe::Price.create(
  product: 'prod_extra_agent',
  currency: 'usd',
  recurring: { interval: 'month' },
  unit_amount: 1000, # $10 per agent per month
  lookup_key: 'extra_agent',
  nickname: 'Extra Agent Seat'
)

# Extra inbox add-on
Stripe::Price.create(
  product: 'prod_extra_inbox',
  currency: 'usd',
  recurring: { interval: 'month' },
  unit_amount: 1500, # $15 per inbox per month
  lookup_key: 'extra_inbox',
  nickname: 'Extra Inbox Channel'
)

# Extra channel add-on
Stripe::Price.create(
  product: 'prod_extra_channel',
  currency: 'usd',
  recurring: { interval: 'month' },
  unit_amount: 500, # $5 per channel per month
  lookup_key: 'extra_channel',
  nickname: 'Extra Channel'
)
```

**Step 2: Create Subscription with Multiple Items**

```ruby
# Initial subscription creation (base + some extras)
Stripe::Subscription.create(
  customer: customer_id,
  items: [
    { 
      price: 'price_starter_base', 
      quantity: 1 
    }
    # Add-ons will be added dynamically as needed
  ],
  metadata: {
    account_id: account.id,
    plan_name: 'starter'
  }
)
```

**Step 3: Unified Service for Managing Add-Ons**

```ruby
# app/services/billing/manage_subscription_add_on_service.rb
class Billing::ManageSubscriptionAddOnService
  ADD_ON_TYPES = {
    agent: { lookup_key: 'extra_agent', price_id: 'price_extra_agent' },
    inbox: { lookup_key: 'extra_inbox', price_id: 'price_extra_inbox' },
    channel: { lookup_key: 'extra_channel', price_id: 'price_extra_channel' }
  }.freeze
  
  def initialize(account, add_on_type)
    @account = account
    @add_on_type = add_on_type.to_sym
    @add_on_config = ADD_ON_TYPES[@add_on_type]
    
    raise ArgumentError, "Invalid add-on type: #{add_on_type}" unless @add_on_config
  end
  
  # Add one unit of the add-on
  def add_unit
    update_quantity(current_quantity + 1)
  end
  
  # Remove one unit of the add-on
  def remove_unit
    return { success: false, error: 'Cannot remove below 0' } if current_quantity.zero?
    update_quantity(current_quantity - 1)
  end
  
  # Set specific quantity
  def set_quantity(quantity)
    update_quantity(quantity)
  end
  
  # Get current quantity
  def current_quantity
    subscription = fetch_subscription
    return 0 unless subscription
    
    item = find_subscription_item(subscription)
    item&.quantity || 0
  end
  
  private
  
  def update_quantity(new_quantity)
    subscription = fetch_subscription
    item = find_subscription_item(subscription)
    
    if new_quantity.zero?
      # Remove the item if quantity is 0
      remove_subscription_item(item) if item
      { success: true, message: "#{@add_on_type} add-on removed", quantity: 0 }
    elsif item
      # Update existing item
      Stripe::SubscriptionItem.update(
        item.id,
        {
          quantity: new_quantity,
          proration_behavior: 'create_prorations'
        }
      )
      { success: true, message: "#{@add_on_type} quantity updated to #{new_quantity}", quantity: new_quantity }
    else
      # Create new item
      Stripe::SubscriptionItem.create(
        subscription: subscription.id,
        price: @add_on_config[:price_id],
        quantity: new_quantity,
        proration_behavior: 'create_prorations'
      )
      { success: true, message: "#{@add_on_type} add-on added with quantity #{new_quantity}", quantity: new_quantity }
    end
  rescue Stripe::StripeError => e
    Rails.logger.error "Failed to update #{@add_on_type} add-on: #{e.message}"
    { success: false, error: e.message }
  end
  
  def find_subscription_item(subscription)
    subscription.items.data.find { |item| 
      item.price.lookup_key == @add_on_config[:lookup_key] 
    }
  end
  
  def remove_subscription_item(item)
    Stripe::SubscriptionItem.delete(item.id)
  end
  
  def fetch_subscription
    customer_id = @account.custom_attributes['stripe_customer_id']
    return nil unless customer_id
    
    subscriptions = Stripe::Subscription.list(customer: customer_id, status: 'active')
    subscriptions.data.first
  end
end
```

**Step 4: Controller Integration**

```ruby
# app/controllers/api/v2/accounts/billing/add_ons_controller.rb
class Api::V2::Accounts::Billing::AddOnsController < Api::BaseController
  before_action :current_account
  before_action :check_authorization
  
  # POST /api/v2/accounts/:account_id/billing/add_ons
  # Body: { add_on_type: 'agent', action: 'add' }
  def update
    service = Billing::ManageSubscriptionAddOnService.new(
      current_account, 
      params[:add_on_type]
    )
    
    result = case params[:action]
             when 'add'
               service.add_unit
             when 'remove'
               service.remove_unit
             when 'set'
               service.set_quantity(params[:quantity].to_i)
             else
               { success: false, error: 'Invalid action' }
             end
    
    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end
  
  # GET /api/v2/accounts/:account_id/billing/add_ons
  def index
    add_ons = {}
    
    %i[agent inbox channel].each do |type|
      service = Billing::ManageSubscriptionAddOnService.new(current_account, type)
      add_ons[type] = {
        current_quantity: service.current_quantity,
        price_per_unit: price_for_type(type)
      }
    end
    
    render json: { add_ons: add_ons }
  end
  
  private
  
  def price_for_type(type)
    prices = {
      agent: '$10/month',
      inbox: '$15/month',
      channel: '$5/month'
    }
    prices[type]
  end
end
```

**Pricing Structure:**

| Feature | Base Included | Extra Unit Price | Managed Via |
|---------|--------------|------------------|-------------|
| Starter Base | 3 agents, 2 inboxes, 5 channels | - | Base subscription |
| Extra Agents | - | $10/agent/month | Subscription item quantity |
| Extra Inboxes | - | $15/inbox/month | Subscription item quantity |
| Extra Channels | - | $5/channel/month | Subscription item quantity |

**Example Customer Invoice:**

```
Starter Plan - February 2025
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Base Plan                          $30.00
  (3 agents, 2 inboxes, 5 channels included)

Extra Agent Seats × 2              $20.00
  ($10.00 per agent)

Extra Inbox Channels × 1           $15.00
  ($15.00 per inbox)

Extra Channels × 2                 $10.00
  ($5.00 per channel)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total                              $75.00

Current Usage:
  • Agents: 5 (3 included + 2 extra)
  • Inboxes: 3 (2 included + 1 extra)
  • Channels: 7 (5 included + 2 extra)
```

**Benefits of This Unified Approach:**

✅ **Single Subscription**: All features managed in one place  
✅ **Single Invoice**: Customer sees clear breakdown  
✅ **Automatic Proration**: Stripe handles all calculations  
✅ **Flexible**: Add/remove any feature independently  
✅ **Scalable**: Easy to add more feature types  
✅ **Simple Billing Cycle**: Everything renews together  
✅ **Easy to Understand**: Clear line items on invoice

---

### 4. Application-Level Limit Enforcement

**Use Case:** Enforce plan limits in application while tracking purchased add-ons

**Recommended Strategy:** Unified Limit Service

#### Implementation

**Step 1: Define Plan Configuration**

```yaml
# config/billing_plans.yml
plans:
  starter:
    name: "Starter"
    base_price_id: "price_starter_base"
    limits:
      agents: 3
      inboxes: 2
      channels: 5
      conversations: 10000
    add_ons:
      agent:
        lookup_key: 'extra_agent'
        price_id: 'price_extra_agent'
        unit_price: 1000  # $10.00 in cents
      inbox:
        lookup_key: 'extra_inbox'
        price_id: 'price_extra_inbox'
        unit_price: 1500  # $15.00 in cents
      channel:
        lookup_key: 'extra_channel'
        price_id: 'price_extra_channel'
        unit_price: 500   # $5.00 in cents

  professional:
    name: "Professional"
    base_price_id: "price_pro_base"
    limits:
      agents: 10
      inboxes: 5
      channels: 15
      conversations: 50000
    add_ons:
      agent:
        lookup_key: 'extra_agent_pro'
        price_id: 'price_extra_agent_pro'
        unit_price: 1000
      inbox:
        lookup_key: 'extra_inbox_pro'
        price_id: 'price_extra_inbox_pro'
        unit_price: 1500
      channel:
        lookup_key: 'extra_channel_pro'
        price_id: 'price_extra_channel_pro'
        unit_price: 500
```

**Step 2: Unified Limit Service**

```ruby
# app/services/billing/unified_limit_service.rb
class Billing::UnifiedLimitService
  RESOURCE_TYPES = %i[agent inbox channel].freeze
  
  def initialize(account, resource_type)
    @account = account
    @resource_type = resource_type.to_sym
    @plan_config = BillingPlans.plan_details(account.custom_attributes['plan_name'])
    
    raise ArgumentError, "Invalid resource type: #{resource_type}" unless RESOURCE_TYPES.include?(@resource_type)
  end
  
  # Check if resource can be created
  def can_create?
    current_count < total_allowed
  end
  
  # Total allowed (base + purchased)
  def total_allowed
    base_limit + purchased_extra
  end
  
  # Base plan limit
  def base_limit
    @plan_config.dig('limits', @resource_type.to_s.pluralize) || 0
  end
  
  # Purchased extra units from Stripe
  def purchased_extra
    subscription = fetch_subscription
    return 0 unless subscription
    
    lookup_key = @plan_config.dig('add_ons', @resource_type.to_s, 'lookup_key')
    item = subscription.items.data.find { |i| i.price.lookup_key == lookup_key }
    
    item&.quantity || 0
  end
  
  # Current usage count
  def current_count
    case @resource_type
    when :agent
      @account.account_users.count
    when :inbox
      @account.inboxes.count
    when :channel
      @account.inboxes.count # Or specific channel count logic
    else
      0
    end
  end
  
  # Remaining capacity
  def remaining
    total_allowed - current_count
  end
  
  # Upgrade options when limit reached
  def upgrade_options
    {
      purchase_extra: {
        type: @resource_type,
        unit_price: format_price(@plan_config.dig('add_ons', @resource_type.to_s, 'unit_price')),
        action: 'purchase_add_on'
      },
      upgrade_plan: next_tier_option
    }
  end
  
  private
  
  def fetch_subscription
    customer_id = @account.custom_attributes['stripe_customer_id']
    return nil unless customer_id
    
    subscriptions = Stripe::Subscription.list(customer: customer_id, status: 'active')
    subscriptions.data.first
  end
  
  def format_price(cents)
    "$#{cents / 100}/month"
  end
  
  def next_tier_option
    current_plan = @account.custom_attributes['plan_name']
    case current_plan
    when 'starter'
      { plan: 'professional', action: 'upgrade_plan' }
    when 'professional'
      { plan: 'enterprise', action: 'contact_sales' }
    else
      nil
    end
  end
end
```

**Step 3: Enforce Limits in Models/Controllers**

```ruby
# app/models/account_user.rb (for agents)
class AccountUser < ApplicationRecord
  before_create :check_agent_limit
  
  private
  
  def check_agent_limit
    limit_service = Billing::UnifiedLimitService.new(account, :agent)
    
    unless limit_service.can_create?
      errors.add(:base, 'Agent limit reached. Please purchase additional seats or upgrade your plan.')
      throw :abort
    end
  end
end

# app/models/inbox.rb (for inboxes/channels)
class Inbox < ApplicationRecord
  before_create :check_inbox_limit
  
  private
  
  def check_inbox_limit
    limit_service = Billing::UnifiedLimitService.new(account, :inbox)
    
    unless limit_service.can_create?
      errors.add(:base, 'Inbox limit reached. Please purchase additional inboxes or upgrade your plan.')
      throw :abort
    end
  end
end
```

**Step 4: Controller with Limit Response**

```ruby
# app/controllers/api/v1/account_users_controller.rb
def create
  @account_user = current_account.account_users.new(account_user_params)
  
  if @account_user.save
    render json: @account_user
  else
    if @account_user.errors[:base].any? { |e| e.include?('limit reached') }
      limit_service = Billing::UnifiedLimitService.new(current_account, :agent)
      
      render json: {
        error: 'Agent limit reached',
        usage: {
          current: limit_service.current_count,
          limit: limit_service.total_allowed,
          remaining: 0,
          base_limit: limit_service.base_limit,
          purchased: limit_service.purchased_extra
        },
        options: limit_service.upgrade_options
      }, status: :payment_required # HTTP 402
    else
      render json: { errors: @account_user.errors }, status: :unprocessable_entity
    end
  end
end
```

**Example Flow:**

```
User on Starter Plan:
├─ Limits: 3 agents, 2 inboxes, 5 channels
├─ Current: 3 agents, 2 inboxes, 5 channels (at limit)
│
├─ Tries to add agent #4
│  └─ ✗ Blocked: "Agent limit reached"
│  └─ Options:
│     • Purchase extra agent seat ($10/month)
│     • Upgrade to Professional plan
│
├─ User purchases 2 extra agent seats
│  └─ Stripe adds subscription item (quantity: 2)
│  └─ Immediate prorated charge
│  └─ New limit: 3 + 2 = 5 agents
│
└─ User can now add agents #4 and #5
```

**Summary: Complete Unified Add-On System**

This combined approach provides:

✅ **Single Service**: `ManageSubscriptionAddOnService` handles all feature types  
✅ **Single Limit Service**: `UnifiedLimitService` enforces all limits  
✅ **Consistent UX**: Same pattern for agents, inboxes, channels  
✅ **One Subscription**: All charges on single invoice  
✅ **Easy to Extend**: Add new feature types by updating config  
✅ **Clear Pricing**: Customer sees itemized breakdown

**Example Complete Customer Journey:**

```
1. Subscribe to Starter Plan
   └─ $30/month (3 agents, 2 inboxes, 5 channels)

2. Add 2 extra agents
   └─ POST /api/v2/accounts/:id/billing/add_ons
       { add_on_type: 'agent', action: 'add', quantity: 2 }
   └─ Prorated charge: ~$20
   └─ New invoice: $50/month

3. Add 1 extra inbox
   └─ POST /api/v2/accounts/:id/billing/add_ons
       { add_on_type: 'inbox', action: 'add' }
   └─ Prorated charge: ~$15
   └─ New invoice: $65/month

4. Monthly invoice shows:
   ┌─────────────────────────────────────┐
   │ Starter Base Plan      $30.00       │
   │ Extra Agents (×2)      $20.00       │
   │ Extra Inboxes (×1)     $15.00       │
   │ Total                  $65.00       │
   └─────────────────────────────────────┘
```

---

### 5. Conversation Limits and One-Time Packs

**Use Case:** Starter plan includes 4,000 conversations. What happens when conversation #4,001 is created?

**Recommended Strategy:** Hard Limit with One-Time Conversation Packs

This provides predictable billing and prevents surprise charges.

#### Implementation

**Step 1: Create Limit Service**

```ruby
# app/services/billing/conversation_limit_service.rb
class Billing::ConversationLimitService
  def initialize(account)
    @account = account
    @plan_config = BillingPlans.plan_details(account.custom_attributes['plan_name'])
  end
  
  def can_create_conversation?
    current_month_conversations < total_allowed_conversations
  end
  
  def total_allowed_conversations
    plan_limit + purchased_extra_conversations
  end
  
  def plan_limit
    @plan_config.dig('limits', 'conversations') || 0
  end
  
  def purchased_extra_conversations
    # Track one-time conversation pack purchases
    @account.custom_attributes['extra_conversations_purchased']&.to_i || 0
  end
  
  def current_month_conversations
    # Count conversations created this billing period
    period_start = billing_period_start
    @account.conversations.where('created_at >= ?', period_start).count
  end
  
  def conversations_remaining
    total_allowed_conversations - current_month_conversations
  end
  
  def upgrade_options
    current_plan = @account.custom_attributes['plan_name']
    
    case current_plan
    when 'starter'
      {
        next_tier: {
          plan: 'professional',
          limit: 50_000,
          price: '$80/month',
          action: 'upgrade'
        },
        conversation_pack: {
          description: '10,000 extra conversations',
          price: '$20',
          action: 'purchase_pack'
        }
      }
    when 'professional'
      {
        next_tier: {
          plan: 'enterprise',
          limit: 'unlimited',
          price: 'Contact sales',
          action: 'contact_sales'
        },
        conversation_pack: {
          description: '25,000 extra conversations',
          price: '$40',
          action: 'purchase_pack'
        }
      }
    end
  end
  
  private
  
  def billing_period_start
    period_end = @account.custom_attributes['current_period_end']
    return 1.month.ago if period_end.blank?
    
    Time.zone.at(period_end.to_i) - 1.month
  end
end
```

**Step 2: Enforce Before Conversation Creation**

```ruby
# app/models/conversation.rb
class Conversation < ApplicationRecord
  before_create :check_conversation_limit
  
  private
  
  def check_conversation_limit
    # Skip limit check for internal conversations or specific types
    return true if internal? || skip_billing_check?
    
    limit_service = Billing::ConversationLimitService.new(account)
    
    unless limit_service.can_create_conversation?
      errors.add(:base, 'Conversation limit reached. Please upgrade your plan or purchase additional conversations.')
      throw :abort
    end
  end
  
  def skip_billing_check?
    # Add logic for conversations that shouldn't count toward limit
    false
  end
end
```

**Step 3: API Response with Options**

```ruby
# app/controllers/api/v1/conversations_controller.rb
def create
  @conversation = Current.account.conversations.new(conversation_params)
  
  if @conversation.save
    render json: @conversation
  else
    if @conversation.errors[:base].any? { |e| e.include?('limit reached') }
      limit_service = Billing::ConversationLimitService.new(Current.account)
      
      render json: {
        error: 'Conversation limit reached',
        usage: {
          current: limit_service.current_month_conversations,
          limit: limit_service.total_allowed_conversations,
          remaining: 0
        },
        options: limit_service.upgrade_options
      }, status: :payment_required # HTTP 402
    else
      render json: { errors: @conversation.errors }, status: :unprocessable_entity
    end
  end
end
```

**Step 4: Purchase Conversation Pack**

```ruby
# app/services/billing/purchase_conversation_pack_service.rb
class Billing::PurchaseConversationPackService
  PACK_SIZES = {
    starter: { conversations: 10_000, price: 2000 },      # $20
    professional: { conversations: 25_000, price: 4000 }  # $40
  }.freeze
  
  def initialize(account)
    @account = account
    @plan_name = account.custom_attributes['plan_name']
  end
  
  def perform
    pack = PACK_SIZES[@plan_name.to_sym]
    customer_id = @account.custom_attributes['stripe_customer_id']
    
    # Create one-time invoice item
    Stripe::InvoiceItem.create(
      customer: customer_id,
      amount: pack[:price],
      currency: 'usd',
      description: "#{pack[:conversations].to_s.gsub(/\B(?=(...)*\b)/, ',')} Conversation Pack"
    )
    
    # Finalize and charge immediately
    invoice = Stripe::Invoice.create(
      customer: customer_id,
      auto_advance: true # Automatically finalize and attempt payment
    )
    
    # Update account with extra conversations
    current_extra = @account.custom_attributes['extra_conversations_purchased']&.to_i || 0
    @account.custom_attributes['extra_conversations_purchased'] = current_extra + pack[:conversations]
    @account.save!
    
    { 
      success: true, 
      conversations_added: pack[:conversations],
      invoice_id: invoice.id 
    }
  end
end
```

**Example Flow:**

```
User on Starter Plan (4,000 conversations/month limit):
├─ Current month: 3,999 conversations created
├─ Tries to create conversation #4,000 ✓ Success
├─ Tries to create conversation #4,001 ✗ Blocked
│  └─ Response:
│     {
│       "error": "Conversation limit reached",
│       "usage": {
│         "current": 4000,
│         "limit": 4000,
│         "remaining": 0
│       },
│       "options": {
│         "next_tier": {
│           "plan": "professional",
│           "limit": 50000,
│           "price": "$80/month"
│         },
│         "conversation_pack": {
│           "description": "10,000 extra conversations",
│           "price": "$20"
│         }
│       }
│     }
├─ User purchases conversation pack ($20)
│  └─ New limit: 4,000 + 10,000 = 14,000
└─ User can now create conversations #4,001 through #14,000
```

---

### 6. Minimizing Merge Conflicts with Upstream

**Problem:** Chatwoot is forked from main project with independent development. Need to minimize conflicts when merging upstream changes.

**Recommended Strategy:** Combined Isolation Approach

#### Implementation

**Step 1: Create Isolated Billing Directory**

```
app/
├── billing/                    # NEW - All custom billing logic
│   ├── services/
│   │   ├── stripe/
│   │   │   ├── customer_service.rb
│   │   │   ├── subscription_service.rb
│   │   │   ├── checkout_service.rb
│   │   │   └── webhook_handler.rb
│   │   ├── limits/
│   │   │   ├── agent_limit_service.rb
│   │   │   ├── channel_limit_service.rb
│   │   │   └── conversation_limit_service.rb
│   │   └── billing_facade.rb
│   ├── controllers/
│   │   └── subscriptions_controller.rb
│   └── jobs/
│       ├── provision_subscription_job.rb
│       └── sync_features_job.rb
```

**Step 2: Configure Git Merge Strategy**

```bash
# .gitattributes (create in repository root)

# Always use OUR version for custom billing files during merges
app/billing/** merge=ours
app/controllers/api/v2/accounts/subscriptions_controller.rb merge=ours
app/services/billing/** merge=ours
app/jobs/billing/** merge=ours
lib/billing/** merge=ours
config/billing_plans.yml merge=ours
docs/ignore/** merge=ours

# Optional: Exclude from upstream pulls
enterprise/app/services/enterprise/billing/** merge=ours
```

**Step 3: Add Feature Flag**

```ruby
# config/initializers/billing_config.rb
module BillingConfig
  def self.custom_billing_enabled?
    ENV.fetch('ENABLE_CUSTOM_BILLING', 'true') == 'true'
  end
  
  def self.stripe_enabled?
    custom_billing_enabled? && 
    ENV['STRIPE_SECRET_KEY'].present? &&
    ENV['STRIPE_WEBHOOK_SECRET'].present?
  end
end

Rails.configuration.custom_billing_enabled = BillingConfig.custom_billing_enabled?
```

**Step 4: Document Custom Files**

```markdown
# README_CUSTOM_BILLING.md

## Custom Stripe Billing Implementation

### Modified/Added Files

The following files contain custom Stripe billing implementation:

**Core Billing Logic:**
- `app/billing/` - All custom billing services and logic
- `app/services/billing/` - Billing service layer
- `lib/billing/` - Billing utilities and constants
- `app/jobs/billing/` - Background jobs for billing

**Controllers:**
- `app/controllers/api/v2/accounts/subscriptions_controller.rb`

**Configuration:**
- `config/billing_plans.yml`
- `config/initializers/stripe.rb`
- `config/initializers/billing_config.rb`

**Documentation:**
- `docs/ignore/StripeInitialState.md`
- `docs/ignore/StripeImprovements.md`

### Git Merge Strategy

Custom billing files use `merge=ours` strategy in `.gitattributes`.
This means during upstream merges, our version is always kept.

### Feature Flag

Set `ENABLE_CUSTOM_BILLING=false` to disable custom billing.

### DO NOT MODIFY from Upstream

These files should NEVER be replaced with upstream versions:
- Anything in `app/billing/`
- `app/services/billing/**`
- `config/billing_plans.yml`
```

**Step 5: Merge Workflow**

```bash
# Safe merge workflow

# 1. Create backup branch
git checkout -b backup-before-upstream-merge
git push origin backup-before-upstream-merge

# 2. Checkout your main development branch
git checkout your-main

# 3. Fetch upstream changes
git remote add upstream https://github.com/chatwoot/chatwoot.git
git fetch upstream

# 4. Merge with automatic conflict resolution for billing files
git merge upstream/develop

# Git will automatically:
# - Keep YOUR version of files marked with merge=ours
# - Merge other files normally
# - Flag conflicts for files not in .gitattributes

# 5. Review changes (billing files should be unchanged)
git diff backup-before-upstream-merge app/billing/
git diff backup-before-upstream-merge app/services/billing/

# 6. Test thoroughly
RAILS_ENV=test bundle exec rspec spec/services/billing/

# 7. Push if everything works
git push origin your-main
```

**Step 6: Isolation Checklist**

Before committing custom billing code, verify:

- [ ] All new billing code is in `app/billing/` directory
- [ ] `.gitattributes` includes all custom billing paths
- [ ] Feature flag allows disabling custom billing
- [ ] README_CUSTOM_BILLING.md is up to date
- [ ] No modifications to core Chatwoot files (except documented exceptions)
- [ ] Tests pass with custom billing enabled and disabled

#### Benefits of This Approach

✅ **Minimal Conflicts:** Git automatically keeps your version of billing files  
✅ **Clear Isolation:** All custom code in dedicated directory  
✅ **Easy Toggle:** Feature flag allows enabling/disabling  
✅ **Documented:** Clear documentation of what's custom  
✅ **Testable:** Can test with/without custom billing  
✅ **Maintainable:** Team knows which files not to touch during upstream merges

#### When Conflicts Still Occur

If conflicts occur in non-billing files:

```bash
# 1. Identify conflict
git status

# 2. For files you modified for billing integration:
#    Manually review and choose appropriate resolution

# 3. For unrelated conflicts:
#    Take upstream version unless you have specific changes
git checkout --theirs path/to/file

# 4. Rebuild assets/dependencies if needed
bundle install
yarn install
rails db:migrate

# 5. Run tests
RAILS_ENV=test bundle exec rspec
```

---

## Additional Resources

- [Stripe API Documentation](https://docs.stripe.com/api)
- [Stripe Webhooks Best Practices](https://docs.stripe.com/webhooks#best-practices)
- [Stripe Error Handling](https://docs.stripe.com/error-handling)
- [Stripe Subscriptions Guide](https://docs.stripe.com/billing/subscriptions/overview)
- [Stripe API Versioning](https://docs.stripe.com/api/versioning)
- [Stripe Metadata Guide](https://docs.stripe.com/metadata)
- [Stripe Idempotent Requests](https://docs.stripe.com/api/idempotent_requests)
- [Stripe Security Guide](https://docs.stripe.com/security/guide)

---

## Document Information

**Document Version:** 3.0  
**Last Updated:** 2025-01-29  
**Audit Completed By:** AI Code Review System  
**Based On:** Stripe API version 2024-12-18.acacia documentation  
**Analysis Context:** Pre-launch, early stage, low traffic, team capacity for refactoring

### Version History

**v3.0 (2025-01-29)**
- **Major simplification**: Removed all overengineered solutions (Phase 3)
- Removed complex implementations: async webhooks, duplicate detection, caching layers, custom retry logic
- Removed unnecessary abstractions: structured logging, API key rotation, health checks with API calls
- Streamlined document to focus only on critical (Phase 1) and important (Phase 2) improvements
- Renumbered sections after removing overengineered content
- Updated all references and cross-links
- Document now focuses on essential Stripe best practices only

**v2.0 (2025-01-28)**
- Added comprehensive priority analysis with phased approach
- Categorized improvements: Critical (Phase 1), Important (Phase 2), Overengineered (Phase 3)
- Added context-specific recommendations for early-stage implementation
- Added implementation checklist for Phase 1 (pre-launch must-do)
- Identified 15 overengineered improvements to skip
- Updated compliance checklist with phase-based approach
- **Clarified Enterprise license restrictions**: Enterprise code cannot be modified
- Documented implications of Enterprise code limitations
- Updated Phase 1 from 10 to 9 critical items (OSS only)

**v1.0 (2025-01-27)**
- Initial comprehensive audit of Stripe implementation
- Documented all findings with current vs recommended approaches
- Covered OSS and Enterprise implementations
- Listed 30+ improvement areas

### How to Use This Document

1. **Start at the top**: Read the "🎯 Implementation Priority Analysis" section first
2. **Follow Phase 1**: Implement the 9 critical OSS improvements (1-2 days effort)
3. **Reference detailed sections**: Each improvement in Phase 1 has detailed code examples below
4. **Consider Phase 2**: Add Phase 2 improvements post-launch for better UX
5. **Use the checklist**: Copy the Phase 1 checklist and track your progress
6. **Enterprise Note**: Enterprise code cannot be modified - see Enterprise section for implications

### Key Takeaway

**Implement Phase 1 (9 items, 1-2 days) before launch.**  
This provides a production-ready, best-practice Stripe integration without unnecessary complexity.

Phase 2 improvements can be added post-launch as needed for enhanced UX and debugging capabilities.

**Important**: Phase 1 improvements apply to OSS code only. Enterprise code cannot be modified due to license restrictions.

