/**
 * AI Chat Configuration Types [CORE]
 *
 * Split ChatConfig into sub-configs per extraction review I1.
 * These interfaces become candidates for @eleva/ai-chat-core/types/chat.ts.
 *
 * IMPORTANT: These interfaces must match mobile's
 * chatwoot-mobile-app/src/types/ai-chat/chatConfig.ts EXACTLY.
 */

import type { UIMessage } from 'ai';

/**
 * Transport configuration for SSE streaming connection.
 */
export interface TransportConfig {
  /** SSE streaming endpoint URL */
  streamEndpoint: string | (() => string);
  /** Returns auth headers for the streaming transport */
  getHeaders: () => Record<string, string> | Promise<Record<string, string>>;
  /** Transform request body before sending */
  prepareRequest?: (options: {
    messages: UIMessage[];
    lastMessage: UIMessage;
    headers: Record<string, string>;
    metadata: Record<string, unknown>;
  }) => { body: Record<string, unknown>; headers: Record<string, string> };
  /** Parse error responses from backend */
  parseError?: (response: Response) => Promise<string>;
  /** Custom fetch function (RN uses expo/fetch) */
  fetch?: typeof globalThis.fetch;
  /** Extract session ID from streaming response. Default: reads X-Chat-Session-Id header */
  extractSessionId?: (response: Response) => string | null;
}

/**
 * Chat behavior configuration.
 */
export interface ChatBehaviorConfig {
  /** Throttle for streaming updates (ms). Default: 150 */
  streamThrottle?: number;
  /** Auto-continue when tool results are added */
  sendAutomaticallyWhen?: (opts: {
    messages: UIMessage[];
  }) => boolean | PromiseLike<boolean>;
}

/**
 * Chat UI configuration for display information.
 */
export interface ChatUIConfig {
  /** User info for avatar display */
  user?: { name?: string; avatarUrl?: string };
  /** Bot info */
  bot?: { id: number; name?: string; avatarUrl?: string };
}

/**
 * Persistence adapter for session IDs.
 */
export interface PersistenceAdapter {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
  remove(key: string): Promise<void>;
}

/**
 * I18n provider interface [CORE].
 * Minimal translation function + locale metadata.
 */
export interface I18nProvider {
  t(key: string, params?: Record<string, unknown>): string;
  locale?: string;
  dir?: 'ltr' | 'rtl';
}

/**
 * Combined chat configuration.
 * Composed from sub-configs rather than being a flat god object.
 *
 * IMPORTANT: The config object must be stable (module-scope constant or
 * computed with empty deps) to preserve INV-4 (transport non-reactive dependencies).
 */
export interface ChatConfig {
  transport: TransportConfig;
  behavior?: ChatBehaviorConfig;
  ui?: ChatUIConfig;
  persistence?: PersistenceAdapter;
  i18n?: I18nProvider;
}

// ============================================================================
// Sessions Adapter Types [CORE]
// ============================================================================

/**
 * Chat session (snake_case, matching API and Zod schemas).
 * Re-exported from ../types.ts for convenience — the canonical
 * definition lives in ../types.ts (ChatSession interface).
 */
export type { ChatSession } from '../types';

/**
 * Chat message DTO.
 */
export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp?: string;
  parts?: Array<{
    type: string;
    text?: string;
    toolName?: string;
    toolCallId?: string;
    args?: Record<string, unknown>;
    result?: unknown;
    state?: string;
  }>;
}

/**
 * Core sessions adapter [CORE].
 * Data-fetching only, returns data via Promise.
 * Optional: when not provided, chat operates in single-session mode.
 */
export interface SessionsAdapter {
  fetchSessions(params: {
    agentBotId: number;
    limit?: number;
  }): Promise<import('../types').ChatSession[]>;
  fetchMessages(params: {
    sessionId: string;
    limit?: number;
  }): Promise<ChatMessage[]>;
  deleteSession?(sessionId: string): Promise<void>;
}
