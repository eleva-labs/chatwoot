import { ref } from 'vue';
import {
  STREAM_EVENTS,
  STREAM_HEADERS,
  STREAM_PROTOCOL_VERSION,
} from 'shared/constants/streamEnums';

/**
 * Composable for AI streaming functionality (Vercel AI SDK compatible format)
 *
 * Provides a reusable interface for streaming AI responses using Server-Sent Events (SSE).
 * Implements the standardized streaming protocol compatible with Vercel AI SDK.
 *
 * Event Types Supported:
 * - start: Stream initialization with messageId
 * - text_start/text_delta/text_end: Text content lifecycle
 * - reasoning_start/reasoning_delta/reasoning_end: Reasoning lifecycle
 * - tool-call/tool-result: Tool invocation and results
 * - finish: Stream completion with usage stats
 * - error: Error events
 * - [DONE]: Stream end marker
 *
 * @param {Object} options - Configuration options
 * @param {Function} options.getAuthHeaders - Function that returns auth headers
 * @param {Function} options.onSessionIdExtracted - Callback when session ID is extracted from headers
 * @param {Function} options.onError - Optional error handler callback
 * @param {Function} options.onStreamStart - Callback when stream starts
 * @param {Function} options.onToken - Callback for each token received
 * @param {Function} options.onStreamComplete - Callback when stream completes
 * @param {Function} options.onReasoningToken - Callback for reasoning tokens (optional)
 *
 * @returns {Object} Streaming interface
 */
