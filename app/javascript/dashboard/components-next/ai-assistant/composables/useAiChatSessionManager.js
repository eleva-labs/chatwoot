/**
 * useAiChatSessionManager.js
 *
 * Composable for AI chat session persistence and history management.
 * Handles fetching sessions, loading message history, and localStorage persistence.
 *
 * Features:
 * - Fetch session list from backend
 * - Load session messages and transform to UIMessage format
 * - Persist active session ID per bot in localStorage
 * - Restore session on mount
 * - Start new sessions
 * - Delete sessions
 */
import { ref } from 'vue';
import { LocalStorage } from 'shared/helpers/localStorage';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { toUIMessages } from './useAiMessageMapper';
import { getAuthHeaders } from '../utils/auth';
import { parseSessionsResponse, parseMessagesResponse } from '../schemas';
import { CHAT_STATUS } from '../constants';

// localStorage key for active sessions per bot
const STORAGE_KEY = 'ai_chat_active_sessions';

/**
 * Composable for managing AI chat sessions.
 *
 * @param {number|string} accountId - Current account ID
 * @returns {Object} Session management state and methods
 *
 * @example
 * const sessionManager = useAiChatSessionManager(accountId);
 *
 * // Fetch sessions for a bot
 * await sessionManager.fetchSessions(botId);
 *
 * // Load a specific session
 * await sessionManager.loadSession(sessionId, botId, chat);
 *
 * // Restore last active session
 * await sessionManager.restoreSession(botId, chat);
 */
