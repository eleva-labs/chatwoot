import { ref } from 'vue';

/**
 * Composable for AI streaming functionality
 *
 * Provides a reusable interface for streaming AI responses using Server-Sent Events (SSE).
 * Handles backend SSE parsing, state management, and streaming indicators.
 *
 * @param {Object} options - Configuration options
 * @param {Function} options.getAuthHeaders - Function that returns auth headers
 * @param {Function} options.onSessionIdExtracted - Callback when session ID is extracted from headers
 * @param {Function} options.onError - Optional error handler callback
 *
 * @returns {Object} Streaming interface
 * @returns {Ref<Array>} messages - Array of chat messages
 * @returns {Ref<Boolean>} isLoading - Loading state
 * @returns {Ref<Boolean>} isStreaming - Active streaming state
 * @returns {Ref<String|null>} error - Error message if any
 * @returns {Ref<Object|null>} currentToolCall - Current tool being called
 * @returns {Ref<String|null>} currentProgress - Current progress message
 * @returns {Function} sendMessage - Send a message with streaming
 * @returns {Function} setMessages - Replace current messages
 * @returns {Function} clearError - Clear error state
 *
 * @example
 * ```js
 * import { useAIStreaming } from 'dashboard/composables/useAIStreaming';
 *
 * const {
 *   messages,
 *   isLoading,
 *   isStreaming,
 *   sendMessage,
 * } = useAIStreaming({
 *   getAuthHeaders: () => ({ 'Authorization': 'Bearer token' }),
 *   onSessionIdExtracted: (sessionId) => { console.log('Session:', sessionId) },
 * });
 *
 * // Send a streaming message
 * await sendMessage({
 *   url: '/api/v1/accounts/123/ai_chat/stream',
 *   body: { messages: [{ role: 'user', content: 'Hello' }], agent_bot_id: 1 },
 * });
 * ```
 */
