# Custom Pricing Table Implementation Plan

## Overview

Replace the embedded Stripe Pricing Table component with a custom Vue 3 component that provides contextual button labels based on the user's current subscription state. All pricing data (images, titles, descriptions, features, prices) will be fetched dynamically from Stripe.

---

## 1. Current State Analysis

### Existing Components Available for Reuse
- **BillingCard.vue** - Card wrapper with rounded borders and shadows
- **BillingHeader.vue** - Grid layout with title, description, and action slot
- **ButtonV4** (`next/button/Button.vue`) - Primary button component
- **DetailItem.vue** - Label-value display component

### Current Data Available
From `customAttributes` in `Index.vue`:
- `plan_name` (e.g., "starter", "professional", "enterprise")
- `subscription_status` (e.g., "active", "trialing", "inactive", "past_due", "canceled")
- `stripe_customer_id`
- `subscription_ends_on`

### Current API Infrastructure
- **Frontend**: `BillingAPI` (`app/javascript/dashboard/api/v2/billing.js`)
- **Backend**: `Api::V2::Accounts::SubscriptionsController`
- **Vuex Store**: `accounts` module with subscription actions

---

## 2. Requirements Summary

### Plan Hierarchy
```
Starter < Professional < Enterprise
```

### Button Logic Matrix

| User's Current Plan | Starter Button | Professional Button | Enterprise Button |
|-------------------|----------------|---------------------|-------------------|
| **No plan** | "Start trial" (purple) | "Start trial" (purple) | "Start trial" (purple) |
| **Trial (Starter)** | "Upgrade" (purple) | "Upgrade" (purple) | "Upgrade" (purple) |
| **Trial (Professional)** | "Upgrade" (purple) | "Upgrade" (purple) | "Upgrade" (purple) |
| **Trial (Enterprise)** | "Upgrade" (purple) | "Upgrade" (purple) | "Upgrade" (purple) |
| **Active Starter** | "Cancel" (grey) | "Upgrade" (purple) | "Upgrade" (purple) |
| **Active Professional** | "Downgrade" (purple) | "Cancel" (grey) | "Upgrade" (purple) |
| **Active Enterprise** | "Downgrade" (purple) | "Downgrade" (purple) | "Cancel" (grey) |

**Note**: Edge cases (past_due, canceled, etc.) use same logic as active subscriptions.

### Button Actions
- **"Start trial"** → Create Stripe Checkout Session (trial mode)
- **"Upgrade"** → Create Stripe Checkout Session (subscription mode)
- **"Downgrade"** → Redirect to Stripe Customer Portal
- **"Cancel"** → Redirect to Stripe Customer Portal

### Data to Fetch from Stripe (per product)
1. **Product Image** (from Stripe Product `images` array or `metadata.image_url`)
2. **Product Title** (from Stripe Product `name`)
3. **Product Description** (from Stripe Product `description`)
4. **Marketing Features** (from Stripe Product `marketing_features` or metadata)
5. **Monthly Price** (from Stripe Price with `recurring.interval = "month"`)
6. **Yearly Price** (from Stripe Price with `recurring.interval = "year"`)

### UI Requirements
- Monthly/Yearly toggle at the top
- Three pricing columns (Starter, Professional, Enterprise)
- Dark background, white text
- Purple buttons for actionable items, grey for cancel
- Checkmarks for feature lists
- Match exact design from provided images (excluding "Sandbox" indication)

---

## 3. Backend Implementation

### 3.1 Create New API Endpoint

**File**: `app/controllers/api/v2/accounts/pricing_controller.rb`

**Purpose**: Fetch all pricing table data from Stripe

**Endpoint**: `GET /api/v2/accounts/:account_id/pricing`

