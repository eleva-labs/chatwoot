<script setup>
/**
 * AiVoiceButton.vue
 *
 * Voice input button for AI chat. Handles recording states and visual feedback.
 *
 * States:
 * - idle: Default state, mic icon
 * - recording: Red pulsing, shows timer
 * - transcribing: Loading spinner
 * - error: Error state with retry option
 * - disabled: Grayed out, not clickable
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { VOICE_INPUT_STATUS } from '../constants';

const props = defineProps({
  status: { type: String, default: VOICE_INPUT_STATUS.DISABLED },
  duration: { type: Number, default: 0 },
  disabled: { type: Boolean, default: true },
});

const emit = defineEmits(['click']);

const { t } = useI18n();

const isRecording = computed(
  () => props.status === VOICE_INPUT_STATUS.RECORDING
);
const isTranscribing = computed(
  () => props.status === VOICE_INPUT_STATUS.TRANSCRIBING
);
const isDisabled = computed(
  () => props.disabled || props.status === VOICE_INPUT_STATUS.DISABLED
);

const buttonLabel = computed(() => {
  if (isDisabled.value) return t('AI_CHAT.VOICE_INPUT.COMING_SOON');
  if (isRecording.value) return t('AI_CHAT.VOICE_INPUT.STOP');
  if (isTranscribing.value) return t('AI_CHAT.VOICE_INPUT.TRANSCRIBING');
  return t('AI_CHAT.VOICE_INPUT.START');
});

const iconClass = computed(() => {
  if (isTranscribing.value) return 'i-lucide-loader-2 animate-spin';
  if (isRecording.value) return 'i-lucide-square';
  return 'i-lucide-mic';
});

const buttonClass = computed(() => {
  const base =
    'flex items-center justify-center h-9 flex-shrink-0 rounded-lg transition-colors';

  if (isDisabled.value) {
    return `${base} w-9 border border-n-weak bg-n-solid-2 text-n-slate-9 opacity-50 cursor-not-allowed`;
  }
  if (isRecording.value) {
    return `${base} gap-1.5 px-3 bg-n-ruby-9 text-white hover:bg-n-ruby-10`;
  }
  if (isTranscribing.value) {
    return `${base} w-9 bg-n-amber-9 text-white`;
  }
  return `${base} w-9 border border-n-weak bg-n-solid-2 text-n-slate-11 hover:bg-n-solid-3 hover:text-n-slate-12`;
});

const formatDuration = seconds => {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
};

const handleClick = () => {
  if (isDisabled.value) return;
  emit('click');
};
</script>

<template>
  <button
    type="button"
    :disabled="isDisabled"
    :aria-label="buttonLabel"
    :title="buttonLabel"
    :class="buttonClass"
    @click="handleClick"
  >
    <!-- Recording indicator -->
    <span
      v-if="isRecording"
      class="size-2 rounded-full bg-white animate-pulse"
    />

    <!-- Duration display when recording -->
    <span v-if="isRecording" class="text-xs font-medium tabular-nums">
      {{ formatDuration(duration) }}
    </span>

    <!-- Icon -->
    <span class="size-4" :class="[iconClass]" />
  </button>
</template>
