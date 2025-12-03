<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TOOL_STATES } from '../constants';

const props = defineProps({
  part: { type: Object, required: true },
});

const { t } = useI18n();
const showDetails = ref(false);

const toolName = computed(() => props.part?.toolName || 'Tool');

const status = computed(() => {
  const partType = props.part?.type;
  if (partType === TOOL_STATES.INPUT_START) return 'pending';
  if (partType === TOOL_STATES.INPUT_AVAILABLE) return 'running';
  if (partType === TOOL_STATES.OUTPUT_AVAILABLE) return 'completed';
  if (partType === TOOL_STATES.OUTPUT_ERROR) return 'error';
  return 'pending';
});

const statusConfig = computed(
  () =>
    ({
      pending: {
        icon: 'i-lucide-clock',
        label: t('AI_CHAT.TOOL.PREPARING'),
        class: 'text-n-slate-9',
      },
      running: {
        icon: 'i-lucide-loader-2 animate-spin',
        label: t('AI_CHAT.TOOL.RUNNING'),
        class: 'text-woot-500',
      },
      completed: {
        icon: 'i-lucide-check-circle',
        label: t('AI_CHAT.TOOL.COMPLETED'),
        class: 'text-green-500',
      },
      error: {
        icon: 'i-lucide-x-circle',
        label: t('AI_CHAT.TOOL.ERROR'),
        class: 'text-red-500',
      },
    })[status.value]
);

const hasInput = computed(() => props.part?.input);
const hasOutput = computed(() => props.part?.output);
</script>

<template>
  <div
    class="my-2 rounded-lg border border-n-weak bg-n-alpha-1 overflow-hidden"
  >
    <button
      class="flex w-full items-center gap-2 px-3 py-2 text-sm hover:bg-n-alpha-2"
      @click="showDetails = !showDetails"
    >
      <span class="size-4" :class="[statusConfig.icon, statusConfig.class]" />
      <span class="font-medium text-n-slate-12">{{ toolName }}</span>
      <span class="text-xs" :class="[statusConfig.class]">{{
        statusConfig.label
      }}</span>
      <span
        class="i-lucide-chevron-down size-4 ml-auto text-n-slate-9 transition-transform"
        :class="{ 'rotate-180': showDetails }"
      />
    </button>

    <div
      v-if="showDetails"
      class="border-t border-n-weak overflow-hidden transition-all duration-200 ease-in-out"
    >
      <div v-if="hasInput" class="px-3 py-2 border-b border-n-weak">
        <div class="text-xs font-medium text-n-slate-10 mb-1">
          {{ t('AI_CHAT.TOOL.INPUT_LABEL') }}
        </div>
        <pre class="text-xs text-n-slate-11 overflow-x-auto">{{
          JSON.stringify(part.input, null, 2)
        }}</pre>
      </div>
      <div v-if="hasOutput" class="px-3 py-2">
        <div class="text-xs font-medium text-n-slate-10 mb-1">
          {{ t('AI_CHAT.TOOL.OUTPUT_LABEL') }}
        </div>
        <pre class="text-xs text-n-slate-11 overflow-x-auto">{{
          JSON.stringify(part.output, null, 2)
        }}</pre>
      </div>
    </div>
  </div>
</template>
