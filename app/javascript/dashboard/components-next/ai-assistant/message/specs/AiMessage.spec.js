import { mount } from '@vue/test-utils';
import AiMessage from '../AiMessage.vue';
import { MESSAGE_ROLE } from '../../constants';

describe('AiMessage', () => {
  const defaultProps = {
    from: MESSAGE_ROLE.ASSISTANT,
  };

  const createWrapper = (props = {}, slots = {}) => {
    return mount(AiMessage, {
      props: { ...defaultProps, ...props },
      slots: {
        default: '<div class="message-content">Message content</div>',
        ...slots,
      },
      global: {
        stubs: {
          Avatar: {
            template:
              '<div class="avatar-stub" :data-name="name" :data-src="src" :data-icon="iconName"></div>',
            props: ['name', 'src', 'iconName', 'size', 'roundedFull'],
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
    it('renders message container', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.flex.w-full').exists()).toBe(true);
    });

    it('renders Avatar component', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.avatar-stub').exists()).toBe(true);
    });

    it('renders slot content', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.message-content').exists()).toBe(true);
      expect(wrapper.text()).toContain('Message content');
    });
  });

  // =============================================================================
  // Message Alignment
  // =============================================================================
  describe('message alignment', () => {
    it('applies flex-row for assistant messages', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.ASSISTANT });

      const container = wrapper.find('.flex.w-full');
      expect(container.classes()).toContain('flex-row');
      expect(container.classes()).not.toContain('flex-row-reverse');
    });

    it('applies flex-row-reverse for user messages', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.USER });

      const container = wrapper.find('.flex.w-full');
      expect(container.classes()).toContain('flex-row-reverse');
    });
  });

  // =============================================================================
  // Content Container Width
  // =============================================================================
  describe('content container width', () => {
    it('applies fixed 80% width for assistant messages', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.ASSISTANT });

      const contentContainer = wrapper.find('.flex.flex-col');
      expect(contentContainer.classes()).toContain('w-[80%]');
      expect(contentContainer.classes()).not.toContain('max-w-[80%]');
    });

    it('applies max-width 80% for user messages', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.USER });

      const contentContainer = wrapper.find('.flex.flex-col');
      expect(contentContainer.classes()).toContain('max-w-[80%]');
      expect(contentContainer.classes()).not.toContain('w-[80%]');
    });
  });

  // =============================================================================
  // Avatar
  // =============================================================================
  describe('avatar', () => {
    it('uses provided avatarName', () => {
      const wrapper = createWrapper({ avatarName: 'John Doe' });

      expect(wrapper.find('.avatar-stub').attributes('data-name')).toBe(
        'John Doe'
      );
    });

    it('uses provided avatarSrc', () => {
      const wrapper = createWrapper({
        avatarSrc: 'https://example.com/avatar.png',
      });

      expect(wrapper.find('.avatar-stub').attributes('data-src')).toBe(
        'https://example.com/avatar.png'
      );
    });

    it('falls back to "User" name for user messages', () => {
      const wrapper = createWrapper({
        from: MESSAGE_ROLE.USER,
        avatarName: '',
      });

      expect(wrapper.find('.avatar-stub').attributes('data-name')).toBe('User');
    });

    it('falls back to "AI" name for assistant messages', () => {
      const wrapper = createWrapper({
        from: MESSAGE_ROLE.ASSISTANT,
        avatarName: '',
      });

      expect(wrapper.find('.avatar-stub').attributes('data-name')).toBe('AI');
    });

    it('shows user icon when no avatar for user messages', () => {
      const wrapper = createWrapper({
        from: MESSAGE_ROLE.USER,
        avatarName: '',
        avatarSrc: '',
      });

      expect(wrapper.find('.avatar-stub').attributes('data-icon')).toBe(
        'i-lucide-user'
      );
    });

    it('shows bot icon when no avatar for assistant messages', () => {
      const wrapper = createWrapper({
        from: MESSAGE_ROLE.ASSISTANT,
        avatarName: '',
        avatarSrc: '',
      });

      expect(wrapper.find('.avatar-stub').attributes('data-icon')).toBe(
        'i-lucide-bot'
      );
    });

    it('hides icon when avatarSrc is provided', () => {
      const wrapper = createWrapper({
        avatarSrc: 'https://example.com/avatar.png',
      });

      expect(wrapper.find('.avatar-stub').attributes('data-icon')).toBeFalsy();
    });

    it('hides icon when avatarName is provided', () => {
      const wrapper = createWrapper({
        avatarName: 'Custom Name',
      });

      expect(wrapper.find('.avatar-stub').attributes('data-icon')).toBeFalsy();
    });
  });

  // =============================================================================
  // User Message Spacer
  // =============================================================================
  describe('user message spacer', () => {
    it('adds spacer for user messages', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.USER });

      const spacer = wrapper.find('[aria-hidden="true"]');
      expect(spacer.exists()).toBe(true);
      expect(spacer.classes()).toContain('h-7');
    });

    it('does not add spacer for assistant messages', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.ASSISTANT });

      const spacer = wrapper.find('[aria-hidden="true"]');
      expect(spacer.exists()).toBe(false);
    });
  });

  // =============================================================================
  // Role Validation
  // =============================================================================
  describe('role validation', () => {
    it('accepts user role', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.USER });

      expect(wrapper.exists()).toBe(true);
    });

    it('accepts assistant role', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.ASSISTANT });

      expect(wrapper.exists()).toBe(true);
    });

    it('accepts tool role', () => {
      const wrapper = createWrapper({ from: MESSAGE_ROLE.TOOL });

      expect(wrapper.exists()).toBe(true);
    });
  });
});
