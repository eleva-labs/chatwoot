<script setup>
/**
 * AiReasoningPart.vue
 *
 * Displays AI reasoning/thinking content in a collapsible panel.
 * Uses AiCollapsiblePart for consistent styling and behavior.
 */
import { computed } from 'vue';
import { useAiI18n } from '../i18n/aiChatI18n';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import AiCollapsiblePart from './AiCollapsiblePart.vue';

const props = defineProps({
  part: { type: Object, required: true },
  isStreaming: { type: Boolean, default: false },
  renderMarkdown: { type: Function, default: null },
});

const { t } = useAiI18n();

const text = computed(() => props.part?.text || '');

const formattedContent = computed(() => {
  if (props.renderMarkdown) return props.renderMarkdown(text.value);
  return new MessageFormatter(text.value).formattedMessage;
});

const label = computed(() =>
  props.isStreaming
    ? t('AI_CHAT.REASONING.THINKING')
    : t('AI_CHAT.REASONING.VIEW')
);
</script>

<template>
  <AiCollapsiblePart
    icon="i-lucide-brain"
    :label="label"
    accent-color="violet"
    :is-streaming="isStreaming"
    :auto-expand-on-stream="false"
  >
    <template #default="{ accentClasses }">
      <div class="text-sm">
        <slot name="content" :text="text" :formatted="formattedContent">
          <span
            v-dompurify-html="formattedContent"
            class="prose prose-sm prose-bubble text-n-slate-12 max-w-none"
          />
        </slot>
        <span
          v-if="isStreaming"
          class="inline-block w-1.5 h-3 ml-0.5 animate-pulse rounded-sm align-middle"
          :class="accentClasses.cursor"
        />
      </div>
    </template>
  </AiCollapsiblePart>
</template>
