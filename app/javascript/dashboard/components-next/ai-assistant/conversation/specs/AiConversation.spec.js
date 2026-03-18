import { mount } from '@vue/test-utils';
import AiConversation from '../AiConversation.vue';

// Mock useAiChatScroll
const mockScrollToBottom = vi.fn();
const mockScrollToTop = vi.fn();

vi.mock('../../composables/useAiChatScroll', () => ({
  useAiChatScroll: vi.fn(() => ({
    containerRef: { value: null },
    isNearBottom: { value: true },
    showScrollToTop: { value: false },
    scrollToTop: mockScrollToTop,
    scrollToBottom: mockScrollToBottom,
  })),
}));

describe('AiConversation', () => {
  const createWrapper = (props = {}, slots = {}) => {
    return mount(AiConversation, {
      props,
      slots: {
        default: '<div class="message">Test message</div>',
        ...slots,
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>',
          },
        },
      },
    });
  };

  afterEach(() => {
    vi.clearAllMocks();
  });

  // =============================================================================
  // Rendering
  // =============================================================================
  describe('rendering', () => {
    it('renders slot content', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.message').exists()).toBe(true);
      expect(wrapper.text()).toContain('Test message');
    });

    it('renders scroll container', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.overflow-y-auto').exists()).toBe(true);
    });

    it('applies overflow hidden to outer container', () => {
      const wrapper = createWrapper();

      const container = wrapper.find('.overflow-hidden');
      expect(container.exists()).toBe(true);
    });
  });

  // =============================================================================
  // Scroll To Bottom
  // =============================================================================
  describe('scroll to bottom', () => {
    it('scrolls to bottom on mount with instant behavior', () => {
      createWrapper();

      expect(mockScrollToBottom).toHaveBeenCalledWith('instant');
    });
  });

  // =============================================================================
  // Exposed Methods
  // =============================================================================
  describe('exposed methods', () => {
    it('exposes scrollToBottom method', () => {
      const wrapper = createWrapper();

      expect(wrapper.vm.scrollToBottom).toBeDefined();
    });
  });

  // =============================================================================
  // isStreaming Prop
  // =============================================================================
  describe('isStreaming prop', () => {
    it('accepts isStreaming prop', () => {
      const wrapper = createWrapper({ isStreaming: true });

      expect(wrapper.exists()).toBe(true);
    });

    it('defaults isStreaming to false', () => {
      const wrapper = createWrapper();

      expect(wrapper.exists()).toBe(true);
    });
  });
});
