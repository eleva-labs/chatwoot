import { ref, computed, unref, watch } from 'vue';
import { useInboxLimits } from './useInboxLimits';
import { useAccount } from 'dashboard/composables/useAccount';

/**
 * Shared channel purchase flow helper.
 *
 * - Surfaces limit usage details (loading, error, remaining)
 * - Provides derived CTA label + warning copy when an extra purchase is required
 * - Executes the add-on purchase synchronously before creating the channel
 *
 * @param {Object} options
 * @param {Object} options.store - Vuex store instance
 * @param {import('vue').ComputedRef<string> | string} options.baseLabel - Default submit label
 * @param {Function} options.t - I18n translate function
 */
export function useChannelPurchaseManager({ store, baseLabel, t }) {
  const {
    isLoading: limitsLoading,
    hasLoadedData,
    limitsError,
    hasAvailableIncludedChannel,
    channelPriceLabel,
    fetchLimits,
  } = useInboxLimits(store);

  const isPurchasingExtraChannel = ref(false);
  const purchaseError = ref(null);
  const prorationAmount = ref(null);
  const isProrationLoading = ref(false);
  const hasFetchedProration = ref(false);

  const showUsageLoadingMessage = computed(
    () => !hasLoadedData.value && limitsLoading.value
  );

  const usageErrorMessage = computed(() => {
    if (!limitsError.value) {
      return '';
    }

    if (limitsError.value === 'UNKNOWN_ERROR') {
      return t('INBOX_MGMT.ADD.USAGE_ERROR');
    }

    return limitsError.value;
  });

  const shouldChargeForChannel = computed(() => {
    if (!hasLoadedData.value) {
      return false;
    }
    return !hasAvailableIncludedChannel.value;
  });

  const resolvedBaseLabel = computed(() => {
    const label = unref(baseLabel);
    return typeof label === 'string' ? label : '';
  });

  const prorationAmountDisplay = computed(() => {
    if (isProrationLoading.value) {
      return t('INBOX_MGMT.ADD.CALCULATING_PRORATION');
    }

    if (prorationAmount.value) {
      return prorationAmount.value;
    }

    return t('INBOX_MGMT.ADD.CALCULATING_PRORATION');
  });

  const primaryButtonLabel = computed(() => {
    const label = resolvedBaseLabel.value;
    if (showUsageLoadingMessage.value) {
      return label;
    }

    if (shouldChargeForChannel.value && channelPriceLabel.value) {
      return t('INBOX_MGMT.ADD.PRIMARY_BUY_LABEL', {
        price: channelPriceLabel.value,
      });
    }

    return label;
  });

  const isChannelInfoLoading = computed(
    () => limitsLoading.value || showUsageLoadingMessage.value
  );

  const { currentAccount } = useAccount();
  const planName = computed(
    () => currentAccount.value?.custom_attributes?.plan_name || 'free_trial'
  );
  const subscriptionStatus = computed(
    () => currentAccount.value?.custom_attributes?.subscription_status || ''
  );
  const isTrialing = computed(() => subscriptionStatus.value === 'trialing');
  const isTrialPlan = computed(
    () => planName.value === 'free_trial' || isTrialing.value
  );
  const trialRestrictionMessage = computed(() => {
    if (!isTrialPlan.value) {
      return '';
    }

    if (showUsageLoadingMessage.value || usageErrorMessage.value) {
      return '';
    }

    if (!shouldChargeForChannel.value) {
      return '';
    }

    return t('INBOX_MGMT.ADD.TRIAL_LIMIT_NOTE');
  });
  const isTrialLimitReached = computed(() => !!trialRestrictionMessage.value);

  const noteMessage = computed(() => {
    if (trialRestrictionMessage.value) {
      return trialRestrictionMessage.value;
    }

    if (showUsageLoadingMessage.value || usageErrorMessage.value) {
      return null;
    }
    if (shouldChargeForChannel.value) {
      return t('INBOX_MGMT.ADD.EXTRA_NOTE', {
        amount: prorationAmountDisplay.value,
      });
    }
    return null;
  });

  const fetchProrationPreview = async () => {
    if (isProrationLoading.value || hasFetchedProration.value) {
      return;
    }

    isProrationLoading.value = true;

    try {
      const response = await store.dispatch('accounts/previewAddOnPurchase', {
        add_on_type: 'inbox',
        action: 'add',
      });

      if (response?.data?.estimated_charge) {
        prorationAmount.value = response.data.estimated_charge;
        hasFetchedProration.value = true;
      } else {
        prorationAmount.value = null;
      }
    } catch (error) {
      prorationAmount.value = null;
    } finally {
      isProrationLoading.value = false;
    }
  };

  watch(
    [hasLoadedData, hasAvailableIncludedChannel, isTrialPlan],
    async ([loaded, hasAvailable, isTrial]) => {
      if (loaded && !hasAvailable) {
        if (!isTrial) {
          await fetchProrationPreview();
        } else {
          prorationAmount.value = null;
          hasFetchedProration.value = false;
        }
      } else if (hasAvailable) {
        prorationAmount.value = null;
        hasFetchedProration.value = false;
      }
    },
    { immediate: true }
  );

  const handleChannelCreation = async creationFn => {
    if (typeof creationFn !== 'function') {
      throw new Error('handleChannelCreation expects a function');
    }

    if (isTrialLimitReached.value) {
      throw new Error(trialRestrictionMessage.value);
    }

    if (!shouldChargeForChannel.value) {
      return creationFn();
    }

    isPurchasingExtraChannel.value = true;
    purchaseError.value = null;

    try {
      // Purchase the add-on
      await store.dispatch('accounts/purchaseAddOn', {
        add_on_type: 'inbox',
        action: 'add',
      });

      // Refresh limits - if this fails, log but don't block channel creation
      // The user has already been charged, so we must complete their intent
      try {
        await fetchLimits(true);
      } catch (refreshError) {
        // eslint-disable-next-line no-console
        console.warn('Failed to refresh limits after purchase:', refreshError);
        // Continue anyway - limits will sync on next page load
      }
    } catch (error) {
      // Only block if the purchase itself failed
      const errorMessage =
        error?.response?.data?.error ||
        error?.message ||
        t('INBOX_MGMT.ADD.PURCHASE_ERROR');

      purchaseError.value = errorMessage;
      throw new Error(errorMessage);
    } finally {
      isPurchasingExtraChannel.value = false;
    }

    return creationFn();
  };

  return {
    // Usage state
    limitsLoading,
    hasLoadedData,
    showUsageLoadingMessage,
    usageErrorMessage,

    // Purchase state
    isPurchasingExtraChannel,
    purchaseError,

    // UI helpers
    noteMessage,
    trialRestrictionMessage,
    isTrialLimitReached,
    primaryButtonLabel,
    isChannelInfoLoading,
    channelPriceLabel,

    // Methods
    handleChannelCreation,
  };
}