**Response Structure**:
```json
{
  "success": true,
  "data": {
    "plans": [
      {
        "id": "prod_ABC123",
        "plan_name": "starter",
        "name": "Starter plan",
        "description": "Ideal for small teams and startups",
        "image_url": "https://...",
        "prices": {
          "monthly": {
            "id": "price_XYZ",
            "amount": 30000,
            "currency": "usd",
            "formatted": "$300"
          },
          "yearly": {
            "id": "price_ABC",
            "amount": 324000,
            "currency": "usd",
            "formatted": "$3,240"
          }
        },
        "features": [
          "5 members",
          "2 channels",
          "100 AI token credits",
          "4000 conversations"
        ]
      },
      // ... Professional and Enterprise
    ]
  }
}
```

### 3.2 Create Service for Fetching Pricing Data

**File**: `app/services/billing/fetch_pricing_table_service.rb`

**Responsibilities**:
1. List all active Stripe Products with metadata `plan_name` in ["starter", "professional", "enterprise"]
2. For each product:
   - Fetch product details (name, description, images, marketing_features)
   - List all active prices for the product
   - Filter prices by `recurring.interval` (monthly/yearly)
   - Extract feature bullets from `marketing_features` or `metadata`
3. Return structured data sorted by plan hierarchy
4. Cache results for performance (invalidate on product.updated webhook)

**Pseudocode**:
```ruby
class Billing::FetchPricingTableService
  PLAN_ORDER = %w[starter professional enterprise].freeze

  def initialize(environment = Rails.env)
    @environment = environment
  end

  def fetch
    products = fetch_stripe_products
    plans = products.map { |product| build_plan_data(product) }
    plans.sort_by { |plan| PLAN_ORDER.index(plan[:plan_name]) }
  end

  private

  def fetch_stripe_products
    # List products with expand for better performance
    products = ::Stripe::Product.list(
      active: true,
      expand: ['data.marketing_features'],
      limit: 100
    )

    # Filter by plan_name metadata
    products.data.select do |product|
      metadata = product.metadata || {}
      PLAN_ORDER.include?(metadata['plan_name']) &&
        (metadata['environment'].nil? || metadata['environment'] == @environment)
    end
  end

  def build_plan_data(product)
    {
      id: product.id,
      plan_name: product.metadata['plan_name'],
      name: product.name,
      description: product.description,
      image_url: extract_image_url(product),
      prices: fetch_prices(product.id),
      features: extract_features(product)
    }
  end

  def fetch_prices(product_id)
    prices = ::Stripe::Price.list(
      product: product_id,
      active: true,
      limit: 10
    )

    {
      monthly: find_price_by_interval(prices.data, 'month'),
      yearly: find_price_by_interval(prices.data, 'year')
    }
  end

  def find_price_by_interval(prices, interval)
    price = prices.find { |p| p.recurring&.interval == interval }
    return nil unless price

    {
      id: price.id,
      amount: price.unit_amount,
      currency: price.currency,
      formatted: format_price(price.unit_amount, price.currency)
    }
  end

  def extract_image_url(product)
    # Try images array first
    return product.images.first if product.images&.any?
    
    # Fallback to metadata
    product.metadata&.dig('image_url')
  end

  def extract_features(product)
    # Try marketing_features first (Stripe's native feature)
    if product.marketing_features&.any?
      return product.marketing_features.map(&:name)
    end

    # Fallback to metadata (bullet_1, bullet_2, etc.)
    features = []
    index = 1
    while (bullet = product.metadata&.dig("bullet_#{index}"))
      features << bullet
      index += 1
    end
    features
  end

  def format_price(amount_cents, currency)
    amount_dollars = amount_cents / 100
    # Standard approach: match each digit followed by groups of 3 digits until end
    formatted = amount_dollars.to_s.gsub(/(\d)(?=(\d{3})+$)/, '\1,')
    "$#{formatted}"
  end
end
```

### 3.3 Controller Implementation

**File**: `app/controllers/api/v2/accounts/pricing_controller.rb`

