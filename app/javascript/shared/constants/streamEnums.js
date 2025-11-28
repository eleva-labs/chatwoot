/**
 * AI Streaming Event Types
 *
 * Enumeration of all AI streaming event types compatible with Vercel AI SDK format.
 * These constants represent the event types that can be received in the SSE stream.
 */
export const STREAM_EVENTS = {
  // Stream lifecycle
  START: 'start',
  DONE: 'done',
  FINISH: 'finish',
  ERROR: 'error',

  // Text content lifecycle
  TEXT_START: 'text_start',
  TEXT_DELTA: 'text_delta',
  TEXT_END: 'text_end',

  // Reasoning lifecycle
  REASONING_START: 'reasoning_start',
  REASONING_DELTA: 'reasoning_delta',
  REASONING_END: 'reasoning_end',

  // Tool events
  TOOL_CALL: 'tool-call',
  TOOL_RESULT: 'tool-result',

  // Step events (for progress indicators)
  START_STEP: 'start-step',
  FINISH_STEP: 'finish-step',
};

/**
 * Streaming protocol header names
 */
export const STREAM_HEADERS = {
  VERCEL_AI_UI_MESSAGE_STREAM: 'x-vercel-ai-ui-message-stream',
  AI_STREAMING_PROTOCOL: 'x-ai-streaming-protocol',
  CHAT_SESSION_ID: 'X-Chat-Session-Id',
};

/**
 * Required streaming protocol version
 */
export const STREAM_PROTOCOL_VERSION = 'v1';
