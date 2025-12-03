<script setup>
import { computed } from 'vue';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';

const props = defineProps({
  part: { type: Object, required: true },
  role: { type: String, required: true },
  isStreaming: { type: Boolean, default: false },
});

// The adapter now handles deep cloning during streaming,
// so props.part.text will be reactive
const text = computed(() => props.part?.text || '');

const formattedContent = computed(() => {
  return new MessageFormatter(text.value).formattedMessage;
});

const showCursor = computed(
  () => props.isStreaming && props.role === 'assistant'
);
</script>

<template>
  <div class="ai-text-part">
    <span v-dompurify-html="formattedContent" class="prose prose-bubble" />
    <span
      v-if="showCursor"
      class="inline-block w-2 h-4 ml-0.5 bg-n-slate-11 animate-pulse"
    />
  </div>
</template>