export function useAIStreaming(options = {}) {
  const {
    getAuthHeaders = () => ({}),
    onSessionIdExtracted = () => {},
    onError = null,
    onStreamStart = () => {},
    onToken = () => {},
    onStreamComplete = () => {},
  } = options;

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

  const sanitizeAssistantRaw = raw => {
    if (!raw) return '';
    if (typeof raw !== 'string') return '';
    const withoutPrefix = raw.replace(/^assistant:\s*/i, '');
    return sanitizeStreamText(withoutPrefix);
  };

  const upsertAssistantMessage = (messageId, content) => {
    const msgIndex = messages.value.findIndex(m => m.id === messageId);
    if (msgIndex === -1) {
      messages.value.push({
        id: messageId,
        role: 'assistant',
        content,
        timestamp: new Date().toISOString(),
      });
    } else {
      messages.value[msgIndex] = {
        ...messages.value[msgIndex],
        content,
      };
    }
  };

  /**
   * Parse SSE event format (event: type\ndata: {...})
   * @private
   */
  const parseSSEEvent = eventText => {
    let eventType = null;
    let data = null;

    // Handle both \r\n and \n line endings
    const lines = eventText.split(/\r?\n/);
    // eslint-disable-next-line no-restricted-syntax
    for (const line of lines) {
      if (line.startsWith('event: ')) {
        eventType = line.slice(7).trim();
      } else if (line.startsWith('data: ')) {
        const dataStr = line.slice(6);
        try {
          data = JSON.parse(dataStr);
        } catch (e) {
          // eslint-disable-next-line no-console
          console.warn(
            '[AI Streaming] Failed to parse data:',
            dataStr.substring(0, 100)
          );
        }
      }
    }

    return eventType && data ? { eventType, data } : null;
  };

  /**
   * Process individual stream event
   * @private
   * @returns {String|null} Updated accumulated text or null
   */
  const processStreamEvent = (parsed, messageId, accumulatedText) => {
    const { eventType, data } = parsed;

    // Handle token events - update message content incrementally
    if (eventType === 'token' && data.delta) {
      const rawDelta = data.delta;
      const isDebugDelta =
        typeof rawDelta === 'string' &&
        (rawDelta.includes('Agent started with input') ||
          rawDelta.includes('ChatMessage('));
      if (isDebugDelta) {
        return accumulatedText;
      }

      const newText = accumulatedText + rawDelta;
      streamBuffer.value = newText;
      streamTranscript.value = sanitizeStreamText(newText);
      onToken({
        delta: rawDelta,
        accumulatedText: newText,
        messageId,
      });

      return newText;
    }

    // Handle tool call events
    if (eventType === 'tool_call') {
      currentToolCall.value = {
        name: data.tool_name,
        arguments: data.arguments,
      };
    }

    // Handle tool result events
    if (eventType === 'tool_result') {
      currentToolCall.value = null;
    }

    // Handle progress events
    if (eventType === 'progress') {
      const progressMessage = data.message || data.status;
      // Ignore verbose diagnostic progress messages
      if (
        progressMessage &&
        progressMessage.includes('Agent started with input')
      ) {
        return accumulatedText;
      }
      currentProgress.value = progressMessage;
    }

    // Handle error events
    if (eventType === 'error') {
      error.value = data.error_message || 'An error occurred during streaming';
      if (onError) {
        onError(new Error(error.value));
      }
    }

    // Handle complete events
    if (eventType === 'complete') {
      // Extract final text from various possible locations
      const finalTextCandidate =
        data.text_response ||
        data.result?.text_response ||
        data.final_output?.text ||
        data.final_state?.agent_response ||
        data.step_results?.[0]?.result?.text_response ||
        null;
      const sanitizedFinalCandidate = sanitizeAssistantRaw(finalTextCandidate);
      const sanitizedRawResponse = sanitizeAssistantRaw(
        data.metadata?.raw_response
      );
      const bufferFallback = sanitizeAssistantRaw(streamBuffer.value);
      const finalText =
        sanitizedFinalCandidate || sanitizedRawResponse || bufferFallback;

      // eslint-disable-next-line no-console
      console.log('[AI Streaming] Complete - candidates:', {
        sanitizedFinalCandidate: sanitizedFinalCandidate?.substring(0, 50),
        sanitizedRawResponse: sanitizedRawResponse?.substring(0, 50),
        bufferFallback: bufferFallback?.substring(0, 50),
        finalText: finalText?.substring(0, 50),
      });

      if (finalText) {
        // eslint-disable-next-line no-console
        console.log(
          '[AI Streaming] Complete event - extracted text:',
          finalText.substring(0, 100)
        );

        upsertAssistantMessage(messageId, finalText);
        streamBuffer.value = finalTextCandidate || finalText;
        if (!streamTranscript.value.trim()) {
          streamTranscript.value = finalText;
        }
        activeAssistantMessageId.value = null;
        // eslint-disable-next-line no-console
        console.log(
          '[AI Streaming] streamTranscript set to:',
          streamTranscript.value?.substring(0, 100)
        );
        return finalText;
      }
      // eslint-disable-next-line no-console
      console.log(
        '[AI Streaming] Complete event but no text found in data:',
        data
      );
    }

    return null;
  };

  /**
   * Process streaming response from backend
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

    try {
      isStreaming.value = true;
      // eslint-disable-next-line no-console
      console.log('[AI Streaming] isStreaming set to true');

      // eslint-disable-next-line no-constant-condition
      while (true) {
        // eslint-disable-next-line no-await-in-loop
        const { done, value } = await reader.read();

        if (done) {
          // eslint-disable-next-line no-console
          console.log(
            '[AI Streaming] Stream complete. Final buffer length:',
            chunkBuffer.length
          );
          // eslint-disable-next-line no-console
          console.log('[AI Streaming] Final buffer content:', chunkBuffer);

          // Process any remaining data in buffer
          if (chunkBuffer.trim()) {
            // Split by SSE event separator (handle both \r\n\r\n and \n\n)
            // Backend sends \r\n\r\n (Windows-style line endings)
            const events = chunkBuffer
              .split(/\r?\n\r?\n/)
              .filter(e => e.trim().length > 0);

            // eslint-disable-next-line no-console
            console.log(
              '[AI Streaming] Processing',
              events.length,
              'events from final buffer'
            );
            // eslint-disable-next-line no-console
            console.log(
              '[AI Streaming] Event lengths:',
              events.map(e => e.length)
            );

            // Process ALL events (not just the last one)
            for (let index = 0; index < events.length; index += 1) {
              const event = events[index];
              if (!event.trim()) {
                // Skip empty events
                // eslint-disable-next-line no-continue
                continue;
              }

              // eslint-disable-next-line no-console
              console.log(
                `[AI Streaming] Parsing event ${index + 1}/${events.length}, length: ${event.length}`
              );

              const parsed = parseSSEEvent(event);
              if (parsed) {
                // eslint-disable-next-line no-console
                console.log(
                  '[AI Streaming] Final buffer event:',
                  parsed.eventType,
                  'Has data:',
                  !!parsed.data
                );

                const newText = processStreamEvent(
                  parsed,
                  messageId,
                  accumulatedText
                );
                if (newText !== null) {
                  accumulatedText = newText;
                  // eslint-disable-next-line no-console
                  console.log(
                    '[AI Streaming] Final accumulated text length:',
                    newText.length,
                    'Text preview:',
                    newText.substring(0, 50)
                  );
                }
              } else {
                // eslint-disable-next-line no-console
                console.warn(
                  '[AI Streaming] Failed to parse event:',
                  event.substring(0, 200)
                );
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

        for (let eventIndex = 0; eventIndex < events.length; eventIndex += 1) {
          const event = events[eventIndex];
          if (!event.trim()) {
            // eslint-disable-next-line no-continue
            continue;
          }

          const parsed = parseSSEEvent(event);
          if (parsed) {
            // eslint-disable-next-line no-console
            console.log(
              '[AI Streaming] Event:',
              parsed.eventType,
              'Data:',
              parsed.data
            );

            const newText = processStreamEvent(
              parsed,
              messageId,
              accumulatedText
            );
            if (newText !== null) {
              accumulatedText = newText;
              // eslint-disable-next-line no-console
              console.log(
                '[AI Streaming] Accumulated text length:',
                newText.length
              );
            }
          }
        }
      }
    } finally {
      isStreaming.value = false;
      currentToolCall.value = null;
      currentProgress.value = null;
      activeAssistantMessageId.value = null;
      streamBuffer.value = '';
    }
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
    // eslint-disable-next-line no-console
    console.log('[AI Streaming] sendMessage called', { url, body });

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

    isLoading.value = true;
    error.value = null;
    activeAssistantMessageId.value = assistantMessageId;
    streamBuffer.value = '';
    streamTranscript.value = '';

    // eslint-disable-next-line no-console
    console.log('[AI Streaming] Starting stream request to:', url);

    try {
      // Attempt streaming first
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          ...getAuthHeaders(),
          Accept: 'text/event-stream',
        },
        body: JSON.stringify(body),
      });

      // eslint-disable-next-line no-console
      console.log(
        '[AI Streaming] Response status:',
        response.status,
        response.statusText
      );

      if (!response.ok) {
        throw new Error(`Stream request failed: ${response.statusText}`);
      }

      // Extract session ID from headers
      const sessionId = response.headers.get('X-Chat-Session-Id');
      if (sessionId) {
        // eslint-disable-next-line no-console
        console.log('[AI Streaming] Session ID extracted:', sessionId);
        onSessionIdExtracted(sessionId);
      }

      // eslint-disable-next-line no-console
      console.log('[AI Streaming] Starting stream processing...');

      onStreamStart(assistantMessageId);

      // Process the stream
      await processStreamingResponse(response, assistantMessageId);

      const finalOutput = sanitizeStreamText(
        streamTranscript.value || streamBuffer.value
      );
      onStreamComplete({
        messageId: assistantMessageId,
        finalText: finalOutput,
      });
      streamBuffer.value = '';

      return {
        success: true,
        sessionId,
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

    // Methods
    sendMessage,
    setMessages,
    clearError,
    clear,
  };
}
