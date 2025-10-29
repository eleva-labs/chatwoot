# Stripe Implementation Analysis - Chatwoot

## Overview

This document provides a comprehensive analysis of the Stripe payment integration in Chatwoot. The implementation follows a service-oriented architecture with provider abstraction, allowing for potential future integration with other payment providers.

## Architecture Overview

### Core Components

1. **Provider Pattern**: Abstract base class (`Billing::Providers::Base`) with Stripe-specific implementation (`Billing::Providers::Stripe`)
2. **Service Layer**: Business logic services for customer creation, checkout sessions, and webhook handling
3. **Configuration**: YAML-based plan and feature configuration
4. **Webhook Processing**: Real-time event handling for subscription changes
5. **Frontend Integration**: Vue.js components for billing management

## Database Schema

### Account Model Integration

Stripe data is stored in the `accounts` table using the `custom_attributes` JSONB field:

```sql
-- Key Stripe-related fields in accounts.custom_attributes:
{
  "stripe_customer_id": "cus_xxxxx",           -- Stripe customer ID
  "plan_name": "starter",                      -- Current plan name
  "subscription_status": "active",             -- Subscription status
  "current_period_end": 1234567890,           -- Unix timestamp
  "subscription_ends_on": "2024-01-15",       -- Human-readable date
  "cancel_at_period_end": false,              -- Cancellation flag
  "canceled_at": null,                        -- Cancellation timestamp
  "ended_at": null,                           -- End timestamp
  "last_payment_status": "succeeded",         -- Payment status
  "last_payment_date": "2024-01-01",          -- Last payment date
  "billing_status": "active",                 -- Internal billing status
  "billing_status_updated_at": "2024-01-01T00:00:00Z"
}
```

### No Dedicated Stripe Tables

Chatwoot uses a flexible approach storing all Stripe-related data in the existing `accounts.custom_attributes` JSONB field, avoiding the need for additional database tables.

## Configuration Files

### 1. Billing Plans (`config/billing_plans.yml`)

```yaml
plans:
  community:
    name: "Community"
    price_id: null
    feature_tiers: ["community"]
    limits:
      agents: 0
      inboxes: 0
      conversations_monthly: 0

  free_trial:
    name: "Free Trial"
    price_id: null
    trial_expires_in_days: 7
    feature_tiers: ["starter"]
    limits:
      agents: 2
      inboxes: 2
      conversations_monthly: 1000

  starter:
    name: "Starter"
    price_id: "price_1RqHHDLIubTPR6wgjFoVzrfR"
    feature_tiers: ["starter"]
    limits:
      agents: 5
      inboxes: 2
      conversations_monthly: 4000

  professional:
    name: "Professional"
    price_id: "THIS_SHOULD_BE_REPLACED_WITH_ACTUAL_PRICE_ID"
    feature_tiers: ["starter", "professional"]
    limits:
      agents: 15
      inboxes: 2
      conversations_monthly: 10000

  enterprise:
    name: "Enterprise"
    price_id: "THIS_SHOULD_BE_REPLACED_WITH_ACTUAL_PRICE_ID"
    feature_tiers: ["starter", "professional", "enterprise"]
    limits:
      agents: -1  # Unlimited
      inboxes: -1
      conversations_monthly: -1

default_plan: "free_trial"
```

### 2. Features Configuration (`config/features.yml`)

Features are organized by tiers (community, starter, professional, enterprise) with each feature having:
- `name`: Internal identifier
- `display_name`: UI display name
- `enabled`: Default enabled state
- `tier`: Subscription tier required
- `help_url`: Documentation link
- `chatwoot_internal`: Internal-only features

### 3. Stripe Initializer (`config/initializers/stripe.rb`)

```ruby
require 'stripe'
Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)
```

## Service Layer Architecture

### 1. Provider Factory (`app/services/billing/provider_factory.rb`)

```ruby
class ProviderFactory
  def self.get_provider
    provider_name = ENV.fetch('PAYMENT_PROVIDER', 'stripe').camelize
    provider_class = "Billing::Providers::#{provider_name}".constantize
    provider_class.new
  end
end
```

### 2. Base Provider (`app/services/billing/providers/base.rb`)

