<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import * as Sentry from '@sentry/vue';
import BillingCard from './BillingCard.vue';
import ButtonV4 from 'next/button/Button.vue';

const { t } = useI18n();
const store = useStore();

// ============================================================================
// STATE MANAGEMENT
// ============================================================================

/**
 * Raw add-ons response from backend
 * Structure: { capacity_add_ons: {...}, training_services: {...} }
 */
const addOnsData = ref(null);

/**
 * Loading state for initial data fetch
 */
const isLoading = ref(true);

/**
 * Track purchase loading state per training type
 * Example: { live_training: false, live_1_1_training: false }
 */
const isPurchasing = ref({});

// ============================================================================
// DATA FETCHING
// ============================================================================

/**
 * Fetch training services from backend via Vuex store
 * Calls the existing fetchAddOns() action which returns both
 * capacity_add_ons and training_services in response.data.data
 */
const fetchTrainingAddOns = async () => {
  try {
    isLoading.value = true;
    const response = await store.dispatch('accounts/fetchAddOns');

    // Backend returns: { capacity_add_ons: {...}, training_services: {...} }
    if (response?.data?.data) {
      addOnsData.value = response.data.data;
    }
  } catch (error) {
    Sentry.captureException(error, {
      tags: { component: 'BillingTrainingCard', action: 'fetchTrainingAddOns' },
    });
    // Silent fail - component will show empty state
  } finally {
    isLoading.value = false;
  }
};

// ============================================================================
// COMPUTED PROPERTIES
// ============================================================================

/**
 * Extract training_services from the response
 * Returns object with training types as keys
 * Example: { live_training: {...}, live_1_1_training: {...} }
 */
const trainingServices = computed(() => {
  return addOnsData.value?.training_services || {};
});

/**
 * Convert training_services object into array for iteration
 * Adds the 'type' key to each service for template usage
 */
const trainingServicesArray = computed(() => {
  return Object.entries(trainingServices.value).map(([type, service]) => ({
    type,
    ...service,
  }));
});

/**
 * Check if there are any training services to display
 */
const hasTrainingServices = computed(() => {
  return trainingServicesArray.value.length > 0;
});

// ============================================================================
// PURCHASE HANDLING
// ============================================================================

/**
 * Purchase a training add-on
 * @param {string} trainingType - The training type (e.g., 'live_training')
 */
const purchaseTraining = async trainingType => {
  try {
    isPurchasing.value[trainingType] = true;

    // Call existing purchaseAddOn action with training type
    const response = await store.dispatch('accounts/purchaseAddOn', {
      add_on_type: trainingType,
      action: 'add',
      quantity: 1,
    });

    // Verify success before refreshing
    if (response?.data?.success) {
      // Refresh training add-ons to reflect new ownership
      await fetchTrainingAddOns();
      useAlert(t('BILLING_SETTINGS.TRAINING.PURCHASE_SUCCESS'));
    } else {
      throw new Error('Purchase failed - no success flag in response');
    }
  } catch (error) {
    Sentry.captureException(error, {
      tags: {
        component: 'BillingTrainingCard',
        action: 'purchaseTraining',
        trainingType,
      },
    });
    useAlert(t('BILLING_SETTINGS.TRAINING.PURCHASE_ERROR'));
  } finally {
    isPurchasing.value[trainingType] = false;
  }
};

/**
 * Check if a specific training type is currently being purchased
 * @param {string} trainingType - The training type to check
 */
const isTrainingPurchasing = trainingType => {
  return isPurchasing.value[trainingType] || false;
};

// ============================================================================
// LIFECYCLE HOOKS
// ============================================================================

onMounted(() => {
  fetchTrainingAddOns();
});
</script>

<template>
  <BillingCard
    :title="t('BILLING_SETTINGS.TRAINING.TITLE')"
    :description="t('BILLING_SETTINGS.TRAINING.DESCRIPTION')"
  >
    <!-- ========================================================================
         LOADING STATE
         ======================================================================== -->
    <div v-if="isLoading" class="flex items-center justify-center py-8">
      <span class="text-sm text-n-slate-11">
        {{ t('BILLING_SETTINGS.TRAINING.LOADING') }}
      </span>
    </div>

    <!-- ========================================================================
         EMPTY STATE
         ======================================================================== -->
    <div
      v-else-if="!hasTrainingServices"
      class="text-center py-8 text-sm text-n-slate-11"
    >
      {{ t('BILLING_SETTINGS.TRAINING.NO_SERVICES') }}
    </div>

    <!-- ========================================================================
         TRAINING SERVICES GRID
         ======================================================================== -->
    <div v-else class="space-y-6 px-4">
      <div
        v-for="service in trainingServicesArray"
        :key="service.type"
        class="rounded-lg border border-n-weak bg-n-solid-2 p-5 shadow-sm"
      >
        <!-- ====================================================================
             SERVICE HEADER (Name + Price)
             ==================================================================== -->
        <div class="flex items-start justify-between mb-4">
          <div class="flex-1">
            <h4 class="text-base font-semibold text-n-slate-12">
              {{ service.display_name }}
            </h4>
            <p v-if="service.description" class="text-sm text-n-slate-11 mt-1">
              {{ service.description }}
            </p>
          </div>

          <div
            class="px-3 py-1.5 rounded-md font-semibold text-sm bg-n-slate-3 text-n-slate-12 ml-4 shrink-0"
          >
            {{ service.unit_price_formatted }}
            <span
              v-if="service.interval"
              class="text-xs font-normal text-n-slate-11"
            >
              {{ t('BILLING_SETTINGS.TRAINING.INTERVAL_SEPARATOR')
              }}{{ service.interval }}
            </span>
          </div>
        </div>

        <!-- ====================================================================
             FEATURE BULLETS
             ==================================================================== -->
        <div
          v-if="service.feature_bullets?.length"
          class="space-y-2 pt-3 border-t border-n-weak mb-4"
        >
          <div class="grid gap-2">
            <div
              v-for="(bullet, index) in service.feature_bullets"
              :key="index"
              class="flex items-start text-sm text-n-slate-11"
            >
              <span class="text-n-teal-9 mr-2 mt-0.5 shrink-0">{{
                t('BILLING_SETTINGS.TRAINING.CHECK_MARK')
              }}</span>
              <span>{{ bullet }}</span>
            </div>
          </div>
        </div>

        <!-- ====================================================================
             PURCHASE BUTTON / OWNERSHIP STATUS
             ==================================================================== -->
        <div
          class="flex items-center justify-between pt-3 border-t border-n-weak"
        >
          <!-- Already Owned Status -->
          <div v-if="service.is_owned" class="flex items-center">
            <span class="text-n-teal-9 mr-2">{{
              t('BILLING_SETTINGS.TRAINING.CHECK_MARK')
            }}</span>
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('BILLING_SETTINGS.TRAINING.ALREADY_PURCHASED') }}
            </span>
          </div>

          <!-- Purchase Button -->
          <ButtonV4
            v-else
            sm
            solid
            blue
            :loading="isTrainingPurchasing(service.type)"
            @click="purchaseTraining(service.type)"
          >
            {{ t('BILLING_SETTINGS.TRAINING.PURCHASE_BUTTON') }}
          </ButtonV4>
        </div>
      </div>
    </div>
  </BillingCard>
</template>
