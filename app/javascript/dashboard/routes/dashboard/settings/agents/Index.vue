<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onMounted, ref } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
import { useI18n } from 'vue-i18n';
import {
  useStoreGetters,
  useStore,
  useMapGetter,
} from 'dashboard/composables/store';

import AddAgent from './AddAgent.vue';
import EditAgent from './EditAgent.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
import { useAgentSeatLimits } from './composables/useAgentSeatLimits';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const agentAPI = ref({ message: '' });
const currentAgent = ref({});
const isPreviewingRemoval = ref(false);
const removalPreview = ref(null);
const removalError = ref(null);
const confirmationModal = ref(null);

// Use the shared composable for seat limits
const {
  isLoading: seatInfoLoading,
  includedLimit,
  includedUsage,
  extraSeatsUsed,
  extraSeatsPurchased,
  hasLoadedData,
  fetchLimits,
  fetchAddOns,
} = useAgentSeatLimits(store);

const deleteConfirmText = computed(
  () => `${t('AGENT_MGMT.DELETE.CONFIRM.YES')} ${currentAgent.value.name}`
);
const deleteRejectText = computed(() => {
  return `${t('AGENT_MGMT.DELETE.CONFIRM.NO')} ${currentAgent.value.name}`;
});
const agentList = computed(() => getters['agents/getAgents'].value);
const uiFlags = computed(() => getters['agents/getUIFlags'].value);
const currentUserId = computed(() => getters.getCurrentUserID.value);
const customRoles = useMapGetter('customRole/getCustomRoles');

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('customRole/getCustomRole');
});

const findCustomRole = agent =>
  customRoles.value.find(role => role.id === agent.custom_role_id);

const getAgentRoleName = agent => {
  if (!agent.custom_role_id) {
    return t(`AGENT_MGMT.AGENT_TYPES.${agent.role.toUpperCase()}`);
  }
  const customRole = findCustomRole(agent);
  return customRole ? customRole.name : '';
};

const getAgentRolePermissions = agent => {
  if (!agent.custom_role_id) {
    return [];
  }
  const customRole = findCustomRole(agent);
  return customRole?.permissions || [];
};

const verifiedAdministrators = computed(() => {
  return agentList.value.filter(
    agent => agent.role === 'administrator' && agent.confirmed
  );
});

const seatInfoLoadingState = computed(() => {
  return !hasLoadedData.value && seatInfoLoading.value;
});

const includedUsageDisplay = computed(() => {
  return `${includedUsage.value}/${includedLimit.value}`;
});

const extraMembersDisplay = computed(() => {
  return `+${extraSeatsPurchased.value || 0}`;
});

const showEditAction = agent => {
  return currentUserId.value !== agent.id;
};

const showDeleteAction = agent => {
  if (currentUserId.value === agent.id) {
    return false;
  }

  if (!agent.confirmed) {
    return true;
  }

  if (agent.role === 'administrator') {
    return verifiedAdministrators.value.length !== 1;
  }
  return true;
};

