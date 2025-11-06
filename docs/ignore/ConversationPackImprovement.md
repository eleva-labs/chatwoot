# Conversation Pack Improvement: Multiple Pack Selection

## Overview

This document outlines the implementation plan to replace the single "Buy 10,000 Conversation Pack" button with a modal that allows users to select from multiple predefined conversation pack options, similar to how extra agents and inboxes work.

---

## Current State Analysis

### Existing Implementation

**Frontend (Vue):**
- Location: `app/javascript/dashboard/routes/dashboard/settings/billing/components/BillingLimitsCard.vue`
- Current button: "Buy 10,000 Conversation Pack" (line 620)
- Click handler: `confirmPurchaseConversationPack()` (line 106-120)
- Purchase method: `purchaseConversationPack()` (line 122-147)
- Uses `ConfirmationModal` for confirmation before purchase
- Vuex action: `accounts/purchaseConversationPack` (no parameters)

**Backend (Ruby):**
- Controller: `app/controllers/api/v2/accounts/billing/conversation_packs_controller.rb`
- Service: `app/services/billing/purchase_conversation_pack_service.rb`
- Current logic:
  - Gets pack configuration from `billing_plans.yml` via `BillingPlans` module
  - Fetches price from Stripe using lookup key from plan config
  - Creates invoice item and invoice in Stripe
  - Updates account's `extra_conversations_purchased` counter

**Configuration:**
- Location: `config/billing_plans.yml`
- Current conversation pack structure (per plan):
  ```yaml
  conversation_packs:
    lookup_key: 'conversation_pack_starter'  # Currently hardcoded per plan
    price_id: null
    conversations: 10000  # Fixed amount per plan
    unit_price: null
  ```

**API Flow:**
1. Frontend calls: `POST /api/v2/accounts/:account_id/billing/conversation_packs/purchase`
2. No parameters sent (pack is determined by plan)
3. Backend looks up pack config based on user's plan
4. Purchases the single configured pack for that plan

**Current Limitation:**
- Only ONE conversation pack option per plan
- Pack size is hardcoded in `billing_plans.yml` (10,000 for starter, 25,000 for professional)
- No way to select different pack sizes

---

## Requirements

### Important Business Rules

**Free Trial Restrictions:**
- ❌ Free Trial users **CANNOT purchase ANY add-ons**
- This includes: agents, inboxes, conversation packs, AND training services
- All purchase buttons should be **disabled** or **hidden** for Free Trial users
- This is a global restriction across all add-on types

**Enterprise Plan Display:**
- ✅ Enterprise users **CAN see** add-on sections
- All limits show as "Unlimited"
- Purchase buttons are **disabled** (grayed out)
- Training add-ons show "✓ Already Purchased" (included in plan)

### Conversation Pack Options

The user should be able to select from these options:

1. **Extra 100 Conversation Pack**
   - Product ID: `prod_TN3bW94wWyWhU1`
   - Price ID: `price_1SQJTt4TqKLiHbZ8SDpBTcK2`
   - Lookup Key: `extra_100_conversation_pack`

2. **Extra 500 Conversation Pack**
   - Product ID: `prod_TN4CdBajG2M0p4`
   - Price ID: `price_1SQK3g4TqKLiHbZ8zWA4nD3Z`
   - Lookup Key: `extra_500_conversation_pack`

3. **Extra 1000 Conversation Pack**
   - Product ID: `prod_TMKWwjrNBpVOpT`
   - Price ID: `price_1SPbrh4TqKLiHbZ8LThjZitj`
   - Lookup Key: `extra_1000_conversation_pack`

**Note:** The old lookup key `conversation_pack_starter` should be updated to `extra_1000_conversation_pack`.

### User Experience

1. Button text changes from "Buy 10,000 Conversation Pack" → "Buy Conversation Packs"
2. Clicking the button opens a modal (similar to extra agents/inboxes confirmation)
3. Modal contains:
   - Title: "Select Conversation Pack"
   - Dropdown/select field with pack options
   - Each option shows: pack size and price
   - Confirm and Cancel buttons
4. Upon confirmation:
   - Purchase the selected pack
   - Show success/error notifications
   - Refresh limits

---

## Proposed Solution

### Architecture Approach

**Option 1: Universal Pack Catalog (Recommended)**
- Define conversation packs globally (not per plan)
- All packs available to all paid plans
- Pack availability determined by plan eligibility
- Simplifies configuration and maintenance
- Matches pattern used for training add-ons

**Recommendation:** Use Option 1 (Universal Pack Catalog) for simplicity and consistency.

---

## Implementation Plan

### Phase 1: Backend Changes

#### 1.1 Update `config/billing_plans.yml`

**Change conversation pack structure from single pack to array of available packs:**

```yaml
# OLD (per-plan structure):
starter:
  conversation_packs:
    lookup_key: 'conversation_pack_starter'
    conversations: 10000

# NEW (global catalog):
conversation_packs:
  available_packs:
    - size: 100
      lookup_key: 'extra_100_conversation_pack'
      price_id: null  # Fetched from Stripe
      display_name: 'Extra 100 Conversations'
      product_id: 'prod_TN3bW94wWyWhU1'
    
    - size: 500
      lookup_key: 'extra_500_conversation_pack'
      price_id: null
      display_name: 'Extra 500 Conversations'
      product_id: 'prod_TN4CdBajG2M0p4'
    
    - size: 1000
      lookup_key: 'extra_1000_conversation_pack'
      price_id: null
      display_name: 'Extra 1,000 Conversations'
      product_id: 'prod_TMKWwjrNBpVOpT'
  
  # Plans that can purchase conversation packs
  # Note: Free Trial cannot purchase ANY add-ons
  # Note: Enterprise has unlimited, doesn't need packs
  eligible_plans:
    - 'starter'
    - 'professional'
```

