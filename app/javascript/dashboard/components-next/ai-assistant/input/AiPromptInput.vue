<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  disabled: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
  placeholder: { type: String, default: null },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const inputText = ref('');
const textareaRef = ref(null);

const placeholderText = computed(
  () => props.placeholder || t('AI_CHAT.INPUT.PLACEHOLDER')
);

const isDisabled = computed(() => props.disabled || props.isLoading);

const handleSubmit = () => {
  const text = inputText.value.trim();
  if (!text || isDisabled.value) return;

  emit('submit', text);
  inputText.value = '';

  // Reset textarea height
  if (textareaRef.value) {
    textareaRef.value.style.height = 'auto';
  }
};

const handleKeydown = e => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    handleSubmit();
  }
};

const handleInput = () => {
  // Auto-resize textarea
  if (textareaRef.value) {
    textareaRef.value.style.height = 'auto';
    textareaRef.value.style.height = `${textareaRef.value.scrollHeight}px`;
  }
};
</script>

<template>
  <div class="p-4 border-t border-n-weak bg-n-solid-1">
    <form class="flex items-start gap-2" @submit.prevent="handleSubmit">
      <textarea
        ref="textareaRef"
        v-model="inputText"
        :placeholder="placeholderText"
        :disabled="isDisabled"
        rows="1"
        :aria-label="placeholderText"
        class="flex-1 resize-none rounded-lg border border-n-weak bg-n-solid-2 px-3 h-9 min-h-9 text-sm text-n-slate-12 placeholder-n-slate-9 focus:border-n-brand focus:outline-none focus:ring-1 focus:ring-n-brand disabled:opacity-50 disabled:cursor-not-allowed max-h-32"
        @keydown="handleKeydown"
        @input="handleInput"
      />

      <button
        type="submit"
        :disabled="isDisabled || !inputText.trim()"
        :aria-label="t('AI_CHAT.INPUT.SEND')"
        class="flex items-center justify-center h-9 w-9 flex-shrink-0 rounded-lg bg-n-brand text-white hover:enabled:brightness-110 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        <span v-if="isLoading" class="i-lucide-loader-2 size-4 animate-spin" />
        <span v-else class="i-lucide-send size-4" />
      </button>
    </form>
  </div>
</template>
