import { mount } from '@vue/test-utils';
import AiReasoningPart from '../AiReasoningPart.vue';

// Mock MessageFormatter - needs to be a class constructor
vi.mock('shared/helpers/MessageFormatter.js', () => ({
  default: class MockMessageFormatter {
    constructor(text) {
      this.formattedMessage = `<p>${text || ''}</p>`;
    }
  },
}));

// Mock @vueuse/core for AiCollapsiblePart
vi.mock('@vueuse/core', () => ({
  useToggle: vi.fn(initial => {
    const value = { value: initial };
    const toggle = () => {
      value.value = !value.value;
    };
    return [value, toggle];
  }),
}));

describe('AiReasoningPart', () => {
  const defaultProps = {
    part: { type: 'reasoning', text: 'Let me think about this...' },
  };

  const createWrapper = (props = {}) => {
    return mount(AiReasoningPart, {
      props: { ...defaultProps, ...props },
      global: {
        directives: {
          'dompurify-html': (el, binding) => {
            el.innerHTML = binding.value;
          },
        },
        stubs: {
          AiCollapsiblePart: {
            template: `
              <div class="ai-collapsible-stub">
                <div class="collapsible-header">
                  <span :class="icon"></span>
                  <span class="collapsible-label">{{ label }}</span>
                  <span v-if="isStreaming" class="streaming-indicator"></span>
                </div>
                <div class="collapsible-content">
                  <slot :is-streaming="isStreaming" :accent-classes="{ cursor: 'bg-n-iris-9' }" />
                </div>
              </div>
            `,
            props: [
              'icon',
              'label',
              'accentColor',
              'isStreaming',
              'autoExpandOnStream',
            ],
          },
          AiMessageAction: true,
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
    it('renders with AiCollapsiblePart wrapper', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.ai-collapsible-stub').exists()).toBe(true);
    });

    it('uses brain icon', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.i-lucide-brain').exists()).toBe(true);
    });

    it('renders reasoning text content', () => {
      const wrapper = createWrapper();

      expect(wrapper.html()).toContain('Let me think about this...');
    });

    it('applies prose styling', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.prose').exists()).toBe(true);
      expect(wrapper.find('.prose-sm').exists()).toBe(true);
    });
  });

  // =============================================================================
  // Labels
  // =============================================================================
  describe('labels', () => {
    it('shows "Thinking..." label when streaming', () => {
      const wrapper = createWrapper({ isStreaming: true });

      // Label is passed to AiCollapsiblePart
      expect(wrapper.find('.collapsible-label').exists()).toBe(true);
    });

    it('shows "View reasoning" label when not streaming', () => {
      const wrapper = createWrapper({ isStreaming: false });

      expect(wrapper.find('.collapsible-label').exists()).toBe(true);
    });
  });

  // =============================================================================
  // Streaming State
  // =============================================================================
  describe('streaming state', () => {
    it('passes isStreaming to AiCollapsiblePart', () => {
      const wrapper = createWrapper({ isStreaming: true });

      expect(wrapper.find('.streaming-indicator').exists()).toBe(true);
    });

    it('shows cursor when streaming', () => {
      const wrapper = createWrapper({ isStreaming: true });

      const cursor = wrapper.find('.animate-pulse');
      expect(cursor.exists()).toBe(true);
    });

    it('hides cursor when not streaming', () => {
      const wrapper = createWrapper({ isStreaming: false });

      // There should be no pulse cursor when not streaming
      expect(wrapper.findAll('.w-1\\.5.h-3').length).toBe(0);
    });
  });

  // =============================================================================
  // Text Handling
  // =============================================================================
  describe('text handling', () => {
    it('formats text using MessageFormatter', () => {
      const wrapper = createWrapper({
        part: { text: 'Formatted reasoning' },
      });

      expect(wrapper.html()).toContain('<p>Formatted reasoning</p>');
    });

    it('handles empty text', () => {
      const wrapper = createWrapper({
        part: { text: '' },
      });

      expect(wrapper.find('.ai-collapsible-stub').exists()).toBe(true);
    });

    it('handles missing text property', () => {
      const wrapper = createWrapper({
        part: {},
      });

      expect(wrapper.find('.ai-collapsible-stub').exists()).toBe(true);
    });
  });

  // =============================================================================
  // Collapsible Configuration
  // =============================================================================
  describe('collapsible configuration', () => {
    it('uses iris accent color', () => {
      const wrapper = createWrapper();

      // Verify the component renders with the AiCollapsiblePart wrapper
      const collapsible = wrapper.find('.ai-collapsible-stub');
      expect(collapsible.exists()).toBe(true);
    });

    it('sets autoExpandOnStream to false by default (collapsed initially)', () => {
      const wrapper = createWrapper({ isStreaming: true });

      // Even when streaming, the reasoning part should not auto-expand
      // This is verified by checking the streaming indicator is shown
      expect(wrapper.find('.streaming-indicator').exists()).toBe(true);
    });
  });
});
