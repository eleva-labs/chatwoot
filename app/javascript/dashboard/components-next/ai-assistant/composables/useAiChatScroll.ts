import {
  ref,
  computed,
  watch,
  onUnmounted,
  unref,
  type Ref,
  type ComputedRef,
} from 'vue';
import { useEventListener, useRafFn } from '@vueuse/core';

interface AutoScrollOptions {
  isStreaming?: Ref<boolean> | boolean;
  thresholdPx?: number;
  resumePx?: number;
}

interface AutoScrollReturn {
  containerRef: Ref<HTMLElement | null>;
  isNearBottom: Ref<boolean>;
  isNearTop: Ref<boolean>;
  userScrolledAway: Ref<boolean>;
  showScrollToTop: ComputedRef<boolean>;
  showScrollToBottom: ComputedRef<boolean>;
  scrollToTop: () => void;
  scrollToBottom: (behavior?: ScrollBehavior) => void;
}

/**
 * Composable for managing auto-scroll behavior in streaming chat interfaces.
 *
 * Features:
 * - RAF-based smooth auto-scroll during streaming (synced with browser render cycle)
 * - User scroll intent detection (pauses auto-scroll when user scrolls away)
 * - Configurable thresholds for "near bottom/top" detection
 * - Scroll-to-top/bottom methods with smooth behavior
 * - Escape hatch: shows scroll-to-top during streaming so user can break free
 */
export function useAiChatScroll(options: AutoScrollOptions = {}): AutoScrollReturn {
  const {
    isStreaming: isStreamingOption = false,
    thresholdPx = 150,
    resumePx = 20,
  } = options;

  // Container ref to bind to scrollable element
  const containerRef = ref<HTMLElement | null>(null);

  // Scroll position state
  const isNearBottom = ref(true);
  const isNearTop = ref(true);

  // User intent tracking - pauses auto-scroll when user manually scrolls away
  const userScrolledAway = ref(false);

  // Computed: resolve isStreaming whether it's a ref or plain value
  const isStreaming = computed(() => unref(isStreamingOption));

  /**
   * Show scroll-to-top button when:
   * - Not near top (normal behavior), OR
   * - During streaming when user hasn't escaped yet (escape hatch)
   */
  const showScrollToTop = computed(
    () => !isNearTop.value || (isStreaming.value && !userScrolledAway.value),
  );

  /**
   * Show scroll-to-bottom button when not near bottom
   */
  const showScrollToBottom = computed(() => !isNearBottom.value);

  /**
   * Scroll to bottom of container
   */
  const scrollToBottom = (behavior: ScrollBehavior = 'smooth'): void => {
    if (containerRef.value) {
      containerRef.value.scrollTo({
        top: containerRef.value.scrollHeight,
        behavior,
      });
    }
  };

  // RAF control - defined early so scrollToTop can use it
  let pauseRaf: () => void = () => {};

  // Timestamp to ignore scroll events briefly after programmatic scroll
  // This prevents the "reset to bottom" logic from firing before animation moves us away
  let ignoreScrollResetUntil = 0;

  /**
   * Scroll to top of container and pause auto-scroll
   */
  const scrollToTop = (): void => {
    if (containerRef.value) {
      userScrolledAway.value = true; // Pause auto-scroll immediately
      pauseRaf(); // Stop RAF immediately (don't wait for watcher)
      // Ignore scroll reset for 150ms to let animation start moving
      ignoreScrollResetUntil = Date.now() + 150;
      containerRef.value.scrollTo({
        top: 0,
        behavior: 'smooth',
      });
    }
  };

  // Track previous scroll position to detect scroll direction
  let lastScrollTop = 0;

  /**
   * Handle scroll events - update position state and detect user intent
   */
  const handleScroll = (): void => {
    if (!containerRef.value) return;

    const { scrollTop, scrollHeight, clientHeight } = containerRef.value;
    const distanceFromBottom = scrollHeight - scrollTop - clientHeight;

    // Detect scroll direction
    const isScrollingUp = scrollTop < lastScrollTop;
    lastScrollTop = scrollTop;

    // Update position state
    isNearBottom.value = distanceFromBottom < thresholdPx;
    isNearTop.value = scrollTop < thresholdPx;

    // During streaming: any upward scroll breaks free from auto-scroll
    if (isStreaming.value && isScrollingUp && distanceFromBottom > 10) {
      userScrolledAway.value = true;
    }

    // Skip reset logic during programmatic scroll grace period
    if (Date.now() < ignoreScrollResetUntil) return;

    // Resume auto-scroll if user scrolls back to very bottom
    // During streaming: only re-lock if truly at the bottom (very small threshold)
    // Not streaming: use normal resume threshold
    const effectiveResumePx = isStreaming.value ? 5 : resumePx;
    if (distanceFromBottom < effectiveResumePx) {
      userScrolledAway.value = false;
    }
  };

  // RAF-based auto-scroll for smooth streaming experience
  // Uses useRafFn from VueUse for proper lifecycle management
  let resumeRaf: () => void = () => {};
  const rafFn = useRafFn(
    () => {
      // Double-check userScrolledAway in RAF loop for immediate response
      if (containerRef.value && !userScrolledAway.value) {
        containerRef.value.scrollTop = containerRef.value.scrollHeight;
      }
    },
    { immediate: false }, // Don't start immediately, controlled by watchers
  );

  // Assign RAF controls after creation
  pauseRaf = rafFn.pause;
  resumeRaf = rafFn.resume;

  // Start/stop RAF loop based on streaming state
  watch(
    isStreaming,
    (streaming: boolean) => {
      if (streaming && !userScrolledAway.value) {
        resumeRaf();
      } else {
        pauseRaf();
        // Reset user scroll state when streaming ends
        if (!streaming) {
          userScrolledAway.value = false;
        }
      }
    },
    { immediate: true },
  );

  // Stop RAF when user scrolls away, resume when they return (during streaming)
  watch(userScrolledAway, (scrolledAway: boolean) => {
    if (scrolledAway) {
      pauseRaf();
    } else if (isStreaming.value) {
      resumeRaf();
    }
  });

  // Setup scroll event listener using VueUse (auto cleanup on unmount)
  useEventListener(containerRef, 'scroll', handleScroll, { passive: true });

  // Cleanup RAF on unmount (useRafFn handles this, but explicit for safety)
  onUnmounted(() => {
    pauseRaf();
  });

  return {
    // Refs
    containerRef,

    // State
    isNearBottom,
    isNearTop,
    userScrolledAway,

    // Computed
    showScrollToTop,
    showScrollToBottom,

    // Methods
    scrollToTop,
    scrollToBottom,
  };
}
