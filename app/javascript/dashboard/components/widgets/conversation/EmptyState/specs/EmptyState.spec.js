import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { ref } from 'vue';
import EmptyState from '../EmptyState.vue';

// ─── Mock router ────────────────────────────────────────────────────────────────
const mockRoute = ref({ params: { accountId: '1' }, name: 'dashboard' });

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
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
describe('EmptyState.vue', () => {
  afterEach(() => {
    mockIsAdminRef.value = true;
    mockRoute.value = { params: { accountId: '1' }, name: 'dashboard' };
  });

  describe('no inboxes configured', () => {
    it('shows empty state message for admin when no inboxes and not fetching', () => {
      mockIsAdminRef.value = true;
      const wrapper = createWrapper({ inboxes: [], isFetching: false });

      const message = wrapper.find('.empty-state-message');
      expect(message.exists()).toBe(true);
      expect(message.text()).toBe('CONVERSATION.NO_MESSAGE_1');
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
      expect(message.text()).toBe('CONVERSATION.NO_INBOX_AGENT');
    });

    it('does not show no-inbox state when inboxes exist', () => {
      mockIsAdminRef.value = true;
      const wrapper = createWrapper({
        inboxes: [{ id: 1 }],
        isFetching: false,
      });

      // With inboxes, onboarding is completed, so "no inbox" block should not show
      const messages = wrapper.findAll('.empty-state-message');
      const noInboxMessage = messages.filter(
        m => m.text() === 'CONVERSATION.NO_INBOX_AGENT'
      );
      expect(noInboxMessage).toHaveLength(0);
    });
  });

  describe('loading and empty states', () => {
    it('shows loading state when inboxes are being fetched', () => {
      mockIsAdminRef.value = true;
      const wrapper = createWrapper({ inboxes: [], isFetching: true });

      const loadingEl = wrapper.find('woot-loading-state');
      expect(loadingEl.exists()).toBe(true);
    });

    it('shows loading state when chat list is loading', () => {
      const wrapper = createWrapper({
        inboxes: [{ id: 1 }],
        loadingChatList: true,
      });

      const loadingEl = wrapper.find('woot-loading-state');
      expect(loadingEl.exists()).toBe(true);
    });

    it('shows no conversations message when inboxes exist but no conversations', () => {
      const wrapper = createWrapper({
        inboxes: [{ id: 1 }],
        isFetching: false,
        allConversations: [],
      });

      const message = wrapper.find('.empty-state-message');
      expect(message.exists()).toBe(true);
      expect(message.text()).toBe('CONVERSATION.NO_MESSAGE_1');
    });

    it('shows select conversation message when conversations exist but none selected', () => {
      const wrapper = createWrapper({
        inboxes: [{ id: 1 }],
        isFetching: false,
        allConversations: [{ id: 1 }],
        currentChat: {},
      });

      const message = wrapper.find('.empty-state-message');
      expect(message.exists()).toBe(true);
      expect(message.text()).toBe('CONVERSATION.SELECT_A_CONVERSATION');
    });
  });
});
