<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue';
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
const scrollContainer = ref(null);
const scrollLeft = ref(0);
const scrollWidth = ref(0);
const clientWidth = ref(0);
let initTimeout = null;

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

const updateScrollState = () => {
  if (!scrollContainer.value) return;
  scrollLeft.value = scrollContainer.value.scrollLeft;
  scrollWidth.value = scrollContainer.value.scrollWidth;
  clientWidth.value = scrollContainer.value.clientWidth;
};

const canScrollLeft = computed(() => scrollLeft.value > 0);
const canScrollRight = computed(
  () => scrollLeft.value < scrollWidth.value - clientWidth.value - 1
);

const scrollTo = direction => {
  if (!scrollContainer.value) return;
  const scrollAmount = 300; // Scroll by card width + gap
  const targetScroll =
    direction === 'left'
      ? scrollContainer.value.scrollLeft - scrollAmount
      : scrollContainer.value.scrollLeft + scrollAmount;
  scrollContainer.value.scrollTo({
    left: targetScroll,
    behavior: 'smooth',
  });
};

onMounted(() => {
  fetchPricingData();
  // Update scroll state after plans load
  initTimeout = setTimeout(() => {
    updateScrollState();
    // Only add resize listener - scroll is already handled by @scroll in template
    if (scrollContainer.value) {
      window.addEventListener('resize', updateScrollState);
    }
  }, 100);
});

onUnmounted(() => {
  // Clear timeout if component unmounts before it executes
  if (initTimeout) {
    clearTimeout(initTimeout);
    initTimeout = null;
  }
  // Remove window resize event listener
  window.removeEventListener('resize', updateScrollState);
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
    <div v-else class="relative group">
      <!-- Left gradient fade with scroll indicator -->
      <div
        class="absolute left-0 top-0 bottom-2 w-16 bg-gradient-to-r from-n-background to-transparent pointer-events-none z-10 transition-opacity duration-300"
        :class="canScrollLeft ? 'opacity-100' : 'opacity-0'"
      >
        <!-- Left scroll button -->
        <button
          v-if="canScrollLeft"
          class="absolute left-2 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-n-solid-2 border border-n-weak shadow-lg flex items-center justify-center text-n-slate-11 hover:text-n-slate-12 hover:bg-n-solid-3 transition-all duration-200 pointer-events-auto"
          @click="scrollTo('left')"
        >
          <span class="i-lucide-chevron-left text-base" />
        </button>
      </div>
      <!-- Right gradient fade with scroll indicator -->
      <div
        class="absolute right-0 top-0 bottom-2 w-16 bg-gradient-to-l from-n-background to-transparent pointer-events-none z-10 transition-opacity duration-300"
        :class="canScrollRight ? 'opacity-100' : 'opacity-0'"
      >
        <!-- Right scroll button -->
        <button
          v-if="canScrollRight"
          class="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-n-solid-2 border border-n-weak shadow-lg flex items-center justify-center text-n-slate-11 hover:text-n-slate-12 hover:bg-n-solid-3 transition-all duration-200 pointer-events-auto"
          @click="scrollTo('right')"
        >
          <span class="i-lucide-chevron-right text-base" />
        </button>
      </div>
      <!-- Scroll progress indicator -->
      <div
        v-if="canScrollRight || canScrollLeft"
        class="absolute bottom-0 left-0 right-0 h-0.5 bg-n-weak z-10"
      >
        <div
          class="h-full bg-n-brand transition-all duration-200 ease-out"
          :style="{
            width: `${
              scrollWidth > clientWidth
                ? (clientWidth / scrollWidth) * 100
                : 100
            }%`,
            transform: `translateX(${
              scrollWidth > clientWidth
                ? (scrollLeft / (scrollWidth - clientWidth)) *
                  (100 - (clientWidth / scrollWidth) * 100)
                : 0
            }%)`,
          }"
        />
      </div>
      <!-- Scrollable container -->
      <div
        ref="scrollContainer"
        class="flex w-full max-w-full overflow-x-auto gap-6 pb-8 flex-nowrap scroll-smooth snap-x snap-mandatory"
        style="scrollbar-width: thin;"
        @scroll="updateScrollState"
      >
        <div
          v-for="(plan, index) in plans"
          :key="plan.id"
          class="flex-shrink-0 min-w-[280px] snap-start pricing-card"
          :style="{ animationDelay: `${index * 100}ms` }"
        >
          <PricingCard
            :plan="plan"
            :billing-interval="billingInterval"
            :current-plan-name="currentPlanName"
            :subscription-status="subscriptionStatus"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Custom scrollbar styling for pricing table */
.pricing-table .flex.overflow-x-auto::-webkit-scrollbar {
  height: 8px;
}

.pricing-table .flex.overflow-x-auto::-webkit-scrollbar-track {
  background: transparent;
  border-radius: 4px;
}

.pricing-table .flex.overflow-x-auto::-webkit-scrollbar-thumb {
  background: rgb(148 163 184 / 0.4);
  border-radius: 4px;
}

.pricing-table .flex.overflow-x-auto::-webkit-scrollbar-thumb:hover {
  background: rgb(148 163 184 / 0.6);
}

/* Staggered fade-in animation for cards */
.pricing-card {
  animation: fadeInUp 0.6s ease-out forwards;
  opacity: 0;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Card hover effect */
.pricing-card:hover {
  transform: translateY(-4px);
  transition: transform 0.3s ease-out;
}
</style>
