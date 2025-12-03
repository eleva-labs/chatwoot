<script setup>
import { ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';

const props = defineProps({
  part: { type: Object, required: true },
  isStreaming: { type: Boolean, default: false },
});

const { t } = useI18n();
const isExpanded = ref(false);

// The adapter now handles deep cloning during streaming,
// so props.part.text will be reactive
const text = computed(() => props.part?.text || '');
const isThinking = computed(() => props.isStreaming && !text.value);

const formattedContent = computed(() => {
  return new MessageFormatter(text.value).formattedMessage;
});

// Auto-expand when streaming
watch(
  () => props.isStreaming,
  streaming => {
    if (streaming) {
      isExpanded.value = true;
    }
  },
  { immediate: true }
);

const toggleLabel = computed(() =>
  isExpanded.value ? t('AI_CHAT.REASONING.HIDE') : t('AI_CHAT.REASONING.VIEW')
);
</script>

<template>
  <div class="my-2 rounded-lg border border-n-weak bg-n-alpha-1">
    <button
      class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-11 hover:bg-n-alpha-2"
      @click="isExpanded = !isExpanded"
    >
      <span class="i-lucide-brain size-4" />
      <span v-if="isThinking">{{ t('AI_CHAT.REASONING.THINKING') }}</span>
      <span v-else>{{ toggleLabel }}</span>
      <span
        class="i-lucide-chevron-down size-4 ml-auto transition-transform"
        :class="{ 'rotate-180': isExpanded }"
      />
    </button>

    <div
      v-if="isExpanded"
      class="px-3 pb-3 overflow-hidden transition-all duration-200 ease-in-out"
    >
      <div class="text-sm text-n-slate-11 italic">
        <span v-dompurify-html="formattedContent" class="prose prose-bubble" />
        <span
          v-if="isStreaming"
          class="inline-block w-2 h-4 ml-0.5 bg-n-slate-9 animate-pulse"
        />
      </div>
    </div>
  </div>
</template>