```ruby
# frozen_string_literal: true

class Api::V2::Accounts::PricingController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper

  before_action :current_account
  before_action :check_authorization

  # GET /api/v2/accounts/:account_id/pricing
  def index
    service = Billing::FetchPricingTableService.new
    pricing_data = service.fetch

    render json: {
      success: true,
      data: { plans: pricing_data }
    }
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching pricing table: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch pricing data'
    }, status: :internal_server_error
  end

  private

  def check_authorization
    authorize(:billing, :show?)
  end
end
```

### 3.4 Add Route

**File**: `config/routes.rb`

```ruby
namespace :api, defaults: { format: 'json' } do
  namespace :v2 do
    resources :accounts, only: [] do
      # ... existing routes
      resource :pricing, only: [:index], controller: 'accounts/pricing'
    end
  end
end
```

### 3.5 Caching Strategy

Use Rails cache with webhook invalidation:

```ruby
# In FetchPricingTableService
def fetch
  Rails.cache.fetch(cache_key, expires_in: 1.hour) do
    # ... fetch logic
  end
end

def cache_key
  "pricing_table:#{@environment}:v1"
end

# In Billing::Providers::Stripe webhook handler
def handle_product_updated(product)
  # ... existing logic
  
  # Invalidate pricing table cache
  %w[development staging production].each do |env|
    Rails.cache.delete("pricing_table:#{env}:v1")
  end
end
```

---

## 4. Frontend Implementation

### 4.1 Create API Client Method

**File**: `app/javascript/dashboard/api/v2/billing.js`

Add new method:
```javascript
// GET /api/v2/accounts/:account_id/pricing
getPricingTable() {
  return axios.get(`${this.url}pricing`);
}
```

### 4.2 Component Structure

#### 4.2.1 Main Component: `PricingTable.vue`

**File**: `app/javascript/dashboard/routes/dashboard/settings/billing/components/PricingTable.vue`

**Responsibilities**:
- Fetch pricing data from API
- Manage monthly/yearly toggle state
- Pass data to individual plan cards
- Handle loading and error states

**Props**:
- `currentPlanName` (String) - e.g., "starter", "professional", "enterprise", or null
- `subscriptionStatus` (String) - e.g., "active", "trialing", "inactive"
- `hasStripeCustomer` (Boolean) - whether user has Stripe customer ID

**Structure**:
```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import BillingAPI from 'dashboard/api/v2/billing.js';
import PricingCard from './PricingCard.vue';

const props = defineProps({
  currentPlanName: {
    type: String,
    default: null
  },
  subscriptionStatus: {
    type: String,
    default: null
  },
  hasStripeCustomer: {
    type: Boolean,
    default: false
  }
});

const { t } = useI18n();
const plans = ref([]);
const isLoading = ref(true);
const billingInterval = ref('monthly'); // 'monthly' or 'yearly'

const fetchPricingData = async () => {
  isLoading.value = true;
  try {
    const response = await BillingAPI.getPricingTable();
    if (response.data.success) {
      plans.value = response.data.data.plans;
    }
  } catch (error) {
    console.error('Error fetching pricing:', error);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchPricingData();
});
</script>

<template>
  <div class="pricing-table">
    <!-- Billing Interval Toggle -->
    <div class="flex justify-center mb-8">
      <div class="inline-flex rounded-lg bg-n-solid-3 p-1">
        <button
          :class="[
            'px-6 py-2 rounded-md text-sm font-medium transition-colors',
            billingInterval === 'monthly'
              ? 'bg-p-purple-9 text-white'
              : 'text-n-slate-11 hover:text-n-slate-12'
          ]"
          @click="billingInterval = 'monthly'"
        >
          {{ t('BILLING_SETTINGS.PRICING_TABLE.MONTHLY') }}
        </button>
        <button
          :class="[
            'px-6 py-2 rounded-md text-sm font-medium transition-colors',
            billingInterval === 'yearly'
              ? 'bg-p-purple-9 text-white'
              : 'text-n-slate-11 hover:text-n-slate-12'
          ]"
          @click="billingInterval = 'yearly'"
        >
          {{ t('BILLING_SETTINGS.PRICING_TABLE.YEARLY') }}
        </button>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center py-16">
      <span class="text-sm text-n-slate-11">
        {{ t('BILLING_SETTINGS.PRICING_TABLE.LOADING') }}
      </span>
    </div>

    <!-- Pricing Cards Grid -->
    <div
      v-else
      class="grid grid-cols-1 md:grid-cols-3 gap-6"
    >
      <PricingCard
        v-for="plan in plans"
        :key="plan.id"
        :plan="plan"
        :billing-interval="billingInterval"
        :current-plan-name="currentPlanName"
        :subscription-status="subscriptionStatus"
        :has-stripe-customer="hasStripeCustomer"
      />
    </div>
  </div>
</template>
```

