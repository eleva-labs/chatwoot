# Frontend Testing Patterns (Vitest + Vue Test Utils)

## Table of Contents
1. [Setup and Configuration](#setup-and-configuration)
2. [Testing Framework and Tools](#testing-framework-and-tools)
3. [Test Structure and Organization](#test-structure-and-organization)
4. [Mocking Patterns](#mocking-patterns)
5. [Component Testing](#component-testing)
6. [Composable Testing](#composable-testing)
7. [Store/Vuex Testing](#storevuex-testing)
8. [API Mocking](#api-mocking)
9. [Global Test Configuration](#global-test-configuration)
10. [Best Practices](#best-practices)
11. [Running Tests](#running-tests)

---

## Setup and Configuration

### Configuration Files

#### `vite.config.ts`

The Vitest configuration is embedded in the Vite config:

```typescript
export default defineConfig({
  test: {
    environment: 'jsdom',                                    // DOM environment for Vue
    include: ['app/**/*.{test,spec}.?(c|m)[jt]s?(x)'],     // Test file pattern
    coverage: {
      reporter: ['lcov', 'text'],
      include: ['app/**/*.js', 'app/**/*.vue'],
      exclude: [
        'app/**/*.@(spec|stories|routes).js',
        '**/specs/**/*',
        '**/i18n/**/*',
      ],
    },
    globals: true,                                          // Global test APIs
    setupFiles: ['fake-indexeddb/auto', 'vitest.setup.js'],// Setup files
    mockReset: true,                                        // Reset mocks between tests
    clearMocks: true,                                       // Clear mock call history
  },
});
```

**Key Features:**
- Uses `jsdom` for DOM simulation
- Global test APIs (no need to import `describe`, `it`, `expect`)
- Automatic mock reset between tests
- IndexedDB support via `fake-indexeddb`

#### `vitest.setup.js`

Global test configuration and stubs:

```javascript
import { config } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import i18nMessages from 'dashboard/i18n';
import FloatingVue from 'floating-vue';

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: i18nMessages,
});

config.global.plugins = [i18n, FloatingVue];
config.global.stubs = {
  WootModal: { template: '<div><slot/></div>' },
  WootModalHeader: { template: '<div><slot/></div>' },
  NextButton: { template: '<button><slot/></button>' },
  // Component stubs here
};
```

**Purpose:**
- Sets up global plugins (i18n, FloatingVue)
- Defines global component stubs to simplify testing
- Configures Vue Test Utils defaults

---

## Testing Framework and Tools

### Core Testing Tools

| Tool | Purpose |
|------|---------|
| **Vitest** | Fast unit test framework (Vite-native) |
| **@vue/test-utils** | Official Vue 3 testing utilities |
| **jsdom** | DOM simulation in Node.js |
| **fake-indexeddb** | IndexedDB mock for browser storage testing |
| **vi (Vitest)** | Mocking and spying utilities |

### Import Patterns

```javascript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mount, shallowMount } from '@vue/test-utils';
import { ref, computed } from 'vue';
```

**Note:** With `globals: true`, you don't need to import `describe`, `it`, `expect`, but it's shown here for clarity.

---

## Test Structure and Organization

### Directory Structure

```
app/javascript/
├── dashboard/
│   ├── composables/
│   │   └── spec/                       # Composable tests
│   │       ├── useKeyboardNavigableList.spec.js
│   │       └── useAgentsList.spec.js
│   ├── components/
│   │   └── ComponentName.spec.js       # Component tests (co-located)
│   ├── store/
│   │   └── modules/
│   │       └── specs/                  # Store tests
│   │           ├── actions.spec.js
│   │           ├── mutations.spec.js
│   │           └── getters.spec.js
│   └── helper/
│       └── specs/                      # Helper utility tests
├── widget/
│   ├── composables/
│   │   └── specs/
│   ├── store/
│   │   └── modules/
│   │       └── specs/
│   └── helpers/
│       └── specs/
└── portal/
    └── specs/
```

### File Naming Convention

- Component tests: `ComponentName.spec.js` (co-located with component)
- Composable tests: `composables/spec/useComposableName.spec.js`
- Store tests: `store/modules/specs/actions.spec.js`
- Helper tests: `helper/specs/helperName.spec.js`

### Test File Structure

```javascript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { composableOrFunction } from '../composable';

describe('FeatureName', () => {
  let variable1;
  let variable2;

  beforeEach(() => {
    // Setup code that runs before each test
    variable1 = ref('value');
    variable2 = vi.fn();
    vi.clearAllMocks();
  });

  it('should do something specific', () => {
    const result = composableOrFunction({ variable1, variable2 });

    expect(result).toHaveProperty('property');
    expect(variable2).toHaveBeenCalledWith('expected');
  });

  it('should handle another case', () => {
    // Test code
  });
});
```

---

## Mocking Patterns

### Vitest Mock Functions

#### Creating Mocks

```javascript
// Create a mock function
const mockFn = vi.fn();

// Mock function with return value
const mockFn = vi.fn().mockReturnValue('value');

// Mock function with resolved promise
const mockFn = vi.fn().mockResolvedValue({ data: 'value' });

// Mock function with rejected promise
const mockFn = vi.fn().mockRejectedValue(new Error('failed'));
```

#### Module Mocking

```javascript
// Mock an entire module
vi.mock('../useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

// Mock specific exports
vi.mock('widget/helpers/axios', () => ({
  API: {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
  },
}));

// Mock with factory function
vi.mock('widget/helpers/utils', () => ({
  sendMessage: vi.fn(),
}));
```

#### Spying on Methods

```javascript
// Spy on method and mock implementation
vi.spyOn(API, 'patch').mockResolvedValue({
  data: { widget_auth_token: 'token' },
});

// Spy without changing implementation
vi.spyOn(console, 'warn');
```

#### Clearing and Resetting Mocks

```javascript
beforeEach(() => {
  vi.clearAllMocks();   // Clears call history
  vi.resetAllMocks();   // Resets implementation too
});
```

### Assertions on Mocks

```javascript
// Call verification
expect(mockFn).toHaveBeenCalled();
expect(mockFn).toHaveBeenCalledTimes(2);
expect(mockFn).toHaveBeenCalledWith('arg1', 'arg2');

// Mock call inspection
expect(mockFn.mock.calls).toEqual([
  ['arg1'],
  ['arg2'],
]);

expect(mockFn.mock.calls[0][0]).toBe('first argument of first call');
```

---

## Component Testing

### Mounting Components

```javascript
import { mount, shallowMount } from '@vue/test-utils';
import MyComponent from './MyComponent.vue';

describe('MyComponent', () => {
  it('renders correctly', () => {
    const wrapper = mount(MyComponent, {
      props: {
        title: 'Test Title',
      },
    });

    expect(wrapper.text()).toContain('Test Title');
  });
});
```

### Mount vs ShallowMount

```javascript
// mount: Renders component and all children
const wrapper = mount(ParentComponent);

// shallowMount: Stubs child components (faster, more isolated)
const wrapper = shallowMount(ParentComponent);
```

### Component Mounting Options

```javascript
const wrapper = mount(Component, {
  props: {
    title: 'Test',
    value: 123,
  },
  global: {
    plugins: [store, router],
    stubs: {
      ChildComponent: true,  // Stub child component
    },
    mocks: {
      $t: (key) => key,      // Mock i18n
    },
  },
  slots: {
    default: '<p>Slot content</p>',
  },
  attachTo: document.body,   // Attach to DOM for focus/blur tests
});
```

### Component Interaction

```javascript
// Find elements
const button = wrapper.find('button');
const input = wrapper.find('input[type="text"]');

// Trigger events
await button.trigger('click');
await input.setValue('new value');
await input.trigger('input');

// Check classes
expect(button.classes()).toContain('active');
expect(button.classes('disabled')).toBe(true);

// Check attributes
expect(input.attributes('placeholder')).toBe('Enter text');

// Check visibility
expect(wrapper.find('.error').exists()).toBe(false);

// Access component instance
expect(wrapper.vm.someProperty).toBe('value');
```

### Testing Emitted Events

```javascript
it('emits event when button clicked', async () => {
  const wrapper = mount(Component);

  await wrapper.find('button').trigger('click');

  expect(wrapper.emitted()).toHaveProperty('submit');
  expect(wrapper.emitted('submit')).toHaveLength(1);
  expect(wrapper.emitted('submit')[0]).toEqual([{ id: 123 }]);
});
```

### Testing Slots

```javascript
it('renders slot content', () => {
  const wrapper = mount(Component, {
    slots: {
      default: '<span>Default slot</span>',
      header: '<h1>Header slot</h1>',
    },
  });

  expect(wrapper.html()).toContain('Default slot');
  expect(wrapper.html()).toContain('Header slot');
});
```

### Testing with Vuex Store

```javascript
import { createStore } from 'vuex';

const store = createStore({
  state: { count: 0 },
  mutations: {
    increment(state) { state.count++; },
  },
  actions: {
    asyncIncrement({ commit }) { commit('increment'); },
  },
});

const wrapper = mount(Component, {
  global: {
    plugins: [store],
  },
});

// Test store integration
await wrapper.vm.$store.dispatch('asyncIncrement');
expect(wrapper.vm.$store.state.count).toBe(1);
```

---

## Composable Testing

### Basic Composable Testing

```javascript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ref } from 'vue';
import { useKeyboardNavigableList } from '../useKeyboardNavigableList';

describe('useKeyboardNavigableList', () => {
  let items;
  let onSelect;
  let adjustScroll;
  let selectedIndex;

  beforeEach(() => {
    items = ref(['item1', 'item2', 'item3']);
    onSelect = vi.fn();
    adjustScroll = vi.fn();
    selectedIndex = ref(0);
    vi.clearAllMocks();
  });

  it('should return expected functions', () => {
    const result = useKeyboardNavigableList({
      items,
      onSelect,
      adjustScroll,
      selectedIndex,
    });

    expect(result).toHaveProperty('moveSelectionUp');
    expect(result).toHaveProperty('moveSelectionDown');
  });
});
```

### Testing Composable Reactivity

```javascript
it('should update reactive values correctly', () => {
  const count = ref(0);
  const { increment } = useCounter(count);

  increment();

  expect(count.value).toBe(1);
});
```

### Testing Composable Side Effects

```javascript
it('should call callback after action', () => {
  const callback = vi.fn();
  const { performAction } = useComposable({ onComplete: callback });

  performAction();

  expect(callback).toHaveBeenCalledTimes(1);
});
```

### Mocking Composable Dependencies

```javascript
vi.mock('../useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

describe('useKeyboardNavigableList', () => {
  it('should call useKeyboardEvents with correct parameters', () => {
    useKeyboardNavigableList({ items, onSelect, adjustScroll, selectedIndex });

    expect(useKeyboardEvents).toHaveBeenCalledWith(expect.any(Object));
  });

  it('should handle ArrowUp key', () => {
    useKeyboardNavigableList({ items, onSelect, adjustScroll, selectedIndex });

    const keyboardEvents = useKeyboardEvents.mock.calls[0][0];
    const mockEvent = { preventDefault: vi.fn() };

    keyboardEvents.ArrowUp.action(mockEvent);

    expect(selectedIndex.value).toBe(2);  // Circular navigation
    expect(adjustScroll).toHaveBeenCalled();
    expect(mockEvent.preventDefault).toHaveBeenCalled();
  });
});
```

---

## Store/Vuex Testing

### Testing Actions

```javascript
import { API } from 'widget/helpers/axios';
import { sendMessage } from 'widget/helpers/utils';
import { actions } from '../../contacts';

const commit = vi.fn();
const dispatch = vi.fn();

vi.mock('widget/helpers/axios');
vi.mock('widget/helpers/utils', () => ({
  sendMessage: vi.fn(),
}));

describe('#actions', () => {
  describe('#setUser', () => {
    it('dispatches correct actions when user is refreshed', async () => {
      const user = {
        email: 'user@example.com',
        name: 'User Name',
        avatar_url: '',
      };

      vi.spyOn(API, 'patch').mockResolvedValue({
        data: { widget_auth_token: 'token' },
      });

      await actions.setUser({ commit, dispatch }, { identifier: 1, user });

      expect(sendMessage.mock.calls).toEqual([
        [{ data: { widgetAuthToken: 'token' }, event: 'setAuthCookie' }],
      ]);

      expect(dispatch.mock.calls).toEqual([
        ['get'],
        ['conversation/clearConversations', {}, { root: true }],
        ['conversation/fetchOldConversations', {}, { root: true }],
        ['conversationAttributes/getAttributes', {}, { root: true }],
      ]);
    });
  });
});
```

### Testing Mutations

```javascript
import { mutations } from '../../contacts';

describe('#mutations', () => {
  describe('SET_USER', () => {
    it('sets user in state', () => {
      const state = { user: null };
      const user = { id: 1, name: 'Test' };

      mutations.SET_USER(state, user);

      expect(state.user).toEqual(user);
    });
  });
});
```

### Testing Getters

```javascript
import { getters } from '../../contacts';

describe('#getters', () => {
  describe('getUserName', () => {
    it('returns user name when user exists', () => {
      const state = { user: { name: 'Test User' } };

      expect(getters.getUserName(state)).toBe('Test User');
    });

    it('returns empty string when user is null', () => {
      const state = { user: null };

      expect(getters.getUserName(state)).toBe('');
    });
  });
});
```

---

## API Mocking

### Mocking Axios Requests

```javascript
import { API } from 'widget/helpers/axios';

vi.mock('widget/helpers/axios');

describe('API calls', () => {
  it('fetches data successfully', async () => {
    const mockData = { id: 1, name: 'Test' };

    vi.spyOn(API, 'get').mockResolvedValue({ data: mockData });

    const result = await fetchData();

    expect(API.get).toHaveBeenCalledWith('/api/endpoint');
    expect(result).toEqual(mockData);
  });

  it('handles API errors', async () => {
    const error = new Error('Network error');

    vi.spyOn(API, 'get').mockRejectedValue(error);

    await expect(fetchData()).rejects.toThrow('Network error');
  });
});
```

### Mocking Different Response Scenarios

```javascript
// Success response
API.get.mockResolvedValue({ data: { success: true } });

// Error response
API.post.mockRejectedValue({ response: { status: 404 } });

// Different responses for multiple calls
API.get
  .mockResolvedValueOnce({ data: { page: 1 } })
  .mockResolvedValueOnce({ data: { page: 2 } });
```

---

## Global Test Configuration

### Global Stubs

Stubs defined in `vitest.setup.js` are available in all tests:

```javascript
config.global.stubs = {
  WootModal: { template: '<div><slot/></div>' },
  WootModalHeader: { template: '<div><slot/></div>' },
  NextButton: { template: '<button><slot/></button>' },
  'dashboard/components-next/button/Button.vue': {
    template: '<button><slot/></button>',
    props: ['isLoading', 'type', 'solid', 'blue', 'green', 'label', 'disabled', 'class'],
    emits: ['click'],
  },
};
```

### Global Plugins

```javascript
config.global.plugins = [i18n, FloatingVue];
```

This means you don't need to provide these plugins in individual tests unless you need custom configuration.

### Per-Test Overrides

You can override global configuration per test:

```javascript
const wrapper = mount(Component, {
  global: {
    stubs: {
      CustomComponent: false,  // Don't stub this one
    },
    mocks: {
      $t: (key) => `mocked_${key}`,  // Override i18n
    },
  },
});
```

---

## Best Practices

### 1. Use `beforeEach` for Test Setup

```javascript
describe('Feature', () => {
  let variable;

  beforeEach(() => {
    variable = ref('initial');
    vi.clearAllMocks();
  });

  it('test 1', () => {
    // variable is fresh here
  });

  it('test 2', () => {
    // variable is fresh here too
  });
});
```

### 2. Create Mock Helper Functions

```javascript
const createMockEvent = () => ({ preventDefault: vi.fn() });

it('handles event', () => {
  const mockEvent = createMockEvent();
  handler(mockEvent);
  expect(mockEvent.preventDefault).toHaveBeenCalled();
});
```

### 3. Test User Interactions, Not Implementation

```javascript
// Good: Test what user sees/does
it('shows error when form is invalid', async () => {
  const wrapper = mount(Form);

  await wrapper.find('input').setValue('');
  await wrapper.find('button').trigger('click');

  expect(wrapper.find('.error').text()).toBe('Field is required');
});

// Avoid: Testing internal state
it('sets error flag', () => {
  wrapper.vm.hasError = true;
  expect(wrapper.vm.hasError).toBe(true);  // Testing implementation
});
```

### 4. Keep Tests Isolated

```javascript
// Each test should work independently
beforeEach(() => {
  vi.clearAllMocks();  // Clear mock call history
  // Reset state
});
```

### 5. Use Descriptive Test Names

```javascript
// Good
it('should move selection up when ArrowUp is pressed', () => {

// Avoid
it('works', () => {
```

### 6. Test Edge Cases

```javascript
it('should not trigger onSelect when items are empty', () => {
  const { moveSelectionUp } = useKeyboardNavigableList({
    items: ref([]),
    onSelect,
  });

  moveSelectionUp();

  expect(onSelect).not.toHaveBeenCalled();
});
```

### 7. Use Shallow Mounting When Appropriate

```javascript
// Shallow mount for isolated component testing
const wrapper = shallowMount(ParentComponent);

// Full mount when testing component integration
const wrapper = mount(ParentComponent);
```

### 8. Mock External Dependencies

```javascript
// Mock API calls
vi.mock('widget/helpers/axios');

// Mock utilities
vi.mock('widget/helpers/utils', () => ({
  sendMessage: vi.fn(),
}));
```

### 9. Test Async Operations Properly

```javascript
it('handles async operation', async () => {
  const promise = asyncFunction();

  await promise;  // Wait for promise

  expect(result).toBe(expected);
});
```

### 10. Use Assertions That Clearly Communicate Intent

```javascript
// Clear intent
expect(wrapper.find('.button').exists()).toBe(true);

// Even clearer
expect(wrapper.find('.button').exists()).toBeTruthy();

// Best for boolean checks
expect(isVisible).toBe(true);
```

---

## Running Tests

### Run All Tests

```bash
pnpm test
```

### Run Tests in Watch Mode

```bash
pnpm test:watch
```

### Run Tests with Coverage

```bash
pnpm test:coverage
```

### Run Specific Test File

```bash
pnpm test path/to/file.spec.js
```

### Run Tests with Pattern Matching

```bash
pnpm test -- --grep="pattern"
```

### Run Tests in UI Mode

```bash
pnpm vitest --ui
```

### Debugging Tests

```javascript
it('debugs here', () => {
  console.log(wrapper.html());  // Log component HTML
  console.log(wrapper.vm);      // Log component instance
  console.log(mockFn.mock.calls);  // Log mock calls

  // Use debugger
  debugger;

  expect(result).toBe(expected);
});
```

### Test Environment Variables

Tests run with `TZ=UTC` to ensure consistent timezone handling:

```bash
TZ=UTC vitest
```

---

## Common Patterns Summary

| Pattern | Example |
|---------|---------|
| **Create mock function** | `const mockFn = vi.fn()` |
| **Mock module** | `vi.mock('../module', () => ({ export: vi.fn() }))` |
| **Spy on method** | `vi.spyOn(obj, 'method').mockResolvedValue(value)` |
| **Mount component** | `mount(Component, { props: { title: 'Test' } })` |
| **Shallow mount** | `shallowMount(Component)` |
| **Find element** | `wrapper.find('.selector')` |
| **Trigger event** | `await wrapper.find('button').trigger('click')` |
| **Check emitted events** | `expect(wrapper.emitted('event')).toHaveLength(1)` |
| **Test ref reactivity** | `const count = ref(0); increment(); expect(count.value).toBe(1)` |
| **Mock API call** | `API.get.mockResolvedValue({ data: {} })` |
| **Verify mock call** | `expect(mockFn).toHaveBeenCalledWith('arg')` |
| **Clear mocks** | `vi.clearAllMocks()` |

---

## Troubleshooting

### Common Issues

1. **Module not found errors**
   - Check path aliases in `vite.config.ts`
   - Ensure correct import paths

2. **Component doesn't render**
   - Check if component needs plugins (i18n, router)
   - Verify props are provided correctly
   - Check global stubs in `vitest.setup.js`

3. **Async test failures**
   - Always `await` async operations
   - Use `wrapper.vm.$nextTick()` for Vue reactivity

4. **Mock not working**
   - Ensure `vi.mock()` is at the top level (before tests)
   - Clear mocks in `beforeEach`

5. **Tests interfering with each other**
   - Use `vi.clearAllMocks()` in `beforeEach`
   - Ensure tests don't share mutable state

6. **Component instance is null**
   - Component might not be mounted yet
   - Check if `shallowMount` is preventing child rendering

7. **i18n errors**
   - Global i18n is configured in `vitest.setup.js`
   - Can mock with `$t: (key) => key` for specific tests

### Debugging Strategies

```javascript
// Log wrapper HTML
console.log(wrapper.html());

// Log component data
console.log(wrapper.vm.$data);

// Log mock calls
console.log(mockFn.mock.calls);

// Check element exists
console.log(wrapper.find('.selector').exists());

// Log all emitted events
console.log(wrapper.emitted());
```

---

## Key Differences from Jest

If you're familiar with Jest, here are the key differences with Vitest:

| Jest | Vitest |
|------|--------|
| `jest.fn()` | `vi.fn()` |
| `jest.mock()` | `vi.mock()` |
| `jest.spyOn()` | `vi.spyOn()` |
| `jest.clearAllMocks()` | `vi.clearAllMocks()` |

Otherwise, the API is very similar!

---

## Additional Resources

- [Vitest Documentation](https://vitest.dev/)
- [Vue Test Utils Documentation](https://test-utils.vuejs.org/)
- [Vue 3 Testing Guide](https://vuejs.org/guide/scaling-up/testing.html)
