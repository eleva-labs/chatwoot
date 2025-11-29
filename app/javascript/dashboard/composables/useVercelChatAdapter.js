/* eslint-disable no-use-before-define, no-restricted-syntax */
import { Chat } from '@ai-sdk/vue';

/**
 * Custom transport adapter for Vercel AI SDK
 *
 * Transforms our backend's snake_case event format to AI SDK 5's kebab-case format.
 * This allows using the official @ai-sdk/vue Chat class without backend changes.
 *
 * @module useVercelChatAdapter
 */

/**
 * Event type mapping: snake_case → kebab-case
 * Maps our backend event types to Vercel AI SDK 5 expected format
 * @deprecated Reserved for future use when backend fully supports kebab-case
 */
// eslint-disable-next-line no-unused-vars
const EVENT_TYPE_MAP = {
  // Text events
  text_start: 'text-start',
  text_delta: 'text-delta',
  text_end: 'text-end',

  // Reasoning events
  reasoning_start: 'reasoning-start',
  reasoning_delta: 'reasoning-delta',
  reasoning_end: 'reasoning-end',

  // Tool events - map our 2-state to 4-state model
  'tool-call': 'tool-input-available',
  'tool-result': 'tool-output-available',

  // Step events (already kebab-case)
  'start-step': 'start-step',
  'finish-step': 'finish-step',

  // Lifecycle events (no change needed)
  start: 'start',
  finish: 'finish',
  error: 'error',
};

/**
 * Transform SSE event to AI SDK UI Message Stream format
 *
 * AI SDK UI Message Stream uses JSON objects with type field:
 * - {"type":"text-start","id":"msg-1"}
 * - {"type":"text-delta","id":"msg-1","delta":"Hello"}
 * - {"type":"text-end","id":"msg-1"}
 * - {"type":"error","errorText":"..."}
 *
 * NOTE: We do NOT generate text-end here. The stream wrapper handles that
 * when the HTTP stream closes (done=true). This is important because the
 * backend may have multiple steps, each with their own complete events.
 *
 * @param {string} sseData - JSON data from SSE event
 * @param {string} eventName - SSE event name (from "event:" line)
 * @param {string} messageId - Current message ID for correlation
 * @returns {Array<Object>} Array of UI Message Stream chunks
 */
function transformToUIMessageFormat(sseData, messageId, eventName = '') {
  try {
    // Guard against empty or whitespace-only data
    if (!sseData || !sseData.trim()) {
      return [];
    }

    const parsed = JSON.parse(sseData);

    // Guard against non-object parsed data
    if (!parsed || typeof parsed !== 'object') {
      return [];
    }

    // Use event_type from data or eventName from SSE
    const eventType = parsed.event_type || parsed.type || eventName;

    // eslint-disable-next-line no-console
    console.log('[Transform] Event type:', eventType);

    const chunks = [];

    // Map our events to UI Message Stream format
    switch (eventType) {
      case 'text_delta':
      case 'text-delta': {
        const delta = parsed.delta || parsed.text || '';
        if (delta) {
          chunks.push({
            type: 'text-delta',
            id: messageId,
            delta,
          });
        }
        break;
      }

      case 'text_start':
      case 'text-start':
      case 'start':
        // text-start is handled by stream wrapper - ignore
        // eslint-disable-next-line no-console
        console.log('[Transform] Start event - handled by wrapper');
        break;

      case 'text_end':
      case 'text-end':
      case 'finish':
      case 'done':
      case 'complete': {
        // Check if this is the FINAL complete (status: "done") vs step complete
        // Backend sends {"status":"done"} as the final signal
        if (parsed.status === 'done') {
          // eslint-disable-next-line no-console
          console.log(
            '[Transform] FINAL complete (status:done) - signaling stream end'
          );
          // Return special marker to indicate stream should end
          return { chunks: [], shouldEnd: true };
        }
        // Otherwise it's a step completion - ignore it
        // eslint-disable-next-line no-console
        console.log('[Transform] Step complete event - ignoring (not final)');
        break;
      }

      case 'reasoning_delta':
      case 'reasoning-delta': {
        const reasoningDelta = parsed.delta || '';
        if (reasoningDelta) {
          chunks.push({
            type: 'reasoning-delta',
            id: messageId,
            delta: reasoningDelta,
          });
        }
        break;
      }

      case 'progress':
        // Progress events - show as text deltas (optional, can be noisy)
        // eslint-disable-next-line no-console
        console.log('[Transform] Progress event:', {
          status: parsed.status,
          step_name: parsed.step_name,
        });
        // Only show step progress, skip other progress events
        if (parsed.step_name && parsed.total_steps) {
          chunks.push({
            type: 'text-delta',
            id: messageId,
            delta: `⏳ Step ${(parsed.step_index || 0) + 1}/${parsed.total_steps}: ${parsed.step_name}\n`,
          });
        }
        break;

      case 'chunk': {
        // Chunk event - contains actual text content
        const content = parsed.content || parsed.delta || parsed.text;
        if (content && typeof content === 'string') {
          chunks.push({
            type: 'text-delta',
            id: messageId,
            delta: content,
          });
        }
        break;
      }

      case 'error':
        chunks.push({
          type: 'error',
          errorText: parsed.message || parsed.error || 'Unknown error',
        });
        break;

      default: {
        // eslint-disable-next-line no-console
        console.log('[Transform] Unknown event type:', eventType);
        // Try to extract any text content from unknown events
        const unknownContent = parsed.content || parsed.delta || parsed.text;
        if (unknownContent && typeof unknownContent === 'string') {
          chunks.push({
            type: 'text-delta',
            id: messageId,
            delta: unknownContent,
          });
        }
        break;
      }
    }

    return chunks;
  } catch (err) {
    // eslint-disable-next-line no-console
    console.log(
      '[Transform] JSON parse error:',
      err.message,
      'Data:',
      sseData.substring(0, 100)
    );
    return [];
  }
}