Abstract base class defining the interface for all payment providers:
- `create_customer(account, plan_name)`
- `create_subscription(customer_id, plan_id, quantity)`
- `create_portal_session(customer_id, return_url)`
- `handle_webhook(event_data)`
- `verify_webhook_signature(payload, signature, secret)`
- `get_customer(customer_id)`
- `get_subscription(subscription_id)`
- `cancel_subscription(subscription_id)`
- `update_subscription(subscription_id, options)`

### 3. Stripe Provider (`app/services/billing/providers/stripe.rb`)

Complete Stripe implementation with:

#### Customer Management
- Creates Stripe customers with account metadata
- Handles customer retrieval and updates
- Manages customer portal sessions

#### Subscription Management
- Creates subscriptions with trial periods
- Handles subscription updates and cancellations
- Manages subscription status transitions

#### Webhook Processing
Handles multiple Stripe webhook events:
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`
- `product.updated`

#### Dynamic Plan Resolution
- Fetches plan data from Stripe Product metadata
- Caches plan information for performance
- Supports environment-specific configurations

## Business Logic Services

### 1. Create Customer Service (`app/services/billing/create_customer_service.rb`)

Handles the complete customer creation flow:
1. Validates account eligibility
2. Creates Stripe customer
3. Creates subscription (if not free trial)
4. Updates account attributes
5. Syncs account features

### 2. Create Checkout Session Service (`app/services/billing/create_checkout_session_service.rb`)

Creates Stripe Checkout sessions for:
- Free trial plans (setup mode)
- Paid plans (subscription mode)
- Handles existing customer reuse

### 3. Create Portal Session Service (`app/services/billing/create_portal_session_service.rb`)

Creates Stripe Customer Portal sessions for self-service billing management.

### 4. Sync Account Features Service (`app/services/billing/sync_account_features_service.rb`)

Synchronizes account features based on the current plan:
- Enables/disables features based on plan tiers
- Handles feature flag management
- Updates account feature flags

### 5. Webhook Services

#### Handle Event Service (`app/services/billing/handle_event_service.rb`)
Generic webhook handler that delegates to the configured provider.

#### Webhook Service (`app/services/billing/webhook_service.rb`)
Additional abstraction layer for webhook processing with provider-agnostic interface.

## Webhook Processing

### Webhook Controller (`app/controllers/webhooks/stripe_controller.rb`)

```ruby
def process_event
  payload = request.body.read
  sig_header = request.env['HTTP_STRIPE_SIGNATURE']
  
  # Verify webhook signature
  event = verify_webhook_signature(payload, sig_header)
  
  # Process the event
  service = Billing::HandleEventService.new(event)
  result = service.perform
  
  # Return appropriate response
end
```

### Webhook Routes

```ruby
# Generic billing webhook endpoints (provider-agnostic)
post 'billing/process_event', to: 'billing#process_event'
get 'billing/health', to: 'billing#health'

