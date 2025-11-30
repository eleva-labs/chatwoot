import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import AccountAPI from '../../api/account';
import { differenceInDays } from 'date-fns';
import EnterpriseAccountAPI from '../../api/enterprise/account';
import BillingAPI from '../../api/v2/billing';
import { throwErrorMessage } from '../utils/api';
import { getLanguageDirection } from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';

const findRecordById = ($state, id) =>
  $state.records.find(record => record.id === Number(id)) || {};

const DEFAULT_TRIAL_PERIOD_DAYS = 7;

const trialPeriodDaysForAccount = account =>
  account?.custom_attributes?.trial_expires_in_days ?? DEFAULT_TRIAL_PERIOD_DAYS;

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isUpdating: false,
    isCheckoutInProcess: false,
  },
};

export const getters = {
  getAccount: $state => id => {
    return findRecordById($state, id);
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  isRTL: ($state, _getters, rootState, rootGetters) => {
    const accountId = Number(rootState.route?.params?.accountId);
    const userLocale = rootGetters?.getUISettings?.locale;
    const accountLocale =
      accountId && findRecordById($state, accountId)?.locale;

    // Prefer user locale; fallback to account locale
    const effectiveLocale = userLocale ?? accountLocale;

    return effectiveLocale ? getLanguageDirection(effectiveLocale) : false;
  },
  isTrialAccount: $state => id => {
    const account = findRecordById($state, id);
    const createdAt = new Date(account.created_at);
    const diffDays = differenceInDays(new Date(), createdAt);
    const trialDays = trialPeriodDaysForAccount(account);

    return diffDays <= trialDays;
  },
  isFeatureEnabledonAccount: $state => (id, featureName) => {
    const { features = {} } = findRecordById($state, id);
    return features[featureName] || false;
  },
  isOnboardingCompleted: ($state, _getters, _rootState, rootGetters) => () => {
    const inboxes = rootGetters['inboxes/getInboxes'];
    return inboxes && inboxes.length > 0;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await AccountAPI.get();
      commit(types.default.ADD_ACCOUNT, response.data);
      commit(types.default.SET_ACCOUNT_UI_FLAG, {
        isFetchingItem: false,
      });
    } catch (error) {
      commit(types.default.SET_ACCOUNT_UI_FLAG, {
        isFetchingItem: false,
      });
    }
  },
  update: async ({ commit }, { options, ...updateObj }) => {
    if (options?.silent !== true) {
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: true });
    }

    try {
      const response = await AccountAPI.update('', updateObj);
      commit(types.default.EDIT_ACCOUNT, response.data);
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: false });
    } catch (error) {
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: false });
      throw new Error(error);
    }
  },
  delete: async ({ commit }, { id }) => {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: true });
    try {
      await AccountAPI.delete(id);
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: false });
    } catch (error) {
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: false });
      throw new Error(error);
    }
  },
  toggleDeletion: async (
    { commit },
    { action_type } = { action_type: 'delete' }
  ) => {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: true });
    try {
      await EnterpriseAccountAPI.toggleDeletion(action_type);
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: false });
    } catch (error) {
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdating: false });
      throw new Error(error);
    }
  },
  create: async ({ commit }, accountInfo) => {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isCreating: true });
    try {
      const response = await AccountAPI.createAccount(accountInfo);
      const account_id = response.data.data.account_id;
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isCreating: false });
      return account_id;
    } catch (error) {
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isCreating: false });
      throw error;
    }
  },

  checkout: async ({ commit }) => {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isCheckoutInProcess: true });
    try {
      const response = await BillingAPI.getBillingPortal();
      if (response.data.success && response.data.data.session_url) {
        window.location = response.data.data.session_url;
      } else {
        throw new Error(
          response.data.error || 'Failed to create billing portal session'
        );
      }
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isCheckoutInProcess: false });
    }
  },

  subscription: async ({ commit, getters: storeGetters }) => {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isCheckoutInProcess: true });
    try {
      const response = await BillingAPI.getSubscription();
      if (response.data.success) {
        // Update account attributes while preserving existing data including features
        const accountId = response.data.data.account_id;
        const existingAccount = storeGetters.getAccount(accountId);
        const updatedAccount = {
          ...existingAccount,
          custom_attributes: {
            ...existingAccount.custom_attributes,
            plan_name: response.data.data.plan_name,
            subscription_status: response.data.data.subscription_status,
            subscription_ends_on: response.data.data.subscription_ends_on,
            cancel_at: response.data.data.cancel_at,
            stripe_customer_id: response.data.data.customer_id,
            plan_limits: response.data.data.plan_limits,
            cancel_at_period_end: response.data.data.cancel_at_period_end,
            canceled_at: response.data.data.canceled_at,
            ended_at: response.data.data.ended_at,
          },
        };
        commit(types.default.EDIT_ACCOUNT, updatedAccount);
      }
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isCheckoutInProcess: false });
    }
  },

  createSubscription: async (
    { commit, getters: storeGetters },
    { planName = 'starter', billingInterval = 'monthly' } = {}
  ) => {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isCheckoutInProcess: true });
    try {
      const response = await BillingAPI.createSubscription(planName, billingInterval);

      if (response.data.success) {
        // If the backend sends a checkout URL, redirect the user immediately
        if (response.data.data.checkout_url) {
          window.location = response.data.data.checkout_url;
          return; // Stop execution to allow for redirect
        }

        // Otherwise, update the account data with the new subscription information while preserving existing data
        const accountId = response.data.data.account_id;
        const existingAccount = storeGetters.getAccount(accountId);
        const updatedAccount = {
          ...existingAccount,
          custom_attributes: {
            ...existingAccount.custom_attributes,
            plan_name: response.data.data.plan_name,
            subscription_status: response.data.data.subscription_status,
            stripe_customer_id: response.data.data.customer_id,
          },
        };
        commit(types.default.EDIT_ACCOUNT, updatedAccount);
        return;
      }
      throw new Error(response.data.error || 'Failed to create subscription');
    } catch (error) {
      throwErrorMessage(error);
      throw error; // Re-throw to be caught by the component
    } finally {
      commit(types.default.SET_ACCOUNT_UI_FLAG, { isCheckoutInProcess: false });
    }
  },

  limits: async ({ commit }) => {
    try {
      const response = await BillingAPI.getLimits();
      if (response.data.success) {
        commit(types.default.SET_ACCOUNT_LIMITS, response.data.data);
      }
    } catch (error) {
      // silent error
    }
  },

  fetchAddOns: async () => {
    try {
      const response = await BillingAPI.getAddOns();
      return response;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  fetchAddOnLimits: async () => {
    try {
      const response = await BillingAPI.getAddOnLimits();
      return response;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  fetchSubscriptionBreakdown: async () => {
    try {
      const response = await BillingAPI.getSubscriptionBreakdown();
      return response;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  purchaseAddOn: async (_, { add_on_type, action, quantity = null, skip_validation = false }) => {
    try {
      const response = await BillingAPI.updateAddOn(
        add_on_type,
        action,
        quantity,
        skip_validation
      );
      if (response.data.success) {
        return response;
      }
      throw new Error(response.data.error || 'Failed to purchase add-on');
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  previewAddOnRemoval: async (_, { add_on_type, action, quantity = null }) => {
    try {
      const response = await BillingAPI.previewAddOnRemoval(
        add_on_type,
        action,
        quantity
      );

      if (response.data.success) {
        return response;
      }

      throw new Error(response.data.error || 'Failed to preview removal');
    } catch (error) {
      // Do not show toast for preview failures; log for debugging instead
      // eslint-disable-next-line no-console
      console.error('Preview add-on removal failed:', error);
      throw error;
    }
  },

  previewAddOnPurchase: async (_, { add_on_type, action, quantity = null }) => {
    try {
      const response = await BillingAPI.previewAddOnPurchase(
        add_on_type,
        action,
        quantity
      );

      if (response.data.success) {
        return response;
      }

      throw new Error(response.data.error || 'Failed to preview purchase');
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Preview add-on purchase failed:', error);
      throw error;
    }
  },

  checkPaymentMethod: async () => {
    try {
      const response = await BillingAPI.checkPaymentMethod();
      return response;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  fetchConversationPacks: async () => {
    try {
      const response = await BillingAPI.getConversationPacks();
      return response;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  purchaseConversationPack: async (_context, { lookup_key }) => {
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

  fetchAiTokenCredits: async () => {
    try {
      const response = await BillingAPI.getAiTokenPacks();
      return response;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  checkAiTokenPaymentMethod: async () => {
    try {
      const response = await BillingAPI.checkAiTokenPaymentMethod();
      return response;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  purchaseAiTokenCredits: async (_context, { lookup_key }) => {
    try {
      const response = await BillingAPI.purchaseAiTokenCredits(lookup_key);
      if (response.data.success) {
        return response;
      }

      throw new Error(
        response.data.error || 'Failed to purchase AI token credits'
      );
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    }
  },

  getCacheKeys: async () => {
    return AccountAPI.getCacheKeys();
  },
};

export const mutations = {
  [types.default.SET_ACCOUNT_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.default.ADD_ACCOUNT]: MutationHelpers.setSingleRecord,
  [types.default.EDIT_ACCOUNT]: MutationHelpers.update,
  [types.default.SET_ACCOUNT_LIMITS]: MutationHelpers.updateAttributes,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