**Note:** Remove per-plan `conversation_packs` configuration from individual plan definitions.

#### 1.2 Update `lib/billing_plans.rb` Module

Add method to retrieve conversation pack catalog:

```ruby
module BillingPlans
  # ... existing code ...

  def conversation_packs_catalog
    Rails.configuration.billing_plans.dig('conversation_packs', 'available_packs') || []
  end

  def conversation_pack_eligible_plans
    Rails.configuration.billing_plans.dig('conversation_packs', 'eligible_plans') || []
  end

  def conversation_packs_available_for_plan?(plan_name)
    conversation_pack_eligible_plans.include?(plan_name)
  end
end
```

#### 1.3 Update `app/services/billing/purchase_conversation_pack_service.rb`

**Changes needed:**
1. Accept `lookup_key` parameter to specify which pack to purchase
2. Fetch pack details from global catalog instead of plan config
3. Update validation to use new structure
4. **Add payment method validation (Layer 1 - Backend Protection)**

```ruby
# Modified initialize
def initialize(account, lookup_key)
  @account = account
  @plan_name = account.custom_attributes&.dig('plan_name') || 'free_trial'
  @lookup_key = lookup_key
  @pack_config = find_pack_config
end

def perform
  # Validate pack is available for this plan
  return failure_response('Conversation packs not available for this plan') unless pack_available?

  # Get pack configuration
  return failure_response('Pack configuration not found') unless @pack_config

  # Fetch price from Stripe
  price = fetch_price_from_stripe(@pack_config['lookup_key'])
  return failure_response("Price not found in Stripe for lookup_key: #{@pack_config['lookup_key']}") unless price

  # Get customer ID
  customer_id = @account.custom_attributes&.dig('stripe_customer_id')
  return failure_response('No Stripe customer found for this account') unless customer_id

  # NEW: Verify payment method exists before attempting purchase
  unless has_payment_method?(customer_id)
    return failure_response(
      'No payment method on file. Please add a payment method in the billing portal before purchasing.'
    )
  end

  # Create one-time invoice item
  invoice_item = ::Stripe::InvoiceItem.create(
    customer: customer_id,
    price: price.id,
    description: "#{format_number(@pack_config['conversations'])} Conversation Pack"
  )

  # Create and finalize invoice
  invoice = ::Stripe::Invoice.create(
    customer: customer_id,
    auto_advance: true, # Automatically finalize and attempt payment
    description: "Conversation Pack Purchase"
  )

  # Update account with extra conversations
  current_extra = @account.custom_attributes&.dig('extra_conversations_purchased')&.to_i || 0
  attrs = @account.custom_attributes || {}
  attrs['extra_conversations_purchased'] = current_extra + @pack_config['conversations']
  attrs['conversations_last_reset'] = Time.current.to_i
  @account.custom_attributes = attrs
  @account.save!

  Rails.logger.info "Conversation pack purchased for account #{@account.id}: #{@pack_config['conversations']} conversations"

  success_response(
    'Conversation pack purchased successfully',
    conversations_added: @pack_config['conversations'],
    new_total: current_extra + @pack_config['conversations'],
    invoice_id: invoice.id,
    amount: price.unit_amount,
    currency: price.currency
  )
rescue ::Stripe::CardError => e
  Rails.logger.error "Card error purchasing conversation pack: #{e.message}"
  failure_response("Payment failed: #{e.user_message}")
rescue ::Stripe::RateLimitError => e
  Rails.logger.warn "Stripe rate limit hit: #{e.message}"
  failure_response('Rate limited - please try again')
rescue ::Stripe::InvalidRequestError => e
  Rails.logger.error "Stripe invalid request: #{e.message}"
  # Check for specific "no payment method" errors
  if e.message.include?('no attached payment source') || 
     e.message.include?('no payment method')
    failure_response('No payment method on file. Please add one in the billing portal.')
  else
    failure_response("Invalid request: #{e.message}")
  end
rescue ::Stripe::StripeError => e
  Rails.logger.error "Stripe error purchasing conversation pack: #{e.message}"
  failure_response("Purchase failed: #{e.message}")
rescue StandardError => e
  Rails.logger.error "Error purchasing conversation pack: #{e.message}"
  failure_response("Purchase failed: #{e.message}")
end

private

def find_pack_config
  packs = self.class.conversation_packs_catalog
  packs.find { |pack| pack['lookup_key'] == @lookup_key }
end

def pack_available?
  return false unless @pack_config.present?
  
  # Check if plan is eligible
  return false unless self.class.conversation_packs_available_for_plan?(@plan_name)
  
  true
end

# NEW: Check if customer has a payment method on file
def has_payment_method?(customer_id)
  customer = ::Stripe::Customer.retrieve(customer_id)
  
  # Check for default payment method (preferred) or default source (legacy)
  customer.invoice_settings&.default_payment_method.present? ||
    customer.default_source.present?
rescue ::Stripe::StripeError => e
  Rails.logger.error "Error checking payment method: #{e.message}"
  false # Fail safely - will be caught during invoice creation
end

# ... rest of existing methods (fetch_price_from_stripe, format_number, etc.)
```

