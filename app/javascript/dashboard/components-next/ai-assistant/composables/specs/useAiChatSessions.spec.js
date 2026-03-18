import { useAiChatSessions } from '../useAiChatSessions';

// Mock dependencies
vi.mock('../useAiMessageMapper', () => ({
  toUIMessages: vi.fn(messages =>
    messages.map(m => ({
      id: m.id,
      role: m.role,
      parts: [{ type: 'text', text: m.content }],
    }))
  ),
}));

import { toUIMessages } from '../useAiMessageMapper';

// Helper to create a mock persistence adapter
const createMockPersistence = () => ({
  get: vi.fn().mockResolvedValue(null),
  set: vi.fn().mockResolvedValue(undefined),
  remove: vi.fn().mockResolvedValue(undefined),
});

describe('useAiChatSessions', () => {
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
      const manager = useAiChatSessions(createMockAdapter());

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
      const { sessions } = useAiChatSessions(createMockAdapter());
      expect(sessions.value).toEqual([]);
    });

    it('initializes with null activeSessionId', () => {
      const { activeSessionId } = useAiChatSessions(createMockAdapter());
      expect(activeSessionId.value).toBeNull();
    });

    it('initializes with loading states as false', () => {
      const { isLoadingSessions, isLoadingMessages } =
        useAiChatSessions(createMockAdapter());
      expect(isLoadingSessions.value).toBe(false);
      expect(isLoadingMessages.value).toBe(false);
    });
  });

  // =============================================================================
  // persistence methods (in-memory + adapter)
  // =============================================================================
  describe('persistence methods', () => {
    it('getStoredSessionId returns null when nothing stored', () => {
      const { getStoredSessionId } = useAiChatSessions(createMockAdapter());
      const result = getStoredSessionId(botId);

      expect(result).toBeNull();
    });

    it('storeSessionId saves to in-memory store', () => {
      const { storeSessionId, getStoredSessionId } =
        useAiChatSessions(createMockAdapter());
      storeSessionId(botId, sessionId);

      expect(getStoredSessionId(botId)).toBe(sessionId);
    });

    it('storeSessionId delegates to persistence adapter when provided', () => {
      const persistence = createMockPersistence();
      const { storeSessionId } = useAiChatSessions(
        createMockAdapter(),
        persistence
      );
      storeSessionId(botId, sessionId);

      expect(persistence.set).toHaveBeenCalledWith(
        `ai_chat_active_sessions:${String(botId)}`,
        sessionId
      );
    });

    it('clearStoredSessionId removes from in-memory store', () => {
      const { storeSessionId, clearStoredSessionId, getStoredSessionId } =
        useAiChatSessions(createMockAdapter());
      storeSessionId(botId, sessionId);
      clearStoredSessionId(botId);

      expect(getStoredSessionId(botId)).toBeNull();
    });

    it('clearStoredSessionId delegates to persistence adapter when provided', () => {
      const persistence = createMockPersistence();
      const { clearStoredSessionId } = useAiChatSessions(
        createMockAdapter(),
        persistence
      );
      clearStoredSessionId(botId);

      expect(persistence.remove).toHaveBeenCalledWith(
        `ai_chat_active_sessions:${String(botId)}`
      );
    });
  });

  // =============================================================================
  // fetchSessions
  // =============================================================================
  describe('fetchSessions', () => {
    it('returns empty array when no adapter provided', async () => {
      const { fetchSessions } = useAiChatSessions();
      const result = await fetchSessions(botId);
      expect(result).toEqual([]);
    });

    it('returns empty array when botId is missing', async () => {
      const { fetchSessions } = useAiChatSessions(createMockAdapter());
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
        useAiChatSessions(adapter);

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

      const { fetchSessions, sessions, error } = useAiChatSessions(adapter);
      const result = await fetchSessions(botId);

      expect(result).toEqual([]);
      expect(sessions.value).toEqual([]);
      expect(error.value).toContain('Failed to fetch sessions');
    });

    it('handles network errors gracefully', async () => {
      const adapter = createMockAdapter({
        fetchSessions: vi.fn().mockRejectedValue(new Error('Network error')),
      });

      const { fetchSessions, error } = useAiChatSessions(adapter);
      await fetchSessions(botId);

      expect(error.value).toBe('Network error');
    });

    it('passes agentBotId to adapter', async () => {
      const adapter = createMockAdapter();

      const { fetchSessions } = useAiChatSessions(adapter);
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
      const { fetchSessionMessages } = useAiChatSessions();
      const result = await fetchSessionMessages(sessionId);
      expect(result).toEqual([]);
    });

    it('returns empty array when sessionId is missing', async () => {
      const { fetchSessionMessages } = useAiChatSessions(createMockAdapter());
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
        useAiChatSessions(adapter);

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

      const { fetchSessionMessages, error } = useAiChatSessions(adapter);
      const result = await fetchSessionMessages(sessionId);

      expect(result).toEqual([]);
      expect(error.value).toContain('Failed to fetch messages');
    });
  });

  // =============================================================================
  // loadSession
  // =============================================================================
  describe('loadSession', () => {
    it('sets activeSessionId and stores in memory', async () => {
      const adapter = createMockAdapter();

      const { loadSession, activeSessionId, getStoredSessionId } =
        useAiChatSessions(adapter);
      await loadSession(sessionId, botId, mockChat);

      expect(activeSessionId.value).toBe(sessionId);
      expect(getStoredSessionId(botId)).toBe(sessionId);
    });

    it('fetches messages via adapter and sets them on chat instance', async () => {
      const mockMessages = [
        { id: '1', role: 'user', content: 'Hello' },
        { id: '2', role: 'assistant', content: 'Hi!' },
      ];

      const adapter = createMockAdapter({
        fetchMessages: vi.fn().mockResolvedValue(mockMessages),
      });

      const { loadSession } = useAiChatSessions(adapter);
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
      const { restoreSession } = useAiChatSessions(createMockAdapter());
      const result = await restoreSession(botId, mockChat);

      expect(result).toBe(false);
    });

    it('loads stored session from memory and returns true', async () => {
      const adapter = createMockAdapter();

      const { restoreSession, activeSessionId, storeSessionId } =
        useAiChatSessions(adapter);
      // Pre-store a session ID
      storeSessionId(botId, sessionId);

      const result = await restoreSession(botId, mockChat);

      expect(result).toBe(true);
      expect(activeSessionId.value).toBe(sessionId);
    });

    it('hydrates from persistence adapter when memory is empty', async () => {
      const adapter = createMockAdapter();
      const persistence = createMockPersistence();
      persistence.get.mockResolvedValue(sessionId);

      const { restoreSession, activeSessionId } = useAiChatSessions(
        adapter,
        persistence
      );
      const result = await restoreSession(botId, mockChat);

      expect(persistence.get).toHaveBeenCalledWith(
        `ai_chat_active_sessions:${String(botId)}`
      );
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
        useAiChatSessions(createMockAdapter());
      activeSessionId.value = sessionId;

      startNewSession(botId, mockChat);

      expect(activeSessionId.value).toBeNull();
    });

    it('clears stored session from memory', () => {
      const { startNewSession, storeSessionId, getStoredSessionId } =
        useAiChatSessions(createMockAdapter());
      storeSessionId(botId, sessionId);
      startNewSession(botId, mockChat);

      expect(getStoredSessionId(botId)).toBeNull();
    });

    it('clears chat messages', () => {
      const { startNewSession } = useAiChatSessions(createMockAdapter());
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

      const { deleteSession, sessions } = useAiChatSessions(adapter);
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

      const { deleteSession, activeSessionId, sessions, getStoredSessionId } =
        useAiChatSessions(adapter);
      activeSessionId.value = sessionId;
      sessions.value = [
        { chat_session_id: sessionId, updated_at: '2025-01-01' },
      ];

      await deleteSession(sessionId, botId);

      expect(activeSessionId.value).toBeNull();
      expect(getStoredSessionId(botId)).toBeNull();
    });

    it('does not clear activeSessionId if different session deleted', async () => {
      const adapter = createMockAdapter();

      const { deleteSession, activeSessionId, sessions } =
        useAiChatSessions(adapter);
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

      const { deleteSession, error } = useAiChatSessions(adapter);
      const result = await deleteSession(sessionId, botId);

      expect(result).toBe(false);
      expect(error.value).toContain('Failed to delete session');
    });

    it('returns false when adapter has no deleteSession', async () => {
      const adapter = createMockAdapter();
      delete adapter.deleteSession;

      const { deleteSession } = useAiChatSessions(adapter);
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
        useAiChatSessions(createMockAdapter());

      setActiveSessionId(sessionId, botId);

      expect(activeSessionId.value).toBe(sessionId);
    });

    it('stores session in memory when both ids provided', () => {
      const { setActiveSessionId, getStoredSessionId } =
        useAiChatSessions(createMockAdapter());

      setActiveSessionId(sessionId, botId);

      expect(getStoredSessionId(botId)).toBe(sessionId);
    });

    it('stores session via persistence adapter when both ids provided', () => {
      const persistence = createMockPersistence();
      const { setActiveSessionId } = useAiChatSessions(
        createMockAdapter(),
        persistence
      );

      setActiveSessionId(sessionId, botId);

      expect(persistence.set).toHaveBeenCalledWith(
        `ai_chat_active_sessions:${String(botId)}`,
        sessionId
      );
    });

    it('does not store when sessionId is null', () => {
      const persistence = createMockPersistence();
      const { setActiveSessionId } = useAiChatSessions(
        createMockAdapter(),
        persistence
      );

      setActiveSessionId(null, botId);

      expect(persistence.set).not.toHaveBeenCalled();
    });

    it('does not store when botId is null', () => {
      const persistence = createMockPersistence();
      const { setActiveSessionId } = useAiChatSessions(
        createMockAdapter(),
        persistence
      );

      setActiveSessionId(sessionId, null);

      expect(persistence.set).not.toHaveBeenCalled();
    });
  });

  // =============================================================================
  // Single-session mode (no adapter)
  // =============================================================================
  describe('single-session mode (no adapter)', () => {
    it('fetchSessions returns empty array', async () => {
      const { fetchSessions } = useAiChatSessions();
      const result = await fetchSessions(botId);
      expect(result).toEqual([]);
    });

    it('fetchSessionMessages returns empty array', async () => {
      const { fetchSessionMessages } = useAiChatSessions();
      const result = await fetchSessionMessages(sessionId);
      expect(result).toEqual([]);
    });

    it('deleteSession returns false', async () => {
      const { deleteSession } = useAiChatSessions();
      const result = await deleteSession(sessionId, botId);
      expect(result).toBe(false);
    });

    it('in-memory persistence methods still work', () => {
      const { getStoredSessionId, storeSessionId, clearStoredSessionId } =
        useAiChatSessions();

      expect(getStoredSessionId(botId)).toBeNull();

      storeSessionId(botId, 'new-session');
      expect(getStoredSessionId(botId)).toBe('new-session');

      clearStoredSessionId(botId);
      expect(getStoredSessionId(botId)).toBeNull();
    });
  });
});
