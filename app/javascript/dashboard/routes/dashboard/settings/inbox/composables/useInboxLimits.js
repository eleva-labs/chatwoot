import { ref, computed, onMounted } from 'vue';

const sharedState = {
  limits: null,
  addOns: null,
  limitsFetchedAt: null,
  addOnsFetchedAt: null,
  error: null,
};

let limitsPromise = null;
let addOnsPromise = null;

/**
 * Composable for inbox/channel limit usage summary and pricing.
 * Reused across Billing > Inboxes card and Settings > Channels screens.
 *
 * @param {Object} store - Vuex store instance
 * @returns {Object} Usage state, pricing, and refresh helpers
 */
export function useInboxLimits(store) {
  const limits = ref(sharedState.limits ? { ...sharedState.limits } : {});
  const addOns = ref(sharedState.addOns ? { ...sharedState.addOns } : {});
  const isLoading = ref(false);
  const hasLoadedData = ref(
    typeof sharedState.limitsFetchedAt === 'number' &&
      sharedState.limitsFetchedAt > 0
  );
  const limitsError = ref(sharedState.error);

  const hasSuccessfulLimitsFetch = () =>
    typeof sharedState.limitsFetchedAt === 'number' &&
    sharedState.limitsFetchedAt > 0;

  const hasSuccessfulAddOnsFetch = () =>
    typeof sharedState.addOnsFetchedAt === 'number' &&
    sharedState.addOnsFetchedAt > 0;

  const syncFromCache = () => {
    limits.value = sharedState.limits ? { ...sharedState.limits } : {};
    addOns.value = sharedState.addOns ? { ...sharedState.addOns } : {};
    limitsError.value = sharedState.error;
    hasLoadedData.value = hasSuccessfulLimitsFetch();
  };

  const fetchLimitsInternal = async (force = false) => {
    if (!force && hasSuccessfulLimitsFetch()) {
      return sharedState.limits;
    }

    if (limitsPromise) {
      return limitsPromise;
    }

    limitsPromise = (async () => {
      try {
        const response = await store.dispatch('accounts/fetchAddOnLimits');
        if (response?.data?.data) {
          sharedState.limits = response.data.data.limits || {};
          sharedState.limitsFetchedAt = Date.now();
        }
        return sharedState.limits;
      } catch (error) {
        sharedState.error =
          error?.response?.data?.error || error?.message || 'UNKNOWN_ERROR';
        throw error;
      } finally {
        limitsPromise = null;
      }
    })();

    return limitsPromise;
  };

  const fetchAddOnsInternal = async (force = false) => {
    if (!force && hasSuccessfulAddOnsFetch()) {
      return sharedState.addOns;
    }

    if (addOnsPromise) {
      return addOnsPromise;
    }

    addOnsPromise = (async () => {
      try {
        const response = await store.dispatch('accounts/fetchAddOns');
        if (response?.data?.data) {
          sharedState.addOns = response.data.data.add_ons || {};
          sharedState.addOnsFetchedAt = Date.now();
        }
        return sharedState.addOns;
      } catch (error) {
        sharedState.error =
          error?.response?.data?.error || error?.message || 'UNKNOWN_ERROR';
        throw error;
      } finally {
        addOnsPromise = null;
      }
    })();

    return addOnsPromise;
  };

  const fetchData = async (force = false) => {
    if (!force && hasSuccessfulLimitsFetch() && hasSuccessfulAddOnsFetch()) {
      syncFromCache();
      return;
    }

    isLoading.value = true;
    try {
      await Promise.all([
        fetchLimitsInternal(force),
        fetchAddOnsInternal(force),
      ]);
      // Only clear error when both succeed
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
    await fetchAddOnsInternal(force);
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

  // Extra inboxes used (reuses exact formula from useAgentSeatLimits)
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
