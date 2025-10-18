<script setup>
import { computed, watch, nextTick } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { transformStageGraphToVueFlow } from 'dashboard/helper/workflowTransformer';

const props = defineProps({
  workflow: {
    type: Object,
    required: true,
  },
});

// Transform workflow data to Vue Flow format
const flowData = computed(() => {
  if (!props.workflow) {
    return { nodes: [], edges: [] };
  }
  return transformStageGraphToVueFlow(props.workflow);
});

const nodes = computed(() => flowData.value.nodes);
const edges = computed(() => flowData.value.edges);

// Vue Flow composable
const { fitView } = useVueFlow();

// Auto-fit view when nodes change
watch(
  () => nodes.value,
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

<style>
/* NOTE: @vue-flow v1.x bundles CSS with JS, no separate CSS files to import */
/* Using non-scoped styles to ensure they apply to Vue Flow components */

.workflow-canvas {
  background-color: #f1f5f9 !important;
  position: relative;
}

/* Vue Flow Container */
.workflow-canvas .vue-flow {
  background-color: #f1f5f9 !important;
}

.workflow-canvas .vue-flow__viewport {
  background-color: #f1f5f9 !important;
}

/* Nodes - Large, colorful, easy to see */
.workflow-canvas .vue-flow__node {
  padding: 20px 24px !important;
  border-radius: 12px !important;
  border: 3px solid #3b82f6 !important;
  background: linear-gradient(135deg, #ffffff 0%, #f0f9ff 100%) !important;
  min-width: 200px !important;
  max-width: 300px !important;
  box-shadow: 0 4px 16px rgba(59, 130, 246, 0.2) !important;
  font-family:
    system-ui,
    -apple-system,
    sans-serif !important;
  cursor: pointer !important;
  transition: all 0.2s ease !important;
}

.workflow-canvas .vue-flow__node:hover {
  border-color: #2563eb !important;
  box-shadow: 0 8px 24px rgba(37, 99, 235, 0.3) !important;
  transform: translateY(-2px) !important;
}

.workflow-canvas .vue-flow__node.selected {
  border-color: #1d4ed8 !important;
  box-shadow: 0 8px 32px rgba(29, 78, 216, 0.4) !important;
  background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%) !important;
}

/* Node Labels - FORCE TEXT TO SHOW */
.workflow-canvas .vue-flow__node,
.workflow-canvas .vue-flow__node *,
.workflow-canvas .vue-flow__node .label,
.workflow-canvas .vue-flow__node-label,
.workflow-canvas .vue-flow__node div,
.workflow-canvas .vue-flow__node span {
  font-size: 15px !important;
  font-weight: 600 !important;
  color: #1e293b !important;
  line-height: 1.4 !important;
  text-align: center !important;
  word-wrap: break-word !important;
  overflow: visible !important;
  white-space: normal !important;
  display: block !important;
}

/* Connection Handles - Larger and more visible */
.workflow-canvas .vue-flow__handle {
  width: 14px !important;
  height: 14px !important;
  background: #3b82f6 !important;
  border: 3px solid #ffffff !important;
  border-radius: 50% !important;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2) !important;
}

.workflow-canvas .vue-flow__handle:hover {
  background: #1d4ed8 !important;
  transform: scale(1.3) !important;
  box-shadow: 0 4px 12px rgba(29, 78, 216, 0.4) !important;
}

.workflow-canvas .vue-flow__handle-top {
  top: -7px !important;
}

.workflow-canvas .vue-flow__handle-bottom {
  bottom: -7px !important;
}

.workflow-canvas .vue-flow__handle-left {
  left: -7px !important;
}

.workflow-canvas .vue-flow__handle-right {
  right: -7px !important;
}

/* Edges - Thick, visible lines */
.workflow-canvas .vue-flow__edge-path {
  stroke: #64748b !important;
  stroke-width: 3 !important;
  stroke-linecap: round !important;
}

.workflow-canvas .vue-flow__edge.selected .vue-flow__edge-path {
  stroke: #3b82f6 !important;
  stroke-width: 4 !important;
}

.workflow-canvas .vue-flow__edge-text {
  font-size: 13px !important;
  font-weight: 500 !important;
  fill: #1e293b !important;
  background: #ffffff !important;
  padding: 4px 8px !important;
  border-radius: 4px !important;
}

.workflow-canvas .vue-flow__edge-textbg {
  fill: #ffffff !important;
  stroke: #cbd5e1 !important;
  stroke-width: 1 !important;
}

/* Controls - Larger, visible buttons */
.workflow-canvas .vue-flow__controls {
  display: flex !important;
  flex-direction: column !important;
  gap: 8px !important;
  bottom: 24px !important;
  left: 24px !important;
  z-index: 10 !important;
}

.workflow-canvas .vue-flow__controls button {
  background: #ffffff !important;
  border: 2px solid #cbd5e1 !important;
  border-radius: 8px !important;
  padding: 12px !important;
  cursor: pointer !important;
  transition: all 0.2s !important;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1) !important;
  width: 40px !important;
  height: 40px !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
}

.workflow-canvas .vue-flow__controls button:hover {
  background: #f1f5f9 !important;
  border-color: #3b82f6 !important;
  transform: translateY(-2px) !important;
  box-shadow: 0 4px 12px rgba(59, 130, 246, 0.2) !important;
}

.workflow-canvas .vue-flow__controls button svg {
  width: 20px !important;
  height: 20px !important;
  color: #475569 !important;
}

.workflow-canvas .vue-flow__controls button:hover svg {
  color: #3b82f6 !important;
}

/* Background Grid */
.workflow-canvas .vue-flow__background {
  background-color: #f1f5f9 !important;
}

.workflow-canvas .vue-flow__background-pattern {
  stroke: #cbd5e1 !important;
  stroke-width: 1 !important;
}
</style>
