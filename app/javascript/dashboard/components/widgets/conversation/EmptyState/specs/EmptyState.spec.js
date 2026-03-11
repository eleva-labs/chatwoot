import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { nextTick, ref } from 'vue';
import EmptyState from '../EmptyState.vue';

// ─── Mock router ────────────────────────────────────────────────────────────────
const mockRouterPush = vi.fn();
const mockRoute = ref({ params: { accountId: '1' }, name: 'dashboard' });

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockRouterPush }),
  useRoute: () => mockRoute.value,
}));

// ─── Mock composables ───────────────────────────────────────────────────────────
const mockIsAdminRef = ref(true);

vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({
    isAdmin: mockIsAdminRef,
  }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedUrl: url => `/app/accounts/1/${url}`,
  }),
}));

// ─── Helpers ────────────────────────────────────────────────────────────────────

/**
 * Creates a real Vuex store with the getters EmptyState depends on.
 *
 * Using createStore (not a mock object) ensures both `useStore()` (Composition API)
 * and `mapGetters` (Options API) resolve to the same store instance.
 */
const createMockStore = ({
  inboxes = [],
  isFetching = false,
  loadingChatList = false,
  allConversations = [],
  currentChat = {},
} = {}) => {
  return createStore({
    getters: {
      getSelectedChat: () => currentChat,
      getAllConversations: () => allConversations,
      getChatListLoadingStatus: () => loadingChatList,
    },
    modules: {
      inboxes: {
        namespaced: true,
        state: () => ({
          records: inboxes,
          uiFlags: {
            isFetching,
            isFetchingItem: false,
            isCreating: false,
            isUpdating: false,
            isDeleting: false,
            isUpdatingIMAP: false,
            isUpdatingSMTP: false,
          },
        }),
        getters: {
          getInboxes: $state => $state.records,
          getUIFlags: $state => $state.uiFlags,
        },
      },
      accounts: {
        namespaced: true,
        getters: {
          // isOnboardingCompleted is a function-getter: () => () => boolean
          // It checks rootGetters['inboxes/getInboxes'].length > 0
          isOnboardingCompleted: (_s, _g, _rs, rootGetters) => () => {
            const inboxList = rootGetters['inboxes/getInboxes'];
            return inboxList && inboxList.length > 0;
          },
        },
      },
    },
  });
};

const createWrapper = (storeOptions = {}) => {
  const store = createMockStore(storeOptions);

  return shallowMount(EmptyState, {
    props: {
      isOnExpandedLayout: false,
    },
    global: {
      plugins: [store],
      mocks: {
        $t: key => key,
      },
      stubs: {
        EmptyStateMessage: {
          template: '<div class="empty-state-message">{{ message }}</div>',
          props: ['message'],
        },
      },
    },
  });
};

// ─── Tests ──────────────────────────────────────────────────────────────────────
describe('EmptyState.vue — onboarding redirect guard', () => {
  afterEach(() => {
    mockIsAdminRef.value = true; // reset default
    mockRoute.value = { params: { accountId: '1' }, name: 'dashboard' };
    mockRouterPush.mockClear();
  });

  // =============================================================================
  // Redirect behavior
  // =============================================================================
  describe('onboarding redirect', () => {
    it('redirects to onboarding when admin has no inboxes and not fetching', () => {
      mockIsAdminRef.value = true;
      createWrapper({ inboxes: [], isFetching: false });

      expect(mockRouterPush).toHaveBeenCalledWith({
        name: 'settings_inbox_new',
        query: { onboarding: 'true' },
      });
    });

    it('does not redirect when inboxes exist (onboarding already completed)', () => {
      mockIsAdminRef.value = true;
      createWrapper({ inboxes: [{ id: 1 }], isFetching: false });

      expect(mockRouterPush).not.toHaveBeenCalled();
    });

    it('does not redirect when inboxes are still being fetched (race condition guard)', () => {
      mockIsAdminRef.value = true;
      createWrapper({ inboxes: [], isFetching: true });

      expect(mockRouterPush).not.toHaveBeenCalled();
    });

    it('redirects after inbox fetching completes with no inboxes', async () => {
      mockIsAdminRef.value = true;
      const store = createMockStore({ inboxes: [], isFetching: true });
      shallowMount(EmptyState, {
        props: { isOnExpandedLayout: false },
        global: {
          plugins: [store],
          mocks: { $t: key => key },
          stubs: {
            EmptyStateMessage: {
              template: '<div class="empty-state-message">{{ message }}</div>',
              props: ['message'],
            },
          },
        },
      });

      expect(mockRouterPush).not.toHaveBeenCalled();

      store.state.inboxes.uiFlags.isFetching = false;
      await nextTick();

      expect(mockRouterPush).toHaveBeenCalledWith({
        name: 'settings_inbox_new',
        query: { onboarding: 'true' },
      });
    });

    it('does not redirect when already on onboarding route', () => {
      mockIsAdminRef.value = true;
      mockRoute.value = {
        params: { accountId: '1' },
        name: 'settings_inbox_new',
      };

      createWrapper({ inboxes: [], isFetching: false });

      expect(mockRouterPush).not.toHaveBeenCalled();
    });

    it('does not redirect when user is not an admin', () => {
      mockIsAdminRef.value = false;
      createWrapper({ inboxes: [], isFetching: false });

      expect(mockRouterPush).not.toHaveBeenCalled();
    });
  });

  // =============================================================================
  // Loading / empty states
  // =============================================================================
  describe('loading and empty states', () => {
    it('shows loading state when inboxes are being fetched', () => {
      mockIsAdminRef.value = true;
      const wrapper = createWrapper({ inboxes: [], isFetching: true });

      // woot-loading-state is a globally registered component; in tests it renders
      // as a custom element <woot-loading-state>.
      const loadingEl = wrapper.find('woot-loading-state');
      expect(loadingEl.exists()).toBe(true);
    });

    it('shows no-inbox-agent message when user is not admin and has no inboxes', () => {
      mockIsAdminRef.value = false;
      const wrapper = createWrapper({
        inboxes: [],
        isFetching: false,
        loadingChatList: false,
      });

      const message = wrapper.find('.empty-state-message');
      expect(message.exists()).toBe(true);
    });
  });
});
