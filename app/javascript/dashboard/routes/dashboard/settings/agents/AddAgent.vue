<script setup>
import { ref, computed, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, email } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAgentSeatLimits } from './composables/useAgentSeatLimits';

const emit = defineEmits(['close']);

const store = useStore();
const router = useRouter();
const route = useRoute();
const { t } = useI18n();

const agentName = ref('');
const agentEmail = ref('');
const selectedRoleId = ref('agent');
const isPurchasingExtraSeat = ref(false);
const purchaseError = ref(null);
const prorationAmount = ref(null);
const isProrationLoading = ref(false);
const hasFetchedProration = ref(false);

// Use the shared composable for seat limits
const {
  hasAvailableIncludedSeat,
  agentPriceLabel,
  isLoading,
  limitsError,
  hasLoadedData,
  fetchLimits,
} = useAgentSeatLimits(store);

const showUsageLoadingMessage = computed(() => {
  return !hasLoadedData.value && isLoading.value;
});

const usageErrorMessage = computed(() => limitsError.value);

const isSeatInfoLoading = computed(() => isLoading.value);

const rules = {
  agentName: { required },
  agentEmail: { required, email },
  selectedRoleId: { required },
};

const v$ = useVuelidate(rules, {
  agentName,
  agentEmail,
  selectedRoleId,
});

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');

const roles = computed(() => {
  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

// Compute primary button label based on seat availability
const primaryButtonLabel = computed(() => {
  if (isSeatInfoLoading.value) {
    return t('AGENT_MGMT.ADD.FORM.SUBMIT');
  }

  if (hasAvailableIncludedSeat.value) {
    return t('AGENT_MGMT.ADD.FORM.SUBMIT');
  }

  // Need to purchase extra seat
  if (agentPriceLabel.value) {
    return `${t('AGENT_MGMT.ADD.PRIMARY_BUY_LABEL', {
      price: agentPriceLabel.value,
    })}`;
  }

  return t('AGENT_MGMT.ADD.FORM.SUBMIT');
});

const prorationAmountDisplay = computed(() => {
  if (isProrationLoading.value) {
    return t('AGENT_MGMT.ADD.CALCULATING_PRORATION');
  }

  if (prorationAmount.value) {
    return prorationAmount.value;
  }

  return t('AGENT_MGMT.ADD.CALCULATING_PRORATION');
});

const fetchProrationPreview = async () => {
  if (isProrationLoading.value || hasFetchedProration.value) {
    return;
  }

  isProrationLoading.value = true;

  try {
    const response = await store.dispatch('accounts/previewAddOnPurchase', {
      add_on_type: 'agent',
      action: 'add',
    });

    if (response?.data?.estimated_charge) {
      prorationAmount.value = response.data.estimated_charge;
      hasFetchedProration.value = true;
    } else {
      prorationAmount.value = null;
    }
  } catch (error) {
    prorationAmount.value = null;
  } finally {
    isProrationLoading.value = false;
  }
};

watch(
  [hasLoadedData, hasAvailableIncludedSeat],
  async ([loaded, hasSeat]) => {
    if (loaded && !hasSeat) {
      await fetchProrationPreview();
    } else if (hasSeat) {
      prorationAmount.value = null;
      hasFetchedProration.value = false;
    }
  },
  { immediate: true }
);

// Note message when extra charge applies
const noteMessage = computed(() => {
  if (!hasLoadedData.value) {
    return null;
  }

  if (!hasAvailableIncludedSeat.value) {
    const displayAmount = prorationAmountDisplay.value;
    return t('AGENT_MGMT.ADD.EXTRA_NOTE', { amount: displayAmount });
  }
  return null;
});

// Handle purchase and create flow
const handlePurchaseAndCreate = async () => {
  try {
    // If no included seats available, purchase extra seat first
    if (!hasAvailableIncludedSeat.value) {
      isPurchasingExtraSeat.value = true;
      purchaseError.value = null;

      await store.dispatch('accounts/purchaseAddOn', {
        add_on_type: 'agent',
        action: 'add',
      });

      // Refresh limits after purchase
      await fetchLimits(true);
    }

    // Now create the agent
    const payload = {
      name: agentName.value,
      email: agentEmail.value,
    };

    if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
    }

    await store.dispatch('agents/create', payload);
    useAlert(t('AGENT_MGMT.ADD.API.SUCCESS_MESSAGE'));

    // Handle navigation/close based on context
    if (route.name === 'settings_inboxes_invite_team') {
      router.push({
        name: 'settings_inboxes_add_agents',
        params: { inbox_id: route.params.inbox_id },
      });
    } else {
      emit('close');
    }
  } catch (error) {
    // Check if it's a purchase error
    if (isPurchasingExtraSeat.value) {
      const errorMessage = error?.response?.data?.error || error?.message;
      purchaseError.value = errorMessage || t('AGENT_MGMT.ADD.PURCHASE_ERROR');
      useAlert(purchaseError.value);
      return; // Don't proceed to agent creation
    }

    // Agent creation error
    const {
      response: {
        data: {
          error: errorResponse = '',
          attributes: attributes = [],
          message: attrError = '',
        } = {},
      } = {},
    } = error;

    let errorMessage = '';
    if (error?.response?.status === 422 && !attributes.includes('base')) {
      errorMessage = t('AGENT_MGMT.ADD.API.EXIST_MESSAGE');
    } else {
      errorMessage = t('AGENT_MGMT.ADD.API.ERROR_MESSAGE');
    }
    useAlert(errorResponse || attrError || errorMessage);
  } finally {
    isPurchasingExtraSeat.value = false;
  }
};

const addAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  await handlePurchaseAndCreate();
};

