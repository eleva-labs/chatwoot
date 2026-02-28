import { useAiChatSessionManager } from '../useAiChatSessionManager';

// Mock dependencies
vi.mock('shared/helpers/localStorage', () => ({
  LocalStorage: {
    getFromJsonStore: vi.fn(),
    updateJsonStore: vi.fn(),
    deleteFromJsonStore: vi.fn(),
  },
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

import { LocalStorage } from 'shared/helpers/localStorage';
import { toUIMessages } from '../useAiMessageMapper';

describe('useAiChatSessionManager', () => {
  const botId = 456;
  const sessionId = 'session-789';

  // Create a mock adapter that simulates the Chatwoot API
  const createMockAdapter = (overrides = {}) => ({
    fetchSessions: vi.fn().mockResolvedValue([]),
    fetchMessages: vi.fn().mockResolvedValue([]),
    deleteSession: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  });

  let mockChat;

  beforeEach(() => {
    mockChat = {
      setMessages: vi.fn(),
    };

    // Reset mocks
    vi.clearAllMocks();
  });

  // =============================================================================
  // Initialization
  // =============================================================================
  describe('initialization', () => {
    it('returns expected state and methods', () => {
      const manager = useAiChatSessionManager(createMockAdapter());

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
      const { sessions } = useAiChatSessionManager(createMockAdapter());
      expect(sessions.value).toEqual([]);
    });

    it('initializes with null activeSessionId', () => {
      const { activeSessionId } = useAiChatSessionManager(createMockAdapter());
      expect(activeSessionId.value).toBeNull();
    });

    it('initializes with loading states as false', () => {
      const { isLoadingSessions, isLoadingMessages } =
        useAiChatSessionManager(createMockAdapter());
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

      const { getStoredSessionId } =
        useAiChatSessionManager(createMockAdapter());
      const result = getStoredSessionId(botId);

      expect(LocalStorage.getFromJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId)
      );
      expect(result).toBe('stored-session-123');
    });

    it('storeSessionId saves to localStorage', () => {
      const { storeSessionId } = useAiChatSessionManager(createMockAdapter());
      storeSessionId(botId, sessionId);

      expect(LocalStorage.updateJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId),
        sessionId
      );
    });

    it('clearStoredSessionId removes from localStorage', () => {
      const { clearStoredSessionId } =
        useAiChatSessionManager(createMockAdapter());
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
    it('returns empty array when no adapter provided', async () => {
      const { fetchSessions } = useAiChatSessionManager();
      const result = await fetchSessions(botId);
      expect(result).toEqual([]);
    });

    it('returns empty array when botId is missing', async () => {
      const { fetchSessions } = useAiChatSessionManager(createMockAdapter());
      const result = await fetchSessions(null);
      expect(result).toEqual([]);
    });

    it('fetches sessions via adapter and updates state', async () => {
      const mockSessions = [
        { chat_session_id: 'sess-1', updated_at: '2025-01-01' },
        { chat_session_id: 'sess-2', updated_at: '2025-01-02' },
      ];

      const adapter = createMockAdapter({
        fetchSessions: vi.fn().mockResolvedValue(mockSessions),
      });

      const { fetchSessions, sessions, isLoadingSessions } =
        useAiChatSessionManager(adapter);

      const fetchPromise = fetchSessions(botId);

      // Check loading state is set
      expect(isLoadingSessions.value).toBe(true);

      const result = await fetchPromise;

      expect(isLoadingSessions.value).toBe(false);
      expect(adapter.fetchSessions).toHaveBeenCalledWith({
        agentBotId: botId,
        limit: 25,
      });
      expect(sessions.value).toEqual(mockSessions);
      expect(result).toEqual(mockSessions);
    });

    it('handles adapter errors gracefully', async () => {
      const adapter = createMockAdapter({
        fetchSessions: vi
          .fn()
          .mockRejectedValue(new Error('Failed to fetch sessions: 500')),
      });

      const { fetchSessions, sessions, error } =
        useAiChatSessionManager(adapter);
      const result = await fetchSessions(botId);

      expect(result).toEqual([]);
      expect(sessions.value).toEqual([]);
      expect(error.value).toContain('Failed to fetch sessions');
    });

    it('handles network errors gracefully', async () => {
      const adapter = createMockAdapter({
        fetchSessions: vi.fn().mockRejectedValue(new Error('Network error')),
      });

      const { fetchSessions, error } = useAiChatSessionManager(adapter);
      await fetchSessions(botId);

      expect(error.value).toBe('Network error');
    });

    it('passes agentBotId to adapter', async () => {
      const adapter = createMockAdapter();

      const { fetchSessions } = useAiChatSessionManager(adapter);
      await fetchSessions(botId);

      expect(adapter.fetchSessions).toHaveBeenCalledWith({
        agentBotId: botId,
        limit: 25,
      });
    });
  });

  // =============================================================================
  // fetchSessionMessages
  // =============================================================================
  describe('fetchSessionMessages', () => {
    it('returns empty array when no adapter provided', async () => {
      const { fetchSessionMessages } = useAiChatSessionManager();
      const result = await fetchSessionMessages(sessionId);
      expect(result).toEqual([]);
    });

    it('returns empty array when sessionId is missing', async () => {
      const { fetchSessionMessages } =
        useAiChatSessionManager(createMockAdapter());
      const result = await fetchSessionMessages(null);
      expect(result).toEqual([]);
    });

    it('fetches messages via adapter', async () => {
      const mockMessages = [
        { id: '1', role: 'user', content: 'Hello' },
        { id: '2', role: 'assistant', content: 'Hi there!' },
      ];

      const adapter = createMockAdapter({
        fetchMessages: vi.fn().mockResolvedValue(mockMessages),
      });

      const { fetchSessionMessages, isLoadingMessages } =
        useAiChatSessionManager(adapter);

      const fetchPromise = fetchSessionMessages(sessionId);
      expect(isLoadingMessages.value).toBe(true);

      const result = await fetchPromise;

      expect(isLoadingMessages.value).toBe(false);
      expect(result).toEqual(mockMessages);
    });

    it('handles adapter errors gracefully', async () => {
      const adapter = createMockAdapter({
        fetchMessages: vi
          .fn()
          .mockRejectedValue(new Error('Failed to fetch messages: 404')),
      });

      const { fetchSessionMessages, error } = useAiChatSessionManager(adapter);
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
      const adapter = createMockAdapter();

      const { loadSession, activeSessionId } = useAiChatSessionManager(adapter);
      await loadSession(sessionId, botId, mockChat);

      expect(activeSessionId.value).toBe(sessionId);
      expect(LocalStorage.updateJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId),
        sessionId
      );
    });

    it('fetches messages via adapter and sets them on chat instance', async () => {
      const mockMessages = [
        { id: '1', role: 'user', content: 'Hello' },
        { id: '2', role: 'assistant', content: 'Hi!' },
      ];

      const adapter = createMockAdapter({
        fetchMessages: vi.fn().mockResolvedValue(mockMessages),
      });

      const { loadSession } = useAiChatSessionManager(adapter);
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

      const { restoreSession } = useAiChatSessionManager(createMockAdapter());
      const result = await restoreSession(botId, mockChat);

      expect(result).toBe(false);
    });

    it('loads stored session and returns true', async () => {
      LocalStorage.getFromJsonStore.mockReturnValue(sessionId);

      const adapter = createMockAdapter();

      const { restoreSession, activeSessionId } =
        useAiChatSessionManager(adapter);
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
        useAiChatSessionManager(createMockAdapter());
      activeSessionId.value = sessionId;

      startNewSession(botId, mockChat);

      expect(activeSessionId.value).toBeNull();
    });

    it('clears stored session from localStorage', () => {
      const { startNewSession } = useAiChatSessionManager(createMockAdapter());
      startNewSession(botId, mockChat);

      expect(LocalStorage.deleteFromJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId)
      );
    });

    it('clears chat messages', () => {
      const { startNewSession } = useAiChatSessionManager(createMockAdapter());
      startNewSession(botId, mockChat);

      expect(mockChat.setMessages).toHaveBeenCalledWith([]);
    });
  });

  // =============================================================================
  // deleteSession
  // =============================================================================
  describe('deleteSession', () => {
    it('deletes session via adapter and removes from state', async () => {
      const adapter = createMockAdapter();

      const { deleteSession, sessions } = useAiChatSessionManager(adapter);
      sessions.value = [
        { chat_session_id: sessionId, updated_at: '2025-01-01' },
        { chat_session_id: 'other-session', updated_at: '2025-01-02' },
      ];

      const result = await deleteSession(sessionId, botId);

      expect(result).toBe(true);
      expect(adapter.deleteSession).toHaveBeenCalledWith(sessionId);
      expect(sessions.value).toHaveLength(1);
      expect(sessions.value[0].chat_session_id).toBe('other-session');
    });

    it('clears activeSessionId if deleted session was active', async () => {
      const adapter = createMockAdapter();

      const { deleteSession, activeSessionId, sessions } =
        useAiChatSessionManager(adapter);
      activeSessionId.value = sessionId;
      sessions.value = [
        { chat_session_id: sessionId, updated_at: '2025-01-01' },
      ];

      await deleteSession(sessionId, botId);

      expect(activeSessionId.value).toBeNull();
      expect(LocalStorage.deleteFromJsonStore).toHaveBeenCalled();
    });

    it('does not clear activeSessionId if different session deleted', async () => {
      const adapter = createMockAdapter();

      const { deleteSession, activeSessionId, sessions } =
        useAiChatSessionManager(adapter);
      activeSessionId.value = 'different-session';
      sessions.value = [
        { chat_session_id: sessionId, updated_at: '2025-01-01' },
      ];

      await deleteSession(sessionId, botId);

      expect(activeSessionId.value).toBe('different-session');
    });

    it('handles adapter errors and returns false', async () => {
      const adapter = createMockAdapter({
        deleteSession: vi
          .fn()
          .mockRejectedValue(new Error('Failed to delete session: 500')),
      });

      const { deleteSession, error } = useAiChatSessionManager(adapter);
      const result = await deleteSession(sessionId, botId);

      expect(result).toBe(false);
      expect(error.value).toContain('Failed to delete session');
    });

    it('returns false when adapter has no deleteSession', async () => {
      const adapter = createMockAdapter();
      delete adapter.deleteSession;

      const { deleteSession } = useAiChatSessionManager(adapter);
      const result = await deleteSession(sessionId, botId);

      expect(result).toBe(false);
    });
  });

  // =============================================================================
  // setActiveSessionId
  // =============================================================================
  describe('setActiveSessionId', () => {
    it('updates activeSessionId ref', () => {
      const { setActiveSessionId, activeSessionId } =
        useAiChatSessionManager(createMockAdapter());

      setActiveSessionId(sessionId, botId);

      expect(activeSessionId.value).toBe(sessionId);
    });

    it('stores session in localStorage when both ids provided', () => {
      const { setActiveSessionId } =
        useAiChatSessionManager(createMockAdapter());

      setActiveSessionId(sessionId, botId);

      expect(LocalStorage.updateJsonStore).toHaveBeenCalledWith(
        'ai_chat_active_sessions',
        String(botId),
        sessionId
      );
    });

    it('does not store when sessionId is null', () => {
      const { setActiveSessionId } =
        useAiChatSessionManager(createMockAdapter());

      setActiveSessionId(null, botId);

      expect(LocalStorage.updateJsonStore).not.toHaveBeenCalled();
    });

    it('does not store when botId is null', () => {
      const { setActiveSessionId } =
        useAiChatSessionManager(createMockAdapter());

      setActiveSessionId(sessionId, null);

      expect(LocalStorage.updateJsonStore).not.toHaveBeenCalled();
    });
  });

  // =============================================================================
  // Single-session mode (no adapter)
  // =============================================================================
  describe('single-session mode (no adapter)', () => {
    it('fetchSessions returns empty array', async () => {
      const { fetchSessions } = useAiChatSessionManager();
      const result = await fetchSessions(botId);
      expect(result).toEqual([]);
    });

    it('fetchSessionMessages returns empty array', async () => {
      const { fetchSessionMessages } = useAiChatSessionManager();
      const result = await fetchSessionMessages(sessionId);
      expect(result).toEqual([]);
    });

    it('deleteSession returns false', async () => {
      const { deleteSession } = useAiChatSessionManager();
      const result = await deleteSession(sessionId, botId);
      expect(result).toBe(false);
    });

    it('localStorage methods still work', () => {
      LocalStorage.getFromJsonStore.mockReturnValue('session-abc');
      const { getStoredSessionId, storeSessionId, clearStoredSessionId } =
        useAiChatSessionManager();

      expect(getStoredSessionId(botId)).toBe('session-abc');

      storeSessionId(botId, 'new-session');
      expect(LocalStorage.updateJsonStore).toHaveBeenCalled();

      clearStoredSessionId(botId);
      expect(LocalStorage.deleteFromJsonStore).toHaveBeenCalled();
    });
  });
});
