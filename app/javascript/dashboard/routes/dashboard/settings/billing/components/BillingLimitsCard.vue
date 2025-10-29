<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import BillingCard from './BillingCard.vue';
import BillingMeter from './BillingMeter.vue';
import ButtonV4 from 'next/button/Button.vue';

const { t } = useI18n();
const store = useStore();

const limits = ref({});
const addOns = ref({});
const isLoading = ref(true);
const isPurchasing = ref(false);

const fetchLimits = async () => {
  try {
    isLoading.value = true;
    const response = await store.dispatch('accounts/fetchAddOnLimits');
    if (response?.data) {
      limits.value = response.data.limits || {};
    }
  } catch (error) {
    // Error handling - silent fail
  } finally {
    isLoading.value = false;
  }
};

const fetchAddOns = async () => {
  try {
    const response = await store.dispatch('accounts/fetchAddOns');
    if (response?.data) {
      addOns.value = response.data.add_ons || {};
    }
  } catch (error) {
    // Error handling - silent fail
  }
};

const purchaseAddOn = async addOnType => {
  try {
    isPurchasing.value = true;
    await store.dispatch('accounts/purchaseAddOn', {
      add_on_type: addOnType,
      action: 'add',
    });
    // Refresh limits and add-ons after purchase
    await Promise.all([fetchLimits(), fetchAddOns()]);
  } catch (error) {
    // Error handling - silent fail
  } finally {
    isPurchasing.value = false;
  }
};

const purchaseConversationPack = async () => {
  try {
    isPurchasing.value = true;
    await store.dispatch('accounts/purchaseConversationPack');
    // Refresh limits after purchase
    await fetchLimits();
  } catch (error) {
    // Error handling - silent fail
  } finally {
    isPurchasing.value = false;
  }
};

const agentLimit = computed(() => limits.value.agent || {});
const inboxLimit = computed(() => limits.value.inbox || {});
const conversationLimit = computed(() => limits.value.conversation || {});

const agentAddOn = computed(() => addOns.value.agent || {});
const inboxAddOn = computed(() => addOns.value.inbox || {});

const canPurchaseAddOns = computed(() => {
  return Object.keys(addOns.value).length > 0;
});

const formatLimit = value => {
  if (value === 'unlimited' || value === -1)
    return t('BILLING_SETTINGS.LIMITS.UNLIMITED');
  return value?.toLocaleString() || '0';
};

const getUsagePercentage = limit => {
  if (!limit || limit.usage_percentage === undefined) return 0;
  return Math.min(limit.usage_percentage, 100);
};

const getStatusColor = limit => {
  const percentage = getUsagePercentage(limit);
  if (percentage >= 100) return 'red';
  if (percentage >= 80) return 'orange';
  return 'green';
};

onMounted(async () => {
  await Promise.all([fetchLimits(), fetchAddOns()]);
});
</script>

