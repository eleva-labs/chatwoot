<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { TAB_INDICES } from './constants';

import SettingIntroBanner from 'dashboard/components/widgets/SettingIntroBanner.vue';
import GeneralTab from './tabs/GeneralTab.vue';
import WorkflowsTab from './tabs/WorkflowsTab.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  employeeId: {
    type: [String, Number],
    required: true,
  },
});
const router = useRouter();
const store = useStore();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const selectedTabIndex = ref(TAB_INDICES.GENERAL);
const deleteDialogRef = ref(null);

const aiEmployees = useMapGetter('agentBots/getBots');
const uiFlags = useMapGetter('agentBots/getUIFlags');

const employee = computed(
  () => aiEmployees.value.find(e => e.id === Number(props.employeeId)) || {}
);

const deleteMessage = computed(() =>
  t('AI_EMPLOYEES.DELETE.MESSAGE', { name: employee.value?.name || '' })
);

const onTabChange = index => {
  selectedTabIndex.value = index;
};

const navigateToList = () => {
  router.push(accountScopedRoute('ai_employees_list'));
};

const fetchEmployee = () => {
  store.dispatch('agentBots/get');
};

const confirmDeletion = async () => {
  try {
    await store.dispatch('agentBots/delete', employee.value.id);
    useAlert(t('AI_EMPLOYEES.DELETE.SUCCESS'));
    navigateToList();
  } catch (error) {
    useAlert(t('AI_EMPLOYEES.DELETE.ERROR'));
  } finally {
    deleteDialogRef.value.close();
  }
};

onMounted(() => {
  if (!aiEmployees.value.length) {
    fetchEmployee();
  }
});

watch(
  () => employee.value.id,
  newId => {
    if (!newId) {
      navigateToList();
    }
  },
  { immediate: true }
);
</script>

<template>
  <div
    class="overflow-auto flex-grow flex-shrink pr-0 pl-0 w-full min-w-0 settings"
  >
    <SettingIntroBanner
      :header-title="employee.name || $t('AI_EMPLOYEES.HEADER')"
      :header-content="employee.description"
    >
      <woot-tabs
        class="[&_ul]:p-0"
        :index="selectedTabIndex"
        :border="false"
        @change="onTabChange"
      >
        <woot-tabs-item
          :index="TAB_INDICES.GENERAL"
          :name="$t('AI_EMPLOYEES.TABS.GENERAL')"
          :show-badge="false"
          is-compact
        />
        <woot-tabs-item
          :index="TAB_INDICES.WORKFLOWS"
          :name="$t('AI_EMPLOYEES.TABS.WORKFLOWS')"
          :show-badge="false"
          is-compact
        />
      </woot-tabs>
    </SettingIntroBanner>
    <section class="mx-auto w-full max-w-6xl">
      <div v-if="selectedTabIndex === TAB_INDICES.GENERAL" class="mx-8">
        <GeneralTab
          :employee="employee"
          :is-loading="uiFlags.isUpdating"
          @updated="fetchEmployee"
        />
      </div>

      <div v-if="selectedTabIndex === TAB_INDICES.WORKFLOWS" class="mx-8">
        <WorkflowsTab v-if="employee.id" :bot-id="employee.id" />
      </div>
    </section>
  </div>

  <Dialog
    ref="deleteDialogRef"
    type="confirm"
    :title="$t('AI_EMPLOYEES.DELETE.TITLE')"
    :description="deleteMessage"
    :confirm-text="$t('AI_EMPLOYEES.DELETE.CONFIRM')"
    :reject-text="$t('AI_EMPLOYEES.DELETE.CANCEL')"
    @confirm="confirmDeletion"
  />
</template>