**Key changes:**
- Line 8-12: Add `lookup_key` parameter and fetch pack config
- Line 24-30: **NEW - Payment method validation before purchase**
- Line 71-78: **Enhanced error handling for missing payment method**
- Line 109-117: **NEW - `has_payment_method?` helper method**
- Keep rest of the purchase logic the same (invoice creation, account updates)

#### 1.4 Update `app/controllers/api/v2/accounts/billing/conversation_packs_controller.rb`

**Add two new endpoints:**

**Endpoint 1: Check Payment Method (Layer 2 - Proactive Frontend Check)**

```ruby
# GET /api/v2/accounts/:account_id/billing/conversation_packs/check_payment_method
def check_payment_method
  customer_id = current_account.custom_attributes&.dig('stripe_customer_id')
  
  if customer_id.blank?
    return render json: { 
      has_payment_method: false,
      message: 'No Stripe customer found'
    }
  end
  
  begin
    customer = ::Stripe::Customer.retrieve(customer_id)
    
    # Check for payment method in two places:
    # 1. invoice_settings.default_payment_method (preferred)
    # 2. default_source (legacy credit cards)
    has_payment_method = customer.invoice_settings&.default_payment_method.present? ||
                         customer.default_source.present?
    
    render json: {
      has_payment_method: has_payment_method,
      message: has_payment_method ? 'Payment method on file' : 'No payment method on file'
    }
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error checking payment method: #{e.message}"
    render json: {
      has_payment_method: false,
      message: e.message
    }, status: :unprocessable_entity
  end
end
```

**Endpoint 2: List Available Packs**

```ruby
# GET /api/v2/accounts/:account_id/billing/conversation_packs
def index
  plan_name = current_account.custom_attributes&.dig('plan_name')
  
  # Check if conversation packs are available for this plan
  eligible = BillingPlans.conversation_packs_available_for_plan?(plan_name)
  
  if eligible
    # Get pack catalog
    packs_catalog = BillingPlans.conversation_packs_catalog
    
    # Enrich with Stripe pricing data
    enriched_packs = packs_catalog.map do |pack|
      price = fetch_price_from_stripe(pack['lookup_key'])
      {
        lookup_key: pack['lookup_key'],
        size: pack['size'],
        display_name: pack['display_name'],
        product_id: pack['product_id'],
        price_id: price&.id,
        unit_amount: price&.unit_amount,
        currency: price&.currency,
        formatted_price: format_price(price)
      }
    end
    
    render json: {
      success: true,
      data: {
        packs: enriched_packs,
        eligible: true
      }
    }
  else
    render json: {
      success: true,
      data: {
        packs: [],
        eligible: false,
        message: 'Conversation packs not available for this plan'
      }
    }
  end
rescue StandardError => e
  Rails.logger.error "Error fetching conversation packs: #{e.message}"
  render json: {
    success: false,
    error: 'Failed to fetch conversation packs'
  }, status: :internal_server_error
end

private

def fetch_price_from_stripe(lookup_key)
  return nil unless lookup_key
  
  prices = ::Stripe::Price.list(lookup_keys: [lookup_key], limit: 1)
  prices.data.first
rescue ::Stripe::StripeError => e
  Rails.logger.error "Error fetching price from Stripe: #{e.message}"
  nil
end

def format_price(price)
  return nil unless price
  
  amount = price.unit_amount / 100.0
  currency_symbol = price.currency.upcase == 'USD' ? '$' : price.currency
  "#{currency_symbol}#{amount}"
end
```

#### 1.5 Update `app/controllers/api/v2/accounts/billing/conversation_packs_controller.rb` Purchase Endpoint

**Modify existing `purchase` action to accept pack selection:**

```ruby
# POST /api/v2/accounts/:account_id/billing/conversation_packs/purchase
def purchase
  lookup_key = params[:lookup_key]
  
  unless lookup_key.present?
    return render json: {
      success: false,
      error: 'Missing lookup_key parameter'
    }, status: :bad_request
  end
  
  service = Billing::PurchaseConversationPackService.new(current_account, lookup_key)
  result = service.perform
  
  if result[:success]
    render json: {
      success: true,
      message: result[:message],
      data: {
        conversations_added: result[:conversations_added],
        new_total: result[:new_total],
        invoice_id: result[:invoice_id],
        amount: result[:amount],
        currency: result[:currency]
      }
    }
  else
    render json: {
      success: false,
      error: result[:error]
    }, status: :unprocessable_entity
  end
rescue StandardError => e
  Rails.logger.error "Error purchasing conversation pack: #{e.message}"
  render json: {
    success: false,
    error: 'Failed to purchase conversation pack'
  }, status: :internal_server_error
end
```

**Key change:** Accept `lookup_key` parameter and pass it to service.

#### 1.6 Update Routes

**File:** `config/routes.rb`

Ensure the conversation packs endpoints are properly defined:

```ruby
namespace :billing do
  # ... existing routes ...
  
  resources :conversation_packs, only: [] do
    collection do
      get '/', action: :index  # List available packs
      get '/check_payment_method', action: :check_payment_method  # NEW: Check if payment method exists
      post '/purchase', action: :purchase  # Purchase selected pack
    end
  end
end
```

