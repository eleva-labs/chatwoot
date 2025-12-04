import { Chat } from '@ai-sdk/vue';
import { DefaultChatTransport } from 'ai';
import { ref, onUnmounted, getCurrentInstance } from 'vue';
import Auth from 'dashboard/api/auth';
import { CHAT_STATUS } from '../constants';

/**
 * Extract text content from UIMessage parts.
 * UIMessages use parts[] array with type='text' items.
 *
 * @param {Object} message - UIMessage object
 * @returns {string} Combined text content
 */
function extractTextContent(message) {
  if (message.parts && Array.isArray(message.parts)) {
    return message.parts
      .filter(part => part.type === 'text')
      .map(part => part.text)
      .join('');
  }
  return message.content || '';
}

/**
 * Get authentication headers for API requests.
 * Uses Chatwoot's standard Devise token authentication.
 *
 * @returns {Object} Headers object with auth tokens
 */
function getAuthHeaders() {
  if (!Auth.hasAuthCookie()) {
    return { 'Content-Type': 'application/json' };
  }

  const authData = Auth.getAuthData();
  return {
    'Content-Type': 'application/json',
    'access-token': authData['access-token'],
    'token-type': authData['token-type'],
    client: authData.client,
    expiry: authData.expiry,
    uid: authData.uid,
  };
}

/**
 * Create a Vercel AI SDK Chat instance configured for Chatwoot.
 *
 * Uses the SDK's native DefaultChatTransport with custom configuration
 * for authentication, request body format, and session ID extraction.
 *
 * @param {Object} options - Configuration options
 * @param {string} options.api - API endpoint URL
 * @param {Function} [options.getAuthHeaders] - DEPRECATED: Auth headers are now handled internally
 * @param {Object|Function} options.body - Additional body params or function returning them
 * @param {Function} [options.onSessionId] - Callback with session ID from response headers
 * @param {Function} [options.onFinish] - Callback when stream finishes
 * @param {Function} [options.onError] - Callback on error
 * @returns {Chat} Vercel AI SDK Chat instance
 *
 * @example
 * const chat = useVercelChat({
 *   api: `/api/v1/accounts/${accountId}/ai_chat/stream`,
 *   body: () => ({
 *     agent_bot_id: selectedBotId.value,
 *     chat_session_id: sessionId.value,
 *   }),
 *   onSessionId: (id) => { sessionId.value = id; },
 *   onFinish: (result) => console.log('Done:', result),
 * });
 *
 * // Send a message
 * await chat.sendMessage({ text: 'Hello!' });
 *
 * // Access reactive state
 * chat.messages  // UIMessage[]
 * chat.status    // 'ready' | 'submitted' | 'streaming' | 'error'
 */
export function useVercelChat(options) {
  const { api, body, onSessionId, onFinish, onError } = options;

  const transport = new DefaultChatTransport({
    api,
    headers: getAuthHeaders,

    // Transform UIMessage[] to Chatwoot backend format
    prepareSendMessagesRequest: async ({ messages, headers }) => {
      const lastMessage = messages[messages.length - 1];
      const dynamicBody = typeof body === 'function' ? body() : body || {};

      return {
        body: {
          messages: [
            {
              role: lastMessage.role,
              content: extractTextContent(lastMessage),
            },
          ],
          ...dynamicBody,
        },
        headers,
      };
    },

    // Custom fetch to extract session ID from response headers
    fetch: async (url, fetchOptions) => {
      const response = await window.fetch(url, fetchOptions);

      // Extract session ID from response headers
      const sessionId = response.headers.get('X-Chat-Session-Id');
      if (sessionId && onSessionId) {
        onSessionId(sessionId);
      }

      return response;
    },
  });

  const chat = new Chat({
    transport,
    onFinish,
    onError,
  });

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

  const messages = ref([]);
  const status = ref(CHAT_STATUS.READY);
  const error = ref(null);
  let pollInterval = null;
  let isPolling = false;

  const syncState = () => {
    // Deep clone to ensure Vue detects changes in nested parts
    messages.value = JSON.parse(JSON.stringify(chat.messages));
    status.value = chat.status;
    error.value = chat.error;
  };

  const startPolling = () => {
    if (isPolling) return;
    isPolling = true;

    // Track consecutive idle checks to avoid stopping too early
    let idleChecks = 0;
    const MAX_IDLE_CHECKS = 5; // Allow ~250ms for status to change

    const poll = () => {
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

  const stopPolling = () => {
    isPolling = false;
    if (pollInterval) {
      clearTimeout(pollInterval);
      pollInterval = null;
    }
  };

  const dispose = () => {
    stopPolling();
  };

  // Auto-cleanup when used in a Vue component
  if (getCurrentInstance()) {
    onUnmounted(dispose);
  }

  // Wrap sendMessage to start polling when a message is sent
  const sendMessage = async (...args) => {
    startPolling();
    return chat.sendMessage(...args);
  };

  // Wrap regenerate to start polling
  const regenerate = chat.regenerate
    ? async (...args) => {
        startPolling();
        return chat.regenerate(...args);
      }
    : undefined;

  return {
    // Reactive state (refs for Vue reactivity when passed as props)
    messages,
    status,
    error,

    // Methods
    sendMessage,
    setMessages: msgs => {
      chat.messages = msgs; // Use setter, not method
      syncState();
    },
    clearError: () => {
      if (chat.clearError) chat.clearError();
      syncState();
    },
    regenerate,

    // Manual cleanup (for non-component usage)
    dispose,
  };
}

export default useVercelChat;
