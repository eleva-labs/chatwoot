<script setup>
/**
 * AiMessageAction.vue
 *
 * Individual action button for message actions (copy, regenerate, etc).
 * Supports disabled state for "coming soon" features.
 */
import { computed } from 'vue';

const props = defineProps({
  icon: { type: String, required: true },
  label: { type: String, required: true },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['click']);

const buttonClass = computed(() => {
  const base = 'p-1.5 rounded-md transition-colors';
  if (props.disabled) {
    return `${base} text-n-slate-9 opacity-50 cursor-not-allowed`;
  }
  return `${base} text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2`;
});

const handleClick = () => {
  if (props.disabled) return;
  emit('click');
};
</script>

<template>
  <button
    v-tooltip="label"
    type="button"
    :disabled="disabled"
    :aria-label="label"
    :class="buttonClass"
    @click="handleClick"
  >
    <span class="size-4" :class="[icon]" />
  </button>
</template>
