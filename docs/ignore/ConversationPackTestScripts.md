# Conversation Pack Selection - Test Scripts

Simple, effective test scripts to verify the new conversation pack selection functionality.

---

## Backend API Tests (Manual)

### Test 1: List Available Conversation Packs (Eligible Plan)

**Scenario:** User on Starter plan should see all available packs with pricing

```bash
# Get your account ID and auth token from the browser (dev tools > Application > Local Storage)
ACCOUNT_ID=1
AUTH_TOKEN="your_auth_token_here"

curl -X GET "http://localhost:3000/api/v2/accounts/${ACCOUNT_ID}/billing/conversation_packs" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" | jq
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "packs": [
      {
        "lookup_key": "extra_100_conversation_pack",
        "size": 100,
        "display_name": "Extra 100 Conversations",
        "product_id": "prod_TN3bW94wWyWhU1",
        "price_id": "price_1SQJTt4TqKLiHbZ8SDpBTcK2",
        "unit_amount": 500,
        "currency": "usd",
        "formatted_price": "$5.00"
      },
      {
        "lookup_key": "extra_500_conversation_pack",
        "size": 500,
        "display_name": "Extra 500 Conversations",
        "product_id": "prod_TN4CdBajG2M0p4",
        "price_id": "price_1SQK3g4TqKLiHbZ8zWA4nD3Z",
        "unit_amount": 2000,
        "currency": "usd",
        "formatted_price": "$20.00"
      },
      {
        "lookup_key": "extra_1000_conversation_pack",
        "size": 1000,
        "display_name": "Extra 1,000 Conversations",
        "product_id": "prod_TMKWwjrNBpVOpT",
        "price_id": "price_1SPbrh4TqKLiHbZ8LThjZitj",
        "unit_amount": 3500,
        "currency": "usd",
        "formatted_price": "$35.00"
      }
    ],
    "eligible": true
  }
}
```

**Validation:**
- ✅ `success: true`
- ✅ `eligible: true`
- ✅ All 3 packs returned
- ✅ Each pack has pricing data from Stripe

---

### Test 2: List Packs (Ineligible Plan - Free Trial)

**Scenario:** User on Free Trial should NOT see packs

```bash
# Switch account to free_trial plan first (via Rails console or update custom_attributes)
curl -X GET "http://localhost:3000/api/v2/accounts/${ACCOUNT_ID}/billing/conversation_packs" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" | jq
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "packs": [],
    "eligible": false,
    "message": "Conversation packs not available for this plan"
  }
}
```

**Validation:**
- ✅ `success: true`
- ✅ `eligible: false`
- ✅ `packs` is empty array
- ✅ Helpful message provided

---

### Test 3: Purchase Conversation Pack (100 pack)

**Scenario:** Purchase the 100 conversation pack

```bash
curl -X POST "http://localhost:3000/api/v2/accounts/${ACCOUNT_ID}/billing/conversation_packs/purchase" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "lookup_key": "extra_100_conversation_pack"
  }' | jq
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Conversation pack purchased successfully",
  "data": {
    "conversations_added": 100,
    "new_total": 100,
    "invoice_id": "in_xxxxxxxxxxxxx",
    "amount": 500,
    "currency": "usd"
  }
}
```

**Validation:**
- ✅ `success: true`
- ✅ `conversations_added: 100`
- ✅ Stripe invoice ID returned
- ✅ Amount matches pack price

**Verify in Stripe Dashboard:**
- Invoice created for customer
- Invoice paid/charged
- Amount correct ($5.00)

**Verify in Account:**
```bash
# Check account's extra_conversations_purchased
rails console
> account = Account.find(1)
> account.custom_attributes['extra_conversations_purchased']
=> 100
```

---

### Test 4: Purchase Without lookup_key Parameter

**Scenario:** Error handling when lookup_key is missing

```bash
curl -X POST "http://localhost:3000/api/v2/accounts/${ACCOUNT_ID}/billing/conversation_packs/purchase" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}' | jq
```

**Expected Response:**
```json
{
  "success": false,
  "error": "Missing lookup_key parameter"
}
```

