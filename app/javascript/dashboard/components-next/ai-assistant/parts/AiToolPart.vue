<script setup>
/**
 * AiToolPart.vue
 *
 * Displays tool call details (input/output) in a collapsible panel.
 * Uses AiCollapsiblePart for consistent styling and behavior.
 * Shows state-based icons and colors (pending=slate, complete=teal, error=ruby).
 */
import { computed } from 'vue';
import { useAiI18n } from '../i18n/aiChatI18n';
import { deriveToolDisplayState, isToolComplete, isToolFailed } from '../types';
import { formatToolName } from '../utils/formatHelpers';
import AiCollapsiblePart from './AiCollapsiblePart.vue';

const props = defineProps({
  part: { type: Object, required: true },
  isStreaming: { type: Boolean, default: false },
});

const { t } = useAiI18n();

const displayState = computed(() => deriveToolDisplayState(props.part));

const stateConfig = computed(() => {
  const state = displayState.value;
  if (isToolFailed(state)) {
    return { icon: 'i-lucide-x-circle', accent: 'ruby' };
  }
  if (isToolComplete(state)) {
    return { icon: 'i-lucide-check-circle', accent: 'teal' };
  }
  return { icon: 'i-lucide-wrench', accent: 'slate' };
});

const toolName = computed(
  () => props.part?.toolName || props.part?.output?.tool_name || ''
);
const displayName = computed(() =>
  formatToolName(toolName.value, t('AI_CHAT.TOOL.LABEL'))
);
const hasInput = computed(() => props.part?.input);
const hasOutput = computed(() => props.part?.output);

const label = computed(() => displayName.value);
</script>

<template>
  <AiCollapsiblePart
    :icon="stateConfig.icon"
    :label="label"
    :accent-color="stateConfig.accent"
    :is-streaming="isStreaming"
    :auto-expand-on-stream="false"
  >
    <div v-if="hasInput" class="mb-3">
      <div
        class="text-xs font-medium text-n-slate-10 mb-1.5 uppercase tracking-wide"
      >
        {{ t('AI_CHAT.TOOL.INPUT_LABEL') }}
      </div>
      <pre
        class="text-xs text-n-slate-12 whitespace-pre-wrap break-words bg-n-alpha-2 rounded-lg p-3 font-mono"
        >{{ JSON.stringify(part.input, null, 2) }}
      </pre>
    </div>
    <div v-if="hasOutput">
      <div
        class="text-xs font-medium text-n-slate-10 mb-1.5 uppercase tracking-wide"
      >
        {{ t('AI_CHAT.TOOL.OUTPUT_LABEL') }}
      </div>
      <pre
        class="text-xs text-n-slate-12 whitespace-pre-wrap break-words bg-n-alpha-2 rounded-lg p-3 font-mono"
        >{{ JSON.stringify(part.output, null, 2) }}
      </pre>
    </div>
  </AiCollapsiblePart>
</template>