#### 4.2.2 Child Component: `PricingCard.vue`

**File**: `app/javascript/dashboard/routes/dashboard/settings/billing/components/PricingCard.vue`

**Responsibilities**:
- Display individual plan card
- Calculate button state and label
- Handle button clicks (checkout/portal)

**Props**:
- `plan` (Object) - Plan data from API
- `billingInterval` (String) - 'monthly' or 'yearly'
- `currentPlanName` (String)
- `subscriptionStatus` (String)
- `hasStripeCustomer` (Boolean)

**Structure**:
```vue
<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store.js';
import ButtonV4 from 'next/button/Button.vue';

const props = defineProps({
  plan: {
    type: Object,
    required: true
  },
  billingInterval: {
    type: String,
    required: true
  },
  currentPlanName: {
    type: String,
    default: null
  },
  subscriptionStatus: {
    type: String,
    default: null
  },
  hasStripeCustomer: {
    type: Boolean,
    default: false
  }
});

const { t } = useI18n();
const store = useStore();

// Plan hierarchy for comparison
const PLAN_HIERARCHY = {
  starter: 1,
  professional: 2,
  enterprise: 3
};

/**
 * Calculate button configuration based on user's current plan
 */
const buttonConfig = computed(() => {
  const currentPlan = props.currentPlanName;
  const targetPlan = props.plan.plan_name;
  const status = props.subscriptionStatus;

  // No plan or inactive -> Start trial
  if (!currentPlan || status === 'inactive') {
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.START_TRIAL'),
      action: 'trial',
      variant: 'purple'
    };
  }

  // On trial -> Upgrade (start subscription)
  if (status === 'trialing') {
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.UPGRADE'),
      action: 'upgrade',
      variant: 'purple'
    };
  }

  // Current plan (active, past_due, canceled, etc.)
  const currentTier = PLAN_HIERARCHY[currentPlan];
  const targetTier = PLAN_HIERARCHY[targetPlan];

  // Validate plan names exist in hierarchy
  if (currentTier === undefined || targetTier === undefined) {
    // Invalid plan name(s) - log error and return safe fallback
    console.error(
      `Invalid plan name detected. Current: "${currentPlan}" (tier: ${currentTier}), ` +
      `Target: "${targetPlan}" (tier: ${targetTier})`
    );
    
    // If target plan is invalid, disable button or show contact support
    if (targetTier === undefined) {
      return {
        label: t('BILLING_SETTINGS.PRICING_TABLE.CONTACT_SALES'),
        action: 'contact',
        variant: 'grey'
      };
    }
    
    // If current plan is invalid but target is valid, treat as new subscription
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.START_TRIAL'),
      action: 'trial',
      variant: 'purple'
    };
  }

  if (currentTier === targetTier) {
    // Same plan -> Cancel
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.CANCEL'),
      action: 'cancel',
      variant: 'grey'
    };
  }

  if (targetTier > currentTier) {
    // Higher tier -> Upgrade
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.UPGRADE'),
      action: 'upgrade',
      variant: 'purple'
    };
  }

  // Lower tier -> Downgrade
  return {
    label: t('BILLING_SETTINGS.PRICING_TABLE.DOWNGRADE'),
    action: 'downgrade',
    variant: 'purple'
  };
});

/**
 * Selected price based on billing interval
 */
const selectedPrice = computed(() => {
  return props.plan.prices[props.billingInterval];
});

/**
 * Handle button click
 */
const handleButtonClick = async () => {
  const { action } = buttonConfig.value;

  if (action === 'trial' || action === 'upgrade') {
    // Create checkout session
    await store.dispatch('accounts/createSubscription', {
      planName: props.plan.plan_name
    });
  } else if (action === 'downgrade' || action === 'cancel') {
    // Redirect to billing portal
    await store.dispatch('accounts/checkout');
  } else if (action === 'contact') {
    // Invalid plan - do nothing or show contact modal
    // This prevents errors when target plan name is invalid
    console.warn('Invalid target plan, contact action triggered');
  }
};
</script>

<template>
  <div
    class="rounded-xl border border-n-weak bg-n-solid-2 p-6 flex flex-col shadow-sm hover:shadow-md transition-shadow"
  >
    <!-- Plan Image -->
    <div class="flex justify-center mb-6">
      <img
        :src="plan.image_url"
        :alt="plan.name"
        class="h-32 w-auto object-contain"
      />
    </div>

    <!-- Plan Title -->
    <h3 class="text-xl font-semibold text-n-slate-12 mb-2 text-center">
      {{ plan.name }}
    </h3>

    <!-- Plan Description -->
    <p class="text-sm text-n-slate-11 mb-6 text-center">
      {{ plan.description }}
    </p>

    <!-- Price -->
    <div class="mb-6 text-center">
      <div class="text-4xl font-bold text-white">
        {{ selectedPrice?.formatted || '-' }}
      </div>
      <div class="text-sm text-n-slate-11 mt-1">
        {{ t(`BILLING_SETTINGS.PRICING_TABLE.PER_${billingInterval.toUpperCase()}`) }}
      </div>
    </div>

    <!-- CTA Button -->
    <ButtonV4
      :class="[
        'w-full mb-6',
        buttonConfig.variant === 'grey' ? 'bg-n-slate-6 hover:bg-n-slate-7' : ''
      ]"
      :solid="buttonConfig.variant === 'purple'"
      :blue="buttonConfig.variant === 'purple'"
      @click="handleButtonClick"
    >
      {{ buttonConfig.label }}
    </ButtonV4>

    <!-- Features List -->
    <div class="border-t border-n-weak pt-6">
      <p class="text-xs font-medium text-n-slate-11 uppercase tracking-wide mb-4">
        {{ t('BILLING_SETTINGS.PRICING_TABLE.THIS_INCLUDES') }}
      </p>
      <ul class="space-y-3">
        <li
          v-for="(feature, index) in plan.features"
          :key="index"
          class="flex items-start gap-3"
        >
          <div class="flex-shrink-0 w-5 h-5 rounded-full bg-white flex items-center justify-center mt-0.5">
            <span class="i-lucide-check text-black text-xs" />
          </div>
          <span class="text-sm text-n-slate-12">
            {{ feature }}
          </span>
        </li>
      </ul>
    </div>
  </div>
</template>
```

