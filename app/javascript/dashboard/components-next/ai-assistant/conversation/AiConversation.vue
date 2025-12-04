<script setup>
import { ref, watch, nextTick, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messages: { type: Array, default: () => [] },
  isStreaming: { type: Boolean, default: false },
});

const { t } = useI18n();

const containerRef = ref(null);
const isNearBottom = ref(true);

// Throttle control for streaming scroll
let lastScrollTime = 0;
const THROTTLE_MS = 50;

// Distance threshold for "near bottom" - used for auto-scroll and button visibility
const SCROLL_THRESHOLD_PX = 150;

const scrollToBottom = (behavior = 'smooth') => {
  if (containerRef.value) {
    containerRef.value.scrollTo({
      top: containerRef.value.scrollHeight,
      behavior,
    });
  }
};

const handleScroll = () => {
  if (!containerRef.value) return;
  const { scrollTop, scrollHeight, clientHeight } = containerRef.value;
  const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
  isNearBottom.value = distanceFromBottom < SCROLL_THRESHOLD_PX;
};

// Auto-scroll when messages change (if near bottom)
watch(
  () => props.messages,
  async () => {
    if (!isNearBottom.value) return;

    // Throttle during streaming for performance
    if (props.isStreaming) {
      const now = Date.now();
      if (now - lastScrollTime < THROTTLE_MS) return;
      lastScrollTime = now;
      scrollToBottom('instant');
    } else {
      await nextTick();
      scrollToBottom();
    }
  },
  { deep: true }
);

onMounted(() => {
  scrollToBottom('instant');
});

defineExpose({ scrollToBottom });
</script>

<template>
  <div class="relative flex-1 flex flex-col overflow-hidden">
    <div
      ref="containerRef"
      class="flex-1 overflow-y-auto"
      @scroll="handleScroll"
    >
      <slot />
    </div>

    <!-- Scroll to bottom button - positioned relative to container, not scroll content -->
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