# Legacy Stripe-specific endpoints (for backward compatibility)
post 'stripe/process_event', to: 'billing#process_event'
get 'stripe/health', to: 'billing#health'
```

### Event Processing Flow

1. **Signature Verification**: Validates webhook authenticity using `STRIPE_WEBHOOK_SECRET`
2. **Event Parsing**: Extracts event type and data
3. **Provider Delegation**: Routes to appropriate provider handler
4. **Account Resolution**: Finds account by customer ID or metadata
5. **Data Update**: Updates account attributes and features
6. **Response**: Returns success/error response

## API Endpoints

### Subscription Controller (`app/controllers/api/v2/accounts/subscriptions_controller.rb`)

#### GET `/api/v2/accounts/:account_id/subscription`
Returns current subscription data:
```json
{
  "success": true,
  "data": {
    "account_id": 123,
    "plan_name": "starter",
    "subscription_status": "active",
    "customer_id": "cus_xxxxx",
    "current_period_end": 1234567890,
    "subscription_ends_on": "2024-01-15",
    "last_payment_status": "succeeded",
    "last_payment_date": "2024-01-01",
    "cancel_at_period_end": false,
    "canceled_at": null,
    "ended_at": null
  }
}
```

#### POST `/api/v2/accounts/:account_id/subscription`
Creates new subscription using Stripe Checkout Sessions for all plans:
- For `free_trial`: Creates setup session (collects payment method without charging)
- For all paid plans: Creates subscription checkout session (collects payment and creates subscription)
- Payment is always collected upfront via Stripe's hosted checkout page
- Subscription finalization is handled via `checkout.session.completed` webhook

#### GET `/api/v2/accounts/:account_id/subscription/portal`
Creates billing portal session for self-service management.

#### GET `/api/v2/accounts/:account_id/subscription/limits`
Returns account usage limits:
```json
{
  "success": true,
  "data": {
    "id": 123,
    "limits": {
      "agents": {
        "allowed": 5,
        "consumed": 3
      },
      "inboxes": {
        "allowed": 2,
        "consumed": 1
      },
      "conversations": {
        "allowed": 4000,
        "consumed": 150
      }
    }
  }
}
```

## Frontend Integration

### Vue.js Components

#### Billing Index (`app/javascript/dashboard/routes/dashboard/settings/billing/Index.vue`)
Main billing management interface with:
- Plan information display
- Subscription status
- Billing portal access
- Usage limits visualization

#### Subscription Status Constants (`app/javascript/dashboard/constants/subscriptionStatuses.js`)
Frontend constants matching backend subscription statuses.

### State Management
Uses Vuex store for account data management with reactive updates for billing information.

## Subscription Status Management

### Status Constants (`lib/billing/subscription_statuses.rb`)

```ruby
module Billing::SubscriptionStatuses
  # Stripe statuses
  ACTIVE = 'active'
  CANCELED = 'canceled'
  INCOMPLETE = 'incomplete'
  INCOMPLETE_EXPIRED = 'incomplete_expired'
  PAST_DUE = 'past_due'
  TRIALING = 'trialing'
  UNPAID = 'unpaid'
  PAUSED = 'paused'
  
  # Application statuses
  INACTIVE = 'inactive'
  
  # Status groups
  PAID_STATUSES = [ACTIVE, TRIALING].freeze
  FAILED_PAYMENT_STATUSES = [PAST_DUE, CANCELED, UNPAID].freeze
