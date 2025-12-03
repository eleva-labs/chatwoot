<script setup>
import { computed, defineAsyncComponent } from 'vue';
import { PART_TYPES } from '../constants';

import AiTextPart from './AiTextPart.vue';
const props = defineProps({
  part: { type: Object, required: true },
  role: { type: String, required: true },
  isStreaming: { type: Boolean, default: false },
});
// Lazy load less common parts
const AiReasoningPart = defineAsyncComponent(
  () => import('./AiReasoningPart.vue')
);
const AiToolPart = defineAsyncComponent(() => import('./AiToolPart.vue'));

const partTypeMap = {
  [PART_TYPES.TEXT]: AiTextPart,
  [PART_TYPES.REASONING]: AiReasoningPart,
};

const component = computed(() => {
  const partType = props.part?.type;

  // Handle tool parts
  if (partType?.startsWith('tool-')) {
    return AiToolPart;
  }

  return partTypeMap[partType] || null;
});
</script>

<template>
  <component
    :is="component"
    v-if="component"
    :part="part"
    :role="role"
    :is-streaming="isStreaming"
  />
</template>
