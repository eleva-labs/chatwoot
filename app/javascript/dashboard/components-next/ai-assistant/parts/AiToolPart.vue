<script setup>
/**
 * AiToolPart.vue
 *
 * Displays tool call details (input/output) in a collapsible panel.
 * Uses AiCollapsiblePart for consistent styling and behavior.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import AiCollapsiblePart from './AiCollapsiblePart.vue';

const props = defineProps({
  part: { type: Object, required: true },
  isStreaming: { type: Boolean, default: false },
});

const { t } = useI18n();

const toolName = computed(
  () => props.part?.toolName || props.part?.output?.tool_name || ''
);
const hasInput = computed(() => props.part?.input);
const hasOutput = computed(() => props.part?.output);

const label = computed(() => toolName.value || t('AI_CHAT.TOOL.LABEL'));
</script>

<template>
  <AiCollapsiblePart
    icon="i-lucide-wrench"
    :label="label"
    accent-color="slate"
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
