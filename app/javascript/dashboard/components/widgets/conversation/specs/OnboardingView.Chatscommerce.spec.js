import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { nextTick, computed, ref } from 'vue';
import OnboardingViewChatscommerce from '../OnboardingView.Chatscommerce.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => {
      if (key === 'ONBOARDING.GREETING_MORNING' && params) {
        return `Good morning ${params.name}! Welcome to ${params.installationName}`;
      }
      if (key === 'ONBOARDING.DESCRIPTION' && params) {
        return `Let's set up ${params.installationName} for you`;
      }
      return key;
    },
  }),
}));

vi.mock('dashboard/composables/store', () => {
  const mockUser = ref({ name: 'Test User' });
  const mockGlobalConfig = ref({ installationName: 'Test App' });
  const mockDispatch = vi.fn().mockResolvedValue();

  return {
    useStore: () => ({
      dispatch: mockDispatch,
    }),
    useStoreGetters: () => ({
      getCurrentUser: computed(() => mockUser.value),
      'globalConfig/get': computed(() => mockGlobalConfig.value),
    }),
    useMapGetter: getterName => {
      const data = {
        'agents/getAgents': [{ id: 1 }],
        'inboxes/getInboxes': [{ has_members: true }],
        'agentBots/getBots': [{ id: 1 }],
      };
      return computed(() => data[getterName] || []);
    },
  };
});

vi.mock('dashboard/composables/useBranding', () => ({
  useBranding: () => ({
    isACustomBrandedInstance: ref(false),
  }),
}));

// Mock child components as simple text
vi.mock('../../../../shared/components/Button.vue', () => ({
  default: {
    name: 'Button',
    props: ['disabled'],
    template: '<button :disabled="disabled"><slot /></button>',
  },
}));

vi.mock('../../../../shared/components/StepCircleFlow.vue', () => ({
  default: {
    name: 'StepCircleFlow',
    template: '<div>StepCircleFlowComponent</div>',
  },
}));

vi.mock('./OnboardingView.AddAgent.vue', () => ({
  default: {
    name: 'OnboardingViewAddAgent',
    template: '<div>AddAgentComponent</div>',
  },
}));

vi.mock('./OnboardingView.AddChannel.vue', () => ({
  default: {
    name: 'OnboardingViewAddChannel',
    template: '<div>AddChannelComponent</div>',
  },
}));

vi.mock('./OnboardingView.AddAIAgent.vue', () => ({
  default: {
    name: 'OnboardingViewAddAIAgent',
    template: '<div>AddAIAgentComponent</div>',
  },
}));

vi.mock(
  'dashboard/components/widgets/conversation/CustomBrandPolicyWrapper.vue',
  () => ({
    default: { template: '<div>CustomBrandPolicyWrapper</div>' },
  })
);

vi.mock('dashboard/components/CustomBrandPolicyWrapper.vue', () => ({
  default: { template: '<div>CustomBrandPolicyWrapper</div>' },
}));

beforeAll(() => {
  window.chatwootConfig = {
    chatscommerceApiUrl: 'https://mocked-api-url.com',
  };
});
afterAll(() => {
  delete window.chatwootConfig;
});

