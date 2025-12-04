import { useAiChatSessionManager } from '../useAiChatSessionManager';

// Mock dependencies
vi.mock('shared/helpers/localStorage', () => ({
  LocalStorage: {
    getFromJsonStore: vi.fn(),
    updateJsonStore: vi.fn(),
    deleteFromJsonStore: vi.fn(),
  },
}));

vi.mock('dashboard/composables/useTransformKeys', () => ({
  useCamelCase: vi.fn(data => data), // Pass through for simplicity
}));

vi.mock('../useAiMessageMapper', () => ({
  toUIMessages: vi.fn(messages =>
    messages.map(m => ({
      id: m.id,
      role: m.role,
      parts: [{ type: 'text', text: m.content }],
    }))
  ),
}));

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

import { LocalStorage } from 'shared/helpers/localStorage';
import { toUIMessages } from '../useAiMessageMapper';

describe('useAiChatSessionManager', () => {
  const accountId = 123;
  const botId = 456;
  const sessionId = 'session-789';

  let mockChat;
  let originalFetch;

  beforeEach(() => {
    mockChat = {
      setMessages: vi.fn(),
    };

    // Store original fetch
    originalFetch = global.fetch;

    // Reset mocks
    vi.clearAllMocks();
  });

  afterEach(() => {
    // Restore original fetch
    global.fetch = originalFetch;
  });

  // =============================================================================
  // Initialization
  // =============================================================================
  describe('initialization', () => {
    it('returns expected state and methods', () => {
      const manager = useAiChatSessionManager(accountId);

      expect(manager).toHaveProperty('sessions');
      expect(manager).toHaveProperty('activeSessionId');
      expect(manager).toHaveProperty('isLoadingSessions');
      expect(manager).toHaveProperty('isLoadingMessages');
      expect(manager).toHaveProperty('error');
      expect(manager).toHaveProperty('fetchSessions');
      expect(manager).toHaveProperty('fetchSessionMessages');
      expect(manager).toHaveProperty('loadSession');
      expect(manager).toHaveProperty('restoreSession');
      expect(manager).toHaveProperty('startNewSession');
      expect(manager).toHaveProperty('deleteSession');
      expect(manager).toHaveProperty('setActiveSessionId');
      expect(manager).toHaveProperty('getStoredSessionId');
      expect(manager).toHaveProperty('storeSessionId');
      expect(manager).toHaveProperty('clearStoredSessionId');
    });

    it('initializes with empty sessions array', () => {
      const { sessions } = useAiChatSessionManager(accountId);
      expect(sessions.value).toEqual([]);
    });

    it('initializes with null activeSessionId', () => {
      const { activeSessionId } = useAiChatSessionManager(accountId);
      expect(activeSessionId.value).toBeNull();
    });

    it('initializes with loading states as false', () => {
      const { isLoadingSessions, isLoadingMessages } =
        useAiChatSessionManager(accountId);
      expect(isLoadingSessions.value).toBe(false);
      expect(isLoadingMessages.value).toBe(false);
    });
  });

  // =============================================================================
  // localStorage methods
  // =============================================================================
  describe('localStorage methods', () => {
    it('getStoredSessionId retrieves from localStorage', () => {
      LocalStorage.getFromJsonStore.mockReturnValue('stored-session-123');

      const { getStoredSessionId } = useAiChatSessionManager(accountId);
      const result = getStoredSessionId(botId);

      expect(LocalStorage.getFromJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId)
      );
      expect(result).toBe('stored-session-123');
    });

    it('storeSessionId saves to localStorage', () => {
      const { storeSessionId } = useAiChatSessionManager(accountId);
      storeSessionId(botId, sessionId);

      expect(LocalStorage.updateJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId),
        sessionId
      );
    });

    it('clearStoredSessionId removes from localStorage', () => {
      const { clearStoredSessionId } = useAiChatSessionManager(accountId);
      clearStoredSessionId(botId);

      expect(LocalStorage.deleteFromJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId)
      );
    });
  });

  // =============================================================================
  // fetchSessions
  // =============================================================================
  describe('fetchSessions', () => {
    it('returns empty array when accountId is missing', async () => {
      const { fetchSessions } = useAiChatSessionManager(null);
      const result = await fetchSessions(botId);
      expect(result).toEqual([]);
    });

    it('returns empty array when botId is missing', async () => {
      const { fetchSessions } = useAiChatSessionManager(accountId);
      const result = await fetchSessions(null);
      expect(result).toEqual([]);
    });

    it('fetches sessions from API and updates state', async () => {
      const mockSessions = [
        { chatSessionId: 'sess-1', isActive: true },
        { chatSessionId: 'sess-2', isActive: true },
      ];

      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ sessions: mockSessions }),
      });

      const { fetchSessions, sessions, isLoadingSessions } =
        useAiChatSessionManager(accountId);

      const fetchPromise = fetchSessions(botId);

      // Check loading state is set
      expect(isLoadingSessions.value).toBe(true);

      const result = await fetchPromise;

      expect(isLoadingSessions.value).toBe(false);
      expect(sessions.value).toEqual(mockSessions);
      expect(result).toEqual(mockSessions);
    });

    it('handles API errors gracefully', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
      });

      const { fetchSessions, sessions, error } =
        useAiChatSessionManager(accountId);
      const result = await fetchSessions(botId);

      expect(result).toEqual([]);
      expect(sessions.value).toEqual([]);
      expect(error.value).toContain('Failed to fetch sessions');
    });

    it('handles network errors gracefully', async () => {
      global.fetch = vi.fn().mockRejectedValue(new Error('Network error'));

      const { fetchSessions, error } = useAiChatSessionManager(accountId);
      await fetchSessions(botId);

      expect(error.value).toBe('Network error');
    });

    it('includes auth headers in request', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ sessions: [] }),
      });

      const { fetchSessions } = useAiChatSessionManager(accountId);
      await fetchSessions(botId);

      expect(global.fetch).toHaveBeenCalledWith(
        expect.stringContaining(
          `/api/v1/accounts/${accountId}/ai_chat/sessions`
        ),
        expect.objectContaining({
          headers: expect.objectContaining({
            'access-token': 'test-token',
          }),
        })
      );
    });
  });

  // =============================================================================
  // fetchSessionMessages
  // =============================================================================
  describe('fetchSessionMessages', () => {
    it('returns empty array when accountId is missing', async () => {
      const { fetchSessionMessages } = useAiChatSessionManager(null);
      const result = await fetchSessionMessages(sessionId);
      expect(result).toEqual([]);
    });

    it('returns empty array when sessionId is missing', async () => {
      const { fetchSessionMessages } = useAiChatSessionManager(accountId);
      const result = await fetchSessionMessages(null);
      expect(result).toEqual([]);
    });

    it('fetches messages from API', async () => {
      const mockMessages = [
        { id: '1', role: 'user', content: 'Hello' },
        { id: '2', role: 'assistant', content: 'Hi there!' },
      ];

      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ messages: mockMessages }),
      });

      const { fetchSessionMessages, isLoadingMessages } =
        useAiChatSessionManager(accountId);

      const fetchPromise = fetchSessionMessages(sessionId);
      expect(isLoadingMessages.value).toBe(true);

      const result = await fetchPromise;

      expect(isLoadingMessages.value).toBe(false);
      expect(result).toEqual(mockMessages);
    });

    it('handles API errors gracefully', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 404,
      });

      const { fetchSessionMessages, error } =
        useAiChatSessionManager(accountId);
      const result = await fetchSessionMessages(sessionId);

      expect(result).toEqual([]);
      expect(error.value).toContain('Failed to fetch messages');
    });
  });

  // =============================================================================
  // loadSession
  // =============================================================================
  describe('loadSession', () => {
    it('sets activeSessionId and stores in localStorage', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ messages: [] }),
      });

      const { loadSession, activeSessionId } =
        useAiChatSessionManager(accountId);
      await loadSession(sessionId, botId, mockChat);

      expect(activeSessionId.value).toBe(sessionId);
      expect(LocalStorage.updateJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId),
        sessionId
      );
    });

    it('fetches messages and sets them on chat instance', async () => {
      const mockMessages = [
        { id: '1', role: 'user', content: 'Hello' },
        { id: '2', role: 'assistant', content: 'Hi!' },
      ];

      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ messages: mockMessages }),
      });

      const { loadSession } = useAiChatSessionManager(accountId);
      await loadSession(sessionId, botId, mockChat);

      expect(toUIMessages).toHaveBeenCalledWith(mockMessages);
      expect(mockChat.setMessages).toHaveBeenCalled();
    });
  });

  // =============================================================================
  // restoreSession
  // =============================================================================
  describe('restoreSession', () => {
    it('returns false when no stored session', async () => {
      LocalStorage.getFromJsonStore.mockReturnValue(null);

      const { restoreSession } = useAiChatSessionManager(accountId);
      const result = await restoreSession(botId, mockChat);

      expect(result).toBe(false);
    });

    it('loads stored session and returns true', async () => {
      LocalStorage.getFromJsonStore.mockReturnValue(sessionId);
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ messages: [] }),
      });

      const { restoreSession, activeSessionId } =
        useAiChatSessionManager(accountId);
      const result = await restoreSession(botId, mockChat);

      expect(result).toBe(true);
      expect(activeSessionId.value).toBe(sessionId);
    });
  });

  // =============================================================================
  // startNewSession
  // =============================================================================
  describe('startNewSession', () => {
    it('clears activeSessionId', () => {
      const { startNewSession, activeSessionId } =
        useAiChatSessionManager(accountId);
      activeSessionId.value = sessionId;

      startNewSession(botId, mockChat);

      expect(activeSessionId.value).toBeNull();
    });

    it('clears stored session from localStorage', () => {
      const { startNewSession } = useAiChatSessionManager(accountId);
      startNewSession(botId, mockChat);

      expect(LocalStorage.deleteFromJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId)
      );
    });

    it('clears chat messages', () => {
      const { startNewSession } = useAiChatSessionManager(accountId);
      startNewSession(botId, mockChat);

      expect(mockChat.setMessages).toHaveBeenCalledWith([]);
    });
  });

  // =============================================================================
  // deleteSession
  // =============================================================================
  describe('deleteSession', () => {
    it('deletes session via API and removes from state', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ success: true }),
      });

      const { deleteSession, sessions } = useAiChatSessionManager(accountId);
      sessions.value = [
        { chatSessionId: sessionId },
        { chatSessionId: 'other-session' },
      ];

      const result = await deleteSession(sessionId, botId);

      expect(result).toBe(true);
      expect(sessions.value).toHaveLength(1);
      expect(sessions.value[0].chatSessionId).toBe('other-session');
    });

    it('clears activeSessionId if deleted session was active', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ success: true }),
      });

      const { deleteSession, activeSessionId, sessions } =
        useAiChatSessionManager(accountId);
      activeSessionId.value = sessionId;
      sessions.value = [{ chatSessionId: sessionId }];

      await deleteSession(sessionId, botId);

      expect(activeSessionId.value).toBeNull();
      expect(LocalStorage.deleteFromJsonStore).toHaveBeenCalled();
    });

    it('does not clear activeSessionId if different session deleted', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ success: true }),
      });

      const { deleteSession, activeSessionId, sessions } =
        useAiChatSessionManager(accountId);
      activeSessionId.value = 'different-session';
      sessions.value = [{ chatSessionId: sessionId }];

      await deleteSession(sessionId, botId);

      expect(activeSessionId.value).toBe('different-session');
    });

    it('handles API errors and returns false', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
      });

      const { deleteSession, error } = useAiChatSessionManager(accountId);
      const result = await deleteSession(sessionId, botId);

      expect(result).toBe(false);
      expect(error.value).toContain('Failed to delete session');
    });
  });

  // =============================================================================
  // setActiveSessionId
  // =============================================================================
  describe('setActiveSessionId', () => {
    it('updates activeSessionId ref', () => {
      const { setActiveSessionId, activeSessionId } =
        useAiChatSessionManager(accountId);

      setActiveSessionId(sessionId, botId);

      expect(activeSessionId.value).toBe(sessionId);
    });

    it('stores session in localStorage when both ids provided', () => {
      const { setActiveSessionId } = useAiChatSessionManager(accountId);

      setActiveSessionId(sessionId, botId);

      expect(LocalStorage.updateJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId),
        sessionId
      );
    });

    it('does not store when sessionId is null', () => {
      const { setActiveSessionId } = useAiChatSessionManager(accountId);

      setActiveSessionId(null, botId);

      expect(LocalStorage.updateJsonStore).not.toHaveBeenCalled();
    });

    it('does not store when botId is null', () => {
      const { setActiveSessionId } = useAiChatSessionManager(accountId);

      setActiveSessionId(sessionId, null);

      expect(LocalStorage.updateJsonStore).not.toHaveBeenCalled();
    });
  });
});
