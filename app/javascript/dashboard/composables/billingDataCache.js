/**
 * Singleton billing data cache shared across all billing composables.
 *
 * Both useAgentSeatLimits and useInboxLimits fetch the same endpoints
 * (fetchAddOnLimits + fetchAddOns). This module ensures they share a
 * single in-memory cache and dedup concurrent requests.
 */

const sharedState = {
  limits: null,
  addOns: null,
  limitsFetchedAt: null,
  addOnsFetchedAt: null,
  error: null,
};

let limitsPromise = null;
let addOnsPromise = null;

export function getSharedState() {
  return sharedState;
}

export function hasSuccessfulLimitsFetch() {
  return (
    typeof sharedState.limitsFetchedAt === 'number' &&
    sharedState.limitsFetchedAt > 0
  );
}

export function hasSuccessfulAddOnsFetch() {
  return (
    typeof sharedState.addOnsFetchedAt === 'number' &&
    sharedState.addOnsFetchedAt > 0
  );
}

export async function fetchLimitsInternal(store, force = false) {
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
}

export async function fetchAddOnsInternal(store, force = false) {
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
}
