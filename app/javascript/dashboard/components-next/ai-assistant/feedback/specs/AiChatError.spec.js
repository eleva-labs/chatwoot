import { mount } from '@vue/test-utils';
import AiChatError from '../AiChatError.vue';

describe('AiChatError', () => {
  const defaultProps = {
    error: new Error('Test error'),
  };

  const createWrapper = (props = {}) => {
    return mount(AiChatError, {
      props: { ...defaultProps, ...props },
    });
  };

  afterEach(() => {
    vi.clearAllMocks();
    vi.useRealTimers();
  });

  // =============================================================================
  // Error Categories
  // =============================================================================
  describe('error categories', () => {
    it('displays network error with correct icon', () => {
      const wrapper = createWrapper({
        error: new Error('Network error occurred'),
      });

      expect(wrapper.find('.i-lucide-wifi-off').exists()).toBe(true);
    });

    it('displays rate limit error with correct icon', () => {
      const wrapper = createWrapper({
        error: new Error('429 rate limit exceeded'),
      });

      expect(wrapper.find('.i-lucide-clock').exists()).toBe(true);
    });

    it('displays auth error with correct icon', () => {
      const wrapper = createWrapper({
        error: new Error('401 unauthorized'),
      });

      expect(wrapper.find('.i-lucide-lock').exists()).toBe(true);
    });

    it('displays server error with correct icon', () => {
      const wrapper = createWrapper({
        error: new Error('500 server error'),
      });

      expect(wrapper.find('.i-lucide-server-off').exists()).toBe(true);
    });

    it('displays unknown error with correct icon', () => {
      const wrapper = createWrapper({
        error: new Error('Something went wrong'),
      });

      expect(wrapper.find('.i-lucide-alert-circle').exists()).toBe(true);
    });
  });

  // =============================================================================
  // Retry Button
  // =============================================================================
  describe('retry button', () => {
    it('shows retry button when canRetry is true', () => {
      const wrapper = createWrapper({ canRetry: true });

      const retryButton = wrapper.findAll('button').find(b => {
        return b.find('.i-lucide-refresh-cw').exists();
      });
      expect(retryButton).toBeDefined();
    });

    it('hides retry button when canRetry is false', () => {
      const wrapper = createWrapper({ canRetry: false });

      const refreshIcon = wrapper.find('.i-lucide-refresh-cw');
      expect(refreshIcon.exists()).toBe(false);
    });

    it('emits retry event when retry button is clicked', async () => {
      const wrapper = createWrapper({ canRetry: true });

      const retryButton = wrapper
        .findAll('button')
        .find(b => b.find('.i-lucide-refresh-cw').exists());
      await retryButton.trigger('click');

      expect(wrapper.emitted('retry')).toHaveLength(1);
    });

    it('disables retry for auth errors', () => {
      const wrapper = createWrapper({
        error: new Error('401 unauthorized'),
        canRetry: true,
      });

      const refreshIcon = wrapper.find('.i-lucide-refresh-cw');
      expect(refreshIcon.exists()).toBe(false);
    });
  });

  // =============================================================================
  // Edit Button
  // =============================================================================
  describe('edit button', () => {
    it('shows edit button when canEdit is true', () => {
      const wrapper = createWrapper({ canEdit: true, canRetry: true });

      expect(wrapper.find('.i-lucide-pencil').exists()).toBe(true);
    });

    it('hides edit button when canEdit is false', () => {
      const wrapper = createWrapper({ canEdit: false });

      expect(wrapper.find('.i-lucide-pencil').exists()).toBe(false);
    });

    it('emits edit event when edit button is clicked', async () => {
      const wrapper = createWrapper({ canEdit: true, canRetry: true });

      const editButton = wrapper
        .findAll('button')
        .find(b => b.find('.i-lucide-pencil').exists());
      await editButton.trigger('click');

      expect(wrapper.emitted('edit')).toHaveLength(1);
    });
  });

  // =============================================================================
  // Fresh Start Button
  // =============================================================================
  describe('fresh start button', () => {
    it('shows fresh start button', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.i-lucide-rotate-ccw').exists()).toBe(true);
    });

    it('emits fresh-start event when fresh start button is clicked', async () => {
      const wrapper = createWrapper();

      const freshStartButton = wrapper
        .findAll('button')
        .find(b => b.find('.i-lucide-rotate-ccw').exists());
      await freshStartButton.trigger('click');

      expect(wrapper.emitted('fresh-start')).toHaveLength(1);
    });
  });

  // =============================================================================
  // Dismiss Button
  // =============================================================================
  describe('dismiss button', () => {
    it('emits dismiss event when dismiss button is clicked', async () => {
      const wrapper = createWrapper();

      // Dismiss button is the last button
      const buttons = wrapper.findAll('button');
      const dismissButton = buttons[buttons.length - 1];
      await dismissButton.trigger('click');

      expect(wrapper.emitted('dismiss')).toHaveLength(1);
    });
  });

  // =============================================================================
  // Technical Details
  // =============================================================================
  describe('technical details', () => {
    it('shows technical details when error has message', () => {
      const wrapper = createWrapper({
        error: new Error('Detailed error message'),
      });

      expect(wrapper.find('details').exists()).toBe(true);
    });

    it('displays error message in technical details', () => {
      const errorMessage = 'Detailed error message';
      const wrapper = createWrapper({
        error: new Error(errorMessage),
      });

      expect(wrapper.find('pre').text()).toBe(errorMessage);
    });
  });

  // =============================================================================
  // Countdown Timer
  // =============================================================================
  describe('countdown timer', () => {
    it('initializes countdown with retryDelay', () => {
      const wrapper = createWrapper({
        error: new Error('rate limit'),
        retryDelay: 30,
      });

      // Countdown should be shown in the message
      expect(wrapper.vm.countdown).toBe(30);
    });

    it('decrements countdown every second', async () => {
      vi.useFakeTimers();

      const wrapper = createWrapper({
        error: new Error('rate limit'),
        retryDelay: 5,
      });

      expect(wrapper.vm.countdown).toBe(5);

      vi.advanceTimersByTime(1000);
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.countdown).toBe(4);

      vi.advanceTimersByTime(1000);
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.countdown).toBe(3);
    });

    it('disables retry during countdown for rate limit', () => {
      const wrapper = createWrapper({
        error: new Error('rate limit'),
        retryDelay: 10,
        canRetry: true,
      });

      // Retry should not be available while countdown > 0
      const refreshIcon = wrapper.find('.i-lucide-refresh-cw');
      expect(refreshIcon.exists()).toBe(false);
    });

    it('enables retry after countdown completes', async () => {
      vi.useFakeTimers();

      const wrapper = createWrapper({
        error: new Error('rate limit'),
        retryDelay: 2,
        canRetry: true,
      });

      // Advance past countdown
      vi.advanceTimersByTime(3000);
      await wrapper.vm.$nextTick();

      const refreshIcon = wrapper.find('.i-lucide-refresh-cw');
      expect(refreshIcon.exists()).toBe(true);
    });
  });

  // =============================================================================
  // Color Classes
  // =============================================================================
  describe('color classes', () => {
    it('applies red styling for server errors', () => {
      const wrapper = createWrapper({
        error: new Error('500 server error'),
      });

      const container = wrapper.find('.border-t');
      expect(container.classes()).toContain('bg-n-ruby-3');
    });

    it('applies amber styling for network errors', () => {
      const wrapper = createWrapper({
        error: new Error('network failure'),
      });

      const container = wrapper.find('.border-t');
      expect(container.classes()).toContain('bg-n-amber-3');
    });
  });
});
