<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import BillingCard from './BillingCard.vue';
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
    // Access nested data.data.limits from API response
    if (response?.data?.data) {
      limits.value = response.data.data.limits || {};
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
    // Access nested data.data.add_ons from API response
    if (response?.data?.data) {
      addOns.value = response.data.data.add_ons || {};
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

const getProgressBarColor = percentage => {
  if (percentage >= 90) return 'bg-n-ruby-9';
  if (percentage >= 70) return 'bg-n-amber-9';
  return 'bg-n-teal-9';
};

const getUsageTextColor = percentage => {
  if (percentage >= 90) return 'text-n-ruby-11';
  if (percentage >= 70) return 'text-n-amber-11';
  return 'text-n-teal-11';
};

// eslint-disable-next-line no-unused-vars
const getAvailableText = limit => {
  const available = (limit.total_allowed || 0) - (limit.current || 0);
  if (available <= 0) {
    return t('BILLING_SETTINGS.LIMITS.AT_LIMIT');
  }
  return `${available} ${t('BILLING_SETTINGS.LIMITS.REMAINING')}`;
};

const getAvailableWarning = limit => {
  const available = (limit.total_allowed || 0) - (limit.current || 0);
  return available <= 0;
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
      <span class="text-sm text-n-slate-11">{{
        t('BILLING_SETTINGS.LIMITS.LOADING')
      }}</span>
    </div>

    <div v-else class="space-y-8 px-4">
      <!-- Agents Usage -->
      <div
        class="rounded-lg border p-4 shadow-sm transition-all duration-200"
        :class="
          getUsagePercentage(agentLimit) >= 90
            ? 'border-n-ruby-7 bg-n-ruby-2'
            : getUsagePercentage(agentLimit) >= 70
              ? 'border-n-amber-7 bg-n-amber-2'
              : 'border-n-weak bg-n-solid-2'
        "
      >
        <!-- Summary Header -->
        <div class="flex items-start justify-between mb-3">
          <div>
            <h4 class="text-base font-semibold text-n-slate-12 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.AGENTS') }}
            </h4>
            <p class="text-xs text-n-slate-11">
              {{ t('BILLING_SETTINGS.LIMITS.TRACK_TEAM_MEMBERS') }}
            </p>
          </div>
          <div
            class="px-3 py-1.5 rounded-md font-semibold text-sm tabular-nums"
            :class="
              getUsagePercentage(agentLimit) >= 90
                ? 'bg-n-ruby-4 text-n-ruby-11'
                : getUsagePercentage(agentLimit) >= 70
                  ? 'bg-n-amber-4 text-n-amber-11'
                  : 'bg-n-teal-4 text-n-teal-11'
            "
          >
            {{ agentLimit.current || 0 }} /
            {{ formatLimit(agentLimit.total_allowed) }}
          </div>
        </div>

        <!-- Progress Bar -->
        <div class="mb-4">
          <div class="flex items-center justify-between text-xs mb-2">
            <span class="text-n-slate-11 font-medium">{{
              t('BILLING_SETTINGS.LIMITS.USAGE')
            }}</span>
            <span
              class="font-semibold tabular-nums"
              :class="getUsageTextColor(getUsagePercentage(agentLimit))"
            >
              {{ Math.round(getUsagePercentage(agentLimit)) }}%
            </span>
          </div>
          <div class="w-full h-3 bg-n-slate-3 rounded-full overflow-hidden">
            <div
              class="h-full transition-all duration-500 ease-out"
              :class="getProgressBarColor(getUsagePercentage(agentLimit))"
              :style="{ width: `${getUsagePercentage(agentLimit)}%` }"
            />
          </div>
        </div>

        <!-- Details Grid -->
        <div class="grid grid-cols-2 gap-3 mb-4">
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.BASE_INCLUDED') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ agentLimit.base_limit || 0 }}
            </p>
          </div>
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRA_PURCHASED') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ agentLimit.purchased || 0 }}
            </p>
          </div>
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.CURRENTLY_USING') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ agentLimit.current || 0 }}
            </p>
          </div>
          <div
            class="rounded-md p-3 border"
            :class="
              getAvailableWarning(agentLimit)
                ? 'bg-n-ruby-3 border-n-ruby-7'
                : 'bg-n-solid-1 border-n-weak'
            "
          >
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.AVAILABLE') }}
            </p>
            <p
              class="text-lg font-semibold tabular-nums"
              :class="
                getAvailableWarning(agentLimit)
                  ? 'text-n-ruby-11'
                  : 'text-n-slate-12'
              "
            >
              {{ (agentLimit.total_allowed || 0) - (agentLimit.current || 0) }}
              <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
              <span v-if="getAvailableWarning(agentLimit)" class="text-base">
                ⚠️
              </span>
            </p>
          </div>
        </div>

        <!-- Purchase Button -->
        <div class="flex justify-end pt-2 border-t border-n-weak">
          <ButtonV4
            sm
            solid
            blue
            :disabled="isPurchasing || !canPurchaseAddOns"
            @click="purchaseAddOn('agent')"
          >
            <template v-if="canPurchaseAddOns">
              {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_AGENT') }}
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
              <span v-if="agentAddOn.unit_price_formatted" class="text-xs">
                - {{ agentAddOn.unit_price_formatted }}/{{
                  t('BILLING_SETTINGS.LIMITS.MONTH')
                }}
              </span>
            </template>
            <template v-else>
              {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_AGENT') }}
            </template>
          </ButtonV4>
        </div>
      </div>

      <!-- Inboxes Usage -->
      <div
        class="rounded-lg border p-4 shadow-sm transition-all duration-200"
        :class="
          getUsagePercentage(inboxLimit) >= 90
            ? 'border-n-ruby-7 bg-n-ruby-2'
            : getUsagePercentage(inboxLimit) >= 70
              ? 'border-n-amber-7 bg-n-amber-2'
              : 'border-n-weak bg-n-solid-2'
        "
      >
        <!-- Summary Header -->
        <div class="flex items-start justify-between mb-3">
          <div>
            <h4 class="text-base font-semibold text-n-slate-12 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.INBOXES') }}
            </h4>
            <p class="text-xs text-n-slate-11">
              {{ t('BILLING_SETTINGS.LIMITS.TRACK_CHANNELS') }}
            </p>
          </div>
          <div
            class="px-3 py-1.5 rounded-md font-semibold text-sm tabular-nums"
            :class="
              getUsagePercentage(inboxLimit) >= 90
                ? 'bg-n-ruby-4 text-n-ruby-11'
                : getUsagePercentage(inboxLimit) >= 70
                  ? 'bg-n-amber-4 text-n-amber-11'
                  : 'bg-n-teal-4 text-n-teal-11'
            "
          >
            {{ inboxLimit.current || 0 }} /
            {{ formatLimit(inboxLimit.total_allowed) }}
          </div>
        </div>

        <!-- Progress Bar -->
        <div class="mb-4">
          <div class="flex items-center justify-between text-xs mb-2">
            <span class="text-n-slate-11 font-medium">{{
              t('BILLING_SETTINGS.LIMITS.USAGE')
            }}</span>
            <span
              class="font-semibold tabular-nums"
              :class="getUsageTextColor(getUsagePercentage(inboxLimit))"
            >
              {{ Math.round(getUsagePercentage(inboxLimit)) }}%
            </span>
          </div>
          <div class="w-full h-3 bg-n-slate-3 rounded-full overflow-hidden">
            <div
              class="h-full transition-all duration-500 ease-out"
              :class="getProgressBarColor(getUsagePercentage(inboxLimit))"
              :style="{ width: `${getUsagePercentage(inboxLimit)}%` }"
            />
          </div>
        </div>

        <!-- Details Grid -->
        <div class="grid grid-cols-2 gap-3 mb-4">
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.BASE_INCLUDED') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ inboxLimit.base_limit || 0 }}
            </p>
          </div>
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRA_PURCHASED') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ inboxLimit.purchased || 0 }}
            </p>
          </div>
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.CURRENTLY_USING') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ inboxLimit.current || 0 }}
            </p>
          </div>
          <div
            class="rounded-md p-3 border"
            :class="
              getAvailableWarning(inboxLimit)
                ? 'bg-n-ruby-3 border-n-ruby-7'
                : 'bg-n-solid-1 border-n-weak'
            "
          >
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.AVAILABLE') }}
            </p>
            <p
              class="text-lg font-semibold tabular-nums"
              :class="
                getAvailableWarning(inboxLimit)
                  ? 'text-n-ruby-11'
                  : 'text-n-slate-12'
              "
            >
              {{ (inboxLimit.total_allowed || 0) - (inboxLimit.current || 0) }}
              <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
              <span v-if="getAvailableWarning(inboxLimit)" class="text-base">
                ⚠️
              </span>
            </p>
          </div>
        </div>

        <!-- Purchase Button -->
        <div class="flex justify-end pt-2 border-t border-n-weak">
          <ButtonV4
            sm
            solid
            blue
            :disabled="isPurchasing || !canPurchaseAddOns"
            @click="purchaseAddOn('inbox')"
          >
            <template v-if="canPurchaseAddOns">
              {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_INBOX') }}
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
              <span v-if="inboxAddOn.unit_price_formatted" class="text-xs">
                - {{ inboxAddOn.unit_price_formatted }}/{{
                  t('BILLING_SETTINGS.LIMITS.MONTH')
                }}
              </span>
            </template>
            <template v-else>
              {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_INBOX') }}
            </template>
          </ButtonV4>
        </div>
      </div>

      <!-- Conversations Usage -->
      <div
        class="rounded-lg border p-4 shadow-sm transition-all duration-200"
        :class="
          getUsagePercentage(conversationLimit) >= 90
            ? 'border-n-ruby-7 bg-n-ruby-2'
            : getUsagePercentage(conversationLimit) >= 70
              ? 'border-n-amber-7 bg-n-amber-2'
              : 'border-n-weak bg-n-solid-2'
        "
      >
        <!-- Summary Header -->
        <div class="flex items-start justify-between mb-3">
          <div>
            <h4 class="text-base font-semibold text-n-slate-12 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.CONVERSATIONS') }}
            </h4>
            <p class="text-xs text-n-slate-11">
              {{ t('BILLING_SETTINGS.LIMITS.TRACK_MONTHLY_CONVERSATIONS') }}
            </p>
          </div>
          <div
            class="px-3 py-1.5 rounded-md font-semibold text-sm tabular-nums"
            :class="
              getUsagePercentage(conversationLimit) >= 90
                ? 'bg-n-ruby-4 text-n-ruby-11'
                : getUsagePercentage(conversationLimit) >= 70
                  ? 'bg-n-amber-4 text-n-amber-11'
                  : 'bg-n-teal-4 text-n-teal-11'
            "
          >
            {{ conversationLimit.current || 0 }} /
            {{ formatLimit(conversationLimit.total_allowed) }}
          </div>
        </div>

        <!-- Progress Bar -->
        <div class="mb-4">
          <div class="flex items-center justify-between text-xs mb-2">
            <span class="text-n-slate-11 font-medium">{{
              t('BILLING_SETTINGS.LIMITS.USAGE')
            }}</span>
            <span
              class="font-semibold tabular-nums"
              :class="getUsageTextColor(getUsagePercentage(conversationLimit))"
            >
              {{ Math.round(getUsagePercentage(conversationLimit)) }}%
            </span>
          </div>
          <div class="w-full h-3 bg-n-slate-3 rounded-full overflow-hidden">
            <div
              class="h-full transition-all duration-500 ease-out"
              :class="
                getProgressBarColor(getUsagePercentage(conversationLimit))
              "
              :style="{ width: `${getUsagePercentage(conversationLimit)}%` }"
            />
          </div>
        </div>

        <!-- Details Grid -->
        <div class="grid grid-cols-2 gap-3 mb-4">
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.PLAN_LIMIT') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ (conversationLimit.plan_limit || 0).toLocaleString() }}
            </p>
          </div>
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRA_PURCHASED') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ (conversationLimit.purchased || 0).toLocaleString() }}
            </p>
          </div>
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.CURRENTLY_USED') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ (conversationLimit.current || 0).toLocaleString() }}
            </p>
          </div>
          <div
            class="rounded-md p-3 border"
            :class="
              getAvailableWarning(conversationLimit)
                ? 'bg-n-ruby-3 border-n-ruby-7'
                : 'bg-n-solid-1 border-n-weak'
            "
          >
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.REMAINING') }}
            </p>
            <p
              class="text-lg font-semibold tabular-nums"
              :class="
                getAvailableWarning(conversationLimit)
                  ? 'text-n-ruby-11'
                  : 'text-n-slate-12'
              "
            >
              {{
                (
                  (conversationLimit.total_allowed || 0) -
                  (conversationLimit.current || 0)
                ).toLocaleString()
              }}
              <!-- eslint-disable vue/no-bare-strings-in-template -->
              <span
                v-if="getAvailableWarning(conversationLimit)"
                class="text-base"
              >
                ⚠️
              </span>
              <!-- eslint-enable vue/no-bare-strings-in-template -->
            </p>
          </div>
        </div>

        <!-- Purchase Button -->
        <div class="flex justify-end pt-2 border-t border-n-weak">
          <ButtonV4
            sm
            solid
            blue
            :disabled="isPurchasing || !canPurchaseAddOns"
            @click="purchaseConversationPack"
          >
            {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_CONVERSATION_PACK') }}
          </ButtonV4>
        </div>
      </div>
    </div>
  </BillingCard>
</template>
