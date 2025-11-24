<script setup>
import Banner from 'dashboard/components/ui/Banner.vue';
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useI18n } from 'vue-i18n';

const { currentAccount } = useAccount();
const { t } = useI18n();

const balanceStatus = computed(
  () => currentAccount.value?.custom_attributes?.ai_token_balance_status
);

const impactedCount = computed(
  () => currentAccount.value?.custom_attributes?.ai_token_impacted_conversations_count || 0
);

const shouldShowBanner = computed(() =>
  ['insufficient_tokens', 'low_balance'].includes(balanceStatus.value)
);

const bannerMessage = computed(() => {
  if (balanceStatus.value === 'insufficient_tokens') {
    const count = impactedCount.value;
    if (count > 0) {
      return t('BILLING_SETTINGS.LIMITS.AI_TOKENS.INSUFFICIENT_TOKEN_BANNER_WITH_COUNT', {
        count
      });
    }
    return t('BILLING_SETTINGS.LIMITS.AI_TOKENS.INSUFFICIENT_TOKEN_BANNER');
  }

  if (balanceStatus.value === 'low_balance') {
    return t('BILLING_SETTINGS.LIMITS.AI_TOKENS.LOW_BALANCE_BANNER');
  }

  return '';
});

const colorScheme = computed(() =>
  balanceStatus.value === 'insufficient_tokens' ? 'alert' : 'warning'
);
</script>

<template>
  <Banner
    v-if="shouldShowBanner"
    :banner-message="bannerMessage"
    :color-scheme="colorScheme"
  />
</template>

