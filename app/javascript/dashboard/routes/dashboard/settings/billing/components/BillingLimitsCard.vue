<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BillingCard from './BillingCard.vue';
import ButtonV4 from 'next/button/Button.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
import ConversationPackModal from './ConversationPackModal.vue';

const { t } = useI18n();
const store = useStore();

const limits = ref({});
const addOns = ref({});
const conversationPacks = ref([]);
const isLoading = ref(true);
const isPurchasing = ref(false);
const confirmationModal = ref(null);
const conversationPackModal = ref(null);
const defaultPendingPurchase = {
  type: null,
  name: null,
  price: null,
  action: null,
  quantity: null,
  estimatedCredit: null,
};

const pendingPurchase = ref({ ...defaultPendingPurchase });

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

const agentLimit = computed(() => limits.value.agent || {});
const inboxLimit = computed(() => limits.value.inbox || {});
const conversationLimit = computed(() => limits.value.conversation || {});

const agentAddOn = computed(() => addOns.value.agent || {});
const inboxAddOn = computed(() => addOns.value.inbox || {});

const canPurchaseAddOns = computed(() => {
  return Object.keys(addOns.value).length > 0;
});

// Computed properties for extras usage (agents)
const agentExtrasUsed = computed(() => {
  const current = agentLimit.value.current || 0;
  const included = agentLimit.value.base_limit || 0;
  const purchased = agentLimit.value.purchased || 0;
  
  const rawUsed = current - included;
  return Math.max(0, Math.min(rawUsed, purchased));
});

const agentExtrasUnused = computed(() => {
  const purchased = agentLimit.value.purchased || 0;
  return purchased - agentExtrasUsed.value;
});

// Computed properties for extras usage (inboxes)
const inboxExtrasUsed = computed(() => {
  const current = inboxLimit.value.current || 0;
  const included = inboxLimit.value.base_limit || 0;
  const purchased = inboxLimit.value.purchased || 0;
  
  const rawUsed = current - included;
  return Math.max(0, Math.min(rawUsed, purchased));
});

const inboxExtrasUnused = computed(() => {
  const purchased = inboxLimit.value.purchased || 0;
  return purchased - inboxExtrasUsed.value;
});

// Removal quantity state
const removalQuantity = ref({ agent: 1, inbox: 1 });
const removalError = ref({ agent: null, inbox: null });

// Validate removal quantity input
const validateRemovalQuantity = addOnType => {
  const quantity = removalQuantity.value[addOnType];
  const maxRemovable =
    addOnType === 'agent' ? agentExtrasUnused.value : inboxExtrasUnused.value;

  if (quantity < 1) {
    removalError.value[addOnType] = t(
      'BILLING_SETTINGS.LIMITS.QUANTITY_TOO_LOW'
    );
    return false;
  }

  if (quantity > maxRemovable) {
    const settingsSection =
      addOnType === 'agent'
        ? t('BILLING_SETTINGS.LIMITS.SETTINGS_MEMBERS')
        : t('BILLING_SETTINGS.LIMITS.SETTINGS_CHANNELS');

    removalError.value[addOnType] = t(
      'BILLING_SETTINGS.LIMITS.QUANTITY_EXCEEDS_UNUSED',
      {
        max: maxRemovable,
        section: settingsSection,
      }
    );
    return false;
  }

  removalError.value[addOnType] = null;
  return true;
};

const confirmationTitle = computed(() => {
  if (pendingPurchase.value.action === 'remove_quantity') {
    return t('BILLING_SETTINGS.LIMITS.CONFIRM_REMOVE_TITLE');
  }

  return t('BILLING_SETTINGS.LIMITS.CONFIRM_PURCHASE_TITLE');
});

