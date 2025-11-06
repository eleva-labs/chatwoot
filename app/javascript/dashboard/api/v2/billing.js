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
  createSubscription(planName = 'free') {
    return axios.post(`${this.url}subscription`, {
      subscription: { plan_name: planName },
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
  updateAddOn(addOnType, action, quantity = null) {
    const payload = {
      add_on_type: addOnType,
      action: action,
    };
    if (quantity !== null) {
      payload.quantity = quantity;
    }
    return axios.post(`${this.url}billing/add_ons`, payload);
  }

  // GET /api/v2/accounts/:account_id/billing/conversation_packs
  getConversationPacks() {
    return axios.get(`${this.url}billing/conversation_packs`);
  }

  // POST /api/v2/accounts/:account_id/billing/conversation_packs/purchase
  purchaseConversationPack() {
    return axios.post(`${this.url}billing/conversation_packs/purchase`);
  }

  // GET /api/v2/accounts/:account_id/pricing
  getPricingTable() {
    return axios.get(`${this.url}pricing`);
  }
}

export default new BillingAPI();