### 4.3 Integration in Index.vue

**File**: `app/javascript/dashboard/routes/dashboard/settings/billing/Index.vue`

Replace the Stripe pricing table section (lines 207-213):

```vue
<!-- OLD CODE (REMOVE) -->
<div class="mb-8">
  <stripe-pricing-table
    pricing-table-id="prctbl_1SPqgz4TqKLiHbZ86bGxTMiM"
    publishable-key="pk_test_51RdbZa4TqKLiHbZ8KnKMyQqKmml3ZpNmqskOOXiyO2XVmN6SLhssnr9DJSnbpyjqoGLPzoPfYUoYlXMbHSKtrKcV00Y2qEB4J4"
  />
</div>

<!-- NEW CODE (ADD) -->
<div class="mb-8">
  <PricingTable
    :current-plan-name="customAttributes.plan_name"
    :subscription-status="customAttributes.subscription_status"
    :has-stripe-customer="hasStripeCustomer"
  />
</div>
```

Add import:
```vue
<script setup>
// ... existing imports
import PricingTable from './components/PricingTable.vue';
```

Remove Stripe pricing table script loading (lines 167-182):
```javascript
// DELETE THIS FUNCTION
const loadStripePricingScript = () => {
  // ...
};

// DELETE THIS CALL
onMounted(() => {
  fetchAccountDetails();
  checkForCheckoutSuccess();
  loadStripePricingScript(); // REMOVE THIS LINE
});
```

