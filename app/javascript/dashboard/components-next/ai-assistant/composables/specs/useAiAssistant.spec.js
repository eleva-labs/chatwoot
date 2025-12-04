import { ref } from 'vue';
import { useAiAssistant } from '../useAiAssistant';
import { CHAT_STATUS } from '../../constants';

// Mock vue-router
vi.mock('vue-router', () => ({
  useRoute: vi.fn(() => ({
    params: { accountId: '123' },
  })),
}));

// Mock vuex store
vi.mock('dashboard/composables/store', () => ({
  useStore: vi.fn(() => ({
    getters: {
      getCurrentUser: {
        id: 1,
        name: 'Test User',
        avatar_url: 'https://example.com/avatar.png',
      },
    },
  })),
}));

// Mock useVercelChat
const mockSendMessage = vi.fn();
const mockSetMessages = vi.fn();
const mockClearError = vi.fn();
vi.mock('../useVercelChat', () => ({
  useVercelChat: vi.fn(() => ({
    messages: ref([]),
    status: ref(CHAT_STATUS.READY),
    error: ref(null),
    sendMessage: mockSendMessage,
    setMessages: mockSetMessages,
    clearError: mockClearError,
    dispose: vi.fn(),
  })),
}));

// Mock useAiChatSessionManager
const mockFetchSessions = vi.fn().mockResolvedValue([]);
const mockLoadSession = vi.fn();
const mockStartNewSession = vi.fn();
const mockDeleteSession = vi.fn().mockResolvedValue(true);
const mockSetActiveSessionId = vi.fn();
const mockGetStoredSessionId = vi.fn();

vi.mock('../useAiChatSessionManager', () => ({
  useAiChatSessionManager: vi.fn(() => ({
    sessions: ref([]),
    activeSessionId: ref(null),
    isLoadingSessions: ref(false),
    isLoadingMessages: ref(false),
    error: ref(null),
    fetchSessions: mockFetchSessions,
    loadSession: mockLoadSession,
    startNewSession: mockStartNewSession,
    deleteSession: mockDeleteSession,
    setActiveSessionId: mockSetActiveSessionId,
    getStoredSessionId: mockGetStoredSessionId,
    storeSessionId: vi.fn(),
    clearStoredSessionId: vi.fn(),
  })),
}));

// Mock Auth
vi.mock('dashboard/api/auth', () => ({
  default: {
    hasAuthCookie: vi.fn(() => true),
    getAuthData: vi.fn(() => ({
      'access-token': 'test-token',
      'token-type': 'Bearer',
      client: 'test-client',
      expiry: '12345',
      uid: 'test@example.com',
    })),
  },
}));

import { useRoute } from 'vue-router';
import { useVercelChat } from '../useVercelChat';
import Auth from 'dashboard/api/auth';

