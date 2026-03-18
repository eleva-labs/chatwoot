import { mount } from '@vue/test-utils';
import AiConversationEmptyState from '../AiConversationEmptyState.vue';

describe('AiConversationEmptyState', () => {
  const createWrapper = (props = {}, slots = {}) => {
    return mount(AiConversationEmptyState, {
      props,
      slots,
    });
  };

  afterEach(() => {
    vi.clearAllMocks();
  });

  // =============================================================================
  // Rendering
  // =============================================================================
  describe('rendering', () => {
    it('renders icon', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.i-lucide-message-circle').exists()).toBe(true);
    });

    it('renders title', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('h3').exists()).toBe(true);
    });

    it('renders description', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('p').exists()).toBe(true);
    });

    it('centers content', () => {
      const wrapper = createWrapper();

      const container = wrapper.find('.flex-col');
      expect(container.classes()).toContain('items-center');
      expect(container.classes()).toContain('justify-center');
    });
  });

  // =============================================================================
  // Custom Props
  // =============================================================================
  describe('custom props', () => {
    it('uses custom title when provided', () => {
      const wrapper = createWrapper({ title: 'Custom Title' });

      expect(wrapper.find('h3').text()).toBe('Custom Title');
    });

    it('uses custom description when provided', () => {
      const wrapper = createWrapper({ description: 'Custom description' });

      expect(wrapper.find('p').text()).toBe('Custom description');
    });

    it('uses custom icon when provided', () => {
      const wrapper = createWrapper({ icon: 'i-lucide-bot' });

      expect(wrapper.find('.i-lucide-bot').exists()).toBe(true);
      expect(wrapper.find('.i-lucide-message-circle').exists()).toBe(false);
    });
  });

  // =============================================================================
  // Suggestions Slot
  // =============================================================================
  describe('suggestions slot', () => {
    it('renders suggestions slot content', () => {
      const wrapper = createWrapper(
        {},
        {
          suggestions: '<div class="suggestions">Suggestions here</div>',
        }
      );

      expect(wrapper.find('.suggestions').exists()).toBe(true);
      expect(wrapper.text()).toContain('Suggestions here');
    });
  });

  // =============================================================================
  // Styling
  // =============================================================================
  describe('styling', () => {
    it('applies text styling classes', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('h3').classes()).toContain('text-lg');
      expect(wrapper.find('h3').classes()).toContain('font-semibold');
      expect(wrapper.find('p').classes()).toContain('text-sm');
    });

    it('applies icon container styling', () => {
      const wrapper = createWrapper();

      const iconContainer = wrapper.find('.rounded-full.bg-n-alpha-1');
      expect(iconContainer.exists()).toBe(true);
    });
  });
});
