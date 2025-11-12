<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BillingCard from './BillingCard.vue';
import ButtonV4 from 'next/button/Button.vue';
import ConversationPackModal from './ConversationPackModal.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const limits = ref({});
const addOns = ref({});
const conversationPacks = ref([]);
const isLoading = ref(true);
const isPurchasing = ref(false);
const conversationPackModal = ref(null);

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

const fetchConversationPacks = async () => {
  try {
    const response = await store.dispatch('accounts/fetchConversationPacks');
    if (response?.data?.data?.packs) {
      conversationPacks.value = response.data.data.packs;
    }
  } catch (error) {
    // Silent fail - packs won't be available
    conversationPacks.value = [];
  }
};

// Agent limit still needed for display in simplified section
const agentLimit = computed(() => limits.value.agent || {});
const inboxLimit = computed(() => limits.value.inbox || {});
const conversationLimit = computed(() => limits.value.conversation || {});

const isUnlimitedValue = value => value === 'unlimited' || value === -1;

const toNumber = value => {
  if (typeof value === 'number' && !Number.isNaN(value)) {
    return value;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const formatUsageValue = value => {
  if (isUnlimitedValue(value)) {
    return t('BILLING_SETTINGS.LIMITS.UNLIMITED');
  }
  return toNumber(value).toLocaleString();
};

const conversationPlanLimitValue = computed(
  () => conversationLimit.value.plan_limit
);

const conversationIncludedUsageValue = computed(() => {
  const current = toNumber(conversationLimit.value.current);
  const planLimit = conversationPlanLimitValue.value;

  if (isUnlimitedValue(planLimit)) {
    return current;
  }

  return Math.min(current, toNumber(planLimit));
});

const conversationExtraPurchasedValue = computed(() =>
  toNumber(conversationLimit.value.purchased)
);

const conversationRemainingValue = computed(() => {
  const remaining = conversationLimit.value.remaining;

  if (isUnlimitedValue(remaining)) {
    return remaining;
  }

  return Math.max(toNumber(remaining), 0);
});

const canPurchaseAddOns = computed(() => {
  return Object.keys(addOns.value).length > 0;
});

const goToManageChannels = () => {
  router.push({ name: 'settings_inbox_list' });
};

const purchaseConversationPack = async lookupKey => {
  try {
    isPurchasing.value = true;
    await store.dispatch('accounts/purchaseConversationPack', {
      lookup_key: lookupKey,
    });

    // Close modal
    conversationPackModal.value?.closeModal();

    // Refresh limits after purchase
    await fetchLimits();

    // Show success notification (stays for 5 seconds)
    useAlert(t('BILLING_SETTINGS.LIMITS.CONVERSATION_PACK_SUCCESS'), {
      duration: 5000,
    });
  } catch (error) {
    // Show error notification (stays for 5 seconds)
    const errorMessage = error?.response?.data?.error || error?.message;
    useAlert(
      t('BILLING_SETTINGS.LIMITS.CONVERSATION_PACK_ERROR', {
        error: errorMessage || t('BILLING_SETTINGS.LIMITS.GENERIC_ERROR'),
      }),
      { duration: 5000 }
    );
  } finally {
    isPurchasing.value = false;
  }
};

const confirmPurchaseConversationPack = async () => {
  // Layer 2: Proactive check for payment method BEFORE opening modal
  try {
    const response = await store.dispatch('accounts/checkPaymentMethod');

    if (!response?.data?.has_payment_method) {
      // No payment method found - show error and don't open modal
      useAlert(t('BILLING_SETTINGS.LIMITS.ADD_PAYMENT_METHOD_FIRST'), {
        duration: 7000,
      });
      return; // Stop here - don't open modal
    }
  } catch (error) {
    // If the check itself fails, continue anyway
    // (Fail open, not closed - don't unnecessarily block users)
    // Continue to open modal - backend will catch issues
  }

  // Payment method exists (or check failed but we're being permissive)
  // Proceed to show the conversation pack selection modal
  conversationPackModal.value.showModal();
};

const navigateToMembers = () => {
  router.push({ name: 'agent_list' });
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

onMounted(async () => {
  await Promise.all([fetchLimits(), fetchAddOns(), fetchConversationPacks()]);
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
      <!-- Agents Usage (Simplified) -->
      <div
        class="rounded-lg border p-4 shadow-sm transition-all duration-200 border-n-weak bg-n-solid-2"
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
        </div>

        <!-- Simplified Usage Summary -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-4">
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.INCLUDED_MEMBERS_USAGE') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ agentLimit.current || 0 }}/{{ agentLimit.base_limit || 0 }}
            </p>
          </div>
          <div
            v-if="agentLimit.purchased > 0"
            class="bg-n-solid-1 rounded-md p-3 border border-n-weak"
          >
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRA_MEMBERS') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              +{{ agentLimit.purchased }}
            </p>
          </div>
        </div>

        <!-- Navigate to Members CTA -->
        <div class="flex justify-end pt-2 border-t border-n-weak">
          <ButtonV4 sm solid blue @click="navigateToMembers">
            {{ t('BILLING_SETTINGS.LIMITS.MANAGE_MEMBERS') }}
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
        <div class="mb-3">
          <h4 class="text-base font-semibold text-n-slate-12 mb-1">
            {{ t('BILLING_SETTINGS.LIMITS.INBOXES') }}
          </h4>
          <p class="text-xs text-n-slate-11">
            {{ t('BILLING_SETTINGS.LIMITS.TRACK_CHANNELS') }}
          </p>
        </div>

        <!-- Simplified Usage Summary -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-4">
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.INCLUDED_INBOXES_USAGE') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ inboxLimit.current || 0 }}/{{ inboxLimit.base_limit || 0 }}
            </p>
          </div>
          <div
            v-if="inboxLimit.purchased > 0"
            class="bg-n-solid-1 rounded-md p-3 border border-n-weak"
          >
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRA_INBOXES') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              +{{ inboxLimit.purchased }}
            </p>
          </div>
        </div>

        <!-- Purchase Button -->
        <div class="flex justify-end pt-2 border-t border-n-weak">
          <ButtonV4 sm solid blue @click="goToManageChannels">
            {{ t('BILLING_SETTINGS.LIMITS.MANAGE_CHANNELS') }}
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
        </div>

        <!-- Usage Summary -->
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-4">
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.INCLUDED_CONVERSATIONS_USAGE') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ formatUsageValue(conversationIncludedUsageValue)
              }}{{ t('BILLING_SETTINGS.LIMITS.SEPARATOR')
              }}{{
                formatUsageValue(conversationPlanLimitValue)
              }}
            </p>
          </div>
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRA_CONVERSATIONS') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ formatUsageValue(conversationExtraPurchasedValue) }}
            </p>
          </div>
          <div class="bg-n-solid-1 rounded-md p-3 border border-n-weak">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.REMAINING_CONVERSATIONS') }}
            </p>
            <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
              {{ formatUsageValue(conversationRemainingValue) }}
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
            @click="confirmPurchaseConversationPack"
          >
            {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_CONVERSATION_PACKS') }}
          </ButtonV4>
        </div>
      </div>
    </div>
  </BillingCard>

  <!-- Conversation Pack Selection Modal -->
  <ConversationPackModal
    ref="conversationPackModal"
    :packs="conversationPacks"
    :is-purchasing="isPurchasing"
    @purchase="purchaseConversationPack"
  />
</template>