const confirmationDescription = computed(() => {
  if (pendingPurchase.value.action === 'remove_quantity') {
    const hasExtrasUsed = pendingPurchase.value.extrasUsed > 0;
    const settingsSection =
      pendingPurchase.value.type === 'agent'
        ? t('BILLING_SETTINGS.LIMITS.SETTINGS_MEMBERS')
        : t('BILLING_SETTINGS.LIMITS.SETTINGS_CHANNELS');

    let description = t(
      'BILLING_SETTINGS.LIMITS.CONFIRM_REMOVE_QUANTITY_DESCRIPTION',
      {
        quantity: pendingPurchase.value.quantity,
        item: pendingPurchase.value.name,
        credit: pendingPurchase.value.estimatedCredit,
      }
    );

    if (hasExtrasUsed) {
      description +=
        '\n\n' +
        t('BILLING_SETTINGS.LIMITS.REMOVE_MORE_GUIDANCE', {
          section: settingsSection,
          extrasUsed: pendingPurchase.value.extrasUsed,
          item: pendingPurchase.value.name,
        });
    }

    return description;
  }

  return t('BILLING_SETTINGS.LIMITS.CONFIRM_PURCHASE_DESCRIPTION', {
    item: pendingPurchase.value.name,
    price: pendingPurchase.value.price,
  });
});

const confirmationConfirmLabel = computed(() => {
  if (pendingPurchase.value.action === 'remove_quantity') {
    return t('BILLING_SETTINGS.LIMITS.CONFIRM_REMOVE_BUTTON');
  }

  return t('BILLING_SETTINGS.LIMITS.CONFIRM_PURCHASE_BUTTON');
});

const getAddOnDisplayName = addOnType => {
  const names = {
    agent: t('BILLING_SETTINGS.LIMITS.AGENT_SINGULAR'),
    inbox: t('BILLING_SETTINGS.LIMITS.INBOX_SINGULAR'),
    channel: t('BILLING_SETTINGS.LIMITS.CHANNEL_SINGULAR'),
  };
  return names[addOnType] || addOnType;
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

    // Show success notification (stays for 5 seconds)
    useAlert(
      t('BILLING_SETTINGS.LIMITS.PURCHASE_SUCCESS', {
        item: getAddOnDisplayName(addOnType),
      }),
      { duration: 5000 }
    );
  } catch (error) {
    // Show error notification (stays for 5 seconds)
    const errorMessage = error?.response?.data?.error || error?.message;
    useAlert(
      t('BILLING_SETTINGS.LIMITS.PURCHASE_ERROR', {
        item: getAddOnDisplayName(addOnType),
        error: errorMessage || t('BILLING_SETTINGS.LIMITS.GENERIC_ERROR'),
      }),
      { duration: 5000 }
    );
  } finally {
    isPurchasing.value = false;
  }
};

const removeAddOn = async (addOnType, quantity) => {
  try {
    isPurchasing.value = true;

    const currentPurchased =
      addOnType === 'agent'
        ? agentLimit.value.purchased
        : inboxLimit.value.purchased;

    await store.dispatch('accounts/purchaseAddOn', {
      add_on_type: addOnType,
      action: 'set',
      quantity: currentPurchased - quantity,
    });

    await Promise.all([fetchLimits(), fetchAddOns()]);

    useAlert(
      t('BILLING_SETTINGS.LIMITS.REMOVE_SUCCESS_QUANTITY', {
        quantity: quantity,
        item: getAddOnDisplayName(addOnType),
      }),
      { duration: 5000 }
    );

    // Reset removal quantity and error
    removalQuantity.value[addOnType] = 1;
    removalError.value[addOnType] = null;
  } catch (error) {
    const errorMessage = error?.response?.data?.error || error?.message;
    useAlert(
      t('BILLING_SETTINGS.LIMITS.REMOVE_ERROR', {
        item: getAddOnDisplayName(addOnType),
        error: errorMessage || t('BILLING_SETTINGS.LIMITS.GENERIC_ERROR'),
      }),
      { duration: 5000 }
    );
  } finally {
    isPurchasing.value = false;
  }
};