describe('OnboardingViewChatscommerce', () => {
  let wrapper;

  beforeEach(async () => {
    vi.spyOn(global, 'setTimeout').mockImplementation(cb => cb());
    wrapper = mount(OnboardingViewChatscommerce);
    await flushPromises();
    await nextTick();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('renders greeting message', () => {
    expect(wrapper.text()).toContain(
      'Good morning Test User! Welcome to Test App'
    );
  });

  it('renders description', () => {
    expect(wrapper.text()).toContain("Let's set up Test App for you");
  });

  it('renders the correct onboarding component for current step', async () => {
    // Should start with AddAgent component (step 1)
    expect(wrapper.html()).toContain('AddAgentComponent');
    expect(wrapper.html()).not.toContain('AddChannelComponent');
    expect(wrapper.html()).not.toContain('AddAIAgentComponent');

    // Move to step 2 by setting completion and clicking next
    wrapper.vm.stepCompletionStatus[1] = true;
    await nextTick();
    const nextBtn = wrapper
      .findAll('button')
      .find(btn => btn.text().includes('ONBOARDING.BUTTON.NEXT'));
    await nextBtn.trigger('click');
    await nextTick();
    expect(wrapper.vm.currentStep).toBe(2);
    expect(wrapper.html()).toContain('AddChannelComponent');
    expect(wrapper.html()).not.toContain('AddAgentComponent');
    expect(wrapper.html()).not.toContain('AddAIAgentComponent');

    // Move to step 3
    wrapper.vm.stepCompletionStatus[2] = true;
    await nextTick();
    const nextBtn2 = wrapper
      .findAll('button')
      .find(btn => btn.text().includes('ONBOARDING.BUTTON.NEXT'));
    await nextBtn2.trigger('click');
    await nextTick();
    expect(wrapper.vm.currentStep).toBe(3);
    expect(wrapper.html()).toContain('AddAIAgentComponent');
    expect(wrapper.html()).not.toContain('AddAgentComponent');
    expect(wrapper.html()).not.toContain('AddChannelComponent');
  });

  it('renders navigation buttons correctly', () => {
    const buttons = wrapper.findAll('button').map(b => b.text());
    expect(buttons).toContain('ONBOARDING.BUTTON.NEXT');
    // Previous button should not be visible on step 1
    expect(buttons).not.toContain('ONBOARDING.BUTTON.PREVIOUS');
  });

  it('shows previous button on step 2', async () => {
    // Move to step 2
    wrapper.vm.currentStep = 2;
    await nextTick();

    const buttons = wrapper.findAll('button').map(b => b.text());
    expect(buttons).toContain('ONBOARDING.BUTTON.PREVIOUS');
    expect(buttons).toContain('ONBOARDING.BUTTON.NEXT');
  });

  it('disables Next button if step is incomplete', async () => {
    // Set step as incomplete
    wrapper.vm.stepCompletionStatus[1] = false;
    await nextTick();

    const nextButton = wrapper
      .findAll('button')
      .find(btn => btn.text().includes('ONBOARDING.BUTTON.NEXT'));

    expect(nextButton.attributes('disabled')).toBeDefined();
  });

  it('enables Next button if step is complete', async () => {
    // Set step as complete
    wrapper.vm.stepCompletionStatus[1] = true;
    await nextTick();

    const nextButton = wrapper
      .findAll('button')
      .find(btn => btn.text().includes('ONBOARDING.BUTTON.NEXT'));

    expect(nextButton.attributes('disabled')).toBeUndefined();
  });

  it('shows finish button on last step when complete', async () => {
    // Move to last step (step 3) and mark as complete
    wrapper.vm.currentStep = 3;
    wrapper.vm.stepCompletionStatus[3] = true;
    await nextTick();

    const finishBtn = wrapper
      .findAll('button')
      .find(btn => btn.text().includes('ONBOARDING.BUTTON.FINISH'));

    expect(finishBtn).toBeDefined();
    expect(finishBtn.exists()).toBe(true);
  });

  it('calls finishHandler on finish', async () => {
    // Move to last step and mark as complete
    wrapper.vm.currentStep = 3;
    wrapper.vm.stepCompletionStatus[3] = true;
    await nextTick();

    const finishBtn = wrapper
      .findAll('button')
      .find(btn => btn.text().includes('ONBOARDING.BUTTON.FINISH'));

    // Get the mocked store dispatch function
    const { useStore } = await import('dashboard/composables/store');
    const store = useStore();
    const dispatchSpy = vi.spyOn(store, 'dispatch');

    await finishBtn.trigger('click');

    expect(dispatchSpy).toHaveBeenCalledWith('accounts/update', {
      onboarding_completed: true,
    });
  });

  it('can navigate backwards', async () => {
    // Move to step 2 first
    wrapper.vm.currentStep = 2;
    await nextTick();

    const backBtn = wrapper
      .findAll('button')
      .find(btn => btn.text().includes('ONBOARDING.BUTTON.PREVIOUS'));

    await backBtn.trigger('click');
    await nextTick();

    expect(wrapper.vm.currentStep).toBe(1);
  });
});