---

### Phase 2: Frontend Changes

#### 2.1 Create Conversation Pack Selection Modal Component

**New file:** `app/javascript/dashboard/routes/dashboard/settings/billing/components/ConversationPackModal.vue`

**Purpose:** A modal that displays conversation pack options in a dropdown/select field

**Features:**
- Dropdown/select showing pack options with size and price
- Confirmation buttons (Cancel / Confirm Purchase)
- Loading state during purchase
- Uses existing Modal component as base

**Structure:**

```vue
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  packs: {
    type: Array,
    required: true,
  },
  isPurchasing: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'purchase']);

const { t } = useI18n();
const show = ref(false);
const selectedPackLookupKey = ref(null);

const showModal = () => {
  show.value = true;
  // Pre-select first pack if available
  if (props.packs.length > 0) {
    selectedPackLookupKey.value = props.packs[0].lookup_key;
  }
};

const closeModal = () => {
  show.value = false;
  selectedPackLookupKey.value = null;
  emit('close');
};

const confirmPurchase = () => {
  if (selectedPackLookupKey.value) {
    emit('purchase', selectedPackLookupKey.value);
  }
};

const selectedPack = computed(() => {
  return props.packs.find(p => p.lookup_key === selectedPackLookupKey.value);
});

const packOptions = computed(() => {
  return props.packs.map(pack => ({
    value: pack.lookup_key,
    label: `${pack.display_name} - ${pack.formatted_price || 'Price not available'}`,
    size: pack.size,
    price: pack.formatted_price,
  }));
});

defineExpose({
  showModal,
});
</script>

<template>
  <Modal v-model:show="show" :on-close="closeModal">
    <div class="h-auto overflow-auto flex flex-col">
      <woot-modal-header
        :header-title="t('BILLING_SETTINGS.LIMITS.SELECT_CONVERSATION_PACK_TITLE')"
        :header-content="t('BILLING_SETTINGS.LIMITS.SELECT_CONVERSATION_PACK_DESCRIPTION')"
      />
      
      <div class="px-6 py-4">
        <!-- Dropdown/Select for pack options -->
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ t('BILLING_SETTINGS.LIMITS.PACK_SIZE_LABEL') }}
        </label>
        <select
          v-model="selectedPackLookupKey"
          class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-blue-9"
          :disabled="isPurchasing"
        >
          <option
            v-for="option in packOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
        
        <!-- Selected pack details (optional - for clarity) -->
        <div
          v-if="selectedPack"
          class="mt-4 p-3 bg-n-solid-2 border border-n-weak rounded-md"
        >
          <p class="text-sm text-n-slate-11">
            {{ t('BILLING_SETTINGS.LIMITS.PACK_DETAILS') }}
          </p>
          <p class="text-lg font-semibold text-n-slate-12 mt-1">
            {{ selectedPack.size.toLocaleString() }}
            {{ t('BILLING_SETTINGS.LIMITS.CONVERSATIONS') }}
          </p>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ t('BILLING_SETTINGS.LIMITS.ONE_TIME_CHARGE') }}:
            <span class="font-semibold text-n-slate-12">
              {{ selectedPack.formatted_price }}
            </span>
          </p>
        </div>
      </div>
      
      <!-- Action buttons -->
      <div class="flex flex-row justify-end gap-2 py-4 px-6 w-full border-t border-n-weak">
        <NextButton
          faded
          type="reset"
          :label="t('BILLING_SETTINGS.LIMITS.CANCEL_PURCHASE_BUTTON')"
          :disabled="isPurchasing"
          @click="closeModal"
        />
        <NextButton
          type="submit"
          :label="t('BILLING_SETTINGS.LIMITS.CONFIRM_PURCHASE_BUTTON')"
          :disabled="!selectedPackLookupKey || isPurchasing"
          :loading="isPurchasing"
          @click="confirmPurchase"
        />
      </div>
    </div>
  </Modal>
</template>
```

**Key features:**
- Uses standard `<select>` element (simple, accessible, works everywhere)
- Pre-selects first pack option
- Disables controls during purchase
- Shows loading state on confirm button
- Displays selected pack details for clarity
- Follows existing modal patterns in codebase

#### 2.2 Update `BillingLimitsCard.vue`

**File:** `app/javascript/dashboard/routes/dashboard/settings/billing/components/BillingLimitsCard.vue`

**Important Note:** This component may need additional updates to handle Free Trial restrictions (disabling ALL purchase buttons) and Enterprise unlimited display. Those changes are beyond the scope of this conversation pack feature but should be considered.

**Changes for conversation pack selection:**

**1. Add imports (top of script):**

```javascript
import ConversationPackModal from './ConversationPackModal.vue';
```

**2. Add new reactive state:**

```javascript
const conversationPacks = ref([]);
const conversationPackModal = ref(null);
```

**3. Add method to fetch available packs:**

```javascript
const fetchConversationPacks = async () => {
  try {
    const response = await store.dispatch('accounts/fetchConversationPacks');
    if (response?.data?.data?.packs) {
      conversationPacks.value = response.data.data.packs;
    }
  } catch (error) {
    // Silent fail - packs won't be available
    conversationPacks.value = [];
  }
};
```

**4. Update `onMounted` to fetch packs:**

