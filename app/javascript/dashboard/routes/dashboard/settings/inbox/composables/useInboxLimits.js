import { ref, computed, onMounted } from 'vue';
import {
  getSharedState,
  hasSuccessfulLimitsFetch,
  hasSuccessfulAddOnsFetch,
  fetchLimitsInternal,
  fetchAddOnsInternal,
} from 'dashboard/composables/billingDataCache';

/**
 * Composable for inbox/channel limit usage summary and pricing.
 * Uses the shared billing cache to avoid duplicate API requests.
 *
 * @param {Object} store - Vuex store instance
 * @returns {Object} Usage state, pricing, and refresh helpers
 */
export function useInboxLimits(store) {
  const sharedState = getSharedState();

  const limits = ref(sharedState.limits ? { ...sharedState.limits } : {});
  const addOns = ref(sharedState.addOns ? { ...sharedState.addOns } : {});
  const isLoading = ref(false);
  const hasLoadedData = ref(hasSuccessfulLimitsFetch());
  const limitsError = ref(sharedState.error);

  const syncFromCache = () => {
    limits.value = sharedState.limits ? { ...sharedState.limits } : {};
    addOns.value = sharedState.addOns ? { ...sharedState.addOns } : {};
    limitsError.value = sharedState.error;
    hasLoadedData.value = hasSuccessfulLimitsFetch();
  };

  const fetchData = async (force = false) => {
    if (!force && hasSuccessfulLimitsFetch() && hasSuccessfulAddOnsFetch()) {
      syncFromCache();
      return;
    }

    isLoading.value = true;
    try {
      await Promise.all([
        fetchLimitsInternal(store, force),
        fetchAddOnsInternal(store, force),
      ]);
      sharedState.error = null;
    } catch (error) {
      limitsError.value = sharedState.error;
      throw error;
    } finally {
      syncFromCache();
      isLoading.value = false;
    }
  };

  const fetchLimits = async (force = false) => {
    await fetchData(force);
  };

  const fetchAddOns = async (force = false) => {
    await fetchAddOnsInternal(store, force);
    syncFromCache();
  };

  const inboxLimits = computed(() => limits.value?.inbox || {});

  const includedLimit = computed(() => inboxLimits.value.base_limit || 0);
  const currentUsage = computed(() => inboxLimits.value.current || 0);
  const totalAllowed = computed(() => inboxLimits.value.total_allowed || 0);
  const extraInboxesPurchased = computed(
    () => inboxLimits.value.purchased || 0
  );

  const includedUsage = computed(() => {
    const current = currentUsage.value;
    const included = includedLimit.value;
    return Math.min(current, included);
  });

  // Extra inboxes used
  const extraInboxesUsed = computed(() => {
    const current = currentUsage.value;
    const included = includedLimit.value;
    const purchased = extraInboxesPurchased.value;

    const rawUsed = current - included;
    return Math.max(0, Math.min(rawUsed, purchased));
  });

  const hasAvailableIncludedChannel = computed(
    () => currentUsage.value < includedLimit.value
  );

  const remainingChannels = computed(() => {
    const remaining = totalAllowed.value - currentUsage.value;
    return Math.max(0, remaining);
  });

  const channelAddOn = computed(() => addOns.value.inbox || {});
  const channelPriceLabel = computed(
    () => channelAddOn.value.unit_price_formatted || ''
  );

  onMounted(() => {
    fetchData().catch(() => {
      syncFromCache();
    });
  });

  return {
    // State
    isLoading,
    hasLoadedData,
    limitsError,
    limits,
    addOns,

    // Computed
    includedLimit,
    includedUsage,
    extraInboxesPurchased,
    extraInboxesUsed,
    currentUsage,
    totalAllowed,
    remainingChannels,
    hasAvailableIncludedChannel,
    channelPriceLabel,
    channelAddOn,

    // Methods
    fetchLimits,
    fetchAddOns,
    fetchData,
  };
}
