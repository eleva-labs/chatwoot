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
 * Composable for managing agent seat limits and add-on data
 * Reuses the same calculations as BillingLimitsCard.vue to ensure consistency
 *
 * @param {Object} store - Vuex store instance
 * @returns {Object} Computed properties and methods for agent seat management
 */
export function useAgentSeatLimits(store) {
  const limits = ref(sharedState.limits || {});
  const addOns = ref(sharedState.addOns || {});
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
          sharedState.error = null;
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
    if (!force && sharedState.addOnsFetchedAt) {
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
      } finally {
        addOnsPromise = null;
      }
    })();

    return addOnsPromise;
  };

  // Fetch limits from API
  const fetchLimits = async (force = false) => {
    if (!force && sharedState.limitsFetchedAt) {
      syncFromCache();
      return;
    }

    isLoading.value = true;
    try {
      await fetchLimitsInternal(force);
    } catch (error) {
      limitsError.value = sharedState.error;
      throw error;
    } finally {
      syncFromCache();
      isLoading.value = false;
    }
  };

  // Fetch add-ons (pricing info) from API
  const fetchAddOns = async (force = false) => {
    if (!force && sharedState.addOnsFetchedAt) {
      syncFromCache();
      return;
    }

    isLoading.value = true;
    try {
      await fetchAddOnsInternal(force);
    } finally {
      syncFromCache();
      isLoading.value = false;
    }
  };

  // Fetch both limits and add-ons
  const fetchData = async (force = false) => {
    if (!force && hasSuccessfulLimitsFetch() && hasSuccessfulAddOnsFetch()) {
      syncFromCache();
      return;
    }

    isLoading.value = true;
    try {
      await fetchLimitsInternal(force);
      await fetchAddOnsInternal(force);
      sharedState.error = null;
    } catch (error) {
      limitsError.value = sharedState.error;
      throw error;
    } finally {
      syncFromCache();
      isLoading.value = false;
    }
  };

  // Agent limit data
  const agentLimit = computed(() => limits.value.agent || {});

  // Agent add-on pricing data
  const agentAddOn = computed(() => addOns.value.agent || {});

  // Included limit (base plan seats)
  const includedLimit = computed(() => agentLimit.value.base_limit || 0);

  // Included usage (current agents using included seats)
  const includedUsage = computed(() => {
    const current = agentLimit.value.current || 0;
    const included = includedLimit.value;
    return Math.min(current, included);
  });

  // Extra seats purchased
  const extraSeatsPurchased = computed(() => agentLimit.value.purchased || 0);

  // Extra seats used (reuses exact formula from BillingLimitsCard.vue)
  const extraSeatsUsed = computed(() => {
    const current = agentLimit.value.current || 0;
    const included = includedLimit.value;
    const purchased = extraSeatsPurchased.value;

    const rawUsed = current - included;
    return Math.max(0, Math.min(rawUsed, purchased));
  });

  // Extra seats unused
  const extraSeatsUnused = computed(() => {
    return extraSeatsPurchased.value - extraSeatsUsed.value;
  });

  // Check if there's an available included seat
  const hasAvailableIncludedSeat = computed(() => {
    const current = agentLimit.value.current || 0;
    const included = includedLimit.value;
    return current < included;
  });

  // Total allowed agents
  const totalAllowed = computed(() => agentLimit.value.total_allowed || 0);

  // Current agent count
  const currentAgents = computed(() => agentLimit.value.current || 0);

  // Remaining seats (included + extra)
  const remainingSeats = computed(() => {
    return Math.max(0, totalAllowed.value - currentAgents.value);
  });

  // Agent price label (formatted)
  const agentPriceLabel = computed(() => {
    return agentAddOn.value.unit_price_formatted || '';
  });

  // Initialize on mount
  onMounted(() => {
    fetchData().catch(() => {
      // Error already captured in sharedState; ensure local refs are synced
      syncFromCache();
    });
  });

  return {
    // State
    isLoading,
    limits,
    addOns,
    hasLoadedData,

    // Computed properties
    agentLimit,
    agentAddOn,
    includedLimit,
    includedUsage,
    extraSeatsPurchased,
    extraSeatsUsed,
    extraSeatsUnused,
    hasAvailableIncludedSeat,
    totalAllowed,
    currentAgents,
    remainingSeats,
    agentPriceLabel,
    limitsError,

    // Methods
    fetchData,
    fetchLimits,
    fetchAddOns,
  };
}
