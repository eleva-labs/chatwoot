/**
 * useAiChat.ts
 *
 * Composable wrapping the Vercel AI SDK Chat class.
 * Accepts a TransportConfig + ChatBehaviorConfig to decouple from
 * Chatwoot-specific transport/auth concerns.
 *
 * All Chatwoot-specific logic (auth headers, API paths, request body shape)
 * is injected via the config — see chatwootChatConfig.ts.
 */

import { Chat } from '@ai-sdk/vue';
import { DefaultChatTransport } from 'ai';
import type { UIMessage } from 'ai';
import { ref, onUnmounted, getCurrentInstance, type Ref } from 'vue';
import { CHAT_STATUS, type ChatStatus } from '../constants';
import type {
  TransportConfig,
  ChatBehaviorConfig,
} from '../types/chatConfig';

/**
 * Extract text content from UIMessage parts.
 * Used as default request body builder when TransportConfig.prepareRequest is not provided.
 */
function extractTextContent(message: {
  parts?: Array<{ type: string; text?: string }>;
  content?: string;
}): string {
  if (message.parts && Array.isArray(message.parts)) {
    return message.parts
      .filter(part => part.type === 'text')
      .map(part => part.text)
      .join('');
  }
  return message.content || '';
}

export interface AiChatCallbacks {
  onSessionId?: (sessionId: string) => void;
  onFinish?: (result: unknown) => void;
  onError?: (error: Error) => void;
}

interface AiChatReturn {
  messages: Ref<UIMessage[]>;
  status: Ref<ChatStatus>;
  error: Ref<Error | null>;
  sendMessage: (...args: unknown[]) => Promise<void>;
  setMessages: (msgs: UIMessage[]) => void;
  clearError: () => void;
  regenerate: ((...args: unknown[]) => Promise<void>) | undefined;
  addToolOutput: (opts: {
    tool: string;
    toolCallId: string;
    output?: unknown;
    state?: 'output-error';
    errorText?: string;
  }) => Promise<void>;
  dispose: () => void;
}

/**
 * Create a Vercel AI SDK Chat instance from a TransportConfig.
 *
 * Uses the SDK's native DefaultChatTransport with configuration
 * injected via interfaces — no hardcoded Chatwoot endpoints or auth.
 */
