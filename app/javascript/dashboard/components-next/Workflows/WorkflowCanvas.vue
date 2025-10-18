<script setup>
import { computed, markRaw, onMounted, ref } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { transformStageGraphToVueFlow } from 'dashboard/helper/workflowTransformer';
import StageNode from './nodes/StageNode.vue';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';

const props = defineProps({
  workflow: {
    type: Object,
    required: true,
  },
});

// Register custom node types (use markRaw to avoid reactivity overhead)
const nodeTypes = {
  stageNode: markRaw(StageNode),
};

// Track if pane is ready
const isPaneReady = ref(false);

// Transform workflow data to Vue Flow format
const flowData = computed(() => {
  if (!props.workflow) {
    return { nodes: [], edges: [] };
  }
  return transformStageGraphToVueFlow(props.workflow);
});

// Only expose nodes/edges after pane is ready
const nodes = computed(() => {
  if (!isPaneReady.value) {
    return [];
  }
  const n = flowData.value.nodes;
  // eslint-disable-next-line no-console
  console.log(
    '[VueFlow] Rendering nodes:',
    n.map(node => ({
      id: node.id,
      position: node.position,
      type: node.type,
    }))
  );
  return n;
});

const edges = computed(() => {
  if (!isPaneReady.value) {
    return [];
  }
  const e = flowData.value.edges;
  // eslint-disable-next-line no-console
  console.log('[VueFlow] Rendering edges count:', e.length);
  // eslint-disable-next-line no-console
  console.log('[VueFlow] Rendering edges:', e);
  return e;
});

// Vue Flow composable
const { fitView, onPaneReady } = useVueFlow();

// Auto-fit view when pane is ready
onMounted(() => {
  onPaneReady(() => {
    isPaneReady.value = true;

    // Wait for nodes to render and be measured before fitting view
    setTimeout(() => {
      fitView({ padding: 0.2, duration: 300 });
    }, 100);
  });
});
</script>

<template>
  <div
    class="workflow-canvas w-full h-full min-h-[600px] bg-n-slate-2 border border-weak rounded-lg overflow-hidden"
  >
    <VueFlow
      :nodes="nodes"
      :edges="edges"
      :node-types="nodeTypes"
      :min-zoom="0.2"
      :max-zoom="4"
      :default-viewport="{ x: 0, y: 0, zoom: 1 }"
      class="h-full"
    >
      <!-- Background grid with theme-aware color -->
      <Background pattern-color="rgb(var(--slate-6))" :gap="16" :size="1" />

      <!-- Zoom controls -->
      <Controls show-zoom show-fit-view :show-interactive="false" />
    </VueFlow>
  </div>
</template>

<style>
/* Vue Flow Container - Use Tailwind CSS variables */
.workflow-canvas .vue-flow {
  background: rgb(var(--slate-2));
  height: 100%;
  min-height: 600px;
  position: relative;
}

.workflow-canvas .vue-flow__viewport {
  position: relative;
}

/* Ensure proper stacking order */
.workflow-canvas .vue-flow__edges {
  z-index: 1 !important;
}

.workflow-canvas .vue-flow__nodes {
  z-index: 2 !important;
}

/* Edges - Use CSS variables for theme support */
.workflow-canvas .vue-flow__edge {
  z-index: 1;
  pointer-events: all;
  visibility: visible !important;
  opacity: 1 !important;
}

.workflow-canvas .vue-flow__edge-path {
  stroke: rgb(var(--amber-9)) !important;
  stroke-width: 4 !important;
  stroke-linecap: round;
  fill: none;
}

.workflow-canvas .vue-flow__edge.selected .vue-flow__edge-path {
  stroke: rgb(var(--iris-9));
  stroke-width: 4;
}

/* Animated edges (for conditions) */
.workflow-canvas .vue-flow__edge.animated .vue-flow__edge-path {
  stroke-dasharray: 5;
  animation: dashdraw 0.5s linear infinite;
}

@keyframes dashdraw {
  from {
    stroke-dashoffset: 10;
  }
  to {
    stroke-dashoffset: 0;
  }
}

/* Edge Labels - Amber badges */
.workflow-canvas .vue-flow__edge-text {
  font-size: 13px;
  font-weight: 700;
  fill: rgb(var(--slate-12));
}

.workflow-canvas .vue-flow__edge-textbg {
  fill: rgb(var(--amber-4));
  stroke: rgb(var(--amber-9));
  stroke-width: 2;
  rx: 10;
}

/* Connection Handles */
.workflow-canvas .vue-flow__handle {
  width: 12px;
  height: 12px;
  background: rgb(var(--iris-9)) !important;
  border: 2px solid rgb(var(--slate-1)) !important;
  border-radius: 50%;
  position: absolute !important;
  z-index: 1000 !important;
  pointer-events: all !important;
}

.workflow-canvas .vue-flow__handle:hover {
  background: rgb(var(--iris-10));
  transform: scale(1.2);
}

/* Controls - Use Tailwind-compatible styles */
.workflow-canvas .vue-flow__controls {
  display: flex;
  flex-direction: column;
  gap: 8px;
  bottom: 24px;
  left: 24px;
}

.workflow-canvas .vue-flow__controls button {
  background: rgb(var(--slate-1));
  border: 1px solid rgb(var(--slate-7));
  border-radius: 8px;
  padding: 8px;
  width: 36px;
  height: 36px;
}

.workflow-canvas .vue-flow__controls button:hover {
  background: rgb(var(--slate-3));
  border-color: rgb(var(--iris-9));
}

.workflow-canvas .vue-flow__controls button svg {
  color: rgb(var(--slate-11));
}
</style>
