<script setup>
import { computed, defineAsyncComponent } from 'vue';
import { isToolPart } from '../types';
import { PART_TYPES } from '../constants';
import { usePartRegistry } from '../registry/partRegistry';

import AiTextPart from './AiTextPart.vue';

const props = defineProps({
  part: { type: Object, required: true },
  role: { type: String, required: true },
  isStreaming: { type: Boolean, default: false },
  renderMarkdown: { type: Function, default: null },
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

const registry = usePartRegistry();

const component = computed(() => {
  // 1. Check registry for exact type match
  if (registry.parts?.[props.part.type]) return registry.parts[props.part.type];
  // 2. For tool parts, check tool registry by toolName
  if (isToolPart(props.part)) {
    const toolName = props.part.toolName;
    if (toolName && registry.tools?.[toolName]) return registry.tools[toolName];
    return AiToolPart;
  }
  // 3. Hardcoded defaults
  return partTypeMap[props.part.type] || null;
});

// Only text and reasoning parts declare and use renderMarkdown
const isTextOrReasoningPart = computed(
  () =>
    props.part.type === PART_TYPES.TEXT ||
    props.part.type === PART_TYPES.REASONING
);

// Only AiTextPart declares and uses role; avoid leaking it to reasoning/tool parts
const isTextPart = computed(() => props.part.type === PART_TYPES.TEXT);
</script>

<template>
  <component
    :is="component"
    v-if="component"
    :part="part"
    :is-streaming="isStreaming"
    v-bind="{
      ...(isTextPart ? { role } : {}),
      ...(isTextOrReasoningPart ? { 'render-markdown': renderMarkdown } : {}),
    }"
  />
</template>
