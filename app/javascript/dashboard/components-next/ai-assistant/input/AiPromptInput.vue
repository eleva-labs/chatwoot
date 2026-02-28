<script setup>
import { ref, computed } from 'vue';
import { useAiI18n } from '../i18n/aiChatI18n';
import Button from 'dashboard/components-next/button/Button.vue';
import AiVoiceButton from './AiVoiceButton.vue';
import { useAutoResizeTextarea } from '../composables/useAutoResizeTextarea';
import { VOICE_INPUT_STATUS } from '../constants';

const props = defineProps({
  disabled: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
  placeholder: { type: String, default: null },
});

const emit = defineEmits(['submit']);

// Voice input is disabled for Phase 1 (visual only)
const voiceStatus = ref(VOICE_INPUT_STATUS.DISABLED);

const { t } = useAiI18n();
const inputText = ref('');

// Auto-resize textarea composable
const { textareaRef, resize, reset } = useAutoResizeTextarea();

const placeholderText = computed(
  () => props.placeholder || t('AI_CHAT.INPUT.PLACEHOLDER')
);

const isDisabled = computed(() => props.disabled || props.isLoading);
const canSubmit = computed(() => inputText.value.trim() && !isDisabled.value);

const handleSubmit = () => {
  const text = inputText.value.trim();
  if (!text || isDisabled.value) return;

  emit('submit', text);
  inputText.value = '';
  reset();
};

const handleKeydown = e => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    handleSubmit();
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
        class="flex-1 resize-none rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 h-9 min-h-9 text-sm text-n-slate-12 placeholder-n-slate-9 focus:border-n-brand focus:outline-none focus:ring-1 focus:ring-n-brand disabled:opacity-50 disabled:cursor-not-allowed max-h-32"
        @keydown="handleKeydown"
        @input="resize"
      />

      <!-- Voice input button -->
      <AiVoiceButton :status="voiceStatus" disabled />

      <!-- Submit button -->
      <slot
        name="send-button"
        :disabled="!canSubmit"
        :is-loading="isLoading"
        :label="t('AI_CHAT.INPUT.SEND')"
      >
        <Button
          type="submit"
          :disabled="!canSubmit"
          :is-loading="isLoading"
          :aria-label="t('AI_CHAT.INPUT.SEND')"
          icon="i-lucide-send"
          sm
          solid
          blue
          class="flex-shrink-0"
        />
      </slot>
    </form>
  </div>
</template>
