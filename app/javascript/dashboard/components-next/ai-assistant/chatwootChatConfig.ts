/**
 * Chatwoot Chat Configuration [APP]
 *
 * Wraps Chatwoot-specific transport, sessions, and behavior into
 * the ChatConfig / SessionsAdapter interfaces.
 * This file stays in the Chatwoot app; it is NOT extracted into the package.
 *
 * Mobile equivalent: chatwoot-mobile-app/src/ai/chatwootChatConfig.ts
 *                     chatwoot-mobile-app/src/ai/chatwootSessionsAdapter.ts
 */

import type {
  TransportConfig,
  ChatBehaviorConfig,
  SessionsAdapter,
  PersistenceAdapter,
  ChatMessage,
} from './types/chatConfig';
import type { ChatSession } from './types';
import { getAuthHeaders } from './utils/auth';
import { isTextPart, type MessagePart, type TextPart } from './types';
import { parseSessionsResponse, parseMessagesResponse } from './schemas';
import { LocalStorage } from 'shared/helpers/localStorage';
import type { UIMessage } from 'ai';

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Extract text content from a UIMessage.
 * Handles both parts-based and content-based message formats.
 */
function extractTextContent(message: UIMessage): string {
  if (message.parts && Array.isArray(message.parts)) {
    return message.parts
      .filter((part): part is TextPart => isTextPart(part as MessagePart))
      .map(part => part.text || '')
      .join('');
  }

  if (
    'content' in message &&
    typeof (message as Record<string, unknown>).content === 'string'
  ) {
    return (message as Record<string, unknown>).content as string;
  }

  return '';
}

// ============================================================================
// Transport Configuration Factory
// ============================================================================

/**
 * Create a Chatwoot-specific transport config for streaming.
 *
 * @param getAccountId - Getter that returns current account ID (reactive-safe)
 * @param getMetadata - Function that returns current agentBotId and sessionId
 */
export function createChatwootTransportConfig(
  getAccountId: () => number | string | null,
  getMetadata: () => {
    agentBotId: number | null;
    sessionId: string | null;
  },
): TransportConfig {
  return {
    streamEndpoint: () => `/api/v1/accounts/${getAccountId()}/ai_chat/stream`,
    getHeaders: getAuthHeaders,
    prepareRequest: ({ lastMessage, headers, metadata }) => ({
      body: {
        messages: [
          {
            role: lastMessage.role,
            content: extractTextContent(lastMessage),
          },
        ],
        agent_bot_id: metadata.agentBotId ?? getMetadata().agentBotId,
        ...(metadata.sessionId ?? getMetadata().sessionId
          ? {
              chat_session_id:
                metadata.sessionId ?? getMetadata().sessionId,
            }
          : {}),
      },
      headers,
    }),
    extractSessionId: (response: Response) =>
      response.headers.get('X-Chat-Session-Id'),
  };
}

// ============================================================================
// Behavior Configuration
// ============================================================================

export const chatwootBehaviorConfig: ChatBehaviorConfig = {
  streamThrottle: 150,
};

// ============================================================================
// Persistence Adapter Factory
// ============================================================================

/**
 * Create a Chatwoot-specific persistence adapter using localStorage.
 * Wraps Chatwoot's LocalStorage helper behind the PersistenceAdapter interface.
 */
export function createChatwootPersistenceAdapter(): PersistenceAdapter {
  return {
    async get(key: string): Promise<string | null> {
      return LocalStorage.get(key) ?? null;
    },
    async set(key: string, value: string): Promise<void> {
      LocalStorage.set(key, value);
    },
    async remove(key: string): Promise<void> {
      LocalStorage.remove(key);
    },
  };
}

// ============================================================================
// Sessions Adapter Factory
// ============================================================================

/**
 * Create a Chatwoot-specific sessions adapter.
 * Wraps raw fetch() calls with auth headers and Zod validation.
 *
 * @param getAccountId - Getter that returns current account ID (reactive-safe)
 */
export function createChatwootSessionsAdapter(
  getAccountId: () => number | string | null,
): SessionsAdapter {
  return {
    fetchSessions: async ({ agentBotId, limit = 25 }) => {
      const accountId = getAccountId();
      if (!accountId) return [];
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions?agent_bot_id=${agentBotId}&limit=${limit}`,
        { method: 'GET', headers: getAuthHeaders() },
      );
      if (!response.ok) {
        throw new Error(`Failed to fetch sessions: ${response.status}`);
      }
      const data = await response.json();
      return parseSessionsResponse(data).sessions as ChatSession[];
    },

    fetchMessages: async ({ sessionId, limit = 100 }) => {
      const accountId = getAccountId();
      if (!accountId) return [];
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions/${sessionId}/messages?limit=${limit}`,
        { method: 'GET', headers: getAuthHeaders() },
      );
      if (!response.ok) {
        throw new Error(`Failed to fetch messages: ${response.status}`);
      }
      const data = await response.json();
      return parseMessagesResponse(data)
        .messages as unknown as ChatMessage[];
    },

    deleteSession: async (sessionId: string) => {
      const accountId = getAccountId();
      if (!accountId) return;
      const response = await fetch(
        `/api/v1/accounts/${accountId}/ai_chat/sessions/${sessionId}`,
        { method: 'DELETE', headers: getAuthHeaders() },
      );
      if (!response.ok) {
        throw new Error(`Failed to delete session: ${response.status}`);
      }
    },
  };
}
