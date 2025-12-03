export const PART_TYPES = {
  TEXT: 'text',
  REASONING: 'reasoning',
  FILE: 'file',
  SOURCE_URL: 'source-url',
  SOURCE_DOCUMENT: 'source-document',
};

export const TOOL_STATES = {
  INPUT_START: 'tool-input-start',
  INPUT_STREAMING: 'tool-input-streaming',
  INPUT_AVAILABLE: 'tool-input-available',
  OUTPUT_STREAMING: 'tool-output-streaming',
  OUTPUT_AVAILABLE: 'tool-output-available',
  OUTPUT_ERROR: 'tool-output-error',
};

export const CHAT_STATUS = {
  READY: 'ready',
  SUBMITTED: 'submitted',
  STREAMING: 'streaming',
  ERROR: 'error',
};

export const MESSAGE_ROLE = {
  USER: 'user',
  ASSISTANT: 'assistant',
  TOOL: 'tool',
};
