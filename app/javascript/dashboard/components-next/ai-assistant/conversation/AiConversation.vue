<script setup>
import { ref, watch, nextTick, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messages: { type: Array, default: () => [] },
  isStreaming: { type: Boolean, default: false },
});

const { t } = useI18n();

const containerRef = ref(null);
const showScrollButton = ref(false);
const isNearBottom = ref(true);
const userScrolledUp = ref(false);
const lastScrollTop = ref(0);

// Throttle control for streaming scroll
let lastScrollTime = 0;
const THROTTLE_MS = 50;

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

  // Detect intentional upward scroll (user wants to read history)
  if (scrollTop < lastScrollTop.value && distanceFromBottom > 150) {
    userScrolledUp.value = true;
  }

  // Reset userScrolledUp when user scrolls back to bottom
  if (distanceFromBottom < 100) {
    userScrolledUp.value = false;
  }

  lastScrollTop.value = scrollTop;

  // Update state
  isNearBottom.value = distanceFromBottom < 100;
  showScrollButton.value = !isNearBottom.value;
};

// Manual scroll button resets user intent
const handleScrollButtonClick = () => {
  userScrolledUp.value = false;
  scrollToBottom();
};

// Throttled auto-scroll during streaming
watch(
  () => props.messages,
  () => {
    if (!props.isStreaming) return;

    const now = Date.now();
    if (now - lastScrollTime < THROTTLE_MS) return;
    lastScrollTime = now;

    if (!userScrolledUp.value && isNearBottom.value) {
      scrollToBottom('instant');
    }
  },
  { deep: true }
);

// New messages - scroll if near bottom and user hasn't scrolled up
watch(
  () => props.messages.length,
  async () => {
    // Skip during streaming (handled by deep watcher)
    if (props.isStreaming) return;

    if (isNearBottom.value && !userScrolledUp.value) {
      await nextTick();
      scrollToBottom();
    }
  }
);

onMounted(() => {
  scrollToBottom('instant');
});

defineExpose({ scrollToBottom });
</script>

<template>
  <div
    ref="containerRef"
    class="relative flex-1 overflow-y-auto"
    @scroll="handleScroll"
  >
    <slot />

    <!-- Scroll to bottom button -->
    <Transition
      enter-active-class="transition-opacity duration-200 ease-out"
      leave-active-class="transition-opacity duration-150 ease-in"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <button
        v-if="showScrollButton"
        :aria-label="t('AI_CHAT.SCROLL_TO_BOTTOM')"
        class="absolute bottom-4 ltr:right-4 rtl:left-4 p-2 rounded-full bg-n-solid-3 shadow-lg hover:bg-n-solid-4 transition-colors"
        @click="handleScrollButtonClick"
      >
        <span class="i-lucide-chevron-down size-5 text-n-slate-11" />
      </button>
    </Transition>
  </div>
</template>