describe('useAiAssistant', () => {
  let originalFetch;

  beforeEach(() => {
    vi.clearAllMocks();
    originalFetch = global.fetch;
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  // =============================================================================
  // Initialization
  // =============================================================================
  describe('initialization', () => {
    it('returns expected state and methods', () => {
      const assistant = useAiAssistant();

      expect(assistant).toHaveProperty('chat');
      expect(assistant).toHaveProperty('selectedBotId');
      expect(assistant).toHaveProperty('availableBots');
      expect(assistant).toHaveProperty('botsLoading');
      expect(assistant).toHaveProperty('currentBot');
      expect(assistant).toHaveProperty('chatTitle');
      expect(assistant).toHaveProperty('userName');
      expect(assistant).toHaveProperty('userAvatar');
      expect(assistant).toHaveProperty('botName');
      expect(assistant).toHaveProperty('botAvatar');
      expect(assistant).toHaveProperty('isDisabled');
      expect(assistant).toHaveProperty('sessions');
      expect(assistant).toHaveProperty('activeSessionId');
      expect(assistant).toHaveProperty('isLoadingSessions');
      expect(assistant).toHaveProperty('loadSession');
      expect(assistant).toHaveProperty('startNewSession');
      expect(assistant).toHaveProperty('deleteSession');
      expect(assistant).toHaveProperty('fetchSessions');
      expect(assistant).toHaveProperty('fetchBots');
    });

    it('initializes with null selectedBotId', () => {
      const { selectedBotId } = useAiAssistant();
      expect(selectedBotId.value).toBeNull();
    });

    it('initializes with empty availableBots', () => {
      const { availableBots } = useAiAssistant();
      expect(availableBots.value).toEqual([]);
    });

    it('initializes with botsLoading as false', () => {
      const { botsLoading } = useAiAssistant();
      expect(botsLoading.value).toBe(false);
    });

    it('extracts accountId from route params', () => {
      useRoute.mockReturnValue({ params: { accountId: '456' } });
      useAiAssistant();

      expect(useVercelChat).toHaveBeenCalledWith(
        expect.objectContaining({
          api: expect.stringContaining('/accounts/456/'),
        })
      );
    });
  });

  // =============================================================================
  // Computed Properties
  // =============================================================================
  describe('computed properties', () => {
    it('returns current user name', () => {
      const { userName } = useAiAssistant();
      expect(userName.value).toBe('Test User');
    });

    it('returns current user avatar', () => {
      const { userAvatar } = useAiAssistant();
      expect(userAvatar.value).toBe('https://example.com/avatar.png');
    });

    it('returns default chatTitle when no bot selected', () => {
      const { chatTitle } = useAiAssistant();
      expect(chatTitle.value).toBe('AI Assistant');
    });

    it('returns bot name as chatTitle when bot is selected', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            bots: [{ id: 1, name: 'Test Bot' }],
          }),
      });

      const { chatTitle, fetchBots, selectedBotId } = useAiAssistant();
      await fetchBots();

      // Bot should be auto-selected
      expect(selectedBotId.value).toBe(1);
      expect(chatTitle.value).toBe('Test Bot');
    });

    it('returns currentBot when bot is selected', async () => {
      const mockBot = { id: 1, name: 'Test Bot', avatar_url: 'bot.png' };
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [mockBot] }),
      });

      const { currentBot, fetchBots } = useAiAssistant();
      await fetchBots();

      expect(currentBot.value).toEqual(mockBot);
    });

    it('returns botName from current bot', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [{ id: 1, name: 'My Bot' }] }),
      });

      const { botName, fetchBots } = useAiAssistant();
      await fetchBots();

      expect(botName.value).toBe('My Bot');
    });

    it('returns default botName when no bot selected', () => {
      const { botName } = useAiAssistant();
      expect(botName.value).toBe('AI');
    });

    it('returns isDisabled true when no bot selected', () => {
      const { isDisabled } = useAiAssistant();
      expect(isDisabled.value).toBe(true);
    });

    it('returns isDisabled false when bot is selected', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [{ id: 1, name: 'Bot' }] }),
      });

      const { isDisabled, fetchBots } = useAiAssistant();
      await fetchBots();

      expect(isDisabled.value).toBe(false);
    });
  });

  // =============================================================================
  // fetchBots
  // =============================================================================
  describe('fetchBots', () => {
    it('sets botsLoading to true while fetching', async () => {
      let resolvePromise;
      global.fetch = vi.fn().mockImplementation(
        () =>
          new Promise(resolve => {
            resolvePromise = resolve;
          })
      );

      const { botsLoading, fetchBots } = useAiAssistant();
      const fetchPromise = fetchBots();

      expect(botsLoading.value).toBe(true);

      resolvePromise({ ok: true, json: () => Promise.resolve({ bots: [] }) });
      await fetchPromise;

      expect(botsLoading.value).toBe(false);
    });

    it('populates availableBots from API response', async () => {
      const mockBots = [
        { id: 1, name: 'Bot 1' },
        { id: 2, name: 'Bot 2' },
      ];
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: mockBots }),
      });

      const { availableBots, fetchBots } = useAiAssistant();
      await fetchBots();

      expect(availableBots.value).toEqual(mockBots);
    });

    it('auto-selects first bot when availableBots is populated', async () => {
      const mockBots = [
        { id: 10, name: 'Bot A' },
        { id: 20, name: 'Bot B' },
      ];
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: mockBots }),
      });

      const { selectedBotId, fetchBots } = useAiAssistant();
      await fetchBots();

      expect(selectedBotId.value).toBe(10);
    });

    it('does not auto-select if a bot is already selected', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [{ id: 1, name: 'Bot' }] }),
      });

      const { selectedBotId, fetchBots } = useAiAssistant();
      selectedBotId.value = 999;
      await fetchBots();

      expect(selectedBotId.value).toBe(999);
    });

    it('handles API errors gracefully', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
      });

      const { availableBots, fetchBots } = useAiAssistant();
      await fetchBots();

      expect(availableBots.value).toEqual([]);
    });

    it('handles network errors gracefully', async () => {
      global.fetch = vi.fn().mockRejectedValue(new Error('Network error'));

      const { availableBots, fetchBots } = useAiAssistant();
      await fetchBots();

      expect(availableBots.value).toEqual([]);
    });

    it('does nothing when accountId is null', async () => {
      useRoute.mockReturnValue({ params: {} });
      // Also need to handle window.location fallback
      const originalLocation = window.location;
      delete window.location;
      window.location = { pathname: '/dashboard' };
      window.chatwootConfig = undefined;

      // Create a spy for fetch
      const fetchSpy = vi.fn();
      global.fetch = fetchSpy;

      const { fetchBots } = useAiAssistant();
      await fetchBots();

      expect(fetchSpy).not.toHaveBeenCalled();

      window.location = originalLocation;
    });

    it('includes auth headers in request', async () => {
      Auth.hasAuthCookie.mockReturnValue(true);
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [] }),
      });

      const { fetchBots } = useAiAssistant();
      await fetchBots();

      expect(global.fetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          headers: expect.objectContaining({
            'access-token': 'test-token',
          }),
        })
      );
    });
  });

  // =============================================================================
  // Session Management Delegation
  // =============================================================================
  describe('session management', () => {
    it('exposes sessions from session manager', () => {
      const { sessions } = useAiAssistant();
      expect(sessions.value).toEqual([]);
    });

    it('exposes activeSessionId from session manager', () => {
      const { activeSessionId } = useAiAssistant();
      expect(activeSessionId.value).toBeNull();
    });

    it('exposes isLoadingSessions from session manager', () => {
      const { isLoadingSessions } = useAiAssistant();
      expect(isLoadingSessions.value).toBe(false);
    });

    it('delegates loadSession to session manager', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [{ id: 1, name: 'Bot' }] }),
      });

      const { loadSession, fetchBots } = useAiAssistant();
      await fetchBots();

      await loadSession('session-123');

      expect(mockLoadSession).toHaveBeenCalledWith(
        'session-123',
        1,
        expect.any(Object)
      );
    });

    it('delegates startNewSession to session manager', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [{ id: 1, name: 'Bot' }] }),
      });

      const { startNewSession, fetchBots } = useAiAssistant();
      await fetchBots();

      startNewSession();

      expect(mockStartNewSession).toHaveBeenCalledWith(1, expect.any(Object));
    });

    it('delegates deleteSession to session manager', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [{ id: 1, name: 'Bot' }] }),
      });

      const { deleteSession, fetchBots } = useAiAssistant();
      await fetchBots();

      await deleteSession('session-456');

      expect(mockDeleteSession).toHaveBeenCalledWith('session-456', 1);
    });

    it('delegates fetchSessions to session manager', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ bots: [{ id: 1, name: 'Bot' }] }),
      });

      const { fetchSessions, fetchBots } = useAiAssistant();
      await fetchBots();

      await fetchSessions();

      expect(mockFetchSessions).toHaveBeenCalledWith(1);
    });
  });

  // =============================================================================
  // Chat Instance
  // =============================================================================
  describe('chat instance', () => {
    it('returns chat instance from useVercelChat', () => {
      const { chat } = useAiAssistant();

      expect(chat).toHaveProperty('messages');
      expect(chat).toHaveProperty('status');
      expect(chat).toHaveProperty('sendMessage');
    });

    it('configures useVercelChat with correct API endpoint', () => {
      useRoute.mockReturnValue({ params: { accountId: '789' } });
      useAiAssistant();

      expect(useVercelChat).toHaveBeenCalledWith(
        expect.objectContaining({
          api: '/api/v1/accounts/789/ai_chat/stream',
        })
      );
    });
  });
});
