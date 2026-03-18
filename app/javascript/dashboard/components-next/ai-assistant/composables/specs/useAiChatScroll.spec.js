import { ref } from 'vue';
import { useAiChatScroll } from '../useAiChatScroll';

// Store scroll handler globally so we can call it from tests
let scrollHandler = null;

// Mock @vueuse/core
vi.mock('@vueuse/core', () => ({
  useEventListener: vi.fn((target, event, handler) => {
    // Store handler for manual triggering in tests
    if (event === 'scroll') {
      scrollHandler = handler;
    }
    return vi.fn(); // cleanup function
  }),
  useRafFn: vi.fn(callback => {
    let isActive = false;
    return {
      pause: vi.fn(() => {
        isActive = false;
      }),
      resume: vi.fn(() => {
        isActive = true;
        // Execute callback once when resumed (simulating RAF)
        callback();
      }),
      isActive: () => isActive,
    };
  }),
}));

describe('useAiChatScroll', () => {
  let mockContainer;

  beforeEach(() => {
    // Reset scroll handler
    scrollHandler = null;

    // Create mock container element
    mockContainer = {
      scrollTop: 0,
      scrollHeight: 1000,
      clientHeight: 500,
      scrollTo: vi.fn(),
    };
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  // Helper to simulate scroll event
  const simulateScroll = (container, scrollTop) => {
    container.scrollTop = scrollTop;
    if (scrollHandler) {
      scrollHandler();
    }
  };

  // =============================================================================
  // Initialization
  // =============================================================================
  describe('initialization', () => {
    it('returns expected refs and methods', () => {
      const result = useAiChatScroll();

      expect(result).toHaveProperty('containerRef');
      expect(result).toHaveProperty('isNearBottom');
      expect(result).toHaveProperty('isNearTop');
      expect(result).toHaveProperty('userScrolledAway');
      expect(result).toHaveProperty('showScrollToTop');
      expect(result).toHaveProperty('showScrollToBottom');
      expect(result).toHaveProperty('scrollToTop');
      expect(result).toHaveProperty('scrollToBottom');
    });

    it('initializes isNearBottom as true', () => {
      const { isNearBottom } = useAiChatScroll();
      expect(isNearBottom.value).toBe(true);
    });

    it('initializes isNearTop as true', () => {
      const { isNearTop } = useAiChatScroll();
      expect(isNearTop.value).toBe(true);
    });

    it('initializes userScrolledAway as false', () => {
      const { userScrolledAway } = useAiChatScroll();
      expect(userScrolledAway.value).toBe(false);
    });

    it('accepts custom threshold options', () => {
      const result = useAiChatScroll({
        thresholdPx: 200,
        resumePx: 50,
      });

      expect(result).toBeDefined();
    });
  });

  // =============================================================================
  // isNearBottom detection
  // =============================================================================
  describe('isNearBottom', () => {
    it('is true when scrolled to bottom', () => {
      const { containerRef, isNearBottom } = useAiChatScroll({
        thresholdPx: 150,
      });
      containerRef.value = mockContainer;

      // At bottom: scrollTop = scrollHeight - clientHeight
      // 1000 - 500 - 500 = 0 distance from bottom
      simulateScroll(mockContainer, 500);

      expect(isNearBottom.value).toBe(true);
    });

    it('is true when within threshold of bottom', () => {
      const { containerRef, isNearBottom } = useAiChatScroll({
        thresholdPx: 150,
      });
      containerRef.value = mockContainer;

      // 100px from bottom (within 150px threshold)
      // 1000 - 400 - 500 = 100
      simulateScroll(mockContainer, 400);

      expect(isNearBottom.value).toBe(true);
    });

    it('is false when scrolled away from bottom', () => {
      const { containerRef, isNearBottom } = useAiChatScroll({
        thresholdPx: 150,
      });
      containerRef.value = mockContainer;

      // 300px from bottom (outside 150px threshold)
      // 1000 - 200 - 500 = 300
      simulateScroll(mockContainer, 200);

      expect(isNearBottom.value).toBe(false);
    });
  });

  // =============================================================================
  // isNearTop detection
  // =============================================================================
  describe('isNearTop', () => {
    it('is true when at top', () => {
      const { containerRef, isNearTop } = useAiChatScroll({ thresholdPx: 150 });
      containerRef.value = mockContainer;

      simulateScroll(mockContainer, 0);

      expect(isNearTop.value).toBe(true);
    });

    it('is true when within threshold of top', () => {
      const { containerRef, isNearTop } = useAiChatScroll({ thresholdPx: 150 });
      containerRef.value = mockContainer;

      simulateScroll(mockContainer, 100); // within 150px threshold

      expect(isNearTop.value).toBe(true);
    });

    it('is false when scrolled away from top', () => {
      const { containerRef, isNearTop } = useAiChatScroll({ thresholdPx: 150 });
      containerRef.value = mockContainer;

      simulateScroll(mockContainer, 200); // outside 150px threshold

      expect(isNearTop.value).toBe(false);
    });
  });

  // =============================================================================
  // showScrollToBottom
  // =============================================================================
  describe('showScrollToBottom', () => {
    it('is false when near bottom', () => {
      const { containerRef, showScrollToBottom } = useAiChatScroll({
        thresholdPx: 150,
      });
      containerRef.value = mockContainer;

      simulateScroll(mockContainer, 500); // at bottom

      expect(showScrollToBottom.value).toBe(false);
    });

    it('is true when scrolled away from bottom', () => {
      const { containerRef, showScrollToBottom } = useAiChatScroll({
        thresholdPx: 150,
      });
      containerRef.value = mockContainer;

      simulateScroll(mockContainer, 0); // at top, far from bottom

      expect(showScrollToBottom.value).toBe(true);
    });
  });

  // =============================================================================
  // scrollToBottom
  // =============================================================================
  describe('scrollToBottom', () => {
    it('does nothing when containerRef is null', () => {
      const { scrollToBottom } = useAiChatScroll();

      // Should not throw
      expect(() => scrollToBottom()).not.toThrow();
    });

    it('scrolls to bottom with smooth behavior by default', () => {
      const { containerRef, scrollToBottom } = useAiChatScroll();
      containerRef.value = mockContainer;

      scrollToBottom();

      expect(mockContainer.scrollTo).toHaveBeenCalledWith({
        top: mockContainer.scrollHeight,
        behavior: 'smooth',
      });
    });

    it('accepts custom behavior parameter', () => {
      const { containerRef, scrollToBottom } = useAiChatScroll();
      containerRef.value = mockContainer;

      scrollToBottom('instant');

      expect(mockContainer.scrollTo).toHaveBeenCalledWith({
        top: mockContainer.scrollHeight,
        behavior: 'instant',
      });
    });
  });

  // =============================================================================
  // scrollToTop
  // =============================================================================
  describe('scrollToTop', () => {
    it('does nothing when containerRef is null', () => {
      const { scrollToTop } = useAiChatScroll();

      // Should not throw
      expect(() => scrollToTop()).not.toThrow();
    });

    it('scrolls to top with smooth behavior', () => {
      const { containerRef, scrollToTop } = useAiChatScroll();
      containerRef.value = mockContainer;

      scrollToTop();

      expect(mockContainer.scrollTo).toHaveBeenCalledWith({
        top: 0,
        behavior: 'smooth',
      });
    });

    it('sets userScrolledAway to true', () => {
      const { containerRef, scrollToTop, userScrolledAway } = useAiChatScroll();
      containerRef.value = mockContainer;

      scrollToTop();

      expect(userScrolledAway.value).toBe(true);
    });
  });

  // =============================================================================
  // userScrolledAway behavior
  // =============================================================================
  describe('userScrolledAway', () => {
    it('is set to true when scrolling up during streaming', async () => {
      const isStreaming = ref(true);
      const { containerRef, userScrolledAway } = useAiChatScroll({
        isStreaming,
        thresholdPx: 150,
      });
      containerRef.value = mockContainer;

      // Start near bottom (simulate lastScrollTop)
      simulateScroll(mockContainer, 450);

      // Scroll up (lower scrollTop = scrolling up)
      // distanceFromBottom = 1000 - 200 - 500 = 300 > 10
      simulateScroll(mockContainer, 200);

      expect(userScrolledAway.value).toBe(true);
    });

    it('resets when user scrolls back to bottom', async () => {
      const isStreaming = ref(true);
      const { containerRef, userScrolledAway } = useAiChatScroll({
        isStreaming,
        resumePx: 20,
      });
      containerRef.value = mockContainer;

      // Set userScrolledAway to true
      userScrolledAway.value = true;

      // Scroll very close to bottom (within effectiveResumePx during streaming = 5px)
      // distanceFromBottom = 1000 - 497 - 500 = 3px < 5px
      simulateScroll(mockContainer, 497);

      expect(userScrolledAway.value).toBe(false);
    });
  });

  // =============================================================================
  // showScrollToTop with streaming
  // =============================================================================
  describe('showScrollToTop', () => {
    it('is true when not near top', () => {
      const { containerRef, showScrollToTop } = useAiChatScroll({
        thresholdPx: 150,
      });
      containerRef.value = mockContainer;

      simulateScroll(mockContainer, 300);

      expect(showScrollToTop.value).toBe(true);
    });

    it('is false when near top and not streaming', () => {
      const isStreaming = ref(false);
      const { containerRef, showScrollToTop } = useAiChatScroll({
        isStreaming,
        thresholdPx: 150,
      });
      containerRef.value = mockContainer;

      simulateScroll(mockContainer, 50);

      expect(showScrollToTop.value).toBe(false);
    });
  });
});
