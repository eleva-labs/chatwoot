import { mount } from '@vue/test-utils';
import AiLoader from '../AiLoader.vue';

describe('AiLoader', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  // =============================================================================
  // Rendering
  // =============================================================================
  describe('rendering', () => {
    it('renders a loading spinner', () => {
      const wrapper = mount(AiLoader);

      expect(wrapper.find('.i-lucide-loader-2').exists()).toBe(true);
      expect(wrapper.find('.animate-spin').exists()).toBe(true);
    });

    it('renders default text when no text prop provided', () => {
      const wrapper = mount(AiLoader);

      // Default text from i18n
      expect(wrapper.find('.text-sm').exists()).toBe(true);
    });

    it('renders custom text when text prop is provided', () => {
      const wrapper = mount(AiLoader, {
        props: { text: 'Custom loading text' },
      });

      expect(wrapper.text()).toContain('Custom loading text');
    });
  });

  // =============================================================================
  // Styling
  // =============================================================================
  describe('styling', () => {
    it('applies correct container classes', () => {
      const wrapper = mount(AiLoader);

      const container = wrapper.find('div');
      expect(container.classes()).toContain('flex');
      expect(container.classes()).toContain('items-center');
      expect(container.classes()).toContain('gap-2');
    });

    it('applies text color class', () => {
      const wrapper = mount(AiLoader);

      const container = wrapper.find('div');
      expect(container.classes()).toContain('text-n-slate-11');
    });
  });
});