**Validation:**
- ✅ `success: false`
- ✅ Clear error message
- ✅ HTTP status 400 (Bad Request)

---

### Test 5: Purchase Invalid Pack

**Scenario:** Attempt to purchase with invalid lookup_key

```bash
curl -X POST "http://localhost:3000/api/v2/accounts/${ACCOUNT_ID}/billing/conversation_packs/purchase" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "lookup_key": "invalid_pack_key"
  }' | jq
```

**Expected Response:**
```json
{
  "success": false,
  "error": "Pack configuration not found"
}
```

**Validation:**
- ✅ `success: false`
- ✅ Error indicates pack not found
- ✅ HTTP status 422 (Unprocessable Entity)

---

## Frontend Tests (Vitest)

### Test File: `ConversationPackModal.spec.js`

**Location:** `app/javascript/dashboard/routes/dashboard/settings/billing/components/__tests__/ConversationPackModal.spec.js`

```javascript
import { describe, it, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import ConversationPackModal from '../ConversationPackModal.vue';
import { createI18n } from 'vue-i18n';

const i18n = createI18n({
  locale: 'en',
  messages: {
    en: {
      BILLING_SETTINGS: {
        LIMITS: {
          SELECT_CONVERSATION_PACK_TITLE: 'Select Conversation Pack',
          SELECT_CONVERSATION_PACK_DESCRIPTION: 'Choose a pack',
          PACK_SIZE_LABEL: 'Pack Size',
          PACK_DETAILS: 'You will receive:',
          CONVERSATIONS: 'Conversations',
          ONE_TIME_CHARGE: 'One-time charge',
          CANCEL_PURCHASE_BUTTON: 'Cancel',
          CONFIRM_PURCHASE_BUTTON: 'Confirm Purchase',
        },
      },
    },
  },
});

describe('ConversationPackModal', () => {
  const mockPacks = [
    {
      lookup_key: 'extra_100_conversation_pack',
      size: 100,
      display_name: 'Extra 100 Conversations',
      formatted_price: '$5.00',
    },
    {
      lookup_key: 'extra_500_conversation_pack',
      size: 500,
      display_name: 'Extra 500 Conversations',
      formatted_price: '$20.00',
    },
    {
      lookup_key: 'extra_1000_conversation_pack',
      size: 1000,
      display_name: 'Extra 1,000 Conversations',
      formatted_price: '$35.00',
    },
  ];

  it('renders pack options in dropdown', () => {
    const wrapper = mount(ConversationPackModal, {
      global: {
        plugins: [i18n],
      },
      props: {
        packs: mockPacks,
        isPurchasing: false,
      },
    });

    wrapper.vm.showModal();
    const options = wrapper.findAll('option');
    
    expect(options).toHaveLength(3);
    expect(options[0].text()).toContain('Extra 100 Conversations');
    expect(options[0].text()).toContain('$5.00');
  });

  it('pre-selects first pack by default', async () => {
    const wrapper = mount(ConversationPackModal, {
      global: {
        plugins: [i18n],
      },
      props: {
        packs: mockPacks,
        isPurchasing: false,
      },
    });

    wrapper.vm.showModal();
    await wrapper.vm.$nextTick();
    
    const select = wrapper.find('select');
    expect(select.element.value).toBe('extra_100_conversation_pack');
  });

  it('emits purchase event with selected lookup_key', async () => {
    const wrapper = mount(ConversationPackModal, {
      global: {
        plugins: [i18n],
      },
      props: {
        packs: mockPacks,
        isPurchasing: false,
      },
    });

    wrapper.vm.showModal();
    await wrapper.vm.$nextTick();

    // Select the 500 pack
    const select = wrapper.find('select');
    await select.setValue('extra_500_conversation_pack');

    // Click confirm button
    const confirmButton = wrapper.findAll('button').find(btn => 
      btn.text().includes('Confirm Purchase')
    );
    await confirmButton.trigger('click');

    expect(wrapper.emitted('purchase')).toBeTruthy();
    expect(wrapper.emitted('purchase')[0]).toEqual(['extra_500_conversation_pack']);
  });

  it('disables controls when purchasing', () => {
    const wrapper = mount(ConversationPackModal, {
      global: {
        plugins: [i18n],
      },
      props: {
        packs: mockPacks,
        isPurchasing: true,
      },
    });

    wrapper.vm.showModal();
    
    const select = wrapper.find('select');
    expect(select.attributes('disabled')).toBeDefined();

    const cancelButton = wrapper.findAll('button').find(btn => 
      btn.text().includes('Cancel')
    );
    expect(cancelButton.attributes('disabled')).toBeDefined();
  });

  it('shows selected pack details', async () => {
    const wrapper = mount(ConversationPackModal, {
      global: {
        plugins: [i18n],
      },
      props: {
        packs: mockPacks,
        isPurchasing: false,
      },
    });

    wrapper.vm.showModal();
    await wrapper.vm.$nextTick();

    const details = wrapper.text();
    expect(details).toContain('100');
    expect(details).toContain('$5.00');
  });
});
```

