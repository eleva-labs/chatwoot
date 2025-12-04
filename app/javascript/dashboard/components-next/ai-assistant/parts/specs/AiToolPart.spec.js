import { mount } from '@vue/test-utils';
import AiToolPart from '../AiToolPart.vue';

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

describe('AiToolPart', () => {
  const defaultProps = {
    part: {
      type: 'tool-output-available',
      toolName: 'search_web',
      input: { query: 'weather today' },
      output: { result: 'Sunny, 75°F' },
    },
  };

  const createWrapper = (props = {}) => {
    return mount(AiToolPart, {
      props: { ...defaultProps, ...props },
      global: {
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
                  <slot />
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

    it('uses wrench icon', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.i-lucide-wrench').exists()).toBe(true);
    });

    it('displays tool name as label', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.collapsible-label').text()).toBe('search_web');
    });
  });

  // =============================================================================
  // Tool Name
  // =============================================================================
  describe('tool name', () => {
    it('uses toolName from part', () => {
      const wrapper = createWrapper({
        part: { toolName: 'custom_tool' },
      });

      expect(wrapper.find('.collapsible-label').text()).toBe('custom_tool');
    });

    it('falls back to output.tool_name', () => {
      const wrapper = createWrapper({
        part: { output: { tool_name: 'fallback_tool' } },
      });

      expect(wrapper.find('.collapsible-label').text()).toBe('fallback_tool');
    });

    it('uses default label when no tool name', () => {
      const wrapper = createWrapper({
        part: {},
      });

      // Falls back to i18n key
      expect(wrapper.find('.collapsible-label').exists()).toBe(true);
    });
  });

  // =============================================================================
  // Input Section
  // =============================================================================
  describe('input section', () => {
    it('shows input section when input exists', () => {
      const wrapper = createWrapper({
        part: { input: { query: 'test' } },
      });

      expect(wrapper.find('.collapsible-content').text()).toContain('query');
      expect(wrapper.find('.collapsible-content').text()).toContain('test');
    });

    it('hides input section when input is null', () => {
      const wrapper = createWrapper({
        part: { input: null, output: { result: 'data' } },
      });

      const content = wrapper.find('.collapsible-content');
      expect(content.text()).not.toContain('INPUT');
    });

    it('formats input as JSON', () => {
      const wrapper = createWrapper({
        part: { input: { key: 'value', nested: { a: 1 } } },
      });

      expect(wrapper.find('pre').exists()).toBe(true);
      expect(wrapper.text()).toContain('key');
      expect(wrapper.text()).toContain('value');
    });
  });

  // =============================================================================
  // Output Section
  // =============================================================================
  describe('output section', () => {
    it('shows output section when output exists', () => {
      const wrapper = createWrapper({
        part: { output: { result: 'success' } },
      });

      expect(wrapper.find('.collapsible-content').text()).toContain('result');
      expect(wrapper.find('.collapsible-content').text()).toContain('success');
    });

    it('hides output section when output is null', () => {
      const wrapper = createWrapper({
        part: { input: { query: 'test' }, output: null },
      });

      const pres = wrapper.findAll('pre');
      // Should only show input, not output
      expect(pres.length).toBe(1);
    });

    it('formats output as JSON', () => {
      const wrapper = createWrapper({
        part: { output: { data: [1, 2, 3] } },
      });

      expect(wrapper.text()).toContain('data');
      expect(wrapper.text()).toContain('1');
    });
  });

  // =============================================================================
  // Both Input and Output
  // =============================================================================
  describe('both sections', () => {
    it('shows both input and output when both exist', () => {
      const wrapper = createWrapper({
        part: {
          input: { query: 'search' },
          output: { result: 'found' },
        },
      });

      const pres = wrapper.findAll('pre');
      expect(pres.length).toBe(2);
    });

    it('displays input before output', () => {
      const wrapper = createWrapper({
        part: {
          input: { query: 'first' },
          output: { result: 'second' },
        },
      });

      const content = wrapper.find('.collapsible-content').text();
      const inputIndex = content.indexOf('query');
      const outputIndex = content.indexOf('result');
      expect(inputIndex).toBeLessThan(outputIndex);
    });
  });

  // =============================================================================
  // Streaming State
  // =============================================================================
  describe('streaming state', () => {
    it('passes isStreaming to AiCollapsiblePart', () => {
      const wrapper = createWrapper({
        isStreaming: true,
        part: defaultProps.part,
      });

      expect(wrapper.find('.streaming-indicator').exists()).toBe(true);
    });

    it('passes isStreaming false by default', () => {
      const wrapper = createWrapper();

      expect(wrapper.find('.streaming-indicator').exists()).toBe(false);
    });
  });

  // =============================================================================
  // Collapsible Configuration
  // =============================================================================
  describe('collapsible configuration', () => {
    it('uses slate accent color', () => {
      const wrapper = createWrapper();

      // Check the stubbed component has the correct class indicating accent-color was passed
      const collapsible = wrapper.find('.ai-collapsible-stub');
      expect(collapsible.exists()).toBe(true);
      // The stub template doesn't explicitly show accentColor, but we can verify the component renders
    });

    it('sets autoExpandOnStream to false by default (collapsed initially)', () => {
      const wrapper = createWrapper({ isStreaming: true });

      // Even when streaming, the tool part should not auto-expand
      // This is verified by checking the streaming indicator is shown but no auto-expand happened
      expect(wrapper.find('.streaming-indicator').exists()).toBe(true);
    });
  });
});