const confirmPurchase = async addOnType => {
  // Set pending purchase details for confirmation modal
  const addOnInfo = addOns.value[addOnType];
  pendingPurchase.value = {
    type: addOnType,
    name: getAddOnDisplayName(addOnType),
    price: addOnInfo?.unit_price_formatted || '',
    action: 'purchase',
    quantity: null,
    estimatedCredit: null,
  };

  // Show confirmation modal
  const confirmed = await confirmationModal.value.showConfirmation();

  if (confirmed) {
    await purchaseAddOn(addOnType);
  }
};

const confirmRemove = async addOnType => {
  // Validate before proceeding
  if (!validateRemovalQuantity(addOnType)) {
    return; // Show error via removalError computed property
  }

  const quantity = removalQuantity.value[addOnType];
  const addOnInfo = addOns.value[addOnType];
  const currentPurchased =
    addOnType === 'agent'
      ? agentLimit.value.purchased
      : inboxLimit.value.purchased;

  let estimatedCredit = null;
  try {
    const previewResponse = await store.dispatch(
      'accounts/previewAddOnRemoval',
      {
        add_on_type: addOnType,
        action: 'set',
        quantity: currentPurchased - quantity,
      }
    );

    estimatedCredit = previewResponse?.data?.estimated_credit;
  } catch (error) {
    // Ignore preview errors; continue to confirmation
  }

  const maxRemovable =
    addOnType === 'agent' ? agentExtrasUnused.value : inboxExtrasUnused.value;
  const extrasUsed =
    addOnType === 'agent' ? agentExtrasUsed.value : inboxExtrasUsed.value;

  pendingPurchase.value = {
    type: addOnType,
    name: getAddOnDisplayName(addOnType),
    price: addOnInfo?.unit_price_formatted || '',
    action: 'remove_quantity',
    quantity: quantity,
    maxRemovable: maxRemovable,
    extrasUsed: extrasUsed,
    estimatedCredit:
      estimatedCredit || t('BILLING_SETTINGS.LIMITS.CALCULATING_CREDIT'),
  };

  const confirmed = await confirmationModal.value.showConfirmation();

  if (confirmed) {
    await removeAddOn(addOnType, quantity);
  }
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
            {{ agentLimit.current || 0
            }}{{ t('BILLING_SETTINGS.LIMITS.SEPARATOR')
            }}{{ formatLimit(agentLimit.total_allowed) }}
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
              {{ Math.round(getUsagePercentage(agentLimit))
              }}{{ t('BILLING_SETTINGS.LIMITS.PERCENTAGE_SYMBOL') }}
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
              <span v-if="getAvailableWarning(agentLimit)" class="text-base">
                {{ t('BILLING_SETTINGS.LIMITS.WARNING_ICON') }}
              </span>
            </p>
          </div>

          <!-- Extras in use -->
          <div
            v-if="agentLimit.purchased > 0"
            class="bg-n-amber-2 rounded-md p-3 border border-n-amber-7"
          >
            <p class="text-xs text-n-amber-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRAS_IN_USE') }}
            </p>
            <p class="text-lg font-semibold text-n-amber-11 tabular-nums">
              {{ agentExtrasUsed }}
            </p>
          </div>

          <!-- Extras unused -->
          <div
            v-if="agentLimit.purchased > 0"
            class="bg-n-teal-2 rounded-md p-3 border border-n-teal-7"
          >
            <p class="text-xs text-n-teal-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRAS_UNUSED') }}
            </p>
            <p class="text-lg font-semibold text-n-teal-11 tabular-nums">
              {{ agentExtrasUnused }}
              <span class="text-xs text-n-teal-10 ml-1 font-normal">
                ({{ t('BILLING_SETTINGS.LIMITS.CAN_REMOVE') }})
              </span>
            </p>
          </div>
        </div>

        <!-- Remove Section -->
        <div
          v-if="agentLimit.purchased > 0"
          class="mb-4 p-3 bg-n-solid-1 rounded-md border border-n-weak"
        >
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{ t('BILLING_SETTINGS.LIMITS.REMOVE_EXTRA_AGENTS_LABEL') }}
          </label>
          <div class="flex items-start gap-2">
            <div class="flex-1">
              <input
                v-model.number="removalQuantity.agent"
                type="number"
                min="1"
                :max="agentExtrasUnused"
                :disabled="agentExtrasUnused === 0 || isPurchasing"
                class="w-full px-3 py-2 text-sm border rounded-md"
                :class="
                  removalError.agent
                    ? 'border-n-ruby-7 bg-n-ruby-2 text-n-ruby-11'
                    : 'border-n-weak bg-n-solid-2 text-n-slate-12'
                "
                @input="validateRemovalQuantity('agent')"
              />
              <p v-if="removalError.agent" class="text-xs text-n-ruby-11 mt-1">
                {{ removalError.agent }}
              </p>
              <p v-else class="text-xs text-n-slate-11 mt-1">
                {{
                  t('BILLING_SETTINGS.LIMITS.MAX_REMOVABLE', {
                    max: agentExtrasUnused,
                  })
                }}
              </p>
            </div>
            <ButtonV4
              sm
              outline
              red
              :disabled="
                isPurchasing ||
                !canPurchaseAddOns ||
                agentExtrasUnused === 0 ||
                removalError.agent !== null
              "
              @click="confirmRemove('agent')"
            >
              {{ t('BILLING_SETTINGS.LIMITS.REMOVE_BUTTON') }}
            </ButtonV4>
          </div>
        </div>

        <!-- Purchase Button -->
        <div class="flex justify-end pt-2 border-t border-n-weak">
          <ButtonV4
            sm
            solid
            blue
            :disabled="isPurchasing || !canPurchaseAddOns"
            @click="confirmPurchase('agent')"
          >
            <template v-if="canPurchaseAddOns">
              {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_AGENT') }}
              <span v-if="agentAddOn.unit_price_formatted" class="text-xs">
                {{ t('BILLING_SETTINGS.LIMITS.SEPARATOR')
                }}{{ agentAddOn.unit_price_formatted
                }}{{ t('BILLING_SETTINGS.LIMITS.SLASH')
                }}{{ t('BILLING_SETTINGS.LIMITS.MONTH') }}
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
            {{ inboxLimit.current || 0
            }}{{ t('BILLING_SETTINGS.LIMITS.SEPARATOR')
            }}{{ formatLimit(inboxLimit.total_allowed) }}
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
              {{ Math.round(getUsagePercentage(inboxLimit))
              }}{{ t('BILLING_SETTINGS.LIMITS.PERCENTAGE_SYMBOL') }}
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
              <span v-if="getAvailableWarning(inboxLimit)" class="text-base">
                {{ t('BILLING_SETTINGS.LIMITS.WARNING_ICON') }}
              </span>
            </p>
          </div>

          <!-- Extras in use -->
          <div
            v-if="inboxLimit.purchased > 0"
            class="bg-n-amber-2 rounded-md p-3 border border-n-amber-7"
          >
            <p class="text-xs text-n-amber-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRAS_IN_USE') }}
            </p>
            <p class="text-lg font-semibold text-n-amber-11 tabular-nums">
              {{ inboxExtrasUsed }}
            </p>
          </div>

          <!-- Extras unused -->
          <div
            v-if="inboxLimit.purchased > 0"
            class="bg-n-teal-2 rounded-md p-3 border border-n-teal-7"
          >
            <p class="text-xs text-n-teal-11 mb-1">
              {{ t('BILLING_SETTINGS.LIMITS.EXTRAS_UNUSED') }}
            </p>
            <p class="text-lg font-semibold text-n-teal-11 tabular-nums">
              {{ inboxExtrasUnused }}
              <span class="text-xs text-n-teal-10 ml-1 font-normal">
                ({{ t('BILLING_SETTINGS.LIMITS.CAN_REMOVE') }})
              </span>
            </p>
          </div>
        </div>

        <!-- Remove Section -->
        <div
          v-if="inboxLimit.purchased > 0"
          class="mb-4 p-3 bg-n-solid-1 rounded-md border border-n-weak"
        >
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{ t('BILLING_SETTINGS.LIMITS.REMOVE_EXTRA_INBOXES_LABEL') }}
          </label>
          <div class="flex items-start gap-2">
            <div class="flex-1">
              <input
                v-model.number="removalQuantity.inbox"
                type="number"
                min="1"
                :max="inboxExtrasUnused"
                :disabled="inboxExtrasUnused === 0 || isPurchasing"
                class="w-full px-3 py-2 text-sm border rounded-md"
                :class="
                  removalError.inbox
                    ? 'border-n-ruby-7 bg-n-ruby-2 text-n-ruby-11'
                    : 'border-n-weak bg-n-solid-2 text-n-slate-12'
                "
                @input="validateRemovalQuantity('inbox')"
              />
              <p v-if="removalError.inbox" class="text-xs text-n-ruby-11 mt-1">
                {{ removalError.inbox }}
              </p>
              <p v-else class="text-xs text-n-slate-11 mt-1">
                {{
                  t('BILLING_SETTINGS.LIMITS.MAX_REMOVABLE', {
                    max: inboxExtrasUnused,
                  })
                }}
              </p>
            </div>
            <ButtonV4
              sm
              outline
              red
              :disabled="
                isPurchasing ||
                !canPurchaseAddOns ||
                inboxExtrasUnused === 0 ||
                removalError.inbox !== null
              "
              @click="confirmRemove('inbox')"
            >
              {{ t('BILLING_SETTINGS.LIMITS.REMOVE_BUTTON') }}
            </ButtonV4>
          </div>
        </div>

        <!-- Purchase Button -->
        <div class="flex justify-end pt-2 border-t border-n-weak">
          <ButtonV4
            sm
            solid
            blue
            :disabled="isPurchasing || !canPurchaseAddOns"
            @click="confirmPurchase('inbox')"
          >
            <template v-if="canPurchaseAddOns">
              {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_EXTRA_INBOX') }}
              <span v-if="inboxAddOn.unit_price_formatted" class="text-xs">
                {{ t('BILLING_SETTINGS.LIMITS.SEPARATOR')
                }}{{ inboxAddOn.unit_price_formatted
                }}{{ t('BILLING_SETTINGS.LIMITS.SLASH')
                }}{{ t('BILLING_SETTINGS.LIMITS.MONTH') }}
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
            {{ conversationLimit.current || 0
            }}{{ t('BILLING_SETTINGS.LIMITS.SEPARATOR')
            }}{{ formatLimit(conversationLimit.total_allowed) }}
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
              {{ Math.round(getUsagePercentage(conversationLimit))
              }}{{ t('BILLING_SETTINGS.LIMITS.PERCENTAGE_SYMBOL') }}
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
              <span
                v-if="getAvailableWarning(conversationLimit)"
                class="text-base"
              >
                {{ t('BILLING_SETTINGS.LIMITS.WARNING_ICON') }}
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
            @click="confirmPurchaseConversationPack"
          >
            {{ t('BILLING_SETTINGS.LIMITS.PURCHASE_CONVERSATION_PACKS') }}
          </ButtonV4>
        </div>
      </div>
    </div>
  </BillingCard>

  <!-- Confirmation Modal -->
  <ConfirmationModal
    ref="confirmationModal"
    :title="confirmationTitle"
    :description="confirmationDescription"
    :confirm-label="confirmationConfirmLabel"
    :cancel-label="t('BILLING_SETTINGS.LIMITS.CANCEL_BUTTON')"
  />

  <!-- Conversation Pack Selection Modal -->
  <ConversationPackModal
    ref="conversationPackModal"
    :packs="conversationPacks"
    :is-purchasing="isPurchasing"
    @purchase="purchaseConversationPack"
  />
</template>
