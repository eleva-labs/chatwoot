/**
 * useAiChatSessionManager.ts
 *
 * Composable for AI chat session persistence and history management.
 * Handles fetching sessions, loading message history, and localStorage persistence.
 */
import { ref, type Ref } from 'vue';
import { LocalStorage } from 'shared/helpers/localStorage';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { toUIMessages } from './useAiMessageMapper';
import { getAuthHeaders } from '../utils/auth';
import { parseSessionsResponse, parseMessagesResponse } from '../schemas';
import { CHAT_STATUS } from '../constants';
import type { ChatSession } from '../types';
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
  fetchSessions: (botId: number | string, limit?: number) => Promise<ChatSession[]>;
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
 */
export function useAiChatSessionManager(
  accountId: number | string | null,
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
  // API METHODS
  // ============================================================================

  const fetchSessions = async (
    botId: number | string,
    limit: number = 25,
  ): Promise<ChatSession[]> => {
    if (!accountId || !botId) return [];

    isLoadingSessions.value = true;
    error.value = null;

    try {
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions?agent_bot_id=${botId}&limit=${limit}`,
        { method: 'GET', headers: getAuthHeaders() },
      );

      if (!response.ok) {
        throw new Error(`Failed to fetch sessions: ${response.status}`);
      }

      const data = await response.json();
      const parsed = parseSessionsResponse(data);
      // Transform keys to camelCase for existing consumers
      const transformed = useCamelCase(
        { sessions: parsed.sessions },
        { deep: true },
      ) as { sessions: ChatSession[] };
      sessions.value = transformed.sessions || [];
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
    if (!accountId || !sessionId) return [];

    isLoadingMessages.value = true;
    error.value = null;

    try {
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions/${sessionId}/messages?limit=${limit}`,
        { method: 'GET', headers: getAuthHeaders() },
      );

      if (!response.ok) {
        throw new Error(`Failed to fetch messages: ${response.status}`);
      }

      const data = await response.json();
      const parsed = parseMessagesResponse(data);
      return parsed.messages as unknown as Record<string, unknown>[];
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
    try {
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions/${sessionId}`,
        { method: 'DELETE', headers: getAuthHeaders() },
      );

      if (!response.ok) {
        throw new Error(`Failed to delete session: ${response.status}`);
      }

      // Remove from local state
      sessions.value = sessions.value.filter(
        s =>
          (s as unknown as Record<string, unknown>).chatSessionId !==
          sessionId,
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