const showAlertMessage = message => {
  loading.value[currentAgent.value.id] = false;
  currentAgent.value = {};
  agentAPI.value.message = message;
  useAlert(message);
};

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = agent => {
  showEditPopup.value = true;
  currentAgent.value = agent;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const fetchRemovalPreview = async () => {
  try {
    isPreviewingRemoval.value = true;
    removalError.value = null;

    const response = await store.dispatch('accounts/previewAddOnRemoval', {
      add_on_type: 'agent',
      action: 'remove',
    });

    if (response?.data) {
      removalPreview.value = {
        estimated_credit: response.data.estimated_credit || null,
        details: response.data.details || null,
      };
    }
  } catch (error) {
    removalError.value = error?.message || 'Preview failed';
  } finally {
    isPreviewingRemoval.value = false;
  }
};

const confirmationTitle = computed(() => {
  return t('AGENT_MGMT.DELETE.CONFIRM.TITLE');
});

const confirmationDescription = computed(() => {
  return `${t('AGENT_MGMT.DELETE.CONFIRM.MESSAGE')} ${
    currentAgent.value.name || ''
  }?`;
});

const confirmationDetails = computed(() => {
  const details = [];

  if (extraSeatsUsed.value > 0 && removalPreview.value?.estimated_credit) {
    details.push(
      t('AGENT_MGMT.DELETE.EXTRA_CONFIRM', {
        credit: removalPreview.value.estimated_credit,
      })
    );
  } else if (extraSeatsUsed.value > 0 && removalError.value) {
    details.push(t('AGENT_MGMT.DELETE.EXTRA_CONFIRM_FALLBACK'));
  }

  return details;
});

const removeExtraAgentSeat = async () => {
  try {
    await store.dispatch('accounts/purchaseAddOn', {
      add_on_type: 'agent',
      action: 'remove',
    });
    return true;
  } catch (error) {
    useAlert(t('AGENT_MGMT.DELETE.CONFIRM.EXTRA_REMOVE_ERROR'));
    return false;
  }
};

const deleteAgent = async (id, hadExtraSeat) => {
  try {
    await store.dispatch('agents/delete', id);

    // If this was an extra seat removal, refresh limits
    if (hadExtraSeat) {
      await removeExtraAgentSeat();
      await Promise.all([fetchLimits(true), fetchAddOns(true)]);
    }

    showAlertMessage(t('AGENT_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    showAlertMessage(t('AGENT_MGMT.DELETE.API.ERROR_MESSAGE'));
  } finally {
    // Reset preview state
    removalPreview.value = null;
    removalError.value = null;
  }
};

const confirmDeletion = async () => {
  loading.value[currentAgent.value.id] = true;
  const hadExtraSeat = extraSeatsUsed.value > 0;
  await deleteAgent(currentAgent.value.id, hadExtraSeat);
  loading.value[currentAgent.value.id] = false;
  currentAgent.value = {};
};

const openDeletePopup = async agent => {
  currentAgent.value = agent;
  removalPreview.value = null;
  removalError.value = null;

  // Check if this is an extra seat removal
  const isExtraSeatRemoval = extraSeatsUsed.value > 0;

  if (isExtraSeatRemoval) {
    // Fetch preview before showing modal
    await fetchRemovalPreview();
  }

  // Show confirmation modal
  const confirmed = await confirmationModal.value.showConfirmation();

  if (confirmed) {
    await confirmDeletion();
  } else {
    currentAgent.value = {};
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('AGENT_MGMT.LOADING')"
    :no-records-found="!agentList.length"
    :no-records-message="$t('AGENT_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('AGENT_MGMT.HEADER')"
        :description="$t('AGENT_MGMT.DESCRIPTION')"
        :link-text="$t('AGENT_MGMT.LEARN_MORE')"
        feature-name="agents"
      >
        <template #actions>
          <Button
            icon="i-lucide-circle-plus"
            :label="$t('AGENT_MGMT.HEADER_BTN_TXT')"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #preBody>
      <section class="mb-6">
        <div class="rounded-lg border border-n-weak bg-n-solid-2 p-4 shadow-sm">
          <h3 class="text-base font-semibold text-n-slate-12 mb-3">
            {{ $t('AGENT_MGMT.USAGE_SUMMARY.TITLE') }}
          </h3>
          <p v-if="seatInfoLoadingState" class="text-sm text-n-slate-11">
            {{ $t('AGENT_MGMT.ADD.USAGE_LOADING') }}
          </p>
          <div
            v-else
            class="grid grid-cols-1 gap-3 sm:grid-cols-2"
            data-testid="members-usage-summary"
          >
            <div class="bg-n-solid-1 rounded-md border border-n-weak p-3">
              <p class="text-xs text-n-slate-11 mb-1">
                {{ $t('AGENT_MGMT.ADD.USAGE_TITLE') }}
              </p>
              <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
                {{ includedUsageDisplay }}
              </p>
            </div>
            <div class="bg-n-solid-1 rounded-md border border-n-weak p-3">
              <p class="text-xs text-n-slate-11 mb-1">
                {{ $t('AGENT_MGMT.ADD.EXTRA_TITLE') }}
              </p>
              <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
                {{ extraMembersDisplay }}
              </p>
            </div>
          </div>
        </div>
      </section>
    </template>
    <template #body>
      <table class="divide-y divide-n-weak">
        <tbody class="divide-y divide-n-weak text-n-slate-11">
          <tr v-for="(agent, index) in agentList" :key="agent.email">
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <div class="flex flex-row items-center gap-4">
                <Avatar
                  :src="agent.thumbnail"
                  :name="agent.name"
                  :status="agent.availability_status"
                  :size="40"
                  hide-offline-status
                  rounded-full
                />
                <div>
                  <span class="block font-medium capitalize">
                    {{ agent.name }}
                  </span>
                  <span>{{ agent.email }}</span>
                </div>
              </div>
            </td>

            <td class="relative py-4 ltr:pr-4 rtl:pl-4">
              <span
                class="block font-medium w-fit"
                :class="{
                  'hover:text-gray-900 group cursor-pointer':
                    agent.custom_role_id,
                }"
              >
                {{ getAgentRoleName(agent) }}

                <div
                  class="absolute left-0 z-10 hidden max-w-[300px] w-auto bg-white rounded-xl border border-n-weak shadow-lg top-14 md:top-12 dark:bg-n-solid-2"
                  :class="{ 'group-hover:block': agent.custom_role_id }"
                >
                  <div class="flex flex-col gap-1 p-4">
                    <span class="font-semibold">
                      {{ $t('AGENT_MGMT.LIST.AVAILABLE_CUSTOM_ROLE') }}
                    </span>
                    <ul class="pl-4 mb-0 list-disc">
                      <li
                        v-for="permission in getAgentRolePermissions(agent)"
                        :key="permission"
                        class="font-normal"
                      >
                        {{
                          $t(
                            `CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`
                          )
                        }}
                      </li>
                    </ul>
                  </div>
                </div>
              </span>
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <span v-if="agent.confirmed">
                {{ $t('AGENT_MGMT.LIST.VERIFIED') }}
              </span>
              <span v-if="!agent.confirmed">
                {{ $t('AGENT_MGMT.LIST.VERIFICATION_PENDING') }}
              </span>
            </td>
            <td class="py-4">
              <div class="flex justify-end gap-1">
                <Button
                  v-if="showEditAction(agent)"
                  v-tooltip.top="$t('AGENT_MGMT.EDIT.BUTTON_TEXT')"
                  icon="i-lucide-pen"
                  slate
                  xs
                  faded
                  @click="openEditPopup(agent)"
                />
                <Button
                  v-if="showDeleteAction(agent)"
                  v-tooltip.top="$t('AGENT_MGMT.DELETE.BUTTON_TEXT')"
                  icon="i-lucide-trash-2"
                  xs
                  ruby
                  faded
                  :is-loading="loading[agent.id]"
                  @click="openDeletePopup(agent, index)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddAgent @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditAgent
        v-if="showEditPopup"
        :id="currentAgent.id"
        :name="currentAgent.name"
        :type="currentAgent.role"
        :email="currentAgent.email"
        :availability="currentAgent.availability_status"
        :custom-role-id="currentAgent.custom_role_id"
        @close="hideEditPopup"
      />
    </woot-modal>

    <!-- Confirmation Modal for deletion with preview -->
    <ConfirmationModal
      ref="confirmationModal"
      :title="confirmationTitle"
      :description="confirmationDescription"
      :details="confirmationDetails"
      :confirm-label="deleteConfirmText"
      :cancel-label="deleteRejectText"
    />
  </SettingsLayout>
</template>