```javascript
onMounted(async () => {
  await Promise.all([
    fetchLimits(),
    fetchAddOns(),
    fetchConversationPacks()  // Add this
  ]);
});
```

**5. Replace `confirmPurchaseConversationPack` method (with payment method check):**

```javascript
const confirmPurchaseConversationPack = async () => {
  // Layer 2: Proactive check for payment method BEFORE opening modal
  try {
    const response = await store.dispatch('accounts/checkPaymentMethod');
    
    if (!response?.data?.has_payment_method) {
      // No payment method found - show error and don't open modal
      useAlert(
        t('BILLING_SETTINGS.LIMITS.ADD_PAYMENT_METHOD_FIRST'),
        { duration: 7000 }
      );
      return; // Stop here - don't open modal
    }
  } catch (error) {
    // If the check itself fails, log it but continue anyway
    // (Fail open, not closed - don't unnecessarily block users)
    console.warn('Could not verify payment method:', error);
    // Continue to open modal - backend will catch issues
  }
  
  // Payment method exists (or check failed but we're being permissive)
  // Proceed to show the conversation pack selection modal
  conversationPackModal.value.showModal();
};
```

**6. Update `purchaseConversationPack` to accept lookup_key:**

```javascript
const purchaseConversationPack = async (lookupKey) => {
  try {
    isPurchasing.value = true;
    await store.dispatch('accounts/purchaseConversationPack', {
      lookup_key: lookupKey
    });
    
    // Close modal
    conversationPackModal.value?.closeModal();
    
    // Refresh limits after purchase
    await fetchLimits();
    
    // Show success notification
    useAlert(
      t('BILLING_SETTINGS.LIMITS.CONVERSATION_PACK_SUCCESS'),
      { duration: 5000 }
    );
  } catch (error) {
    // Show error notification
    const errorMessage = error?.response?.data?.error || error?.message;
    useAlert(
      t('BILLING_SETTINGS.LIMITS.CONVERSATION_PACK_ERROR', {
        error: errorMessage || t('BILLING_SETTINGS.LIMITS.GENERIC_ERROR'),
      }),
      { duration: 5000 }
    );
  } finally {
    isPurchasing.value = false;
  }
};
```

**7. Update the button text (template section, line ~620):**

```vue
<!-- OLD -->
{{ t('BILLING_SETTINGS.LIMITS.PURCHASE_CONVERSATION_PACK') }}

<!-- NEW -->
{{ t('BILLING_SETTINGS.LIMITS.PURCHASE_CONVERSATION_PACKS') }}
```

**8. Add ConversationPackModal component to template (after existing ConfirmationModal, line ~640):**

```vue
<!-- Conversation Pack Selection Modal -->
<ConversationPackModal
  ref="conversationPackModal"
  :packs="conversationPacks"
  :is-purchasing="isPurchasing"
  @purchase="purchaseConversationPack"
/>
```

#### 2.3 Update Vuex Store Actions

**File:** `app/javascript/dashboard/store/modules/accounts.js`

**Add new actions:**

**Action 1: Check Payment Method (Layer 2)**

```javascript
checkPaymentMethod: async () => {
  try {
    const response = await BillingAPI.checkPaymentMethod();
    return response;
  } catch (error) {
    throwErrorMessage(error);
    throw error;
  }
},
```

**Action 2: Fetch Conversation Packs**

```javascript
fetchConversationPacks: async () => {
  try {
    const response = await BillingAPI.getConversationPacks();
    return response;
  } catch (error) {
    throwErrorMessage(error);
    throw error;
  }
},
```

**Update existing `purchaseConversationPack` action to accept lookup_key:**

```javascript
purchaseConversationPack: async ({ commit }, { lookup_key }) => {
  try {
    const response = await BillingAPI.purchaseConversationPack(lookup_key);
    if (response.data.success) {
      return response;
    }
    throw new Error(
      response.data.error || 'Failed to purchase conversation pack'
    );
  } catch (error) {
    throwErrorMessage(error);
    throw error;
  }
},
```

#### 2.4 Update Billing API Client

**File:** `app/javascript/dashboard/api/v2/billing.js`

**Add/Update methods:**

**1. NEW: Add `checkPaymentMethod` (Layer 2)**

```javascript
// GET /api/v2/accounts/:account_id/billing/conversation_packs/check_payment_method
checkPaymentMethod() {
  return axios.get(`${this.url}billing/conversation_packs/check_payment_method`);
}
```

**2. `getConversationPacks` (already exists, line 61-64):**

```javascript
// GET /api/v2/accounts/:account_id/billing/conversation_packs
getConversationPacks() {
  return axios.get(`${this.url}billing/conversation_packs`);
}
```

**3. Update `purchaseConversationPack` to accept lookup_key:**

```javascript
// POST /api/v2/accounts/:account_id/billing/conversation_packs/purchase
purchaseConversationPack(lookupKey) {
  return axios.post(`${this.url}billing/conversation_packs/purchase`, {
    lookup_key: lookupKey,
  });
}
```

#### 2.5 Add Translation Keys

**Files:**
- `app/javascript/dashboard/i18n/locale/en/settings.json`
- `app/javascript/dashboard/i18n/locale/es/settings.json`

**English (`en/settings.json`):**

