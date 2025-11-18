<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import BillingCard from './BillingCard.vue';

const { t } = useI18n();
const store = useStore();

const breakdown = ref(null);
const isLoading = ref(true);

const fetchBreakdown = async () => {
  try {
    isLoading.value = true;
    const response = await store.dispatch(
      'accounts/fetchSubscriptionBreakdown'
    );
    if (response?.data?.data) {
      breakdown.value = response.data.data;
    }
  } catch (error) {
    // Error handling - silent fail
  } finally {
    isLoading.value = false;
  }
};

const hasActivePlan = computed(() => {
  // Check if there's actual plan data to display
  // A plan is considered "active" if:
  // 1. base_plan exists AND
  // 2. It has inclusions (means it's a real plan, not just an empty placeholder)
  return (
    breakdown.value?.base_plan !== null &&
    breakdown.value?.base_plan?.inclusions?.length > 0
  );
});

const hasAddOns = computed(() => {
  return breakdown.value?.add_ons?.length > 0;
});

const formattedNextBillingDate = computed(() => {
  if (!breakdown.value?.next_billing_date) return null;

  const date = new Date(breakdown.value.next_billing_date * 1000);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
});

const isFreeOrTrial = computed(() => {
  return breakdown.value?.total?.amount_cents === 0;
});

const billingDateLabel = computed(() => {
  // Don't show "Trial ends" if there's a valid billing date (active subscription)
  // Always show "Next billing" when there's a valid billing date
  if (breakdown.value?.next_billing_date) {
    return t('BILLING_SETTINGS.SUBSCRIPTION.NEXT_BILLING');
  }
  // Only show "Trial ends" if truly in trial with no billing date
  if (isFreeOrTrial.value) {
    return t('BILLING_SETTINGS.SUBSCRIPTION.TRIAL_ENDS');
  }
  return t('BILLING_SETTINGS.SUBSCRIPTION.NEXT_BILLING');
});

const hasCredits = computed(() => {
  return (
    breakdown.value?.credits_applied?.amount_cents > 0 &&
    breakdown.value?.total_before_credits
  );
});

onMounted(() => {
  fetchBreakdown();
});
</script>

<template>
  <BillingCard
    :title="t('BILLING_SETTINGS.SUBSCRIPTION.TITLE')"
    :description="t('BILLING_SETTINGS.SUBSCRIPTION.DESCRIPTION')"
  >
    <div v-if="isLoading" class="flex items-center justify-center py-8">
      <span class="text-sm text-n-light">{{
        t('BILLING_SETTINGS.SUBSCRIPTION.LOADING')
      }}</span>
    </div>

    <div
      v-else-if="!hasActivePlan"
      class="text-center py-8 text-sm text-n-slate-11"
    >
      {{ t('BILLING_SETTINGS.SUBSCRIPTION.NO_ACTIVE_PLAN') }}
    </div>

    <div v-else class="space-y-6 px-4">
      <!-- Base Plan Section -->
      <div class="rounded-lg border border-n-weak bg-n-solid-2 p-4 shadow-sm">
        <!-- Plan Header -->
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-base font-semibold text-n-slate-12">
            {{ breakdown.base_plan.name }}
          </h4>
          <div
            class="px-3 py-1.5 rounded-md font-semibold text-sm bg-n-slate-3 text-n-slate-12"
          >
            {{ breakdown.base_plan.price_formatted }}
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            <span class="text-xs font-normal text-n-slate-11">
              /{{ breakdown.base_plan.interval }}
            </span>
          </div>
        </div>

        <!-- Plan Inclusions -->
        <div
          v-if="breakdown.base_plan.inclusions?.length"
          class="space-y-2 pt-2 border-t border-n-weak"
        >
          <p
            class="text-xs font-medium text-n-slate-11 uppercase tracking-wide"
          >
            {{ t('BILLING_SETTINGS.SUBSCRIPTION.INCLUDES') }}
          </p>
          <div class="grid gap-2">
            <div
              v-for="(inclusion, index) in breakdown.base_plan.inclusions"
              :key="index"
              class="flex items-start text-sm text-n-slate-11"
            >
              <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
              <span class="text-n-teal-9 mr-2 mt-0.5">✓</span>
              <span>{{ inclusion }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Add-ons Section -->
      <div
        v-if="hasAddOns"
        class="rounded-lg border border-n-weak bg-n-solid-2 p-4 shadow-sm"
      >
        <h5 class="text-sm font-semibold text-n-slate-12 mb-3">
          {{ t('BILLING_SETTINGS.SUBSCRIPTION.ADD_ONS_LABEL') }}
        </h5>
        <div class="space-y-3">
          <div
            v-for="addOn in breakdown.add_ons"
            :key="addOn.type"
            class="flex items-center justify-between py-2 border-b border-n-weak last:border-0"
          >
            <div class="flex flex-col">
              <span class="text-sm font-medium text-n-slate-12">
                {{ addOn.name }}
              </span>
              <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
              <span class="text-xs text-n-slate-11">
                Quantity: {{ addOn.quantity }}
              </span>
            </div>
            <span class="font-semibold text-sm text-n-slate-12">
              {{ addOn.total_price_formatted }}
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
              <span class="text-xs font-normal text-n-slate-11 ml-0.5">
                /{{ addOn.interval }}
              </span>
            </span>
          </div>
        </div>
      </div>

      <!-- Total Summary -->
      <div
        class="rounded-lg border-2 border-n-slate-6 bg-n-slate-2 p-4 shadow-sm"
      >
        <!-- Total before credits (if credits are applied) -->
        <div
          v-if="hasCredits"
          class="flex items-center justify-between pb-2 mb-2 border-b border-n-slate-5"
        >
          <span class="text-sm text-n-slate-11">
            {{ t('BILLING_SETTINGS.SUBSCRIPTION.TOTAL_BEFORE_CREDITS') }}
          </span>
          <span class="text-sm font-medium text-n-slate-12">
            {{ breakdown.total_before_credits.amount_formatted }}
          </span>
        </div>

        <!-- Applied credits line (if credits are applied) -->
        <div
          v-if="hasCredits"
          class="flex items-center justify-between pb-2 mb-2 border-b border-n-slate-5"
        >
          <span class="text-sm text-n-slate-11">
            {{ t('BILLING_SETTINGS.SUBSCRIPTION.APPLIED_CREDITS') }}
          </span>
          <span class="text-sm font-medium text-n-teal-9">
            -{{ breakdown.credits_applied.amount_formatted }}
          </span>
        </div>

        <!-- Total (Next billing) -->
        <div class="flex items-center justify-between">
          <h4 class="text-base font-semibold text-n-slate-12">
            {{ t('BILLING_SETTINGS.SUBSCRIPTION.TOTAL_LABEL') }}
          </h4>
          <span class="text-xl font-bold text-n-slate-12">
            {{ breakdown.total.amount_formatted }}
          </span>
        </div>

        <!-- Next Billing Date / Trial End Date -->
        <div
          v-if="formattedNextBillingDate"
          class="text-center text-sm text-n-slate-11 pt-3 mt-3 border-t border-n-slate-5"
        >
          <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
          {{ billingDateLabel }}:
          <span class="font-medium text-n-slate-12">
            {{ formattedNextBillingDate }}
          </span>
        </div>
      </div>
    </div>
  </BillingCard>
</template>
