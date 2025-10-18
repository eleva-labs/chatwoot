<script setup>
import { computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import WorkflowCanvas from '@/components-next/Workflows/WorkflowCanvas.vue';

const props = defineProps({
  botId: {
    type: [Number, String],
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const workflow = computed(() => store.getters['workflows/getWorkflow']);
const isLoading = computed(() => store.getters['workflows/isLoading']);
const hasError = computed(() => store.getters['workflows/hasError']);

const loadWorkflow = async () => {
  await store.dispatch('workflows/fetchDefaultWorkflow', {
    botId: props.botId,
  });
};

onMounted(() => {
  loadWorkflow();
});
</script>

<template>
  <div class="workflows-tab min-h-96">
    <!-- Loading State -->
    <div
      v-if="isLoading"
      class="flex flex-col items-center justify-center h-96"
    >
      <div
        class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"
      />
      <p class="mt-4 text-slate-600">{{ t('WORKFLOWS.LOADING') }}</p>
    </div>

    <!-- Error State -->
    <div
      v-else-if="hasError"
      class="flex flex-col items-center justify-center h-96"
    >
      <div class="text-center">
        <svg
          class="mx-auto h-12 w-12 text-red-500 mb-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <p class="text-red-600 mb-4">{{ t('WORKFLOWS.ERROR') }}</p>
        <button
          class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
          @click="loadWorkflow"
        >
          {{ t('WORKFLOWS.RETRY') }}
        </button>
      </div>
    </div>

    <!-- Success State - Show Canvas -->
    <div v-else-if="workflow" class="h-96">
      <WorkflowCanvas :workflow="workflow" />
    </div>

    <!-- Empty State -->
    <div v-else class="flex flex-col items-center justify-center h-96">
      <svg
        class="mx-auto h-12 w-12 text-slate-400 mb-4"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
        />
      </svg>
      <p class="text-slate-500">{{ t('WORKFLOWS.NO_WORKFLOW') }}</p>
    </div>
  </div>
</template>
