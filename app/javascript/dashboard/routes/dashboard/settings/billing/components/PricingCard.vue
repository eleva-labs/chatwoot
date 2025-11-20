<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store.js';
import * as Sentry from '@sentry/vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  plan: {
    type: Object,
    required: true,
  },
  billingInterval: {
    type: String,
    required: true,
  },
  currentPlanName: {
    type: String,
    default: null,
  },
  subscriptionStatus: {
    type: String,
    default: null,
  },
});

const { t, locale } = useI18n();
const store = useStore();

// Plan hierarchy for comparison
const PLAN_HIERARCHY = {
  starter: 1,
};

/**
 * Calculate button configuration based on user's current plan
 */
const buttonConfig = computed(() => {
  const currentPlan = props.currentPlanName;
  const targetPlan = props.plan.plan_name;
  const status = props.subscriptionStatus;

  // Custom plan always shows "Get in Touch" regardless of current plan status
  if (targetPlan === 'custom') {
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.GET_IN_TOUCH'),
      action: 'contact',
      color: 'blue',
    };
  }

  // No plan or inactive -> Start trial
  if (!currentPlan || status === 'inactive') {
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.START_TRIAL'),
      action: 'trial',
      color: 'blue',
    };
  }

  // On trial -> Upgrade (start subscription)
  if (status === 'trialing') {
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.UPGRADE'),
      action: 'upgrade',
      color: 'blue',
    };
  }

  // Current plan (active, past_due, canceled, etc.)
  const currentTier = PLAN_HIERARCHY[currentPlan];
  const targetTier = PLAN_HIERARCHY[targetPlan];

  // Validate plan names exist in hierarchy
  if (currentTier === undefined || targetTier === undefined) {
    // Invalid plan name(s) - track error and return safe fallback
    Sentry.captureException(
      new Error(
        `Invalid plan name detected. Current: "${currentPlan}" (tier: ${currentTier}), ` +
          `Target: "${targetPlan}" (tier: ${targetTier})`
      ),
      {
        tags: { component: 'PricingCard', action: 'buttonConfig' },
        extra: { currentPlan, targetPlan, currentTier, targetTier },
      }
    );

    // If target plan is invalid, disable button or show contact support
    if (targetTier === undefined) {
      return {
        label: t('BILLING_SETTINGS.PRICING_TABLE.CONTACT_SALES'),
        action: 'contact',
        color: 'slate',
      };
    }

    // If current plan is invalid but target is valid, treat as new subscription
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.START_TRIAL'),
      action: 'trial',
      color: 'blue',
    };
  }

  if (currentTier === targetTier) {
    // Same plan -> Cancel
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.CANCEL'),
      action: 'cancel',
      color: 'slate',
    };
  }

  if (targetTier > currentTier) {
    // Higher tier -> Upgrade
    return {
      label: t('BILLING_SETTINGS.PRICING_TABLE.UPGRADE'),
      action: 'upgrade',
      color: 'blue',
    };
  }

  // Lower tier -> Downgrade
  return {
    label: t('BILLING_SETTINGS.PRICING_TABLE.DOWNGRADE'),
    action: 'downgrade',
    color: 'blue',
  };
});

/**
 * Selected price based on billing interval
 */
const selectedPrice = computed(() => {
  return props.plan.prices[props.billingInterval];
});

/**
 * Handle button click
 */
const handleButtonClick = async () => {
  const { action } = buttonConfig.value;

  if (action === 'trial' || action === 'upgrade') {
    // Create checkout session
    await store.dispatch('accounts/createSubscription', {
      planName: props.plan.plan_name,
    });
  } else if (action === 'downgrade' || action === 'cancel') {
    // Redirect to billing portal
    await store.dispatch('accounts/checkout');
  } else if (action === 'contact') {
    // Handle contact action - redirect to form based on plan and locale
    if (props.plan.plan_name === 'custom') {
      // Custom plan: redirect to language-specific contact form
      const formUrls = {
        en: 'https://forms.clickup.com/9013924102/f/8cmb486-5173/W29DO6NS9VUXETLKYQ',
        es: 'https://forms.clickup.com/9013924102/f/8cmb486-5193/BCKGPPMB966PE28WH2',
      };
      const currentLocale = locale.value || 'en';
      const formUrl = formUrls[currentLocale] || formUrls.en;
      window.open(formUrl, '_blank', 'noopener noreferrer');
    } else {
      // Invalid plan - track warning and do nothing
      // This prevents errors when target plan name is invalid
      Sentry.captureMessage('Invalid target plan, contact action triggered', {
        level: 'warning',
        tags: { component: 'PricingCard', action: 'handleButtonClick' },
        extra: { targetPlan: props.plan.plan_name },
      });
    }
  }
};
</script>

<template>
  <div
    class="rounded-xl border border-n-weak bg-n-solid-2 p-6 flex flex-col shadow-sm hover:shadow-md transition-shadow"
  >
    <!-- Plan Image -->
    <div v-if="plan.image_url" class="flex justify-center mb-6">
      <img
        :src="plan.image_url"
        :alt="plan.name"
        class="h-32 w-auto object-contain"
      />
    </div>

    <!-- Plan Title -->
    <h3 class="text-xl font-semibold text-n-slate-12 mb-2 text-center">
      {{ plan.name }}
    </h3>

    <!-- Plan Description -->
    <p class="text-sm text-n-slate-11 mb-6 text-center">
      {{ plan.description }}
    </p>

    <!-- Price -->
    <div class="mb-6 text-center">
      <div v-if="selectedPrice" class="text-4xl font-bold text-white">
        {{ selectedPrice.formatted }}
      </div>
      <div v-else class="text-2xl font-semibold text-n-slate-11">
        {{ t('BILLING_SETTINGS.PRICING_TABLE.CONTACT_SALES') }}
      </div>
      <div v-if="selectedPrice" class="text-sm text-n-slate-11 mt-1">
        <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
        {{
          t(
            `BILLING_SETTINGS.PRICING_TABLE.PER_${billingInterval.toUpperCase()}`
          )
        }}
      </div>
    </div>

    <!-- CTA Button -->
    <ButtonV4
      class="w-full mb-6"
      variant="solid"
      :color="buttonConfig.color"
      @click="handleButtonClick"
    >
      {{ buttonConfig.label }}
    </ButtonV4>

    <!-- Features List -->
    <div class="border-t border-n-weak pt-6">
      <p
        class="text-xs font-medium text-n-slate-11 uppercase tracking-wide mb-4"
      >
        {{ t('BILLING_SETTINGS.PRICING_TABLE.THIS_INCLUDES') }}
      </p>
      <ul v-if="plan.features && plan.features.length > 0" class="space-y-3">
        <li
          v-for="(feature, index) in plan.features"
          :key="index"
          class="flex items-start gap-3"
        >
          <div
            class="flex-shrink-0 w-5 h-5 rounded-full bg-green-500 flex items-center justify-center mt-0.5"
          >
            <span class="i-lucide-check text-white text-xs" />
          </div>
          <span class="text-sm text-n-slate-12">
            {{ feature }}
          </span>
        </li>
      </ul>
      <p v-else class="text-sm text-n-slate-11 text-center">
        {{ t('BILLING_SETTINGS.PRICING_TABLE.CONTACT_SALES') }}
      </p>
    </div>
  </div>
</template>
