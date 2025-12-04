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
  <div class="rounded-xl bg-n-alpha-1/50 border border-n-weak/50">
    <button
      class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-10 hover:text-n-slate-11 transition-colors"
      @click="isExpanded = !isExpanded"
    >
      <span
        class="i-lucide-brain size-4"
        :class="{ 'animate-pulse text-n-violet-9': isThinking }"
      />
      <span v-if="isThinking" class="text-n-violet-11">{{
        t('AI_CHAT.REASONING.THINKING')
      }}</span>
      <span v-else>{{ toggleLabel }}</span>
      <span
        class="i-lucide-chevron-right size-4 ml-auto transition-transform duration-200"
        :class="{ 'rotate-90': isExpanded }"
      />
    </button>

    <div
      v-if="isExpanded"
      class="px-3 pb-3 overflow-hidden transition-all duration-200 ease-in-out"
    >
      <div
        class="text-sm text-n-slate-10 italic pl-6 border-l-2 border-n-violet-6"
      >
        <span v-dompurify-html="formattedContent" class="prose prose-bubble" />
        <span
          v-if="isStreaming"
          class="inline-block w-1.5 h-4 ml-0.5 bg-n-violet-9 animate-pulse rounded-sm"
        />
      </div>
    </div>
  </div>
</template>
