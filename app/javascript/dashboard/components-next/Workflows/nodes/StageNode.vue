<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { Handle, Position } from '@vue-flow/core';

const props = defineProps({
  data: {
    type: Object,
    required: true,
    validator(value) {
      return (
        typeof value.name === 'string' &&
        typeof value.initialNode === 'boolean' &&
        Array.isArray(value.requirements)
      );
    },
  },
});

const { t } = useI18n();

// Local state
const requirementsExpanded = ref(false);

// Computed properties
const hasRequirements = computed(() => {
  return props.data.requirements && props.data.requirements.length > 0;
});

const truncatedDescription = computed(() => {
  if (!props.data.description) return '';

  const maxLength = 100;
  if (props.data.description.length <= maxLength) {
    return props.data.description;
  }

  return props.data.description.substring(0, maxLength) + '...';
});

// Methods
const toggleRequirements = () => {
  requirementsExpanded.value = !requirementsExpanded.value;
};
</script>

<template>
  <div
    class="stage-node group relative"
    :class="{
      'is-initial': data.initialNode,
      'has-requirements': hasRequirements,
    }"
  >
    <!-- Connection Handles -->
    <Handle
      id="target-left"
      type="target"
      :position="Position.Left"
      connectable
    />
    <Handle
      id="source-right"
      type="source"
      :position="Position.Right"
      connectable
    />

    <!-- Node Header: Name + START badge -->
    <div class="stage-node-header">
      <div class="flex items-center gap-2">
        <!-- START badge (only for initial node) -->
        <span
          v-if="data.initialNode"
          class="start-badge inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-n-teal-9 text-white shadow-sm"
        >
          {{ t('WORKFLOWS.NODE.START_BADGE') }}
        </span>

        <!-- Node name -->
        <h3
          class="stage-node-title text-sm font-semibold text-n-slate-12 leading-tight"
        >
          {{ data.name }}
        </h3>
      </div>
    </div>

    <!-- Node Body: Description -->
    <div
      v-if="data.description"
      class="stage-node-body mt-2 text-xs text-n-slate-11 leading-relaxed"
      :title="data.description"
    >
      {{ truncatedDescription }}
    </div>

    <!-- Node Footer: Requirements -->
    <div v-if="hasRequirements" class="stage-node-footer mt-3">
      <!-- Requirements toggle button -->
      <button
        class="requirements-toggle w-full flex items-center justify-between px-2 py-1.5 rounded-md bg-n-amber-3 hover:bg-n-amber-4 transition-colors"
        :aria-expanded="requirementsExpanded"
        :aria-label="
          requirementsExpanded
            ? t('WORKFLOWS.NODE.COLLAPSE_REQUIREMENTS')
            : t('WORKFLOWS.NODE.EXPAND_REQUIREMENTS')
        "
        @click="toggleRequirements"
      >
        <span
          class="flex items-center gap-1.5 text-xs font-medium text-n-amber-11"
        >
          {{ t('WORKFLOWS.NODE.REQUIREMENTS') }}
          <span class="ml-1">({{ data.requirements.length }})</span>
        </span>
        <span
          class="chevron-icon transition-transform duration-200"
          :class="{ 'rotate-180': requirementsExpanded }"
          aria-hidden="true"
        />
      </button>

      <!-- Requirements list (expandable) -->
      <transition
        enter-active-class="transition-all duration-200 ease-out"
        enter-from-class="opacity-0 max-h-0"
        enter-to-class="opacity-100 max-h-96"
        leave-active-class="transition-all duration-200 ease-in"
        leave-from-class="opacity-100 max-h-96"
        leave-to-class="opacity-0 max-h-0"
      >
        <ul
          v-if="requirementsExpanded"
          class="requirements-list mt-2 space-y-1 max-h-48 overflow-y-auto pl-4 pr-2"
        >
          <li
            v-for="(req, idx) in data.requirements"
            :key="idx"
            class="text-xs text-n-slate-11 leading-snug list-disc list-outside"
          >
            {{ req }}
          </li>
        </ul>
      </transition>
    </div>
  </div>
</template>

<style>
/* Base node styles - Using Tailwind-compatible approach */
.stage-node {
  position: relative !important;
  @apply min-w-[240px] max-w-[320px];
  @apply px-4 py-3;
  @apply bg-n-slate-1;
  @apply border-2 border-n-slate-7;
  @apply rounded-xl;
  @apply shadow-md;
  @apply transition-all duration-200;
  @apply cursor-pointer;
}

/* Hover state */
.stage-node:hover {
  @apply border-n-iris-8;
  @apply shadow-lg;
  transform: translateY(-1px);
}

/* Initial node (START) - Teal border */
.stage-node.is-initial {
  @apply border-n-teal-9;
  border-width: 3px;
  @apply shadow-lg;
}

.stage-node.is-initial:hover {
  @apply border-n-teal-10;
}

/* Selected state (when node is clicked in Vue Flow) */
.stage-node.selected {
  @apply border-n-brand;
  border-width: 3px;
  @apply shadow-xl;
  @apply bg-n-iris-2;
}

/* Chevron icon using CSS */
.chevron-icon {
  @apply inline-block;
  width: 0;
  height: 0;
  border-left: 4px solid transparent;
  border-right: 4px solid transparent;
  border-top: 6px solid rgb(var(--amber-11));
}

/* Requirements list scrollbar */
.requirements-list::-webkit-scrollbar {
  @apply w-1.5;
}

.requirements-list::-webkit-scrollbar-track {
  @apply bg-n-slate-3 rounded;
}

.requirements-list::-webkit-scrollbar-thumb {
  @apply bg-n-slate-6 rounded;
}

.requirements-list::-webkit-scrollbar-thumb:hover {
  @apply bg-n-slate-7;
}
</style>