export function useAIStreaming(options = {}) {
  const {
    getAuthHeaders = () => ({}),
    onSessionIdExtracted = () => {},
    onError = null,
    onStreamStart = () => {},
    onToken = () => {},
    onStreamComplete = () => {},
    onReasoningToken = () => {},
  } = options;

  // Required protocol headers
  const REQUIRED_HEADERS = {
    [STREAM_HEADERS.VERCEL_AI_UI_MESSAGE_STREAM]: STREAM_PROTOCOL_VERSION,
    [STREAM_HEADERS.AI_STREAMING_PROTOCOL]: STREAM_PROTOCOL_VERSION,
  };

  // Reactive state
  const messages = ref([]);
  const isLoading = ref(false);
  const isStreaming = ref(false);
  const error = ref(null);
  const currentToolCall = ref(null);
  const currentProgress = ref(null);
  const activeAssistantMessageId = ref(null);
  const streamBuffer = ref('');
  const streamTranscript = ref('');

  // New state for enhanced features
  const backendMessageId = ref(null);
  const currentReasoning = ref('');
  const isReasoning = ref(false);
  const usage = ref(null);

  /**
   * Sanitize stream text by removing debug markers
   * @private
   */
  const sanitizeStreamText = text => {
    if (!text) return '';
    let cleaned = text;
    const marker = 'Agent started with input:';
    if (cleaned.includes(marker)) {
      const markerIndex = cleaned.indexOf(marker);
      const closingSequence = '])';
      let endIndex = cleaned.indexOf(closingSequence, markerIndex);
      if (endIndex !== -1) {
        endIndex += closingSequence.length;
        cleaned = `${cleaned.slice(0, markerIndex)}${cleaned.slice(endIndex)}`;
      } else {
        cleaned = cleaned.slice(0, markerIndex);
      }
    }
    return cleaned.trimStart();
  };

  /**
   * Sanitize assistant raw response
   * @private
   */
  const sanitizeAssistantRaw = raw => {
    if (!raw) return '';
    if (typeof raw !== 'string') return '';
    const withoutPrefix = raw.replace(/^assistant:\s*/i, '');
    return sanitizeStreamText(withoutPrefix);
  };

  /**
   * Upsert assistant message in messages array
   * @private
   */
  const upsertAssistantMessage = (
    messageId,
    content,
    reasoningContent = null
  ) => {
    const msgIndex = messages.value.findIndex(m => m.id === messageId);
    const messageData = {
      id: messageId,
      role: 'assistant',
      content,
      timestamp: new Date().toISOString(),
    };

    // Include reasoning if present
    if (reasoningContent) {
      messageData.reasoning = reasoningContent;
    }

    if (msgIndex === -1) {
      messages.value.push(messageData);
    } else {
      messages.value[msgIndex] = {
        ...messages.value[msgIndex],
        ...messageData,
      };
    }
  };

  /**
   * Parse SSE event in standard format (Vercel AI SDK compatible)
   *
   * Standard format uses data: only with type inside JSON payload.
   * No event: field is used.
   *
   * @private
   * @param {string} eventText - Raw SSE event text
   * @returns {Object|null} Parsed event with type and data
   */
  const parseSSEEvent = eventText => {
    const lines = eventText.split(/\r?\n/);
    let result = null;

    lines.some(line => {
      if (line.startsWith('data: ')) {
        const dataStr = line.slice(6).trim();

        // Handle [DONE] marker - explicit stream end signal
        if (dataStr === '[DONE]') {
          result = { type: STREAM_EVENTS.DONE, data: null };
          return true;
        }

        try {
          const data = JSON.parse(dataStr);
          // Type is inside the JSON payload
          if (data && data.type) {
            result = { type: data.type, data };
            return true;
          }
          // If no type, return raw data for potential handling
          result = { type: 'unknown', data };
          return true;
        } catch (e) {
          // eslint-disable-next-line no-console
          console.warn(
            '[AI Streaming] Failed to parse data:',
            dataStr.substring(0, 100)
          );
          result = null;
          return true;
        }
      }
      return false;
    });

    return result;
  };

  /**
   * Validate streaming protocol headers
   * @private
   * @param {Response} response - Fetch response object
   * @throws {Error} If headers are invalid
   */
  const validateStreamingHeaders = response => {
    const vercelHeader = response.headers.get(
      STREAM_HEADERS.VERCEL_AI_UI_MESSAGE_STREAM
    );
    const protocolHeader = response.headers.get(
      STREAM_HEADERS.AI_STREAMING_PROTOCOL
    );

    if (
      vercelHeader !==
        REQUIRED_HEADERS[STREAM_HEADERS.VERCEL_AI_UI_MESSAGE_STREAM] ||
      protocolHeader !== REQUIRED_HEADERS[STREAM_HEADERS.AI_STREAMING_PROTOCOL]
    ) {
      throw new Error(
        `Invalid streaming protocol headers. Expected ${STREAM_PROTOCOL_VERSION}, got: vercel=${vercelHeader}, protocol=${protocolHeader}`
      );
    }
  };

  /**
   * Process streaming response from backend
   * Handles the standard Vercel AI SDK compatible format
   * @private
   */
  const processStreamingResponse = async (response, messageId) => {
    const reader = response.body?.getReader();
    if (!reader) {
      throw new Error('Response body is not readable');
    }

    const decoder = new TextDecoder();
    let chunkBuffer = '';
    let accumulatedText = '';
    let accumulatedReasoning = '';
    let currentTextBlockId = null;
    let currentReasoningBlockId = null;

    try {
      isStreaming.value = true;

      // eslint-disable-next-line no-constant-condition
      while (true) {
        // eslint-disable-next-line no-await-in-loop
        const { done, value } = await reader.read();

        if (done) {
          // Process any remaining data in buffer
          if (chunkBuffer.trim()) {
            const events = chunkBuffer
              .split(/\r?\n\r?\n/)
              .filter(e => e.trim().length > 0);

            // eslint-disable-next-line no-restricted-syntax
            for (let i = 0; i < events.length; i += 1) {
              const event = events[i];
              // eslint-disable-next-line no-continue
              if (!event.trim()) continue;

              const parsed = parseSSEEvent(event);
              if (parsed) {
                // eslint-disable-next-line no-use-before-define
                const eventResult = processStreamEvent(
                  parsed,
                  messageId,
                  accumulatedText,
                  accumulatedReasoning,
                  currentTextBlockId,
                  currentReasoningBlockId
                );
                if (eventResult.text !== null)
                  accumulatedText = eventResult.text;
                if (eventResult.reasoning !== null)
                  accumulatedReasoning = eventResult.reasoning;
                if (eventResult.textBlockId !== undefined)
                  currentTextBlockId = eventResult.textBlockId;
                if (eventResult.reasoningBlockId !== undefined)
                  currentReasoningBlockId = eventResult.reasoningBlockId;
                if (eventResult.done) break;
              }
            }
          }
          break;
        }

        // Decode chunk and accumulate in buffer
        const chunk = decoder.decode(value, { stream: true });
        chunkBuffer += chunk;

        // Process complete SSE events (separated by \r\n\r\n or \n\n)
        const events = chunkBuffer.split(/\r?\n\r?\n/);
        // Keep the last incomplete event in buffer
        chunkBuffer = events.pop() || '';

        // eslint-disable-next-line no-restricted-syntax
        for (let i = 0; i < events.length; i += 1) {
          const event = events[i];
          // eslint-disable-next-line no-continue
          if (!event.trim()) continue;

          const parsed = parseSSEEvent(event);
          if (parsed) {
            // eslint-disable-next-line no-use-before-define
            const eventResult = processStreamEvent(
              parsed,
              messageId,
              accumulatedText,
              accumulatedReasoning,
              currentTextBlockId,
              currentReasoningBlockId
            );
            if (eventResult.text !== null) accumulatedText = eventResult.text;
            if (eventResult.reasoning !== null)
              accumulatedReasoning = eventResult.reasoning;
            if (eventResult.textBlockId !== undefined)
              currentTextBlockId = eventResult.textBlockId;
            if (eventResult.reasoningBlockId !== undefined)
              currentReasoningBlockId = eventResult.reasoningBlockId;
            if (eventResult.done) break;
          }
        }
      }
    } finally {
      isStreaming.value = false;
      isReasoning.value = false;
      currentToolCall.value = null;
      currentProgress.value = null;
      activeAssistantMessageId.value = null;
      streamBuffer.value = '';
    }
  };

  /**
   * Process individual stream event (new standardized format)
   * @private
   * @returns {Object} Updated state
   */
  const processStreamEvent = (
    parsed,
    messageId,
    accumulatedText,
    accumulatedReasoning,
    currentTextBlockId,
    currentReasoningBlockId
  ) => {
    const { type, data: eventData } = parsed;
    const result = {
      text: null,
      reasoning: null,
      textBlockId: undefined,
      reasoningBlockId: undefined,
      done: false,
    };

    // Handle [DONE] marker - explicit stream end
    if (type === STREAM_EVENTS.DONE) {
      result.done = true;
      return result;
    }

    // Handle start event - extract messageId
    if (type === STREAM_EVENTS.START) {
      backendMessageId.value = eventData.messageId || null;
      onStreamStart(messageId, eventData.messageId);
      return result;
    }

    // Handle text lifecycle events
    if (type === STREAM_EVENTS.TEXT_START) {
      result.textBlockId = eventData.id;
      result.text = '';
      return result;
    }

    if (type === STREAM_EVENTS.TEXT_DELTA) {
      // Only process if we have an active text block and IDs match
      if (currentTextBlockId && eventData.id !== currentTextBlockId) {
        return result;
      }

      const delta = eventData.delta || '';

      // Skip debug deltas
      if (
        delta.includes('Agent started with input') ||
        delta.includes('ChatMessage(')
      ) {
        return result;
      }

      const newText = accumulatedText + delta;
      streamBuffer.value = newText;
      streamTranscript.value = sanitizeStreamText(newText);

      onToken({
        delta,
        accumulatedText: newText,
        messageId,
      });

      result.text = newText;
      return result;
    }

    if (type === STREAM_EVENTS.TEXT_END) {
      // Finalize text block
      if (accumulatedText) {
        upsertAssistantMessage(
          messageId,
          sanitizeStreamText(accumulatedText),
          accumulatedReasoning || null
        );
      }
      result.textBlockId = null;
      return result;
    }

    // Handle reasoning lifecycle events
    if (type === STREAM_EVENTS.REASONING_START) {
      isReasoning.value = true;
      result.reasoningBlockId = eventData.id;
      result.reasoning = '';
      return result;
    }

    if (type === STREAM_EVENTS.REASONING_DELTA) {
      // Only process if we have an active reasoning block and IDs match
      if (currentReasoningBlockId && eventData.id !== currentReasoningBlockId) {
        return result;
      }

      const delta = eventData.delta || '';
      const newReasoning = accumulatedReasoning + delta;
      currentReasoning.value = newReasoning;

      onReasoningToken({
        delta,
        accumulatedReasoning: newReasoning,
        messageId,
      });

      result.reasoning = newReasoning;
      return result;
    }

    if (type === STREAM_EVENTS.REASONING_END) {
      isReasoning.value = false;
      result.reasoningBlockId = null;
      return result;
    }

    // Handle tool events (standardized format)
    if (type === STREAM_EVENTS.TOOL_CALL) {
      currentToolCall.value = {
        name: eventData.toolName,
        arguments: eventData.args,
        toolCallId: eventData.toolCallId || null,
      };
      return result;
    }

    if (type === STREAM_EVENTS.TOOL_RESULT) {
      // Store result if needed for display
      const toolResult = {
        name: eventData.toolName,
        result: eventData.result,
        isError: eventData.isError || false,
        toolCallId: eventData.toolCallId || null,
      };

      // Handle tool error
      if (toolResult.isError && onError) {
        onError(new Error(`Tool error: ${eventData.result}`));
      }

      currentToolCall.value = null;
      return result;
    }

    // Handle step events (for progress indicators)
    if (type === STREAM_EVENTS.START_STEP) {
      currentProgress.value = eventData.messageId || 'Processing...';
      return result;
    }

    if (type === STREAM_EVENTS.FINISH_STEP) {
      currentProgress.value = null;
      return result;
    }

    // Handle finish event - extract usage stats
    if (type === STREAM_EVENTS.FINISH) {
      // Extract usage statistics
      if (eventData.usage) {
        usage.value = {
          promptTokens: eventData.usage.promptTokens || 0,
          completionTokens: eventData.usage.completionTokens || 0,
          totalTokens:
            (eventData.usage.promptTokens || 0) +
            (eventData.usage.completionTokens || 0),
        };
      }

      // Finalize message if not already done
      const finalText =
        sanitizeStreamText(accumulatedText) ||
        sanitizeAssistantRaw(streamBuffer.value);
      if (finalText) {
        upsertAssistantMessage(
          messageId,
          finalText,
          accumulatedReasoning || null
        );
        streamTranscript.value = finalText;
      }

      onStreamComplete({
        messageId,
        backendMessageId: backendMessageId.value,
        finalText,
        reasoning: accumulatedReasoning || null,
        usage: usage.value,
        finishReason: eventData.finishReason || 'stop',
      });

      activeAssistantMessageId.value = null;
      return result;
    }

    // Handle error event (standardized format)
    if (type === STREAM_EVENTS.ERROR) {
      const errorMessage =
        eventData.errorText ||
        eventData.error ||
        'An error occurred during streaming';
      const errorCode = eventData.errorCode || null;
      const retryAfter = eventData.retryAfter || null;

      error.value = errorMessage;

      if (onError) {
        const err = new Error(errorMessage);
        err.code = errorCode;
        err.retryAfter = retryAfter;
        onError(err);
      }

      return result;
    }

    return result;
  };

  /**
   * Send a message with streaming support
   *
   * @param {Object} params
   * @param {String} params.url - Streaming endpoint URL
   * @param {Object} params.body - Request body
   * @param {Boolean} params.fallbackToNonStreaming - If true, fallback to non-streaming on error
   * @returns {Promise<Object>} Result with success status and session ID
   */
  const sendMessage = async ({ url, body, fallbackToNonStreaming = true }) => {
    const userMessage = body.messages?.[0]?.content || body.messages?.[0];

    // Add user message to UI immediately
    const userMessageObj = {
      id: Date.now(),
      role: 'user',
      content:
        typeof userMessage === 'string' ? userMessage : userMessage.content,
      timestamp: new Date().toISOString(),
    };
    messages.value.push(userMessageObj);

    const assistantMessageId = Date.now() + 1;

    // Reset state
    isLoading.value = true;
    error.value = null;
    activeAssistantMessageId.value = assistantMessageId;
    streamBuffer.value = '';
    streamTranscript.value = '';
    backendMessageId.value = null;
    currentReasoning.value = '';
    isReasoning.value = false;
    usage.value = null;

    try {
      // Attempt streaming
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          ...getAuthHeaders(),
          Accept: 'text/event-stream',
        },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        throw new Error(`Stream request failed: ${response.statusText}`);
      }

      // Validate streaming protocol headers
      validateStreamingHeaders(response);

      // Extract session ID from headers
      const sessionId = response.headers.get(STREAM_HEADERS.CHAT_SESSION_ID);
      if (sessionId) {
        onSessionIdExtracted(sessionId);
      }

      // Process the stream
      await processStreamingResponse(response, assistantMessageId);

      streamBuffer.value = '';

      return {
        success: true,
        sessionId,
        backendMessageId: backendMessageId.value,
        usage: usage.value,
      };
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[AI Streaming] Error:', err);

      // Fallback to non-streaming if enabled
      if (fallbackToNonStreaming) {
        // eslint-disable-next-line no-console
        console.log('[AI Streaming] Falling back to non-streaming API');

        try {
          const nonStreamUrl = url.replace('/stream', '');
          const nonStreamResponse = await fetch(nonStreamUrl, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: JSON.stringify(body),
          });

          if (!nonStreamResponse.ok) {
            throw new Error('Failed to get AI response');
          }

          const data = await nonStreamResponse.json();

          // Update the assistant message with the response
          const sanitizedResponse = sanitizeAssistantRaw(data.response);
          upsertAssistantMessage(
            assistantMessageId,
            sanitizedResponse || data.response
          );

          streamBuffer.value = data.response || '';
          streamTranscript.value = sanitizedResponse || streamTranscript.value;
          activeAssistantMessageId.value = null;
          onStreamComplete({
            messageId: assistantMessageId,
            finalText: sanitizedResponse || streamTranscript.value,
          });

          return {
            success: true,
            sessionId: data.session_id,
          };
        } catch (fallbackErr) {
          // eslint-disable-next-line no-console
          console.error('[AI Streaming] Fallback also failed:', fallbackErr);
          error.value = fallbackErr.message || 'Failed to send message';

          // Update assistant message with error
          upsertAssistantMessage(
            assistantMessageId,
            'Sorry, I encountered an error. Please try again.'
          );

          streamBuffer.value = '';
          streamTranscript.value = '';
          activeAssistantMessageId.value = null;

          if (onError) {
            onError(fallbackErr);
          }

          return {
            success: false,
            error: fallbackErr.message,
          };
        }
      } else {
        error.value = err.message || 'Failed to send message';

        // Update assistant message with error
        upsertAssistantMessage(
          assistantMessageId,
          'Sorry, I encountered an error. Please try again.'
        );

        streamBuffer.value = '';
        streamTranscript.value = '';
        activeAssistantMessageId.value = null;

        if (onError) {
          onError(err);
        }

        return {
          success: false,
          error: err.message,
        };
      }
    } finally {
      isLoading.value = false;
    }
  };

  /**
   * Replace current messages
   */
  const setMessages = newMessages => {
    messages.value = [...newMessages];
  };

  /**
   * Clear error state
   */
  const clearError = () => {
    error.value = null;
  };

  /**
   * Clear all state (useful for new conversations)
   */
  const clear = () => {
    messages.value = [];
    error.value = null;
    currentToolCall.value = null;
    currentProgress.value = null;
    activeAssistantMessageId.value = null;
    streamBuffer.value = '';
    streamTranscript.value = '';
    backendMessageId.value = null;
    currentReasoning.value = '';
    isReasoning.value = false;
    usage.value = null;
  };

  return {
    // Reactive state
    messages,
    isLoading,
    isStreaming,
    error,
    currentToolCall,
    currentProgress,
    activeAssistantMessageId,
    streamBuffer,
    streamTranscript,

    // New enhanced state
    backendMessageId,
    currentReasoning,
    isReasoning,
    usage,

    // Methods
    sendMessage,
    setMessages,
    clearError,
    clear,
  };
}
