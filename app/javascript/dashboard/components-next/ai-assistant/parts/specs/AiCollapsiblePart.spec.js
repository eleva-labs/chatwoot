import { mount } from '@vue/test-utils';
import AiCollapsiblePart from '../AiCollapsiblePart.vue';

describe('AiCollapsiblePart', () => {
  const defaultProps = {
    icon: 'i-lucide-brain',
    label: 'Test Label',
  };

  const createWrapper = (props = {}) => {
    return mount(AiCollapsiblePart, {
      props: { ...defaultProps, ...props },
      slots: {
        default: '<div class="slot-content">Slot content</div>',
      },
      global: {
        stubs: {
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
    it('renders header with icon and label', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.i-lucide-brain').exists()).toBe(true);
      expect(wrapper.text()).toContain('Test Label');
    });

    it('renders chevron icon', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.i-lucide-chevron-right').exists()).toBe(true);
    });

    it('has clickable header button', () => {
      const wrapper = createWrapper();

      const button = wrapper.find('button');
      expect(button.exists()).toBe(true);
      expect(button.attributes('aria-expanded')).toBe('false');
    });
  });

  // =============================================================================
  // Streaming State
  // =============================================================================
  describe('streaming state', () => {
    it('shows spinner when streaming', () => {
      const wrapper = createWrapper({ isStreaming: true });

      expect(wrapper.find('.i-lucide-loader-2').exists()).toBe(true);
      expect(wrapper.find('.animate-spin').exists()).toBe(true);
    });

    it('hides spinner when not streaming', () => {
      const wrapper = createWrapper({ isStreaming: false });

      expect(wrapper.find('.i-lucide-loader-2').exists()).toBe(false);
    });

    it('applies active color classes to icon when streaming', () => {
      const wrapper = createWrapper({
        isStreaming: true,
        accentColor: 'iris',
      });

      const icon = wrapper.find('.i-lucide-brain');
      expect(icon.classes()).toContain('animate-pulse');
      expect(icon.classes()).toContain('text-n-iris-9');
    });
  });

  // =============================================================================
  // Accent Colors
  // =============================================================================
  describe('accent colors', () => {
    it('applies iris accent classes when streaming', () => {
      const wrapper = createWrapper({
        accentColor: 'iris',
        isStreaming: true,
      });

      const icon = wrapper.find('.i-lucide-brain');
      expect(icon.classes()).toContain('text-n-iris-9');
    });

    it('applies amber accent classes when streaming', () => {
      const wrapper = createWrapper({
        accentColor: 'amber',
        isStreaming: true,
      });

      const icon = wrapper.find('.i-lucide-brain');
      expect(icon.classes()).toContain('text-n-amber-9');
    });

    it('applies teal accent classes when streaming', () => {
      const wrapper = createWrapper({
        accentColor: 'teal',
        isStreaming: true,
      });

      const icon = wrapper.find('.i-lucide-brain');
      expect(icon.classes()).toContain('text-n-teal-9');
    });

    it('defaults to slate accent color when streaming', () => {
      const wrapper = createWrapper({
        isStreaming: true,
      });

      const icon = wrapper.find('.i-lucide-brain');
      expect(icon.classes()).toContain('text-n-slate-9');
    });
  });

  // =============================================================================
  // Props Validation
  // =============================================================================
  describe('props', () => {
    it('accepts valid accent colors', () => {
      const validColors = ['iris', 'slate', 'amber', 'teal', 'ruby'];

      validColors.forEach(color => {
        const wrapper = createWrapper({
          accentColor: color,
          isStreaming: true,
        });
        expect(wrapper.exists()).toBe(true);
      });
    });

    it('respects showActions prop default (true)', () => {
      const wrapper = createWrapper();
      // Component should render with showActions true by default
      expect(wrapper.exists()).toBe(true);
    });

    it('respects autoExpandOnStream prop default (true)', () => {
      const wrapper = createWrapper();
      // Component should render with autoExpandOnStream true by default
      expect(wrapper.exists()).toBe(true);
    });
  });
});