### 4.4 Add Translations

**File**: `app/javascript/dashboard/i18n/locale/en/settings.json`

Add to `BILLING_SETTINGS` object:
```json
"PRICING_TABLE": {
  "MONTHLY": "Monthly",
  "YEARLY": "Yearly",
  "LOADING": "Loading pricing...",
  "START_TRIAL": "Start trial",
  "UPGRADE": "Upgrade",
  "DOWNGRADE": "Downgrade",
  "CANCEL": "Cancel",
  "CONTACT_SALES": "Contact sales",
  "PER_MONTHLY": "per month",
  "PER_YEARLY": "per year",
  "THIS_INCLUDES": "This includes:"
}
```

**File**: `app/javascript/dashboard/i18n/locale/es/settings.json`

Add Spanish translations:
```json
"PRICING_TABLE": {
  "MONTHLY": "Mensual",
  "YEARLY": "Anual",
  "LOADING": "Cargando precios...",
  "START_TRIAL": "Iniciar prueba",
  "UPGRADE": "Actualizar",
  "DOWNGRADE": "Bajar de categoría",
  "CANCEL": "Cancelar",
  "CONTACT_SALES": "Contactar ventas",
  "PER_MONTHLY": "por mes",
  "PER_YEARLY": "por año",
  "THIS_INCLUDES": "Esto incluye:"
}
```

---

## 5. Stripe Product Configuration

### 5.1 Product Metadata Structure

For each plan product in Stripe Dashboard:

**Metadata Fields**:
```
plan_name: "starter" | "professional" | "enterprise"
environment: "production" (optional, defaults to all)
image_url: "https://..." (fallback if images array is empty)
bullet_1: "5 members"
bullet_2: "2 channels"
bullet_3: "100 AI token credits"
bullet_4: "4000 conversations"
... (continue for all features)
```

**Recommended**: Use Stripe's native `marketing_features` instead of metadata bullets:
- More structured
- Better Dashboard UI
- Easier to manage

**Product Images**:
Upload futuristic 3D images to Stripe Product's `images` array in Dashboard.

### 5.2 Price Configuration

Each product should have **two active prices**:
1. Monthly price (recurring.interval = "month")
2. Yearly price (recurring.interval = "year")

**Example for Starter**:
- Monthly: $300/month
- Yearly: $3,240/year (10% discount)

---

## 6. Implementation Steps (Ordered)

### Step 1: Backend Setup
1. Create `Billing::FetchPricingTableService` service
2. Create `Api::V2::Accounts::PricingController` controller
3. Add route to `config/routes.rb`
4. Test endpoint manually: `GET /api/v2/accounts/:account_id/pricing`

### Step 2: Configure Stripe Products
1. Add metadata to existing Starter/Professional/Enterprise products
2. Upload product images
3. Add marketing features or metadata bullets
4. Ensure two active prices per product (monthly/yearly)
5. Test service with `rails console`:
   ```ruby
   service = Billing::FetchPricingTableService.new
   puts service.fetch.to_json
   ```