```json
{
  "BILLING_SETTINGS": {
    "LIMITS": {
      // ... existing keys ...
      
      // UPDATE this key (change singular to plural)
      "PURCHASE_CONVERSATION_PACKS": "Buy Conversation Packs",
      
      // ADD new keys for modal
      "SELECT_CONVERSATION_PACK_TITLE": "Select Conversation Pack",
      "SELECT_CONVERSATION_PACK_DESCRIPTION": "Choose the conversation pack size you want to purchase. This will be charged immediately and added to your account.",
      "PACK_SIZE_LABEL": "Pack Size",
      "PACK_DETAILS": "You will receive:",
      "ONE_TIME_CHARGE": "One-time charge",
      
      // ADD new keys for payment method errors (Layer 2 & 3)
      "ADD_PAYMENT_METHOD_FIRST": "Please add a payment method before purchasing conversation packs. Click 'Go to billing portal' to add your payment details.",
      "NO_PAYMENT_METHOD_ERROR": "No payment method on file. Please add a payment method in the billing portal before purchasing add-ons."
    }
  }
}
```

**Spanish (`es/settings.json`):**

```json
{
  "BILLING_SETTINGS": {
    "LIMITS": {
      // ... existing keys ...
      
      "PURCHASE_CONVERSATION_PACKS": "Comprar Paquetes de Conversaciones",
      "SELECT_CONVERSATION_PACK_TITLE": "Seleccionar Paquete de Conversaciones",
      "SELECT_CONVERSATION_PACK_DESCRIPTION": "Elija el tamaño del paquete de conversaciones que desea comprar. Se cobrará inmediatamente y se agregará a su cuenta.",
      "PACK_SIZE_LABEL": "Tamaño del Paquete",
      "PACK_DETAILS": "Recibirás:",
      "ONE_TIME_CHARGE": "Cargo único",
      
      // Payment method error messages
      "ADD_PAYMENT_METHOD_FIRST": "Por favor agregue un método de pago antes de comprar paquetes de conversaciones. Haga clic en 'Ir al portal de facturación' para agregar sus detalles de pago.",
      "NO_PAYMENT_METHOD_ERROR": "No hay método de pago registrado. Por favor agregue un método de pago en el portal de facturación antes de comprar complementos."
    }
  }
}
```

---

### Phase 3: Stripe Configuration

#### 3.1 Verify Existing Products in Stripe

**Products to verify:**
1. Extra 100 Conversation Pack (`prod_TN3bW94wWyWhU1`)
2. Extra 500 Conversation Pack (`prod_TN4CdBajG2M0p4`)
3. Extra 1000 Conversation Pack (`prod_TMKWwjrNBpVOpT`)

**Check in Stripe Dashboard:**
- Product exists
- Price exists with correct lookup key
- Price is one-time (not recurring)
- Price amount is correct


#### 3.2 Update Existing Lookup Key

**Action required:**
- Find the price with lookup key `conversation_pack_starter`
- Update its lookup key to `extra_1000_conversation_pack`
- Ensure it matches the product `prod_TMKWwjrNBpVOpT`

**Location:** Stripe Dashboard → Products → [Product] → Prices → Edit

---

## File Changes Summary

### Files to Modify

#### Backend
1. ✏️ `config/billing_plans.yml` - Restructure conversation packs to global catalog
2. ✏️ `lib/billing_plans.rb` - Add catalog methods (`conversation_packs_catalog`, `conversation_packs_available_for_plan?`)
3. ✏️ `app/services/billing/purchase_conversation_pack_service.rb` - Accept `lookup_key` param + **add payment method validation (Layer 1)**
4. ✏️ `app/controllers/api/v2/accounts/billing/conversation_packs_controller.rb` - Add `index` endpoint, **add `check_payment_method` endpoint (Layer 2)**, update `purchase` endpoint
5. ✏️ `config/routes.rb` - Add conversation pack routes including **`check_payment_method`**

#### Frontend
6. ✏️ `app/javascript/dashboard/routes/dashboard/settings/billing/components/BillingLimitsCard.vue` - Update button, **add proactive payment method check (Layer 2)**, add modal integration
7. ✨ `app/javascript/dashboard/routes/dashboard/settings/billing/components/ConversationPackModal.vue` - NEW modal component for pack selection
8. ✏️ `app/javascript/dashboard/store/modules/accounts.js` - **Add `checkPaymentMethod` action (Layer 2)**, add `fetchConversationPacks` action, update `purchaseConversationPack` to accept `lookup_key`
9. ✏️ `app/javascript/dashboard/api/v2/billing.js` - **Add `checkPaymentMethod` method (Layer 2)**, update `purchaseConversationPack` to accept `lookup_key`
10. ✏️ `app/javascript/dashboard/i18n/locale/en/settings.json` - Add translation keys (modal + **payment method errors**)
11. ✏️ `app/javascript/dashboard/i18n/locale/es/settings.json` - Add translation keys (modal + **payment method errors**)

### Files to Create
- `app/javascript/dashboard/routes/dashboard/settings/billing/components/ConversationPackModal.vue`

### Payment Method Handling (Good UX - All 3 Layers)

**Layer 1 (Backend):** Service validates payment method exists before creating invoice  
**Layer 2 (Frontend):** Proactive check before opening modal - prevents wasted user effort  
**Layer 3 (Error Handling):** Enhanced Stripe error detection for missing payment methods  

**Total new code:** ~95 lines  
**Implementation time:** ~1.5 hours

---

## Payment Method Handling (Detailed)

### Why This Is Important

