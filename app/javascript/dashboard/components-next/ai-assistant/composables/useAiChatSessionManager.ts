/**
 * useAiChatSessionManager.ts
 *
 * Composable for AI chat session persistence and history management.
 * Accepts an optional SessionsAdapter to decouple from Chatwoot-specific
 * API calls. When no adapter is provided, operates in single-session mode.
 *
 * All Chatwoot-specific fetch logic (API paths, auth headers, Zod parsing)
 * lives in the adapter — see chatwootChatConfig.ts.
 */
import { ref, type Ref } from 'vue';
import { LocalStorage } from 'shared/helpers/localStorage';
import { toUIMessages } from './useAiMessageMapper';
import { CHAT_STATUS } from '../constants';
import type { ChatSession } from '../types';
import type { SessionsAdapter, ChatMessage } from '../types/chatConfig';
import type { UIMessage } from 'ai';

// localStorage key for active sessions per bot
const STORAGE_KEY = 'ai_chat_active_sessions';

interface ChatInstance {
  status: Ref<string>;
  setMessages: (messages: UIMessage[]) => void;
}

interface SessionManagerReturn {
  sessions: Ref<ChatSession[]>;
  activeSessionId: Ref<string | null>;
  isLoadingSessions: Ref<boolean>;
  isLoadingMessages: Ref<boolean>;
  error: Ref<string | null>;
  fetchSessions: (
    botId: number | string,
    limit?: number,
  ) => Promise<ChatSession[]>;
  fetchSessionMessages: (
    sessionId: string,
    limit?: number,
  ) => Promise<Record<string, unknown>[]>;
  loadSession: (
    sessionId: string,
    botId: number | string,
    chat: ChatInstance,
  ) => Promise<void>;
  restoreSession: (
    botId: number | string,
    chat: ChatInstance,
  ) => Promise<boolean>;
  startNewSession: (botId: number | string, chat: ChatInstance) => void;
  deleteSession: (
    sessionId: string,
    botId: number | string,
  ) => Promise<boolean>;
  setActiveSessionId: (
    sessionId: string | null,
    botId: number | string | null,
  ) => void;
  getStoredSessionId: (botId: number | string) => string | null;
  storeSessionId: (botId: number | string, sessionId: string) => void;
  clearStoredSessionId: (botId: number | string) => void;
}

/**
 * Composable for managing AI chat sessions.
 *
 * @param adapter - Optional SessionsAdapter. When undefined, session operations
 *   return empty results (single-session mode).
 */
export function useAiChatSessionManager(
  adapter?: SessionsAdapter,
): SessionManagerReturn {
  // State
  const sessions = ref<ChatSession[]>([]);
  const activeSessionId = ref<string | null>(null);
  const isLoadingSessions = ref(false);
  const isLoadingMessages = ref(false);
  const error = ref<string | null>(null);

  // ============================================================================
  // LOCALSTORAGE PERSISTENCE
  // ============================================================================

  const getStoredSessionId = (botId: number | string): string | null => {
    return LocalStorage.getFromJsonStore(STORAGE_KEY, String(botId));
  };

  const storeSessionId = (
    botId: number | string,
    sessionId: string,
  ): void => {
    LocalStorage.updateJsonStore(STORAGE_KEY, String(botId), sessionId);
  };

  const clearStoredSessionId = (botId: number | string): void => {
    LocalStorage.deleteFromJsonStore(STORAGE_KEY, String(botId));
  };

  // ============================================================================
  // API METHODS (delegated to adapter)
  // ============================================================================

  const fetchSessions = async (
    botId: number | string,
    limit: number = 25,
  ): Promise<ChatSession[]> => {
    if (!adapter || !botId) return [];

    isLoadingSessions.value = true;
    error.value = null;

    try {
      const result = await adapter.fetchSessions({
        agentBotId: Number(botId),
        limit,
      });

      // Sessions use snake_case consistently (matching ChatSession type and API)
      sessions.value = result || [];
      return sessions.value;
    } catch (e) {
      error.value = (e as Error).message;
      sessions.value = [];
      return [];
    } finally {
      isLoadingSessions.value = false;
    }
  };

  const fetchSessionMessages = async (
    sessionId: string,
    limit: number = 100,
  ): Promise<Record<string, unknown>[]> => {
    if (!adapter || !sessionId) return [];

    isLoadingMessages.value = true;
    error.value = null;

    try {
      const result = await adapter.fetchMessages({ sessionId, limit });
      return result as unknown as Record<string, unknown>[];
    } catch (e) {
      error.value = (e as Error).message;
      return [];
    } finally {
      isLoadingMessages.value = false;
    }
  };

  const loadSession = async (
    sessionId: string,
    botId: number | string,
    chat: ChatInstance,
  ): Promise<void> => {
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

  const restoreSession = async (
    botId: number | string,
    chat: ChatInstance,
  ): Promise<boolean> => {
    const storedSessionId = getStoredSessionId(botId);
    if (storedSessionId) {
      await loadSession(storedSessionId, botId, chat);
      return true;
    }
    return false;
  };

  const startNewSession = (
    botId: number | string,
    chat: ChatInstance,
  ): void => {
    activeSessionId.value = null;
    clearStoredSessionId(botId);
    chat.setMessages([]);
  };

  const deleteSession = async (
    sessionId: string,
    botId: number | string,
  ): Promise<boolean> => {
    if (!adapter?.deleteSession) return false;

    try {
      await adapter.deleteSession(sessionId);

      // Remove from local state
      sessions.value = sessions.value.filter(
        s => s.chat_session_id !== sessionId,
      );

      // Clear from storage if it was the active session
      if (activeSessionId.value === sessionId) {
        activeSessionId.value = null;
        clearStoredSessionId(botId);
      }

      return true;
    } catch (e) {
      error.value = (e as Error).message;
      return false;
    }
  };

  const setActiveSessionId = (
    sessionId: string | null,
    botId: number | string | null,
  ): void => {
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