export function useAiChat(
  transportConfig: TransportConfig,
  behaviorConfig?: ChatBehaviorConfig,
  callbacks?: AiChatCallbacks,
): AiChatReturn {
  const { onSessionId, onFinish, onError } = callbacks || {};

  // Resolve the stream endpoint (can be a string or factory function)
  const api =
    typeof transportConfig.streamEndpoint === 'function'
      ? transportConfig.streamEndpoint()
      : transportConfig.streamEndpoint;

  const transport = new DefaultChatTransport({
    api,
    headers: transportConfig.getHeaders,

    // Transform UIMessage[] to backend format via config or fallback
    prepareSendMessagesRequest: async ({
      messages,
      headers,
    }: {
      messages: Array<{
        role: string;
        parts?: Array<{ type: string; text?: string }>;
        content?: string;
      }>;
      headers: Record<string, string>;
    }) => {
      const lastMessage = messages[messages.length - 1];

      // If the config provides a prepareRequest function, delegate to it
      if (transportConfig.prepareRequest) {
        return transportConfig.prepareRequest({
          messages: messages as unknown as UIMessage[],
          lastMessage: lastMessage as unknown as UIMessage,
          headers,
          metadata: {},
        });
      }

      // Default: send only the last message's text content
      return {
        body: {
          messages: [
            {
              role: lastMessage.role,
              content: extractTextContent(lastMessage),
            },
          ],
        },
        headers,
      };
    },

    // Custom fetch for session ID extraction and optional fetch override
    fetch: async (url: string | URL | Request, fetchOptions?: RequestInit) => {
      const fetchFn = transportConfig.fetch || window.fetch;
      const response = await fetchFn(url, fetchOptions);

      // Extract session ID using config's extractor (or skip)
      if (transportConfig.extractSessionId && onSessionId) {
        const sessionId = transportConfig.extractSessionId(response);
        if (sessionId) {
          onSessionId(sessionId);
        }
      }

      return response;
    },
  });

  const chatInit: Record<string, unknown> = {
    transport,
    onFinish,
    onError,
  };

  if (behaviorConfig?.sendAutomaticallyWhen) {
    chatInit.sendAutomaticallyWhen = behaviorConfig.sendAutomaticallyWhen;
  }

  const chat = new Chat(chatInit);

  // ============================================================================
  // REACTIVITY WORKAROUND
  // ============================================================================
  // The Vercel AI SDK's Chat class mutates message.parts[] in place during
  // streaming without triggering Vue reactivity. The SDK's VueChatState uses
  // internal refs but only exposes unwrapped values via getters.
  //
  // To ensure Vue components re-render during streaming, we:
  // 1. Poll for state changes during active streaming
  // 2. Deep clone messages to create new object references
  // 3. Stop polling when streaming completes to avoid unnecessary overhead
  //
  // See: https://github.com/vercel/ai/discussions/7510
  // ============================================================================

  const messages = ref<UIMessage[]>([]);
  const status = ref<ChatStatus>(CHAT_STATUS.READY);
  const error = ref<Error | null>(null);
  let pollInterval: ReturnType<typeof setTimeout> | null = null;
  let isPolling = false;

  const syncState = (): void => {
    // Deep clone to ensure Vue detects changes in nested parts
    messages.value = structuredClone(chat.messages);
    status.value = chat.status as ChatStatus;
    error.value = chat.error ?? null;
  };

  const startPolling = (): void => {
    if (isPolling) return;
    isPolling = true;

    // Track consecutive idle checks to avoid stopping too early
    let idleChecks = 0;
    const MAX_IDLE_CHECKS = 5; // Allow ~250ms for status to change

    const poll = (): void => {
      if (!isPolling) return;

      syncState();

      // Check if we should continue polling
      const currentStatus = chat.status;
      const isActive =
        currentStatus === CHAT_STATUS.STREAMING ||
        currentStatus === CHAT_STATUS.SUBMITTED;

      if (isActive) {
        idleChecks = 0; // Reset idle counter when active
        pollInterval = setTimeout(poll, 50);
      } else if (idleChecks < MAX_IDLE_CHECKS) {
        // Give time for status to change after sendMessage
        idleChecks += 1;
        pollInterval = setTimeout(poll, 50);
      } else {
        // Streaming finished, do final sync and stop
        isPolling = false;
        pollInterval = null;
      }
    };

    poll();
  };

  const stopPolling = (): void => {
    isPolling = false;
    if (pollInterval) {
      clearTimeout(pollInterval);
      pollInterval = null;
    }
  };

  const dispose = (): void => {
    stopPolling();
  };

  // Auto-cleanup when used in a Vue component
  if (getCurrentInstance()) {
    onUnmounted(dispose);
  }

  // Wrap sendMessage to start polling when a message is sent
  const sendMessage = async (...args: unknown[]): Promise<void> => {
    startPolling();
    return (chat.sendMessage as (...a: unknown[]) => Promise<void>)(...args);
  };

  // Wrap regenerate to start polling
  const regenerate = chat.regenerate
    ? async (...args: unknown[]): Promise<void> => {
        startPolling();
        return (chat.regenerate as (...a: unknown[]) => Promise<void>)(
          ...args,
        );
      }
    : undefined;

  // Expose addToolOutput from the Chat instance
  const addToolOutput = async (opts: {
    tool: string;
    toolCallId: string;
    output?: unknown;
    state?: 'output-error';
    errorText?: string;
  }): Promise<void> => {
    startPolling();
    return (chat.addToolOutput as (o: unknown) => Promise<void>)(opts);
  };

  return {
    // Reactive state (refs for Vue reactivity when passed as props)
    messages,
    status,
    error,

    // Methods
    sendMessage,
    setMessages: (msgs: UIMessage[]): void => {
      chat.messages = msgs; // Use setter, not method
      syncState();
    },
    clearError: (): void => {
      if (chat.clearError) chat.clearError();
      syncState();
    },
    regenerate,
    addToolOutput,

    // Manual cleanup (for non-component usage)
    dispose,
  };
}

export default useAiChat;