**Run the test:**
```bash
pnpm test ConversationPackModal.spec.js
```

---

### Test File: `BillingLimitsCard.spec.js` (Update existing)

**Add these tests to existing file:**

```javascript
describe('Conversation Pack Selection', () => {
  it('fetches conversation packs on mount', async () => {
    const store = createMockStore();
    store.dispatch = vi.fn().mockResolvedValue({
      data: {
        data: {
          packs: [
            { lookup_key: 'extra_100_conversation_pack', size: 100 }
          ]
        }
      }
    });

    const wrapper = mount(BillingLimitsCard, {
      global: {
        plugins: [store, i18n],
      },
    });

    await wrapper.vm.$nextTick();

    expect(store.dispatch).toHaveBeenCalledWith('accounts/fetchConversationPacks');
  });

  it('opens pack selection modal on button click', async () => {
    const wrapper = mount(BillingLimitsCard, {
      global: {
        plugins: [createMockStore(), i18n],
      },
    });

    const button = wrapper.find('[data-testid="buy-conversation-packs"]');
    await button.trigger('click');

    // Verify modal's showModal was called
    expect(wrapper.vm.conversationPackModal.show).toBe(true);
  });

  it('purchases selected pack and shows success notification', async () => {
    const store = createMockStore();
    store.dispatch = vi.fn().mockResolvedValue({ data: { success: true } });

    const wrapper = mount(BillingLimitsCard, {
      global: {
        plugins: [store, i18n],
      },
    });

    await wrapper.vm.purchaseConversationPack('extra_100_conversation_pack');

    expect(store.dispatch).toHaveBeenCalledWith(
      'accounts/purchaseConversationPack',
      { lookup_key: 'extra_100_conversation_pack' }
    );
  });
});
```

---

## Manual UI Testing Checklist

### Setup
- [ ] Start Docker containers: `task docker-reload-env`
- [ ] Login as user on **Starter** plan
- [ ] Navigate to **Settings > Billing**

### Test Flow 1: Happy Path
- [ ] **Step 1:** Scroll to "Conversations" section
- [ ] **Step 2:** Verify button text is "Buy Conversation Packs" (plural)
- [ ] **Step 3:** Click the button
- [ ] **Step 4:** Modal opens with title "Select Conversation Pack"
- [ ] **Step 5:** Dropdown shows 3 options:
  - Extra 100 Conversations - $5.00
  - Extra 500 Conversations - $20.00
  - Extra 1,000 Conversations - $35.00
- [ ] **Step 6:** First pack (100) is pre-selected
- [ ] **Step 7:** Pack details show below dropdown (100 conversations, $5.00)
- [ ] **Step 8:** Click "Confirm Purchase"
- [ ] **Step 9:** Loading state appears (button disabled, loading spinner)
- [ ] **Step 10:** Success notification: "Conversation pack purchased successfully!"
- [ ] **Step 11:** Modal closes
- [ ] **Step 12:** Conversation limit increases by 100
- [ ] **Step 13:** Check Stripe dashboard - invoice created and paid