Users who have monthly/yearly subscriptions **should** have payment methods on file, but edge cases exist:
- Payment method expired
- Card was removed in Stripe portal
- Trial period ended without payment setup
- Payment failed and card was deleted
- Manual admin intervention

Without proper handling, users get confusing errors when trying to purchase conversation packs.

### The 3-Layer Protection Strategy

#### Layer 1: Backend Validation (Service Level)

**Location:** `app/services/billing/purchase_conversation_pack_service.rb`

**What it does:**
- Checks if payment method exists **before** creating invoice
- Calls `has_payment_method?(customer_id)` helper
- Returns clear error if missing: "No payment method on file. Please add..."
- Prevents failed invoice creation in Stripe

**Code:**
```ruby
def has_payment_method?(customer_id)
  customer = ::Stripe::Customer.retrieve(customer_id)
  customer.invoice_settings&.default_payment_method.present? ||
    customer.default_source.present?
end
```

**Why it's essential:**
- Last line of defense
- Prevents Stripe API failures
- Provides actionable error messages
- Works even if frontend check is bypassed

#### Layer 2: Proactive Frontend Check

**Location:** `app/javascript/dashboard/routes/dashboard/settings/billing/components/BillingLimitsCard.vue`

**What it does:**
- Checks payment method **before** opening modal
- Calls `checkPaymentMethod()` API endpoint
- Shows error immediately if missing
- Prevents user from selecting pack they can't buy

**Code:**
```javascript
const confirmPurchaseConversationPack = async () => {
  const response = await store.dispatch('accounts/checkPaymentMethod');
  
  if (!response?.data?.has_payment_method) {
    useAlert('Please add a payment method first...');
    return; // Don't open modal
  }
  
  conversationPackModal.value.showModal();
};
```

**Why it's valuable:**
- Better UX - fail fast, fail clear
- Prevents wasted time selecting a pack
- Guides user to solution (billing portal)
- Reduces support tickets

#### Layer 3: Enhanced Error Handling

**Location:** `app/services/billing/purchase_conversation_pack_service.rb` (rescue blocks)

**What it does:**
- Catches Stripe-specific "no payment method" errors
- Detects errors from invoice creation attempt
- Returns user-friendly messages
- Distinguishes payment method errors from other issues

**Code:**
```ruby
rescue ::Stripe::InvalidRequestError => e
  if e.message.include?('no attached payment source') || 
     e.message.include?('no payment method')
    failure_response('No payment method on file. Please add one in the billing portal.')
  else
    failure_response("Invalid request: #{e.message}")
  end
```

**Why it's necessary:**
- Handles edge cases where Layers 1-2 miss something
- Provides specific error messages
- Catches Stripe API changes
- Graceful degradation

### How Users Add Payment Methods

When users see "No payment method on file" error, they:

1. Click **"Go to billing portal"** button (already on Settings > Billing page)
2. Stripe portal opens in new tab
3. Navigate to **"Payment methods"** section
4. Click **"Add payment method"**
5. Enter card details
6. Save and return to Chatwoot
7. Try purchasing conversation pack again
8. ✅ Purchase succeeds

**No custom payment collection needed** - Stripe portal handles everything.

### Testing Payment Method Handling

**Test Scenario 1: Happy Path**
- User has payment method → Check passes → Modal opens → Purchase succeeds

**Test Scenario 2: Missing Payment Method (Proactive)**
- User has no payment method → Check fails → Error shown → Modal doesn't open

**Test Scenario 3: Missing Payment Method (Backend Catch)**
- Check bypassed somehow → Purchase attempted → Service catches it → Error returned

**Test Scenario 4: Expired Card**
- User has expired card → Stripe rejects charge → Clear error message shown

**Test Scenario 5: Check Endpoint Fails**
- Check API fails → Log warning → Continue to modal → Backend will catch issues

---

## Migration Steps

### Step 1: Stripe Setup
1. Verify 3 existing products in Stripe
2. Update lookup key: `conversation_pack_starter` → `extra_1000_conversation_pack`
3. Test Stripe API calls to fetch prices

### Step 2: Backend Implementation
1. Update `billing_plans.yml`
2. Update `BillingPlans` module
3. Update `PurchaseConversationPackService` (includes Layer 1 payment method check)
4. Update controller endpoints (includes `check_payment_method` endpoint for Layer 2)
5. Update routes to include `check_payment_method`
6. Test backend with curl:
   ```bash
   # Test payment method check
   curl -X GET "http://localhost:3000/api/v2/accounts/1/billing/conversation_packs/check_payment_method"
   
   # Test list packs
   curl -X GET "http://localhost:3000/api/v2/accounts/1/billing/conversation_packs"
   
   # Test purchase
   curl -X POST "http://localhost:3000/api/v2/accounts/1/billing/conversation_packs/purchase" \
     -d '{"lookup_key": "extra_100_conversation_pack"}'
   ```
  
### Step 3: Frontend Implementation
1. Create `ConversationPackModal.vue`
2. Update `BillingLimitsCard.vue` (includes Layer 2 proactive check)
3. Update Vuex store (add `checkPaymentMethod` action)
4. Update Billing API client (add `checkPaymentMethod` method)
5. Add translation keys (including payment method error messages)
6. Test frontend:
   - With payment method: Modal should open
   - Without payment method: Error should show, modal shouldn't open