/**
 * Create a readable stream that transforms SSE events to UI Message Stream objects
 *
 * CRITICAL: The SDK expects a stream of JavaScript objects, NOT text/JSON strings!
 * The Chat class's processUIMessageStream expects each chunk to be a parsed object
 * with a `type` property.
 *
 * Stream lifecycle:
 * - text-start: Sent once when first content chunk arrives
 * - text-delta: Sent for each piece of content
 * - text-end: Sent ONLY when HTTP stream closes (done=true)
 *
 * NOTE: We do NOT close the stream on backend 'complete' events because
 * multi-step agents send multiple complete events (one per step).
 *
 * @param {ReadableStream} inputStream - Original SSE stream from backend
 * @returns {ReadableStream} Transformed stream yielding JavaScript objects
 */
function createAdaptedStream(inputStream) {
  const reader = inputStream.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let textStartSent = false;
  let streamClosed = false;
  const messageId = `msg-${Date.now()}`;

  /**
   * Safely enqueue a chunk, checking if stream is still open
   */
  const safeEnqueue = (controller, chunk) => {
    if (streamClosed) {
      // eslint-disable-next-line no-console
      console.log('[Stream] Skipping enqueue - stream already closed');
      return false;
    }
    try {
      controller.enqueue(chunk);
      return true;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.log('[Stream] Enqueue failed (stream closed?):', err.message);
      streamClosed = true;
      return false;
    }
  };

  /**
   * Close stream and send text-end if needed
   */
  const closeStream = controller => {
    if (streamClosed) return;

    // Send text-end if we sent text-start
    if (textStartSent) {
      // eslint-disable-next-line no-console
      console.log('[Stream] Sending text-end');
      safeEnqueue(controller, { type: 'text-end', id: messageId });
    }

    // eslint-disable-next-line no-console
    console.log('[Stream] Closing stream');
    streamClosed = true;
    try {
      controller.close();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.log('[Stream] Close failed (already closed?):', err.message);
    }
  };

  return new ReadableStream({
    async pull(controller) {
      if (streamClosed) {
        return;
      }

      try {
        // eslint-disable-next-line no-console
        console.log('[Stream] pull() called, buffer length:', buffer.length);

        const { done, value } = await reader.read();

        if (done) {
          // eslint-disable-next-line no-console
          console.log('[Stream] ==========================================');
          // eslint-disable-next-line no-console
          console.log('[Stream] HTTP STREAM ENDED - this is the real end');

          // Process any remaining buffer
          if (buffer.trim()) {
            const result = processSSEBuffer(buffer, messageId);
            for (const chunk of result.chunks) {
              // eslint-disable-next-line no-console
              console.log('[Stream] Final chunk:', chunk.type);
              if (!textStartSent && chunk.type === 'text-delta') {
                safeEnqueue(controller, { type: 'text-start', id: messageId });
                textStartSent = true;
              }
              safeEnqueue(controller, chunk);
            }
          }

          closeStream(controller);
          return;
        }

        // Append new data to buffer
        const chunk = decoder.decode(value, { stream: true });
        buffer += chunk;
        // eslint-disable-next-line no-console
        console.log(
          '[Stream] Received chunk (' + chunk.length + ' chars):',
          chunk.substring(0, 200)
        );

        // Process complete SSE events (separated by double newlines)
        const events = buffer.split(/\r?\n\r?\n/);
        buffer = events.pop() || '';
        // eslint-disable-next-line no-console
        console.log(
          '[Stream] Found',
          events.length,
          'complete events, buffer remaining:',
          buffer.length
        );

        // Process each complete event
        const allChunks = [];
        let shouldEndStream = false;
        for (const event of events) {
          if (shouldEndStream) break;
          if (event.trim()) {
            const result = processSSEBuffer(event, messageId);
            allChunks.push(...result.chunks);
            if (result.shouldEnd) {
              // eslint-disable-next-line no-console
              console.log(
                '[Stream] Final complete received - will close stream'
              );
              shouldEndStream = true;
            }
          }
        }

        if (allChunks.length > 0) {
          // Send text-start first if not already sent
          if (!textStartSent) {
            // eslint-disable-next-line no-console
            console.log('[Stream] Sending text-start:', messageId);
            safeEnqueue(controller, { type: 'text-start', id: messageId });
            textStartSent = true;
          }
          // Send all chunks as JavaScript objects
          for (const chunkObj of allChunks) {
            // eslint-disable-next-line no-console
            console.log(
              '[Stream] Enqueueing chunk:',
              chunkObj.type,
              chunkObj.delta?.substring(0, 50) || ''
            );
            safeEnqueue(controller, chunkObj);
          }
        } else {
          // eslint-disable-next-line no-console
          console.log('[Stream] No chunks to enqueue');
        }

        // If we received the final complete signal, close the stream
        if (shouldEndStream) {
          // eslint-disable-next-line no-console
          console.log(
            '[Stream] Closing stream due to final complete (status:done)'
          );
          closeStream(controller);
        }
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error('[Stream] ❌ Error in pull:', error.message);
        streamClosed = true;
        try {
          controller.error(error);
        } catch {
          // Controller may already be errored
        }
      }
    },
    cancel(reason) {
      // eslint-disable-next-line no-console
      console.log('[Stream] ⚠️ Stream cancelled, reason:', reason);
      streamClosed = true;
      reader.cancel();
    },
  });
}

