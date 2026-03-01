// constants.ts — ported from mobile's types/ai-chat/constants.ts
// Merged with web-only values (SOURCE_URL, SOURCE_DOCUMENT, INPUT_START, OUTPUT_STREAMING)

/**
 * Message part types from Vercel AI SDK + Chatwoot backend extensions
 */
export const PART_TYPES = {
  // Text content
  TEXT: 'text',
  // Reasoning/thinking content
  REASONING: 'reasoning',
  // Tool-related (SDK format)
  TOOL_INVOCATION: 'tool-invocation',
  TOOL_CALL: 'tool-call',
  TOOL_RESULT: 'tool-result',
  // Tool-related (Backend format - prefixed)
  TOOL_INPUT_STREAMING: 'tool-input-streaming',
  TOOL_INPUT_AVAILABLE: 'tool-input-available',
  TOOL_OUTPUT_AVAILABLE: 'tool-output-available',
  TOOL_OUTPUT_ERROR: 'tool-output-error',
  // File attachments
  FILE: 'file',
  // Source citations
  SOURCE: 'source',
  SOURCE_URL: 'source-url', // Web-only, preserved for backward compat
  SOURCE_DOCUMENT: 'source-document', // Web-only, preserved for backward compat
  // Step indicators
  STEP_START: 'step-start',
} as const;

export type PartType = (typeof PART_TYPES)[keyof typeof PART_TYPES];

/**
 * Tool execution states
 */
export const TOOL_STATES = {
  INPUT_START: 'tool-input-start', // Web-only, preserved for backward compat
  INPUT_STREAMING: 'input-streaming',
  INPUT_AVAILABLE: 'input-available',
  OUTPUT_STREAMING: 'tool-output-streaming', // Web-only, preserved for backward compat
  OUTPUT_AVAILABLE: 'output-available',
  OUTPUT_ERROR: 'output-error',
  // Legacy/fallback states
  PENDING: 'pending',
  RUNNING: 'running',
  COMPLETED: 'completed',
  FAILED: 'failed',
} as const;

export type ToolState = (typeof TOOL_STATES)[keyof typeof TOOL_STATES];

/**
 * Chat status values (matches Vercel SDK useChat status)
 */
export const CHAT_STATUS = {
  READY: 'ready',
  SUBMITTED: 'submitted',
  STREAMING: 'streaming',
  ERROR: 'error',
} as const;

export type ChatStatus = (typeof CHAT_STATUS)[keyof typeof CHAT_STATUS];

/**
 * Message roles
 */
export const MESSAGE_ROLES = {
  USER: 'user',
  ASSISTANT: 'assistant',
  SYSTEM: 'system',
  DATA: 'data',
  TOOL: 'tool', // Web-only, preserved for backward compat
} as const;

// Backward-compatible alias (web used MESSAGE_ROLE singular)
export const MESSAGE_ROLE = MESSAGE_ROLES;

export type MessageRole = (typeof MESSAGE_ROLES)[keyof typeof MESSAGE_ROLES];

export const VOICE_INPUT_STATUS = {
  IDLE: 'idle',
  RECORDING: 'recording',
  TRANSCRIBING: 'transcribing',
  ERROR: 'error',
  DISABLED: 'disabled',
} as const;

export type VoiceInputStatus =
  (typeof VOICE_INPUT_STATUS)[keyof typeof VOICE_INPUT_STATUS];
