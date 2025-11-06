<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import * as Sentry from '@sentry/vue';
import BillingAPI from 'dashboard/api/v2/billing.js';
import PricingCard from './PricingCard.vue';

defineProps({
  currentPlanName: {
    type: String,
    default: null,
  },
  subscriptionStatus: {
    type: String,
    default: null,
  },
});

const { t } = useI18n();
const plans = ref([]);
const isLoading = ref(true);
const billingInterval = ref('monthly'); // 'monthly' or 'yearly'

const fetchPricingData = async () => {
  isLoading.value = true;
  try {
    const response = await BillingAPI.getPricingTable();
    if (response.data.success) {
      plans.value = response.data.data.plans;
    }
  } catch (error) {
    Sentry.captureException(error, {
      tags: { component: 'PricingTable', action: 'fetchPricingData' },
    });
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchPricingData();
});
</script>

<template>
  <div class="pricing-table">
    <!-- Billing Interval Toggle -->
    <div class="flex justify-center mb-8">
      <div class="inline-flex rounded-lg bg-n-solid-3 p-1">
        <button
          class="px-6 py-2 rounded-md text-sm font-medium transition-colors"
          :class="
            billingInterval === 'monthly'
              ? 'bg-n-brand text-white'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="billingInterval = 'monthly'"
        >
          {{ t('BILLING_SETTINGS.PRICING_TABLE.MONTHLY') }}
        </button>
        <button
          class="px-6 py-2 rounded-md text-sm font-medium transition-colors"
          :class="
            billingInterval === 'yearly'
              ? 'bg-n-brand text-white'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="billingInterval = 'yearly'"
        >
          {{ t('BILLING_SETTINGS.PRICING_TABLE.YEARLY') }}
        </button>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center py-16">
      <span class="text-sm text-n-slate-11">
        {{ t('BILLING_SETTINGS.PRICING_TABLE.LOADING') }}
      </span>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="!plans || plans.length === 0"
      class="text-center py-16 text-sm text-n-slate-11"
    >
      {{ t('BILLING_SETTINGS.PRICING_TABLE.NO_PLANS') }}
    </div>

    <!-- Pricing Cards Grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <PricingCard
        v-for="plan in plans"
        :key="plan.id"
        :plan="plan"
        :billing-interval="billingInterval"
        :current-plan-name="currentPlanName"
        :subscription-status="subscriptionStatus"
      />
    </div>
  </div>
</template>