/**
 * Process SSE buffer and extract data for transformation
 *
 * @param {string} sseEvent - Raw SSE event text
 * @param {string} messageId - Current message ID
 * @returns {Object} { chunks: Array<Object>, shouldEnd: boolean }
 */
function processSSEBuffer(sseEvent, messageId) {
  // Extract data from SSE format: "event: name\ndata: {...}"
  const lines = sseEvent.split('\n');
  const allChunks = [];
  let currentEventName = '';
  let shouldEnd = false;

  for (const line of lines) {
    if (shouldEnd) break; // Stop processing after final complete

    if (line.startsWith('event:')) {
      // Extract event name
      currentEventName = line.slice(6).trim();
      // eslint-disable-next-line no-console
      console.log('[SSE] Event name:', currentEventName);
    } else if (line.startsWith('data:')) {
      const jsonData = line.slice(5).trim();
      // eslint-disable-next-line no-console
      console.log('[SSE] Raw data:', jsonData.substring(0, 100));
      if (jsonData && jsonData !== '[DONE]') {
        const result = transformToUIMessageFormat(
          jsonData,
          messageId,
          currentEventName
        );
        // Check if result is object with shouldEnd (final complete)
        if (result && typeof result === 'object' && result.shouldEnd) {
          // eslint-disable-next-line no-console
          console.log('[SSE] Final complete detected - will end stream');
          shouldEnd = true;
        } else if (Array.isArray(result)) {
          // eslint-disable-next-line no-console
          console.log('[SSE] Transformed to', result.length, 'chunks');
          allChunks.push(...result);
        }
      } else if (jsonData === '[DONE]') {
        shouldEnd = true;
      }
      // Reset event name after processing
      currentEventName = '';
    }
  }

  return { chunks: allChunks, shouldEnd };
}

