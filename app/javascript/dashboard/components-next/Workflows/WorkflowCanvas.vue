<script setup>
import { computed, watch, nextTick } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { transformStageGraphToVueFlow } from '@/helper/workflowTransformer';

const props = defineProps({
  workflow: {
    type: Object,
    required: true,
  },
});

// Transform workflow data to Vue Flow format
const { nodes, edges } = computed(() => {
  if (!props.workflow) {
    return { nodes: [], edges: [] };
  }
  return transformStageGraphToVueFlow(props.workflow);
});

// Vue Flow composable
const { fitView } = useVueFlow();

// Auto-fit view when nodes change
watch(
  nodes,
  () => {
    nextTick(() => {
      fitView({ padding: 0.2, duration: 300 });
    });
  },
  { immediate: true }
);
</script>

<template>
  <div
    class="workflow-canvas w-full h-full border border-slate-200 rounded-lg overflow-hidden"
  >
    <VueFlow
      :nodes="nodes"
      :edges="edges"
      fit-view-on-init
      :min-zoom="0.2"
      :max-zoom="4"
      :default-viewport="{ zoom: 1 }"
    >
      <!-- Background grid -->
      <Background pattern-color="#e2e8f0" :gap="16" :size="1" />

      <!-- Zoom controls -->
      <Controls show-zoom show-fit-view :show-interactive="false" />
    </VueFlow>
  </div>
</template>

<style scoped>
/* Import Vue Flow styles */
@import '@vue-flow/core/dist/style.css';
@import '@vue-flow/core/dist/theme-default.css';
@import '@vue-flow/controls/dist/style.css';
@import '@vue-flow/background/dist/style.css';

.workflow-canvas {
  background: #fafafa;
}
</style>