const skipInvitations = () => {
  // Skip to next step in onboarding flow
  router.push({
    name: 'settings_inboxes_add_agents',
    params: { inbox_id: route.params.inbox_id },
  });
};
</script>

<template>
  <div
    class="flex flex-col h-auto overflow-auto"
    :class="{ 'p-6': route.name === 'settings_inboxes_invite_team' }"
  >
    <!-- Onboarding mode header -->
    <div v-if="route.name === 'settings_inboxes_invite_team'" class="mb-6">
      <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-2">
        {{ $t('INBOX_MGMT.CREATE_FLOW.INVITE_TEAM.TITLE') }}
      </h2>
      <p class="text-slate-600 dark:text-slate-400">
        {{ $t('INBOX_MGMT.CREATE_FLOW.INVITE_TEAM.BODY') }}
      </p>
    </div>

    <!-- Modal mode header -->
    <woot-modal-header
      v-else
      :header-title="$t('AGENT_MGMT.ADD.TITLE')"
      :header-content="$t('AGENT_MGMT.ADD.DESC')"
    />

    <form
      class="flex flex-col items-start w-full gap-6"
      @submit.prevent="addAgent"
    >
      <div class="flex flex-col w-full gap-6 mt-6">
        <div class="w-full">
          <label :class="{ error: v$.agentName.$error }">
            {{ $t('AGENT_MGMT.ADD.FORM.NAME.LABEL') }}
            <input
              v-model="agentName"
              type="text"
              :placeholder="$t('AGENT_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
              @input="v$.agentName.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.selectedRoleId.$error }">
            {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.LABEL') }}
            <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
              <option v-for="role in roles" :key="role.id" :value="role.id">
                {{ role.label }}
              </option>
            </select>
            <span v-if="v$.selectedRoleId.$error" class="message">
              {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.ERROR') }}
            </span>
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.agentEmail.$error }">
            {{ $t('AGENT_MGMT.ADD.FORM.EMAIL.LABEL') }}
            <input
              v-model="agentEmail"
              type="email"
              :placeholder="$t('AGENT_MGMT.ADD.FORM.EMAIL.PLACEHOLDER')"
              @input="v$.agentEmail.$touch"
            />
          </label>
        </div>
      </div>

      <!-- Onboarding mode buttons -->
      <div
        v-if="route.name === 'settings_inboxes_invite_team'"
        class="flex flex-row justify-between w-full gap-2 mt-8 pt-6 border-t border-slate-200 dark:border-slate-700"
      >
        <Button faded slate label="Skip for now" @click="skipInvitations" />
        <Button
          type="submit"
          :label="$t('AGENT_MGMT.ADD.FORM.SUBMIT')"
          :disabled="v$.$invalid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        />
      </div>

      <!-- Modal mode buttons -->
      <div v-else class="flex flex-col w-full gap-6 px-0 py-2">
        <div
          class="w-full pt-4 border-t border-n-weak dark:border-n-slate-6 text-sm"
        >
          <p v-if="showUsageLoadingMessage" class="text-n-slate-11">
            {{ $t('AGENT_MGMT.ADD.USAGE_LOADING') }}
          </p>
          <p v-else-if="usageErrorMessage" class="text-n-ruby-11">
            {{ $t('AGENT_MGMT.ADD.USAGE_ERROR') }}
          </p>
        </div>

        <!-- Extra charge note -->
        <p
          v-if="!showUsageLoadingMessage && !usageErrorMessage && noteMessage"
          class="text-xs text-n-amber-11 bg-n-amber-2 border border-n-amber-7 rounded-md px-3 py-2"
        >
          {{ noteMessage }}
        </p>

        <div class="flex flex-row justify-end w-full gap-2">
          <Button
            faded
            slate
            type="reset"
            :label="$t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT')"
            @click.prevent="emit('close')"
          />
          <Button
            type="submit"
            :label="primaryButtonLabel"
            :disabled="
              v$.$invalid ||
              uiFlags.isCreating ||
              isPurchasingExtraSeat ||
              isSeatInfoLoading
            "
            :is-loading="uiFlags.isCreating || isPurchasingExtraSeat"
          />
        </div>
      </div>
    </form>

    <!-- Help text for onboarding mode -->
    <div
      v-if="route.name === 'settings_inboxes_invite_team'"
      class="mt-4 text-sm text-slate-500 dark:text-slate-400"
    >
      <p>
        {{ $t('AGENT_MGMT.ADD.INVITATION_DESC') }}
      </p>
    </div>
  </div>
</template>
