# Pricing Table Implementation - Verification Guide

## Quick Test Commands

### 1. Backend Test (Run in Docker)
```bash
# Start Docker containers
docker compose up -d

# Run the test script
docker compose exec rails rails runner scripts/test_pricing_table.rb
```

**Expected Output:**
- All 5 tests should pass
- Should display 3 plans (Starter, Professional, Enterprise)
- Each plan should have monthly and yearly prices
- Plans should be in correct order

### 2. Manual API Test
```bash
# Get account ID from your test account
# Replace :account_id and :token with actual values

curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/v2/accounts/1/pricing
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "plans": [
      {
        "id": "prod_...",
        "plan_name": "starter",
        "name": "Starter plan",
        "description": "...",
        "image_url": "https://...",
        "prices": {
          "monthly": { "id": "price_...", "amount": 30000, "currency": "usd", "formatted": "$300" },
          "yearly": { "id": "price_...", "amount": 324000, "currency": "usd", "formatted": "$3,240" }
        },
        "features": ["5 members", "2 channels", ...]
      }
      // ... Professional and Enterprise
    ]
  }
}
```

### 3. Frontend Verification

#### Step 1: Start the Application
```bash
# Reload environment and start
task docker-reload-env

# Access at http://localhost:3000
```

#### Step 2: Navigate to Billing
1. Log in to your test account
2. Go to Settings → Billing
3. Scroll to the pricing table section

#### Step 3: Visual Checks
- [ ] Three pricing cards displayed (Starter, Professional, Enterprise)
- [ ] Product images visible
- [ ] Product names and descriptions correct
- [ ] Monthly/Yearly toggle visible at top
- [ ] Feature lists with checkmarks
- [ ] Prices formatted correctly (e.g., "$300" not "30000")

#### Step 4: Toggle Functionality
- [ ] Click "Yearly" → Prices update
- [ ] Click "Monthly" → Prices revert
- [ ] No console errors during toggle

#### Step 5: Button State Tests

**Test Scenario 1: No Subscription**
- Clear custom_attributes or use fresh account
- Expected: All three buttons show "Start trial" (blue)

**Test Scenario 2: Active Starter Plan**
- Set `plan_name: "starter"`, `subscription_status: "active"`
- Expected:
  - Starter → "Cancel" (grey)
  - Professional → "Upgrade" (blue)
  - Enterprise → "Upgrade" (blue)

**Test Scenario 3: Active Professional Plan**
- Set `plan_name: "professional"`, `subscription_status: "active"`
- Expected:
  - Starter → "Downgrade" (blue)
  - Professional → "Cancel" (grey)
  - Enterprise → "Upgrade" (blue)

**Test Scenario 4: Active Enterprise Plan**
- Set `plan_name: "enterprise"`, `subscription_status: "active"`
- Expected:
  - Starter → "Downgrade" (blue)
  - Professional → "Downgrade" (blue)
  - Enterprise → "Cancel" (grey)

**Test Scenario 5: Trial**
- Set `subscription_status: "trialing"`
- Expected: All buttons show "Upgrade" (blue)

#### Step 6: Button Click Tests
- [ ] "Start trial" → Redirects to Stripe Checkout
- [ ] "Upgrade" → Redirects to Stripe Checkout
- [ ] "Downgrade" → Redirects to Stripe Portal
- [ ] "Cancel" → Redirects to Stripe Portal

#### Step 7: Error Handling
- [ ] Stop Rails server → Pricing table shows loading, then no error
- [ ] Invalid plan name in metadata → Shows "Contact sales" button

---

## Troubleshooting

### Problem: No plans returned
**Solution:**
1. Check Stripe products have `plan_name` metadata set to "starter", "professional", or "enterprise"
2. Verify products are marked as "active" in Stripe
3. Check Stripe API keys are correct

### Problem: Missing prices
**Solution:**
1. Ensure each product has two active prices (monthly and yearly)
2. Check `recurring.interval` is set correctly ("month" or "year")
3. Verify prices are marked as "active"