/**
 * Extract text content from message parts or content field
 *
 * @param {Object} message - Message object
 * @returns {string} Extracted text content
 */
function extractTextContent(message) {
  // Handle AI SDK 5 parts format
  if (message.parts && Array.isArray(message.parts)) {
    return message.parts
      .filter(p => p.type === 'text')
      .map(p => p.text)
      .join('');
  }
  // Handle legacy content string
  return message.content || '';
}

/**
 * Custom transport that adapts our backend format to AI SDK format
 *
 * @param {Object} options - Transport options
 * @param {Function} options.getAuthHeaders - Function returning auth headers
 * @param {string} options.baseUrl - API endpoint URL
 * @param {Object|Function} options.body - Additional body params or function returning them
 * @param {Function} options.onSessionId - Callback when session ID is extracted
 * @returns {Object} Transport object with send method
 */
function createAdaptedTransport(options) {
  const { getAuthHeaders, baseUrl, body: bodyOptions, onSessionId } = options;

  return {
    async sendMessages({ messages, abortSignal }) {
      const authHeaders = getAuthHeaders();
      const dynamicBody =
        typeof bodyOptions === 'function' ? bodyOptions() : bodyOptions || {};

      // Transform messages to our backend format
      // Backend expects last message in specific format
      const lastMessage = messages[messages.length - 1];
      const requestBody = {
        messages: [
          {
            role: lastMessage.role,
            content: extractTextContent(lastMessage),
          },
        ],
        ...dynamicBody,
      };

      // Compute URL - handle both string and computed ref
      const url =
        typeof baseUrl === 'string' ? baseUrl : baseUrl.value || baseUrl;

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          ...authHeaders,
          Accept: 'text/event-stream',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
        signal: abortSignal,
      });

      if (!response.ok) {
        throw new Error(
          `Stream request failed: ${response.status} ${response.statusText}`
        );
      }

      // Extract session ID from response headers
      const sessionId = response.headers.get('X-Chat-Session-Id');
      if (sessionId && onSessionId) {
        onSessionId(sessionId);
      }

      // Return the adapted stream directly (Chat class expects ReadableStream)
      return createAdaptedStream(response.body);
    },
  };
}

/**
 * Create a Vercel AI SDK Chat instance with our custom adapter
 *
 * This composable wraps the AI SDK's Chat class with a custom transport
 * that transforms our backend's snake_case events to kebab-case format.
 *
 * @param {Object} options - Configuration options
 * @param {string|ComputedRef<string>} options.api - API endpoint URL
 * @param {Function} options.getAuthHeaders - Function returning auth headers object
 * @param {Object|Function} options.body - Additional body params or function returning them
 * @param {Function} [options.onFinish] - Callback when stream finishes
 * @param {Function} [options.onError] - Callback on error
 * @param {Function} [options.onSessionId] - Callback with session ID from headers
 * @returns {Chat} Vercel AI SDK Chat instance
 *
 * @example
 * const chat = useVercelChat({
 *   api: '/api/v1/accounts/1/ai_chat/stream',
 *   getAuthHeaders: () => ({ 'access-token': '...' }),
 *   body: () => ({ agent_bot_id: selectedBotId.value }),
 *   onFinish: (message) => console.log('Done:', message),
 *   onError: (error) => console.error('Error:', error),
 *   onSessionId: (id) => sessionId.value = id,
 * });
 *
 * // Send a message
 * await chat.sendMessage({ content: 'Hello!' });
 *
 * // Access reactive state
 * chat.messages  // Array of messages
 * chat.status    // 'ready' | 'submitted' | 'streaming' | 'error'
 * chat.error     // Error object if any
 */
export function useVercelChat(options) {
  const { api, getAuthHeaders, body, onFinish, onError, onSessionId } = options;

  const transport = createAdaptedTransport({
    baseUrl: api,
    getAuthHeaders,
    body,
    onSessionId,
  });

  const chat = new Chat({
    transport,
    onFinish: message => {
      // eslint-disable-next-line no-console
      console.log('[useVercelChat] Stream finished:', message);
      if (onFinish) onFinish(message);
    },
    onError: error => {
      // eslint-disable-next-line no-console
      console.error('[useVercelChat] Stream error:', error);
      if (onError) onError(error);
    },
  });

  return chat;
}

export default useVercelChat;
