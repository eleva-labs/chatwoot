<script setup>
import { toRef, onMounted } from 'vue';
import { useAiI18n } from '../i18n/aiChatI18n';
import { useAutoScroll } from '../composables/useAutoScroll';

const props = defineProps({
  isStreaming: { type: Boolean, default: false },
});

const { t } = useAiI18n();

const {
  containerRef,
  isNearBottom,
  showScrollToTop,
  scrollToTop,
  scrollToBottom,
} = useAutoScroll({
  isStreaming: toRef(props, 'isStreaming'),
});

onMounted(() => {
  scrollToBottom('instant');
});

defineExpose({ scrollToBottom });
</script>

<template>
  <div class="relative flex-1 flex flex-col overflow-hidden">
    <div ref="containerRef" class="flex-1 overflow-y-auto">
      <slot />
    </div>

    <!-- Scroll to top button - always visible during streaming as escape hatch -->
    <Transition
      enter-active-class="transition-opacity duration-200 ease-out"
      leave-active-class="transition-opacity duration-150 ease-in"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <button
        v-if="showScrollToTop"
        :aria-label="t('AI_CHAT.SCROLL_TO_TOP')"
        class="absolute top-4 ltr:right-4 rtl:left-4 size-9 flex items-center justify-center rounded-full bg-n-solid-3 shadow-lg hover:bg-n-solid-4 transition-colors z-10"
        @click="scrollToTop"
      >
        <span class="i-lucide-chevron-up size-5 text-n-slate-11" />
      </button>
    </Transition>

    <!-- Scroll to bottom button -->
    <Transition
      enter-active-class="transition-opacity duration-200 ease-out"
      leave-active-class="transition-opacity duration-150 ease-in"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <button
        v-if="!isNearBottom"
        :aria-label="t('AI_CHAT.SCROLL_TO_BOTTOM')"
        class="absolute bottom-4 ltr:right-4 rtl:left-4 size-9 flex items-center justify-center rounded-full bg-n-solid-3 shadow-lg hover:bg-n-solid-4 transition-colors z-10"
        @click="scrollToBottom()"
      >
        <span class="i-lucide-chevron-down size-5 text-n-slate-11" />
      </button>
    </Transition>
  </div>
</template>