end
```

### Status Transitions

1. **Active/Trialing**: Full feature access
2. **Failed Payment**: Transition to community plan
3. **Canceled/Deleted**: Transition to community plan
4. **Inactive**: No billing features

## Plan and Feature Management

### BillingPlans Module (`app/models/concerns/billing_plans.rb`)

Provides utilities for:
- Loading billing plans from YAML
- Resolving features from tiers
- Dynamic plan limits from Stripe metadata
- Plan validation and error handling

### Feature Tiers

1. **Community**: Basic features (website channel, contacts)
2. **Starter**: Core features (email, social channels, help center, automations)
3. **Professional**: Advanced features (SLA, audit logs, custom roles)
4. **Enterprise**: Premium features (unlimited limits, custom integrations)

## Error Handling and Logging

### Comprehensive Logging
- Detailed webhook processing logs
- Error tracking with backtraces
- Performance monitoring
- Debug information for troubleshooting

### Error Recovery
- Graceful handling of Stripe API errors
- Fallback to YAML configuration
- Retry mechanisms for failed operations
- User-friendly error messages

## Security Considerations

### Webhook Security
- Signature verification using `STRIPE_WEBHOOK_SECRET`
- Payload validation
- Rate limiting considerations

### Data Protection
- Sensitive data stored in `custom_attributes` JSONB field
- No plaintext storage of payment information
- Secure API key management

## Environment Configuration

### Required Environment Variables
```bash
STRIPE_SECRET_KEY=sk_test_xxxxx          # Stripe secret key
STRIPE_WEBHOOK_SECRET=whsec_xxxxx        # Webhook endpoint secret
PAYMENT_PROVIDER=stripe                  # Payment provider (default: stripe)
FRONTEND_URL=http://localhost:3000       # Frontend URL for redirects
```

### Optional Configuration
```bash
STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx     # For frontend integration
```

## Background Jobs

### Provision Stripe Subscription Job (`app/jobs/billing/provision_stripe_subscription_job.rb`)
Handles automatic subscription provisioning for new accounts.

### Create Customer Job (`app/jobs/billing/create_customer_job.rb`)
Background job for customer creation to avoid timeout issues.

## Enterprise Integration

### Enterprise Services (`enterprise/app/services/enterprise/billing/`)
- `CreateStripeCustomerService`: Enterprise-specific customer creation
- `HandleStripeEventService`: Enhanced webhook processing
- `CreateSessionService`: Enterprise checkout session handling

### Enterprise Controllers (`enterprise/app/controllers/enterprise/`)
- Enhanced account management
- Enterprise-specific webhook handling

## Testing

### Test Coverage
- Unit tests for all service classes
- Integration tests for webhook processing
- Mock Stripe API responses
- Error scenario testing

### Test Files
- `spec/services/billing/providers/stripe_spec.rb`
- `spec/services/billing/webhook_service_spec.rb`
- `spec/controllers/webhooks/stripe_controller_spec.rb`
- `spec/enterprise/services/enterprise/billing/handle_stripe_event_service_spec.rb`

## Performance Considerations

### Caching
- Plan data caching with 1-hour expiry
- Cache invalidation on product updates
- Redis-based caching for high performance

### API Optimization
- Batch operations where possible
- Efficient database queries
- Minimal API calls to Stripe

## Monitoring and Observability

### Logging
- Structured logging with context
- Error tracking and alerting
- Performance metrics

### Health Checks
- Webhook endpoint health monitoring
- Stripe API connectivity checks
- Database connection monitoring

## Future Considerations

### Scalability
- Provider abstraction allows easy addition of other payment providers
- Modular architecture supports feature expansion
- Caching strategy supports high-volume operations

### Maintenance
- Regular Stripe API updates
- Security patch management
- Feature flag management for gradual rollouts

## Recent Changes

### Unified Checkout Session Flow (2025-01-27)

**Problem Identified:**
The original implementation had a critical bug where Pro and Enterprise plans used a background job approach that created subscriptions without collecting payment methods first. This caused subscriptions to fail when payment was due.

**Root Cause:**
- `free_trial` and `starter` plans → Checkout Session (payment collected upfront) ✅
- `professional` and `enterprise` plans → Background Job → Created subscription with `collection_method: 'charge_automatically'` but no payment method ❌

**Solution Implemented:**
Unified all plans to use Stripe Checkout Sessions:

1. **Controller Change** (`app/controllers/api/v2/accounts/subscriptions_controller.rb`):
   - Removed conditional logic that split plans into different paths
   - All plans now use `Billing::CreateCheckoutSessionService`
   - Removed background job approach for subscription creation
   - Removed `customer_creation_in_progress?` check (no longer needed)

2. **Benefits:**
   - ✅ Payment methods always collected before charging
   - ✅ Consistent user experience across all plans
   - ✅ Simpler codebase (removed conditional complexity)
   - ✅ Better error handling (Stripe validates payment before subscription creation)
   - ✅ Reduced API calls (Stripe handles customer creation in checkout)

3. **Flow for All Plans:**
   ```
   User Request → CreateCheckoutSessionService → Stripe Checkout Page
   → User Pays → checkout.session.completed webhook → Account Updated
   ```

4. **Files Modified:**
   - `app/controllers/api/v2/accounts/subscriptions_controller.rb` - Simplified subscription creation
   - `app/services/billing/create_checkout_session_service.rb` - Updated comments
   - `docs/ignore/StripeInitialState.md` - Updated documentation

5. **Backward Compatibility:**
   - Existing subscriptions remain unaffected
   - Background job code (`CreateCustomerService`, `CreateCustomerJob`) preserved for potential future enterprise use cases (e.g., manual invoicing)
   - Webhook handlers remain the same

## Conclusion

The Stripe implementation in Chatwoot is well-architected with:
- Clean separation of concerns
- Provider abstraction for flexibility
- Comprehensive error handling
- Real-time webhook processing
- Dynamic plan management
- Enterprise-ready features
- **Unified checkout flow ensuring payment collection before charging** (Updated 2025-01-27)

The system provides a robust foundation for subscription billing with room for future enhancements and integrations.