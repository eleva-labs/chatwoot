import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { SUBSCRIPTION_STATUSES } from 'dashboard/constants/subscriptionStatuses';

/**
 * Composable to check if account can purchase add-ons.
 * Unifies checks for both trial and past_due states.
 *
 * Usage:
 *   const { canPurchaseAddOns, isTrialing, isPastDue, blockReason, blockMessage } = useCanPurchaseAddOns();
 *
 * @returns {Object} Object containing:
 *   - canPurchaseAddOns: Boolean - true if add-ons can be purchased
 *   - isTrialing: Boolean - true if subscription is in trial
 *   - isPastDue: Boolean - true if subscription payment is past due
 *   - isCommunity: Boolean - true if on community plan
 *   - blockReason: String|null - 'trial', 'past_due', 'community', or null
 *   - blockMessage: String - User-friendly message explaining the block
 */
export function useCanPurchaseAddOns() {
  const { t } = useI18n();
  const { currentAccount } = useAccount();

  const subscriptionStatus = computed(
    () => currentAccount.value?.custom_attributes?.subscription_status || ''
  );

  const planName = computed(
    () => currentAccount.value?.custom_attributes?.plan_name || ''
  );

  const isTrialing = computed(
    () => subscriptionStatus.value === SUBSCRIPTION_STATUSES.TRIALING
  );

  const isPastDue = computed(
    () => subscriptionStatus.value === SUBSCRIPTION_STATUSES.PAST_DUE
  );

  const isCommunity = computed(() => planName.value === 'community');

  const canPurchaseAddOns = computed(
    () => !isTrialing.value && !isPastDue.value && !isCommunity.value
  );

  const blockReason = computed(() => {
    if (isTrialing.value) return 'trial';
    if (isPastDue.value) return 'past_due';
    if (isCommunity.value) return 'community';
    return null;
  });

  const blockMessage = computed(() => {
    if (isTrialing.value) {
      return t('BILLING_SETTINGS.ADD_ONS.TRIAL_BLOCK_MESSAGE');
    }
    if (isPastDue.value) {
      return t('BILLING_SETTINGS.ADD_ONS.PAST_DUE_BLOCK_MESSAGE');
    }
    if (isCommunity.value) {
      return t('BILLING_SETTINGS.ADD_ONS.COMMUNITY_BLOCK_MESSAGE');
    }
    return '';
  });

  return {
    canPurchaseAddOns,
    isTrialing,
    isPastDue,
    isCommunity,
    blockReason,
    blockMessage,
    subscriptionStatus,
    planName,
  };
}