### Step 3: Frontend API Integration
1. Add `getPricingTable()` method to `BillingAPI`
2. Test API call in browser console

### Step 4: Create Vue Components
1. Create `PricingCard.vue` component
2. Create `PricingTable.vue` component
3. Test components in isolation with mock data

### Step 5: Add Translations
1. Add translations to `en/settings.json`
2. Add translations to `es/settings.json`

### Step 6: Integrate into Billing Page
1. Import `PricingTable` into `Index.vue`
2. Replace Stripe pricing table with custom component
3. Remove Stripe script loading code

### Step 7: Testing
1. Test button states for all plan combinations
2. Test monthly/yearly toggle
3. Test loading states
4. Test error handling
5. Test responsive design (mobile/tablet/desktop)

### Step 8: Caching & Webhooks
1. Add caching to `FetchPricingTableService`
2. Update `handle_product_updated` webhook to invalidate cache
3. Test cache invalidation

---

## 7. Testing Checklist

### Backend Tests

**File**: `spec/services/billing/fetch_pricing_table_service_spec.rb`

Test cases:
- Fetches all three plans in correct order
- Extracts monthly and yearly prices correctly
- Handles missing prices gracefully
- Extracts features from marketing_features
- Falls back to metadata bullets
- Filters by environment correctly
- Returns empty array if no products found

**File**: `spec/controllers/api/v2/accounts/pricing_controller_spec.rb`

Test cases:
- Successful response with pricing data
- Handles Stripe errors gracefully
- Returns 401 for unauthorized users

### Frontend Tests

**File**: `app/javascript/dashboard/routes/dashboard/settings/billing/components/PricingTable.spec.js`

Test cases:
- Fetches pricing data on mount
- Toggles between monthly and yearly
- Shows loading state
- Passes correct props to PricingCard

**File**: `app/javascript/dashboard/routes/dashboard/settings/billing/components/PricingCard.spec.js`

Test cases:
- Displays plan information correctly
- Calculates button label for no plan → "Start trial"
- Calculates button label for trial → "Upgrade"
- Calculates button label for current plan → "Cancel"
- Calculates button label for higher tier → "Upgrade"
- Calculates button label for lower tier → "Downgrade"
- Handles button clicks correctly
- Applies grey variant for cancel button
- **Validates invalid target plan → "Contact sales" (grey)**
- **Validates invalid current plan with valid target → "Start trial"**
- **Logs error when invalid plan names are detected**
- **Handles contact action without errors**

### Manual Testing Scenarios

1. **No subscription**: All buttons show "Start trial"
2. **Trial Starter**: All buttons show "Upgrade"
3. **Active Starter**: Starter = "Cancel" (grey), Pro/Enterprise = "Upgrade"
4. **Active Professional**: Starter = "Downgrade", Pro = "Cancel" (grey), Enterprise = "Upgrade"
5. **Active Enterprise**: Starter/Pro = "Downgrade", Enterprise = "Cancel" (grey)
6. **Past due subscription**: Same as active (edge case)
7. **Canceled subscription**: Same as active (edge case)
8. **Monthly/Yearly toggle**: Prices update correctly
9. **Responsive design**: Works on mobile, tablet, desktop
10. **Invalid target plan name** (e.g., typo "enterprize"): Button shows "Contact sales" (grey)
11. **Invalid current plan name** with valid target: Button shows "Start trial"
12. **Both invalid plan names**: Button shows "Contact sales" (grey)
13. **Check console**: Error logged when invalid plan names detected

---

## 8. Verification Steps After Implementation

### Step 1: Check Backend Endpoint
```bash
# Start Rails server
task docker-reload-env

# Test endpoint (replace :account_id)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/v2/accounts/1/pricing
```

Expected: JSON with three plans, each with monthly/yearly prices and features.