### Step 4: Testing Payment Method Scenarios
1. **Test with valid payment method:**
   - Verify check passes
   - Verify modal opens
   - Verify purchase succeeds
   
2. **Test without payment method:**
   - Remove payment method in Stripe portal
   - Click "Buy Conversation Packs"
   - Verify error: "Please add a payment method first..."
   - Verify modal doesn't open
   
3. **Test backend fallback:**
   - Bypass frontend check (direct API call)
   - Verify service returns: "No payment method on file..."
   
4. **Test error recovery:**
   - Add payment method via billing portal
   - Retry purchase
   - Verify success

---

## Edge Cases & Error Handling

### Edge Cases

1. **Missing Payment Method (Layer 2 - Proactive Check)**
   - Frontend check detects before modal opens
   - Error: "Please add a payment method before purchasing..."
   - Modal doesn't open
   - User guided to billing portal

2. **Missing Payment Method (Layer 1 - Backend Validation)**
   - Service validates before creating invoice
   - Returns: "No payment method on file..."
   - Prevents failed Stripe API call
   - Clear error message to user

3. **Payment Method Check Endpoint Fails**
   - Check API returns error or times out
   - Log warning but continue
   - Modal opens anyway (fail open, not closed)
   - Backend Layer 1 will catch issues during purchase

4. **Expired or Invalid Card**
   - Stripe rejects during charge attempt
   - Error: "Payment failed: Your card has expired"
   - User can update card in billing portal
   - Retry purchase after update

5. **Stripe API failure**
   - Show packs without pricing
   - Disable purchase if pricing unavailable
   - Log error for investigation

6. **Price not found for lookup key**
   - Skip that pack in the list
   - Log warning
   - Continue showing other packs

7. **User has no Stripe customer**
   - Service already handles this
   - Returns error: "No Stripe customer found"

8. **Payment declined (other reasons)**
   - Service handles Stripe errors
   - Show user-friendly error message
   - Allow retry

### Error Messages

**Payment Method Errors (NEW):**
- Frontend proactive check: "Please add a payment method before purchasing conversation packs. Click 'Go to billing portal' to add your payment details."
- Backend validation: "No payment method on file. Please add a payment method in the billing portal before purchasing."
- Stripe-specific: "No payment method on file. Please add one in the billing portal."

**Backend errors:**
- Missing lookup_key: "Please select a conversation pack"
- Pack not found: "Selected conversation pack is not available"
- Not eligible: "Conversation packs not available for this plan"
- No Stripe customer: "No Stripe customer found for this account"
- Card errors: Pass through Stripe error messages (e.g., "Payment failed: Your card was declined")

**Frontend errors:**
- Network failure: "Failed to load conversation packs. Please try again."
- Purchase failure: "Failed to purchase conversation pack. {error}"

---

## Clarifications Received ✅

### 1. Lookup Key Migration
**Answer:** If the lookup key `conversation_pack_starter` exists in the codebase/Stripe, simply update it to `extra_1000_conversation_pack`. It's tied to product `prod_TMKWwjrNBpVOpT`.

**Action:** Update lookup key in Stripe Dashboard for that specific price.

### 2. Plan Eligibility

**Free Trial:**
- ❌ **Cannot purchase ANY add-ons** (not even training services)
- Button should be **disabled** or **hidden**
- Applies to all add-ons: agents, inboxes, conversation packs, training

**Starter/Professional:**
- ✅ **Can purchase all add-ons**
- Normal purchase flow

**Enterprise:**
- ✅ **Can see add-ons sections**
- **Agents section:** Shows "Unlimited" everywhere, button disabled
  - Base included: Unlimited
  - Extra purchased: - (or empty)
  - Currently using: [actual number]
  - Available: Unlimited
  - Button: Disabled (grayed out)
- **Inboxes section:** Same as agents
- **Conversations section:** Same as agents
- **Training add-ons:** Show "✓ Already Purchased" instead of purchase button
  - Training is included in Enterprise plan

### 3. Pack Availability
**Answer:** All eligible plans (Starter/Professional) get the **same 3 pack options**. Enterprise doesn't need packs (they have unlimited).

### 4. Default Selection
**Answer:** Pre-select the **first pack** (100 conversation pack) by default.

### 5. Payment Flow (One-Time Purchase)

**Question:** If buying a conversation pack is a one-time payment, shouldn't it redirect to Stripe for payment?

**Answer:** No redirect needed. Here's why:

**Current Approach (Recommended):**
- Uses customer's **saved payment method** (already on file)
- Creates invoice and charges **immediately**
- User stays on Chatwoot (no redirect)
- Shows success/error notification
- **Consistent with agents/inboxes** purchase flow

**How it works:**
1. User selects pack and confirms
2. Backend creates Stripe invoice with `auto_advance: true`
3. Stripe automatically charges saved payment method
4. Success → Add conversations to account
5. Failure → Show error message
6. User sees result immediately (no waiting for redirect back)

**Why not redirect to Stripe Checkout?**
- ✅ **Faster UX** - no redirect, no waiting
- ✅ **Simpler code** - no checkout sessions, webhooks complexity
- ✅ **Consistent** - matches how other add-ons work
- ✅ **Assumption** - Users on paid plans already have valid payment methods

**Edge case:** If user has no payment method or card is declined:
- Stripe API returns error
- Show error message: "Payment failed: [reason]"
- User can fix payment method via billing portal
- Retry purchase


---