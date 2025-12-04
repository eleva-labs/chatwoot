import { mount } from '@vue/test-utils';
import AiTextPart from '../AiTextPart.vue';
import { PART_TYPES } from '../../constants';

// Mock MessageFormatter - needs to be a class constructor
vi.mock('shared/helpers/MessageFormatter.js', () => ({
  default: class MockMessageFormatter {
    constructor(text) {
      this.formattedMessage = `<p>${text || ''}</p>`;
    }
  },
}));

describe('AiTextPart', () => {
  const defaultProps = {
    part: { type: PART_TYPES.TEXT, text: 'Hello world' },
    role: 'assistant',
  };

  const createWrapper = (props = {}) => {
    return mount(AiTextPart, {
      props: { ...defaultProps, ...props },
      global: {
        directives: {
          'dompurify-html': (el, binding) => {
            el.innerHTML = binding.value;
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
    it('renders text content', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.ai-text-part').exists()).toBe(true);
      expect(wrapper.html()).toContain('Hello world');
    });

    it('applies animation class', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.animate-fade-in-up').exists()).toBe(true);
    });

    it('applies prose styling classes', () => {
      const wrapper = createWrapper();

      const prose = wrapper.find('.prose');
      expect(prose.exists()).toBe(true);
      expect(prose.classes()).toContain('prose-bubble');
    });

    it('renders empty text when part has no text', () => {
      const wrapper = createWrapper({
        part: { type: PART_TYPES.TEXT },
      });

      expect(wrapper.find('.ai-text-part').exists()).toBe(true);
    });
  });

  // =============================================================================
  // Streaming Cursor
  // =============================================================================
  describe('streaming cursor', () => {
    it('shows cursor when streaming and role is assistant', () => {
      const wrapper = createWrapper({
        isStreaming: true,
        role: 'assistant',
      });

      const cursor = wrapper.find('.animate-pulse');
      expect(cursor.exists()).toBe(true);
      expect(cursor.classes()).toContain('bg-n-slate-11');
    });

    it('hides cursor when not streaming', () => {
      const wrapper = createWrapper({
        isStreaming: false,
        role: 'assistant',
      });

      expect(wrapper.findAll('.animate-pulse').length).toBe(0);
    });

    it('hides cursor for user messages even when streaming', () => {
      const wrapper = createWrapper({
        isStreaming: true,
        role: 'user',
      });

      // No cursor should appear for user messages
      expect(wrapper.findAll('.w-2.h-4').length).toBe(0);
    });
  });

  // =============================================================================
  // Text Formatting
  // =============================================================================
  describe('text formatting', () => {
    it('uses MessageFormatter to format text', () => {
      const wrapper = createWrapper({
        part: { type: PART_TYPES.TEXT, text: 'Formatted text' },
      });

      expect(wrapper.html()).toContain('<p>Formatted text</p>');
    });

    it('handles empty text gracefully', () => {
      const wrapper = createWrapper({
        part: { type: PART_TYPES.TEXT, text: '' },
      });

      expect(wrapper.find('.ai-text-part').exists()).toBe(true);
    });

    it('handles null text gracefully', () => {
      const wrapper = createWrapper({
        part: { type: PART_TYPES.TEXT, text: null },
      });

      expect(wrapper.find('.ai-text-part').exists()).toBe(true);
    });
  });
});
