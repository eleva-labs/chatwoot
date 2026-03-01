<script setup>
/**
 * AiCollapsiblePart.vue
 *
 * Base collapsible container for AI message parts (reasoning, tools, etc).
 * Provides unified styling, expand/collapse, and streaming state handling.
 */
import { watch, computed } from 'vue';
import { useToggle } from '@vueuse/core';
import { useAiI18n } from '../i18n/aiChatI18n';
import AiMessageAction from '../message/AiMessageAction.vue';

const props = defineProps({
  icon: { type: String, required: true },
  label: { type: String, required: true },
  accentColor: {
    type: String,
    default: 'slate',
    validator: v => ['iris', 'slate', 'amber', 'teal', 'ruby'].includes(v),
  },
  isStreaming: { type: Boolean, default: false },
  autoExpandOnStream: { type: Boolean, default: true },
  showActions: { type: Boolean, default: true },
});

const { t } = useAiI18n();

const [isExpanded, toggleExpanded] = useToggle(false);

// Auto-expand when streaming starts
watch(
  () => props.isStreaming,
  streaming => {
    if (streaming && props.autoExpandOnStream) {
      isExpanded.value = true;
    }
  },
  { immediate: true }
);

// Dynamic color classes based on accent color
const colorMap = {
  iris: {
    iconActive: 'animate-pulse text-n-iris-9',
    labelActive: 'text-n-iris-11',
    spinner: 'text-n-iris-9',
    border: 'border-n-slate-6',
    cursor: 'bg-n-iris-9',
  },
  slate: {
    iconActive: 'animate-pulse text-n-slate-9',
    labelActive: 'text-n-slate-11',
    spinner: 'text-n-slate-9',
    border: 'border-n-slate-6',
    cursor: 'bg-n-slate-9',
  },
  amber: {
    iconActive: 'animate-pulse text-n-amber-9',
    labelActive: 'text-n-amber-11',
    spinner: 'text-n-amber-9',
    border: 'border-n-amber-6',
    cursor: 'bg-n-amber-9',
  },
  teal: {
    iconActive: 'animate-pulse text-n-teal-9',
    labelActive: 'text-n-teal-11',
    spinner: 'text-n-teal-9',
    border: 'border-n-teal-6',
    cursor: 'bg-n-teal-9',
  },
  ruby: {
    iconActive: 'animate-pulse text-n-ruby-9',
    labelActive: 'text-n-ruby-11',
    spinner: 'text-n-ruby-9',
    border: 'border-n-ruby-6',
    cursor: 'bg-n-ruby-9',
  },
};

const accentClasses = computed(() => colorMap[props.accentColor]);
</script>

<template>
  <div
    class="rounded-xl bg-n-alpha-4 border border-n-weak/50 w-full min-w-0 overflow-hidden"
  >
    <button
      :aria-expanded="isExpanded"
      class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-10 hover:text-n-slate-11 transition-colors"
      @click="toggleExpanded()"
    >
      <span
        class="size-4 flex-shrink-0"
        :class="[icon, isStreaming && accentClasses.iconActive]"
      />
      <span class="truncate" :class="isStreaming && accentClasses.labelActive">
        {{ label }}
      </span>
      <span
        v-if="isStreaming"
        class="i-lucide-loader-2 size-4 flex-shrink-0 animate-spin"
        :class="accentClasses.spinner"
      />
      <span
        class="i-lucide-chevron-right size-4 ml-auto flex-shrink-0 transition-transform duration-200"
        :class="{ 'rotate-90': isExpanded }"
      />
    </button>

    <Transition
      enter-active-class="transition-all duration-500 ease-out"
      leave-active-class="transition-all duration-300 ease-in"
      enter-from-class="opacity-0 -translate-y-2"
      leave-to-class="opacity-0 -translate-y-2"
    >
      <div v-if="isExpanded" class="px-3 pb-3">
        <div
          class="pl-6 border-l-2 overflow-x-auto"
          :class="accentClasses.border"
        >
          <slot :is-streaming="isStreaming" :accent-classes="accentClasses" />
        </div>
        <!-- Actions -->
        <div
          v-if="showActions"
          class="flex items-center justify-end gap-0.5 mt-2"
        >
          <slot name="actions" :collapse="() => (isExpanded = false)" />
          <AiMessageAction
            icon="i-lucide-chevron-up"
            :label="t('AI_CHAT.COLLAPSIBLE.COLLAPSE')"
            @click="isExpanded = false"
          />
        </div>
      </div>
    </Transition>
  </div>
</template>
