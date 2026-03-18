import { shallowMount } from '@vue/test-utils';
import AiPartRenderer from '../AiPartRenderer.vue';
import { PART_TYPES } from '../../constants';

// Note: We use shallowMount to avoid rendering child components
// and focus on testing the component selection logic

describe('AiPartRenderer', () => {
  const createWrapper = (props = {}) => {
    return shallowMount(AiPartRenderer, {
      props: {
        part: { type: PART_TYPES.TEXT, text: 'Test' },
        role: 'assistant',
        ...props,
      },
      global: {
        stubs: {
          AiTextPart: {
            template: '<div class="ai-text-part-stub">{{ part.text }}</div>',
            props: ['part', 'role', 'isStreaming'],
          },
        },
      },
    });
  };

  afterEach(() => {
    vi.clearAllMocks();
  });

  // =============================================================================
  // Component Selection
  // =============================================================================
  describe('component selection', () => {
    it('renders AiTextPart for text type', () => {
      const wrapper = createWrapper({
        part: { type: PART_TYPES.TEXT, text: 'Hello' },
      });

      expect(wrapper.find('.ai-text-part-stub').exists()).toBe(true);
    });

    it('renders nothing for unknown type', () => {
      const wrapper = createWrapper({
        part: { type: 'unknown-type' },
      });

      expect(wrapper.html()).toBe('<!--v-if-->');
    });

    it('renders AiToolPart for tool-* types', () => {
      const wrapper = shallowMount(AiPartRenderer, {
        props: {
          part: { type: 'tool-output-available', toolName: 'search' },
          role: 'assistant',
        },
      });

      // The component should attempt to render AiToolPart
      // In shallow mount, it will be stubbed as a placeholder
      expect(wrapper.html()).not.toBe('<!--v-if-->');
    });

    it('handles tool-input-start type', () => {
      const wrapper = shallowMount(AiPartRenderer, {
        props: {
          part: { type: 'tool-input-start', toolName: 'search' },
          role: 'assistant',
        },
      });

      expect(wrapper.html()).not.toBe('<!--v-if-->');
    });

    it('handles tool-output-streaming type', () => {
      const wrapper = shallowMount(AiPartRenderer, {
        props: {
          part: { type: 'tool-output-streaming', toolName: 'search' },
          role: 'assistant',
        },
      });

      expect(wrapper.html()).not.toBe('<!--v-if-->');
    });
  });

  // =============================================================================
  // Prop Passing
  // =============================================================================
  describe('prop passing', () => {
    it('passes part prop to child component', () => {
      const part = { type: PART_TYPES.TEXT, text: 'Test content' };
      const wrapper = createWrapper({ part });

      expect(wrapper.find('.ai-text-part-stub').text()).toBe('Test content');
    });

    it('passes role prop to child component', () => {
      const wrapper = shallowMount(AiPartRenderer, {
        props: {
          part: { type: PART_TYPES.TEXT, text: 'Test' },
          role: 'user',
        },
        global: {
          stubs: {
            AiTextPart: {
              template:
                '<div class="ai-text-part-stub" :data-role="role"></div>',
              props: ['part', 'role', 'isStreaming'],
            },
          },
        },
      });

      expect(wrapper.find('.ai-text-part-stub').attributes('data-role')).toBe(
        'user'
      );
    });

    it('passes isStreaming prop to child component', () => {
      const wrapper = shallowMount(AiPartRenderer, {
        props: {
          part: { type: PART_TYPES.TEXT, text: 'Test' },
          role: 'assistant',
          isStreaming: true,
        },
        global: {
          stubs: {
            AiTextPart: {
              template:
                '<div class="ai-text-part-stub" :data-streaming="isStreaming"></div>',
              props: ['part', 'role', 'isStreaming'],
            },
          },
        },
      });

      expect(
        wrapper.find('.ai-text-part-stub').attributes('data-streaming')
      ).toBe('true');
    });

    it('defaults isStreaming to false', () => {
      const wrapper = shallowMount(AiPartRenderer, {
        props: {
          part: { type: PART_TYPES.TEXT, text: 'Test' },
          role: 'assistant',
        },
        global: {
          stubs: {
            AiTextPart: {
              template:
                '<div class="ai-text-part-stub" :data-streaming="isStreaming"></div>',
              props: ['part', 'role', 'isStreaming'],
            },
          },
        },
      });

      expect(
        wrapper.find('.ai-text-part-stub').attributes('data-streaming')
      ).toBe('false');
    });
  });

  // =============================================================================
  // Edge Cases
  // =============================================================================
  describe('edge cases', () => {
    it('handles null part type gracefully', () => {
      const wrapper = createWrapper({
        part: { type: null },
      });

      expect(wrapper.html()).toBe('<!--v-if-->');
    });

    it('handles undefined part type gracefully', () => {
      const wrapper = createWrapper({
        part: {},
      });

      expect(wrapper.html()).toBe('<!--v-if-->');
    });

    it('handles reasoning type', () => {
      const wrapper = shallowMount(AiPartRenderer, {
        props: {
          part: { type: PART_TYPES.REASONING, text: 'Thinking...' },
          role: 'assistant',
        },
      });

      // Should render AiReasoningPart (async component)
      expect(wrapper.html()).not.toBe('<!--v-if-->');
    });
  });
});