### Test Flow 2: Change Selection
- [ ] **Step 1:** Click "Buy Conversation Packs" button
- [ ] **Step 2:** Change dropdown to "Extra 500 Conversations"
- [ ] **Step 3:** Details update to show 500 conversations, $20.00
- [ ] **Step 4:** Change to "Extra 1,000 Conversations"
- [ ] **Step 5:** Details update to show 1,000 conversations, $35.00
- [ ] **Step 6:** Click "Confirm Purchase"
- [ ] **Step 7:** Purchase succeeds
- [ ] **Step 8:** Limit increases by 1,000

### Test Flow 3: Cancel Purchase
- [ ] **Step 1:** Click "Buy Conversation Packs" button
- [ ] **Step 2:** Modal opens
- [ ] **Step 3:** Select any pack
- [ ] **Step 4:** Click "Cancel"
- [ ] **Step 5:** Modal closes
- [ ] **Step 6:** No purchase occurs
- [ ] **Step 7:** Limits unchanged

### Test Flow 4: Ineligible Plan (Free Trial)
- [ ] **Step 1:** Switch account to Free Trial plan (Rails console)
- [ ] **Step 2:** Reload billing page
- [ ] **Step 3:** Verify "Buy Conversation Packs" button is **disabled** or **hidden**
- [ ] **Step 4:** Cannot purchase packs

### Test Flow 5: Enterprise Plan (Unlimited)
- [ ] **Step 1:** Switch account to Enterprise plan
- [ ] **Step 2:** Reload billing page
- [ ] **Step 3:** Conversations section shows "Unlimited"
- [ ] **Step 4:** Button is **disabled** (can't buy packs when unlimited)

### Test Flow 6: Error Handling
- [ ] **Step 1:** Disconnect internet
- [ ] **Step 2:** Click "Buy Conversation Packs" button
- [ ] **Step 3:** Try to purchase
- [ ] **Step 4:** Error notification: "Failed to purchase conversation pack. Please try again..."
- [ ] **Step 5:** Modal stays open (can retry)
- [ ] **Step 6:** Reconnect internet and retry
- [ ] **Step 7:** Purchase succeeds

---

## Quick Verification Script (Rails Console)

```ruby
# Open Rails console
task docker-rails-console

# Or if not using Docker:
bundle exec rails console

# === Test 1: Verify Pack Catalog ===
packs = BillingPlans.conversation_packs_catalog
puts "Packs available: #{packs.count}"
packs.each do |pack|
  puts "- #{pack['display_name']}: #{pack['size']} conversations"
end

# === Test 2: Check Plan Eligibility ===
puts "Starter eligible: #{BillingPlans.conversation_packs_available_for_plan?('starter')}"
puts "Professional eligible: #{BillingPlans.conversation_packs_available_for_plan?('professional')}"
puts "Free Trial eligible: #{BillingPlans.conversation_packs_available_for_plan?('free_trial')}"
puts "Enterprise eligible: #{BillingPlans.conversation_packs_available_for_plan?('enterprise')}"

# === Test 3: Test Purchase Service (without actually purchasing) ===
account = Account.find(1)
service = Billing::PurchaseConversationPackService.new(account, 'extra_100_conversation_pack')

# Check if pack found
if service.instance_variable_get(:@pack_config).present?
  puts "✅ Pack config found"
else
  puts "❌ Pack config NOT found"
end

# === Test 4: Verify Account Conversations ===
account = Account.find(1)
extra_conversations = account.custom_attributes&.dig('extra_conversations_purchased') || 0
puts "Extra conversations purchased: #{extra_conversations}"
```

---

## Summary

**Backend Tests:** 5 API endpoint tests (curl)  
**Frontend Tests:** 2 component test suites (Vitest)  
**Manual Tests:** 6 UI flows with 50+ checkpoints  
**Console Tests:** 4 verification scripts  

**Total Testing Time:** ~30-45 minutes for complete verification

**Key Validations:**
- ✅ Eligible plans see all packs
- ✅ Ineligible plans see nothing
- ✅ Pack selection works
- ✅ Purchase creates invoice
- ✅ Limits update correctly
- ✅ Error handling works
- ✅ Enterprise/Free Trial handled correctly