### Problem: No features displayed
**Solution:**
1. Add `marketing_features` in Stripe Dashboard, OR
2. Add metadata: `bullet_1`, `bullet_2`, etc.

### Problem: Button shows wrong state
**Solution:**
1. Check `custom_attributes.plan_name` matches one of: "starter", "professional", "enterprise"
2. Verify `custom_attributes.subscription_status` is set correctly
3. Check browser console for error logs

### Problem: "Contact sales" shown unexpectedly
**Solution:**
- This is expected for invalid plan names
- Check console for error message indicating which plan name is invalid
- Fix the plan name in Stripe metadata or custom_attributes

---

## Manual Testing Checklist for All Scenarios

### Button States Matrix

| Current Plan | Starter Button | Professional Button | Enterprise Button |
|--------------|----------------|---------------------|-------------------|
| No plan | "Start trial" ✓ | "Start trial" ✓ | "Start trial" ✓ |
| Trial (any) | "Upgrade" ✓ | "Upgrade" ✓ | "Upgrade" ✓ |
| Active Starter | "Cancel" (grey) ✓ | "Upgrade" ✓ | "Upgrade" ✓ |
| Active Professional | "Downgrade" ✓ | "Cancel" (grey) ✓ | "Upgrade" ✓ |
| Active Enterprise | "Downgrade" ✓ | "Downgrade" ✓ | "Cancel" (grey) ✓ |

### Edge Cases

- [ ] **Past due subscription**: Same as active
- [ ] **Canceled subscription**: Same as active
- [ ] **Invalid target plan**: "Contact sales" (grey)
- [ ] **Invalid current plan**: "Start trial"
- [ ] **Missing monthly price**: Shows "Contact sales"
- [ ] **Missing yearly price**: Shows "Contact sales"
- [ ] **No image_url**: Card renders without image
- [ ] **Empty features array**: Shows "Contact sales"

---

## Next Steps (Not Yet Implemented)

### Step 7: Simple Tests (To Do)
- Backend RSpec test for `FetchPricingTableService`
- Backend controller spec for `PricingController`
- Simple frontend Vitest test for button logic

### Step 8: Caching & Webhooks (To Do)
- Add Rails cache to service
- Add cache invalidation on `product.updated` webhook
- Test cache expiration

---

## File Changes Summary

### Backend Files Created
1. `app/services/billing/fetch_pricing_table_service.rb`
2. `app/controllers/api/v2/accounts/pricing_controller.rb`

### Backend Files Modified
1. `config/routes.rb` - Added pricing route

### Frontend Files Created
1. `app/javascript/dashboard/routes/dashboard/settings/billing/components/PricingCard.vue`
2. `app/javascript/dashboard/routes/dashboard/settings/billing/components/PricingTable.vue`

### Frontend Files Modified
1. `app/javascript/dashboard/api/v2/billing.js` - Added `getPricingTable()`
2. `app/javascript/dashboard/routes/dashboard/settings/billing/Index.vue` - Integrated pricing table
3. `app/javascript/dashboard/i18n/locale/en/settings.json` - Added translations
4. `app/javascript/dashboard/i18n/locale/es/settings.json` - Added translations

### Test/Documentation Files Created
1. `scripts/test_pricing_table.rb` - Backend test script
2. `docs/ignore/PricingTableVerification.md` - This file

---

## Success Criteria

- ✅ Backend endpoint returns pricing data
- ✅ Frontend displays three pricing cards
- ✅ Monthly/yearly toggle works
- ✅ Button states are contextual and correct
- ✅ Button clicks trigger correct actions
- ✅ No console errors
- ✅ No linter errors
- ✅ Works on mobile/tablet/desktop
- ✅ Translations work for en/es

---

## Performance Notes

- Initial load fetches from Stripe API (may take 1-2 seconds)
- Caching not yet implemented (planned for Step 8)
- Consider implementing loading skeleton for better UX

---

## Security Notes

- API endpoint requires authentication (checked via `check_authorization`)
- Stripe API keys stored in environment variables
- No sensitive data exposed to frontend beyond public pricing info

