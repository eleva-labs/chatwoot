<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import * as Sentry from '@sentry/vue';
import Icon from 'next/icon/Icon.vue';
import ButtonV4 from 'next/button/Button.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';

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

/**
 * Reference to the confirmation modal component
 */
const confirmationModal = ref(null);

/**
 * Stores details about the training being purchased for confirmation modal
 * Example: { type: 'live_training', name: 'Live Training', price: '$299' }
 */
const pendingPurchase = ref({
  type: '',
  name: '',
  price: '',
});

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
 * Purchase a training add-on (called after confirmation)
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

      // Show success notification (stays for 5 seconds)
      useAlert(t('BILLING_SETTINGS.TRAINING.PURCHASE_SUCCESS'), {
        duration: 5000,
      });
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

    // Show error notification (stays for 5 seconds)
    useAlert(t('BILLING_SETTINGS.TRAINING.PURCHASE_ERROR'), {
      duration: 5000,
    });
  } finally {
    isPurchasing.value[trainingType] = false;
  }
};

/**
 * Show confirmation modal before purchasing training
 * @param {string} trainingType - The training type (e.g., 'live_training')
 * @param {object} service - The service object containing details
 */
const confirmPurchaseTraining = async (trainingType, service) => {
  // Set pending purchase details for confirmation modal
  pendingPurchase.value = {
    type: trainingType,
    name: service.display_name,
    price: service.unit_price_formatted,
  };

  // Show confirmation modal
  const confirmed = await confirmationModal.value.showConfirmation();

  if (confirmed) {
    await purchaseTraining(trainingType);
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
  <div
    class="rounded-xl shadow-sm border border-n-weak bg-n-solid-2 py-5 space-y-5"
  >
    <!-- ========================================================================
         CUSTOM HEADER WITH BADGES
         ======================================================================== -->
    <div class="px-5 space-y-3">
      <!-- Title Row with Badges -->
      <div class="flex items-center justify-between">
        <!-- Left Side: Title + LIVE Badge -->
        <div class="flex items-center gap-2">
          <span class="text-base font-medium text-n-slate-12">
            {{ t('BILLING_SETTINGS.TRAINING.TITLE') }}
          </span>
          <span
            class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-n-teal-4 text-n-teal-11 text-xs font-semibold rounded-md"
          >
            <Icon icon="i-ri-record-circle-fill" class="size-3" />
            {{ t('BILLING_SETTINGS.TRAINING.LIVE_BADGE') }}
          </span>
        </div>

        <!-- Right Side: Money-Back Guarantee Badge -->
        <span
          class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-n-teal-4 text-n-teal-11 text-xs font-semibold rounded-md"
        >
          <Icon icon="i-ri-checkbox-circle-fill" class="size-3" />
          {{ t('BILLING_SETTINGS.TRAINING.GUARANTEE_BADGE') }}
        </span>
      </div>

      <!-- Description -->
      <p class="text-sm text-n-slate-11">
        {{ t('BILLING_SETTINGS.TRAINING.DESCRIPTION') }}
      </p>
    </div>

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
        <div class="flex items-center justify-end pt-3 border-t border-n-weak">
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
            @click="confirmPurchaseTraining(service.type, service)"
          >
            {{ t('BILLING_SETTINGS.TRAINING.PURCHASE_BUTTON') }}
          </ButtonV4>
        </div>
      </div>
    </div>
  </div>

  <!-- Confirmation Modal -->
  <ConfirmationModal
    ref="confirmationModal"
    :title="t('BILLING_SETTINGS.TRAINING.CONFIRM_PURCHASE_TITLE')"
    :description="
      t('BILLING_SETTINGS.TRAINING.CONFIRM_PURCHASE_DESCRIPTION', {
        item: pendingPurchase.name,
        price: pendingPurchase.price,
      })
    "
    :confirm-label="t('BILLING_SETTINGS.TRAINING.CONFIRM_PURCHASE_BUTTON')"
    :cancel-label="t('BILLING_SETTINGS.TRAINING.CANCEL_PURCHASE_BUTTON')"
  />
</template>
