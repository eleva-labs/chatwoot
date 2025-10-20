<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';

import SettingsLayout from 'dashboard/routes/dashboard/settings/SettingsLayout.vue';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import AIEmployeeCard from './components/AIEmployeeCard.vue';
import CreateAIEmployeeModal from './components/CreateAIEmployeeModal.vue';

const router = useRouter();
const store = useStore();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const aiEmployees = useMapGetter('agentBots/getBots');
const uiFlags = useMapGetter('agentBots/getUIFlags');
const showCreateModal = ref(false);
const selectedEmployee = ref(null);
const deleteDialogRef = ref(null);

const deleteMessage = computed(() =>
  t('AI_EMPLOYEES.DELETE.MESSAGE', { name: selectedEmployee.value?.name || '' })
);

const openCreateModal = () => {
  showCreateModal.value = true;
};

const navigateToDetail = id => {
  router.push(accountScopedRoute('ai_employees_show', { id }));
};

const openDeleteDialog = employee => {
  selectedEmployee.value = employee;
  deleteDialogRef.value.open();
};

const confirmDeletion = async () => {
  try {
    await store.dispatch('agentBots/delete', selectedEmployee.value.id);
    useAlert(t('AI_EMPLOYEES.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(t('AI_EMPLOYEES.DELETE.ERROR'));
  } finally {
    selectedEmployee.value = null;
    deleteDialogRef.value.close();
  }
};

const handleEmployeeCreated = employeeId => {
  showCreateModal.value = false;
  navigateToDetail(employeeId);
};

onMounted(() => {
  store.dispatch('agentBots/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('AI_EMPLOYEES.LIST.LOADING')"
    :no-records-found="!aiEmployees.length"
    :no-records-message="$t('AI_EMPLOYEES.LIST.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('AI_EMPLOYEES.HEADER')"
        :description="$t('AI_EMPLOYEES.DESCRIPTION')"
        feature-name="ai_employees"
      >
        <template #actions>
          <Button
            icon="i-lucide-circle-plus"
            :label="$t('AI_EMPLOYEES.ADD_BUTTON')"
            @click="openCreateModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <AIEmployeeCard
          v-for="employee in aiEmployees"
          :key="employee.id"
          :employee="employee"
          @configure="navigateToDetail(employee.id)"
          @delete="openDeleteDialog(employee)"
        />
      </div>
    </template>

    <CreateAIEmployeeModal
      v-if="showCreateModal"
      @created="handleEmployeeCreated"
      @close="showCreateModal = false"
    />

    <Dialog
      ref="deleteDialogRef"
      type="confirm"
      :title="$t('AI_EMPLOYEES.DELETE.TITLE')"
      :description="deleteMessage"
      :confirm-text="$t('AI_EMPLOYEES.DELETE.CONFIRM')"
      :reject-text="$t('AI_EMPLOYEES.DELETE.CANCEL')"
      @confirm="confirmDeletion"
    />
  </SettingsLayout>
</template>
