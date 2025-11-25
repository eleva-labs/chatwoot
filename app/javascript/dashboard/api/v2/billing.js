/* global axios */
import ApiClient from '../ApiClient';

class BillingAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true, apiVersion: 'v2' });
  }

  // GET /api/v2/accounts/:account_id/subscription
  getSubscription() {
    return axios.get(`${this.url}subscription`);
  }

  // POST /api/v2/accounts/:account_id/subscription
  createSubscription(planName = 'free', billingInterval = 'monthly') {
    return axios.post(`${this.url}subscription`, {
      subscription: { plan_name: planName, billing_interval: billingInterval },
    });
  }

  // GET /api/v2/accounts/:account_id/subscription/portal
  getBillingPortal(returnUrl = null) {
    const params = returnUrl ? { return_url: returnUrl } : {};
    return axios.get(`${this.url}subscription/portal`, {
      params,
    });
  }

  // GET /api/v2/accounts/:account_id/subscription/limits
  getLimits() {
    return axios.get(`${this.url}subscription/limits`);
  }

  // GET /api/v2/accounts/:account_id/billing/add_ons
  getAddOns() {
    return axios.get(`${this.url}billing/add_ons`);
  }

  // GET /api/v2/accounts/:account_id/billing/add_ons/limits
  getAddOnLimits() {
    return axios.get(`${this.url}billing/add_ons/limits`);
  }

  // GET /api/v2/accounts/:account_id/billing/add_ons/breakdown
  getSubscriptionBreakdown() {
    return axios.get(`${this.url}billing/add_ons/breakdown`);
  }

  // POST /api/v2/accounts/:account_id/billing/add_ons
  updateAddOn(addOnType, action, quantity = null, skipValidation = false) {
    const payload = {
      add_on_type: addOnType,
      action: action,
    };
    if (quantity !== null) {
      payload.quantity = quantity;
    }
    if (skipValidation) {
      payload.skip_validation = true;
    }
    return axios.post(`${this.url}billing/add_ons`, payload);
  }

  // POST /api/v2/accounts/:account_id/billing/add_ons/preview
  previewAddOnRemoval(addOnType, action, quantity = null) {
    const payload = {
      add_on_type: addOnType,
      action,
    };

    if (quantity !== null) {
      payload.quantity = quantity;
    }

    return axios.post(`${this.url}billing/add_ons/preview`, payload);
  }

  // POST /api/v2/accounts/:account_id/billing/add_ons/preview_purchase
  previewAddOnPurchase(addOnType, action, quantity = null) {
    const payload = {
      add_on_type: addOnType,
      action,
    };

    if (quantity !== null) {
      payload.quantity = quantity;
    }

    return axios.post(`${this.url}billing/add_ons/preview_purchase`, payload);
  }

  // GET /api/v2/accounts/:account_id/billing/conversation_packs
  getConversationPacks() {
    return axios.get(`${this.url}billing/conversation_packs`);
  }

  // GET /api/v2/accounts/:account_id/billing/conversation_packs/check_payment_method
  checkPaymentMethod() {
    return axios.get(
      `${this.url}billing/conversation_packs/check_payment_method`
    );
  }

  // POST /api/v2/accounts/:account_id/billing/conversation_packs/purchase
  purchaseConversationPack(lookupKey) {
    return axios.post(`${this.url}billing/conversation_packs/purchase`, {
      lookup_key: lookupKey,
    });
  }

  // GET /api/v2/accounts/:account_id/pricing
  getPricingTable() {
    return axios.get(`${this.url}pricing`);
  }

  // GET /api/v2/accounts/:account_id/billing/ai_token_credits
  getAiTokenPacks() {
    return axios.get(`${this.url}billing/ai_token_credits`);
  }

  // GET /api/v2/accounts/:account_id/billing/ai_token_credits/check_payment_method
  checkAiTokenPaymentMethod() {
    return axios.get(
      `${this.url}billing/ai_token_credits/check_payment_method`
    );
  }

  // POST /api/v2/accounts/:account_id/billing/ai_token_credits/purchase
  purchaseAiTokenCredits(lookupKey) {
    return axios.post(`${this.url}billing/ai_token_credits/purchase`, {
      lookup_key: lookupKey,
    });
  }
}

export default new BillingAPI();