export function useAiChatSessionManager(accountId) {
  // State
  const sessions = ref([]);
  const activeSessionId = ref(null);
  const isLoadingSessions = ref(false);
  const isLoadingMessages = ref(false);
  const error = ref(null);

  // ============================================================================
  // LOCALSTORAGE PERSISTENCE
  // Using LocalStorage helper from shared/helpers/localStorage.js
  // ============================================================================

  /**
   * Get stored session ID for a bot from localStorage.
   * @param {number|string} botId - Bot ID
   * @returns {string|null} Stored session ID or null
   */
  const getStoredSessionId = botId => {
    return LocalStorage.getFromJsonStore(STORAGE_KEY, String(botId));
  };

  /**
   * Store session ID for a bot in localStorage.
   * @param {number|string} botId - Bot ID
   * @param {string} sessionId - Session ID to store
   */
  const storeSessionId = (botId, sessionId) => {
    LocalStorage.updateJsonStore(STORAGE_KEY, String(botId), sessionId);
  };

  /**
   * Clear stored session ID for a bot from localStorage.
   * @param {number|string} botId - Bot ID
   */
  const clearStoredSessionId = botId => {
    LocalStorage.deleteFromJsonStore(STORAGE_KEY, String(botId));
  };

  // ============================================================================
  // API METHODS
  // ============================================================================

  /**
   * Fetch sessions list from backend.
   * @param {number|string} botId - Agent bot ID
   * @param {number} limit - Max sessions to fetch (default 25)
   * @returns {Array} List of sessions
   */
  const fetchSessions = async (botId, limit = 25) => {
    if (!accountId || !botId) return [];

    isLoadingSessions.value = true;
    error.value = null;

    try {
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions?agent_bot_id=${botId}&limit=${limit}`,
        { method: 'GET', headers: getAuthHeaders() }
      );

      if (!response.ok) {
        throw new Error(`Failed to fetch sessions: ${response.status}`);
      }

      const data = await response.json();
      const parsed = parseSessionsResponse(data);
      // Transform keys to camelCase for existing consumers
      const transformed = useCamelCase(
        { sessions: parsed.sessions },
        { deep: true }
      );
      sessions.value = transformed.sessions || [];
      return sessions.value;
    } catch (e) {
      error.value = e.message;
      sessions.value = [];
      return [];
    } finally {
      isLoadingSessions.value = false;
    }
  };

  /**
   * Fetch messages for a specific session.
   * @param {string} sessionId - Chat session ID
   * @param {number} limit - Max messages to fetch (default 100)
   * @returns {Array} List of messages in backend format
   */
  const fetchSessionMessages = async (sessionId, limit = 100) => {
    if (!accountId || !sessionId) return [];

    isLoadingMessages.value = true;
    error.value = null;

    try {
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions/${sessionId}/messages?limit=${limit}`,
        { method: 'GET', headers: getAuthHeaders() }
      );

      if (!response.ok) {
        throw new Error(`Failed to fetch messages: ${response.status}`);
      }

      const data = await response.json();
      const parsed = parseMessagesResponse(data);
      return parsed.messages;
    } catch (e) {
      error.value = e.message;
      return [];
    } finally {
      isLoadingMessages.value = false;
    }
  };

  /**
   * Load a session into the chat instance.
   * Fetches messages and transforms to UIMessage format.
   *
   * @param {string} sessionId - Session to load
   * @param {number|string} botId - Current bot ID (for persistence)
   * @param {Object} chat - Vercel Chat instance with setMessages()
   */
  const loadSession = async (sessionId, botId, chat) => {
    // Guard: don't load while streaming (prevents message corruption)
    const currentStatus = chat.status?.value;
    if (
      currentStatus === CHAT_STATUS.STREAMING ||
      currentStatus === CHAT_STATUS.SUBMITTED
    ) {
      return;
    }

    activeSessionId.value = sessionId;
    storeSessionId(botId, sessionId);

    const messages = await fetchSessionMessages(sessionId);
    // Transform backend messages to UIMessage format
    // Backend returns newest first, reverse to get chronological order
    const uiMessages = toUIMessages(messages).reverse();
    chat.setMessages(uiMessages);
  };

  /**
   * Restore session from localStorage on mount.
   * Call this after bot is selected.
   *
   * @param {number|string} botId - Current bot ID
   * @param {Object} chat - Vercel Chat instance
   * @returns {boolean} True if session was restored
   */
  const restoreSession = async (botId, chat) => {
    const storedSessionId = getStoredSessionId(botId);
    if (storedSessionId) {
      await loadSession(storedSessionId, botId, chat);
      return true;
    }
    return false;
  };

  /**
   * Start a new chat session.
   * Clears messages and active session ID.
   *
   * @param {number|string} botId - Current bot ID
   * @param {Object} chat - Vercel Chat instance
   */
  const startNewSession = (botId, chat) => {
    activeSessionId.value = null;
    clearStoredSessionId(botId);
    chat.setMessages([]);
  };

  /**
   * Delete a session from backend and local state.
   *
   * @param {string} sessionId - Session to delete
   * @param {number|string} botId - Current bot ID (to clear from storage if active)
   * @returns {boolean} True if deletion was successful
   */
  const deleteSession = async (sessionId, botId) => {
    try {
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions/${sessionId}`,
        { method: 'DELETE', headers: getAuthHeaders() }
      );

      if (!response.ok) {
        throw new Error(`Failed to delete session: ${response.status}`);
      }

      // Remove from local state
      sessions.value = sessions.value.filter(
        s => s.chatSessionId !== sessionId
      );

      // Clear from storage if it was the active session
      if (activeSessionId.value === sessionId) {
        activeSessionId.value = null;
        clearStoredSessionId(botId);
      }

      return true;
    } catch (e) {
      error.value = e.message;
      return false;
    }
  };

  /**
   * Update active session ID when received from stream response.
   * Call this from onSessionId callback in useVercelChat.
   *
   * @param {string} sessionId - New session ID from backend
   * @param {number|string} botId - Current bot ID
   */
  const setActiveSessionId = (sessionId, botId) => {
    activeSessionId.value = sessionId;
    if (sessionId && botId) {
      storeSessionId(botId, sessionId);
    }
  };

  return {
    // State
    sessions,
    activeSessionId,
    isLoadingSessions,
    isLoadingMessages,
    error,

    // API Methods
    fetchSessions,
    fetchSessionMessages,
    loadSession,
    restoreSession,
    startNewSession,
    deleteSession,
    setActiveSessionId,

    // Storage helpers (for testing/advanced use)
    getStoredSessionId,
    storeSessionId,
    clearStoredSessionId,
  };
}

export default useAiChatSessionManager;