<template>
  <BillingCard
    :title="t('BILLING_SETTINGS.LIMITS.TITLE')"
    :description="t('BILLING_SETTINGS.LIMITS.DESCRIPTION')"
  >
    <div v-if="isLoading" class="flex items-center justify-center py-8">
      <span class="text-sm text-n-light">{{
        t('BILLING_SETTINGS.LIMITS.LOADING')
      }}</span>
    </div>

    <div v-else class="space-y-6">
      <!-- Agents Usage -->
      <div class="space-y-2">
        <div class="flex items-center justify-between">
          <div>
            <h4 class="text-sm font-medium text-n-dark">
              {{ t('BILLING_SETTINGS.LIMITS.AGENTS') }}
            </h4>
            <p class="text-xs text-n-light mt-0.5">
              {{ agentLimit.current || 0 }} /
              {{ formatLimit(agentLimit.total_allowed) }}
              {{ t('BILLING_SETTINGS.LIMITS.USED') }}
              <span v-if="agentLimit.purchased > 0" class="text-n-medium">
                ({{ agentLimit.base_limit }}
                {{ t('BILLING_SETTINGS.LIMITS.BASE') }} +
                {{ agentLimit.purchased }}
                {{ t('BILLING_SETTINGS.LIMITS.PURCHASED') }})
              </span>
            </p>
          </div>
          <ButtonV4
            v-if="canPurchaseAddOns && agentLimit.approaching_limit"
            xs
            solid
            blue
            :disabled="isPurchasing"
            @click="purchaseAddOn('agent')"
          >
            {{ t('BILLING_SETTINGS.LIMITS.ADD_MORE') }}
            <span v-if="agentAddOn.unit_price_formatted">{{
              agentAddOn.unit_price_formatted
            }}</span>
          </ButtonV4>
        </div>
        <BillingMeter
          :percentage="getUsagePercentage(agentLimit)"
          :color="getStatusColor(agentLimit)"
        />
      </div>

      <!-- Inboxes Usage -->
      <div class="space-y-2">
        <div class="flex items-center justify-between">
          <div>
            <h4 class="text-sm font-medium text-n-dark">
              {{ t('BILLING_SETTINGS.LIMITS.INBOXES') }}
            </h4>
            <p class="text-xs text-n-light mt-0.5">
              {{ inboxLimit.current || 0 }} /
              {{ formatLimit(inboxLimit.total_allowed) }}
              {{ t('BILLING_SETTINGS.LIMITS.USED') }}
              <span v-if="inboxLimit.purchased > 0" class="text-n-medium">
                ({{ inboxLimit.base_limit }}
                {{ t('BILLING_SETTINGS.LIMITS.BASE') }} +
                {{ inboxLimit.purchased }}
                {{ t('BILLING_SETTINGS.LIMITS.PURCHASED') }})
              </span>
            </p>
          </div>
          <ButtonV4
            v-if="canPurchaseAddOns && inboxLimit.approaching_limit"
            xs
            solid
            blue
            :disabled="isPurchasing"
            @click="purchaseAddOn('inbox')"
          >
            {{ t('BILLING_SETTINGS.LIMITS.ADD_MORE') }}
            <span v-if="inboxAddOn.unit_price_formatted">{{
              inboxAddOn.unit_price_formatted
            }}</span>
          </ButtonV4>
        </div>
        <BillingMeter
          :percentage="getUsagePercentage(inboxLimit)"
          :color="getStatusColor(inboxLimit)"
        />
      </div>

      <!-- Conversations Usage -->
      <div class="space-y-2">
        <div class="flex items-center justify-between">
          <div>
            <h4 class="text-sm font-medium text-n-dark">
              {{ t('BILLING_SETTINGS.LIMITS.CONVERSATIONS') }}
            </h4>
            <p class="text-xs text-n-light mt-0.5">
              {{ conversationLimit.current || 0 }} /
              {{ formatLimit(conversationLimit.total_allowed) }}
              {{ t('BILLING_SETTINGS.LIMITS.USED_THIS_PERIOD') }}
              <span
                v-if="conversationLimit.purchased > 0"
                class="text-n-medium"
              >
                ({{ conversationLimit.plan_limit }}
                {{ t('BILLING_SETTINGS.LIMITS.BASE') }} +
                {{ conversationLimit.purchased }}
                {{ t('BILLING_SETTINGS.LIMITS.PURCHASED') }})
              </span>
            </p>
          </div>
          <ButtonV4
            v-if="canPurchaseAddOns && conversationLimit.approaching_limit"
            xs
            solid
            blue
            :disabled="isPurchasing"
            @click="purchaseConversationPack"
          >
            {{ t('BILLING_SETTINGS.LIMITS.BUY_PACK') }}
          </ButtonV4>
        </div>
        <BillingMeter
          :percentage="getUsagePercentage(conversationLimit)"
          :color="getStatusColor(conversationLimit)"
        />
      </div>

      <!-- Warning Message when approaching limits -->
      <div
        v-if="
          agentLimit.approaching_limit ||
          inboxLimit.approaching_limit ||
          conversationLimit.approaching_limit
        "
        class="mt-4 p-3 bg-orange-50 border border-orange-200 rounded-lg"
      >
        <p class="text-xs text-orange-800">
          <span class="font-medium"
            >{{ t('BILLING_SETTINGS.LIMITS.WARNING') }}:</span
          >
          {{ t('BILLING_SETTINGS.LIMITS.WARNING_MESSAGE') }}
        </p>
      </div>
    </div>
  </BillingCard>
</template>