### Step 2: Check Frontend Rendering
1. Navigate to Settings > Billing
2. Verify pricing table renders with three cards
3. Verify images, titles, descriptions, features display correctly
4. Toggle monthly/yearly and verify prices update

### Step 3: Check Button Logic
1. Test with no subscription (clear custom_attributes)
2. Create trial subscription and verify buttons
3. Activate subscription and verify buttons
4. Change to different plans and verify buttons update

### Step 4: Check Button Actions
1. Click "Start trial" → Should create Stripe Checkout Session
2. Click "Upgrade" → Should create Stripe Checkout Session
3. Click "Downgrade" → Should redirect to Stripe Portal
4. Click "Cancel" → Should redirect to Stripe Portal

### Step 5: Lint and Format
```bash
# Backend
bundle exec rubocop -a app/services/billing/fetch_pricing_table_service.rb
bundle exec rubocop -a app/controllers/api/v2/accounts/pricing_controller.rb

# Frontend
pnpm eslint:fix
```

### Step 6: Run Tests
```bash
# Backend tests
task test-backend-file -- spec/services/billing/fetch_pricing_table_service_spec.rb
task test-backend-file -- spec/controllers/api/v2/accounts/pricing_controller_spec.rb

# Frontend tests
pnpm test PricingTable
pnpm test PricingCard
```

---

## 9. Edge Cases and Considerations

### 9.1 Missing Data Handling
- **No image**: Show placeholder or fallback icon
- **Missing price**: Show "Contact sales" instead of amount
- **No features**: Show empty list or "Contact for details"

### 9.2 Error States
- Stripe API timeout: Show cached data if available
- Network error: Show retry button
- Invalid response: Log error, show user-friendly message

### 9.3 Performance
- Cache pricing data (1 hour TTL)
- Lazy load images
- Debounce interval toggle if needed

### 9.4 Accessibility
- Add ARIA labels to buttons
- Ensure keyboard navigation works
- Use semantic HTML
- Sufficient color contrast

### 9.5 Internationalization
- All text must use i18n
- Format prices based on locale (future enhancement)
- Translate feature bullets (if stored in metadata)



---

## 14. Important Notes

### Avoid These Pitfalls
- ❌ Don't hardcode plan names or prices
- ❌ Don't skip error handling
- ❌ Don't forget to test edge cases
- ❌ Don't ignore mobile responsiveness
- ❌ Don't use inline styles (Tailwind only)
- ❌ Don't leave console.log statements
- ❌ Don't skip translations
- ❌ Don't over-engineer (keep it simple)

### Follow These Practices
- ✅ Use existing components (ButtonV4, BillingCard)
- ✅ Follow Vue 3 Composition API (`<script setup>`)
- ✅ Use Tailwind utility classes only
- ✅ Extract complex logic to computed properties
- ✅ Add JSDoc comments for functions
- ✅ Test each unit as you build
- ✅ Check rules after each step
- ✅ Keep components focused and small
- ✅ **Validate plan names before using them in comparisons**
- ✅ **Handle invalid plan names gracefully with error logging**

---

## 15. Key Architecture Decisions

### Why Custom Component Over Stripe Pricing Table?
1. **Contextual Buttons**: Stripe doesn't support dynamic button text
2. **Plan Awareness**: Need to show current plan, upgrades, downgrades
3. **UX Control**: Better user experience with contextual actions
4. **Design Match**: Exact match to provided design mockups

### Why Fetch from Stripe Instead of Hardcoding?
1. **Single Source of Truth**: Stripe is the pricing authority
2. **Easy Updates**: Change prices in Stripe Dashboard, no code changes
3. **Consistency**: Same data across all systems
4. **Future Proof**: Supports A/B testing, seasonal pricing, etc.

### Why Backend Endpoint Instead of Direct API?
1. **Security**: Don't expose Stripe API key to frontend
2. **Caching**: Server-side caching for performance
3. **Transformation**: Clean, structured data for frontend
4. **Error Handling**: Better error handling on server

---
