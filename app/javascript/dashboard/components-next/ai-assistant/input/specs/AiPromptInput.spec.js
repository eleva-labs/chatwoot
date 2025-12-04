import { mount } from '@vue/test-utils';
import AiPromptInput from '../AiPromptInput.vue';

// Mock useAutoResizeTextarea
vi.mock('../../composables/useAutoResizeTextarea', () => ({
  useAutoResizeTextarea: vi.fn(() => ({
    textareaRef: { value: null },
    resize: vi.fn(),
    reset: vi.fn(),
  })),
}));

describe('AiPromptInput', () => {
  const createWrapper = (props = {}) => {
    return mount(AiPromptInput, {
      props,
      global: {
        stubs: {
          Button: {
            template:
              '<button class="submit-button" :disabled="disabled" type="submit"><slot /></button>',
            props: [
              'disabled',
              'isLoading',
              'type',
              'icon',
              'sm',
              'solid',
              'blue',
            ],
          },
          AiVoiceButton: {
            template: '<button class="voice-button" disabled></button>',
            props: ['status', 'disabled'],
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
    it('renders a textarea', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('textarea').exists()).toBe(true);
    });

    it('renders a submit button', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.submit-button').exists()).toBe(true);
    });

    it('renders a voice button', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.voice-button').exists()).toBe(true);
    });

    it('renders form element', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('form').exists()).toBe(true);
    });
  });

  // =============================================================================
  // Placeholder
  // =============================================================================
  describe('placeholder', () => {
    it('uses custom placeholder when provided', () => {
      const wrapper = createWrapper({ placeholder: 'Custom placeholder' });

      expect(wrapper.find('textarea').attributes('placeholder')).toBe(
        'Custom placeholder'
      );
    });

    it('uses i18n default placeholder when not provided', () => {
      const wrapper = createWrapper();

      // Placeholder comes from i18n
      expect(wrapper.find('textarea').attributes('placeholder')).toBeTruthy();
    });
  });

  // =============================================================================
  // Disabled State
  // =============================================================================
  describe('disabled state', () => {
    it('disables textarea when disabled prop is true', () => {
      const wrapper = createWrapper({ disabled: true });

      expect(wrapper.find('textarea').attributes('disabled')).toBeDefined();
    });

    it('disables textarea when isLoading is true', () => {
      const wrapper = createWrapper({ isLoading: true });

      expect(wrapper.find('textarea').attributes('disabled')).toBeDefined();
    });

    it('enables textarea when neither disabled nor isLoading', () => {
      const wrapper = createWrapper({ disabled: false, isLoading: false });

      expect(wrapper.find('textarea').attributes('disabled')).toBeUndefined();
    });
  });

  // =============================================================================
  // Submit Button
  // =============================================================================
  describe('submit button', () => {
    it('disables submit button when textarea is empty', () => {
      const wrapper = createWrapper();

      expect(
        wrapper.find('.submit-button').attributes('disabled')
      ).toBeDefined();
    });

    it('disables submit button when disabled prop is true', async () => {
      const wrapper = createWrapper({ disabled: true });

      await wrapper.find('textarea').setValue('Hello');

      expect(
        wrapper.find('.submit-button').attributes('disabled')
      ).toBeDefined();
    });

    it('disables submit button when isLoading is true', async () => {
      const wrapper = createWrapper({ isLoading: true });

      await wrapper.find('textarea').setValue('Hello');

      expect(
        wrapper.find('.submit-button').attributes('disabled')
      ).toBeDefined();
    });

    it('enables submit button when has text and not disabled', async () => {
      const wrapper = createWrapper();

      await wrapper.find('textarea').setValue('Hello');

      expect(
        wrapper.find('.submit-button').attributes('disabled')
      ).toBeUndefined();
    });
  });

  // =============================================================================
  // Submit Event
  // =============================================================================
  describe('submit event', () => {
    it('emits submit event with text when form is submitted', async () => {
      const wrapper = createWrapper();

      await wrapper.find('textarea').setValue('Hello world');
      await wrapper.find('form').trigger('submit');

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0]).toEqual(['Hello world']);
    });

    it('trims whitespace from submitted text', async () => {
      const wrapper = createWrapper();

      await wrapper.find('textarea').setValue('  Hello world  ');
      await wrapper.find('form').trigger('submit');

      expect(wrapper.emitted('submit')[0]).toEqual(['Hello world']);
    });

    it('clears textarea after submit', async () => {
      const wrapper = createWrapper();

      await wrapper.find('textarea').setValue('Hello world');
      await wrapper.find('form').trigger('submit');

      expect(wrapper.find('textarea').element.value).toBe('');
    });

    it('does not emit submit when textarea is empty', async () => {
      const wrapper = createWrapper();

      await wrapper.find('form').trigger('submit');

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('does not emit submit when only whitespace', async () => {
      const wrapper = createWrapper();

      await wrapper.find('textarea').setValue('   ');
      await wrapper.find('form').trigger('submit');

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('does not emit submit when disabled', async () => {
      const wrapper = createWrapper({ disabled: true });

      await wrapper.find('textarea').setValue('Hello');
      await wrapper.find('form').trigger('submit');

      expect(wrapper.emitted('submit')).toBeUndefined();
    });
  });

  // =============================================================================
  // Keyboard Events
  // =============================================================================
  describe('keyboard events', () => {
    it('submits on Enter key', async () => {
      const wrapper = createWrapper();

      await wrapper.find('textarea').setValue('Hello');
      await wrapper.find('textarea').trigger('keydown', { key: 'Enter' });

      expect(wrapper.emitted('submit')).toHaveLength(1);
    });

    it('does not submit on Shift+Enter (allows newline)', async () => {
      const wrapper = createWrapper();

      await wrapper.find('textarea').setValue('Hello');
      await wrapper
        .find('textarea')
        .trigger('keydown', { key: 'Enter', shiftKey: true });

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('prevents default on Enter without Shift', async () => {
      const wrapper = createWrapper();
      const preventDefault = vi.fn();

      await wrapper.find('textarea').setValue('Hello');
      await wrapper
        .find('textarea')
        .trigger('keydown', { key: 'Enter', preventDefault });

      expect(preventDefault).toHaveBeenCalled();
    });
  });

  // =============================================================================
  // Styling
  // =============================================================================
  describe('styling', () => {
    it('applies container border and background classes', () => {
      const wrapper = createWrapper();

      const container = wrapper.find('.border-t');
      expect(container.exists()).toBe(true);
      expect(container.classes()).toContain('border-n-weak');
      expect(container.classes()).toContain('bg-n-solid-1');
    });

    it('applies textarea styling classes', () => {
      const wrapper = createWrapper();

      const textarea = wrapper.find('textarea');
      expect(textarea.classes()).toContain('flex-1');
      expect(textarea.classes()).toContain('resize-none');
      expect(textarea.classes()).toContain('rounded-lg');
    });
  });

  // =============================================================================
  // Accessibility
  // =============================================================================
  describe('accessibility', () => {
    it('sets aria-label on textarea', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('textarea').attributes('aria-label')).toBeTruthy();
    });

    it('uses placeholder as aria-label by default', () => {
      const wrapper = createWrapper({ placeholder: 'Type a message' });

      expect(wrapper.find('textarea').attributes('aria-label')).toBe(
        'Type a message'
      );
    });
  });
});
