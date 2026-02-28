/**
 * useAiMessageMapper.ts
 *
 * Pure functions for transforming messages between backend format and
 * Vercel AI SDK UIMessage format.
 *
 * CRITICAL: mapPart() preserves tool calls, tool results, and reasoning parts
 * from history — without this, historical messages display as plain text.
 *
 * Ported from mobile's store/ai-chat/aiChatMapper.ts
 */
import type { UIMessage } from 'ai';
import camelcaseKeys from 'camelcase-keys';
import { PART_TYPES, MESSAGE_ROLE } from '../constants';

// === Part mapping (critical - preserves tool calls + reasoning) ===

/**
 * Map a single part from backend DTO to SDK format.
 *
 * Handles:
 * - text parts -> { type: 'text', text }
 * - reasoning parts -> { type: 'reasoning', text, state: 'done' }
 * - tool-call / tool-input-available -> { type: 'dynamic-tool', state: 'input-available' }
 * - tool-result / tool-output-available -> { type: 'dynamic-tool', state: 'output-available' }
 * - unknown parts with text -> text fallback
 * - unknown parts without text -> null (filtered out)
 */
function mapPart(
  part: Record<string, unknown>,
): UIMessage['parts'][number] | null {
  const type = part.type as string;

  // Text parts
  if (type === PART_TYPES.TEXT) {
    return {
      type: 'text' as const,
      text: (part.text as string) || '',
    };
  }

  // Reasoning parts - SDK v5 uses 'text' not 'reasoning'
  if (type === PART_TYPES.REASONING) {
    return {
      type: 'reasoning' as const,
      text: (part.text as string) || (part.reasoning as string) || '',
      state: 'done' as const,
    };
  }

  // Tool call parts - SDK v5 uses 'dynamic-tool' type
  if (
    type === PART_TYPES.TOOL_CALL ||
    type === PART_TYPES.TOOL_INPUT_AVAILABLE
  ) {
    return {
      type: 'dynamic-tool' as const,
      toolCallId: (part.toolCallId as string) || '',
      toolName: (part.toolName as string) || '',
      state: 'input-available' as const,
      input: (part.args as Record<string, unknown>) || {},
    } as UIMessage['parts'][number];
  }

  // Tool result parts - SDK v5 uses 'dynamic-tool' with output
  if (
    type === PART_TYPES.TOOL_RESULT ||
    type === PART_TYPES.TOOL_OUTPUT_AVAILABLE
  ) {
    return {
      type: 'dynamic-tool' as const,
      toolCallId: (part.toolCallId as string) || '',
      toolName: (part.toolName as string) || '',
      state: 'output-available' as const,
      input: (part.args as Record<string, unknown>) || {},
      output: part.result,
    } as UIMessage['parts'][number];
  }

  // Unknown part type - return as text if has content
  if (part.text) {
    return {
      type: 'text' as const,
      text: part.text as string,
    };
  }

  return null;
}

/**
 * Map message parts from DTO format to SDK format.
 * Always returns an array (never undefined).
 *
 * If no parts exist but fallback content is available, creates a text part.
 * If all parts are unmappable, falls back to content as text.
 */
function mapParts(
  parts?: Array<Record<string, unknown>>,
  fallbackContent?: string,
): UIMessage['parts'] {
  if (!parts || parts.length === 0) {
    // Use != null to allow empty string '' as valid content
    if (fallbackContent != null) {
      return [{ type: 'text' as const, text: fallbackContent }];
    }
    return [];
  }

  const mapped = parts
    .map(mapPart)
    .filter((p): p is NonNullable<typeof p> => p !== null);

  if (mapped.length === 0 && fallbackContent != null) {
    return [{ type: 'text' as const, text: fallbackContent }];
  }
  return mapped;
}

// === Message -> UIMessage mapping ===

/**
 * Transform a single backend message to UIMessage format.
 * UIMessage is the Vercel AI SDK format with parts[] array.
 *
 * Key differences from old code:
 * - Calls mapParts() to preserve tool calls, results, and reasoning
 * - Skips tool-role messages
 * - Skips assistant messages ONLY when BOTH content AND parts are empty
 *
 * @param backendMsg - Message from backend API
 * @returns UIMessage format for Vercel AI SDK, or null if should be filtered
 */
export function toUIMessage(
  backendMsg: Record<string, unknown>,
): UIMessage | null {
  // Normalize keys to camelCase
  const msg = camelcaseKeys(backendMsg, { deep: true }) as Record<
    string,
    unknown
  >;
  const role = (msg.messageRole || msg.role) as string;
  const content = ((msg.content as string) || '').toString();

  // Skip tool messages from backend
  if (role === MESSAGE_ROLE.TOOL) {
    return null;
  }

  // Skip assistant messages with empty content AND empty/missing parts
  if (role === MESSAGE_ROLE.ASSISTANT) {
    const hasParts =
      msg.parts &&
      Array.isArray(msg.parts) &&
      (msg.parts as unknown[]).length > 0;
    if (!content.trim() && !hasParts) {
      return null;
    }
  }

  // Handle various timestamp field names from backend
  const timestamp = (msg.sentDate || msg.timestamp || msg.createdAt) as
    | string
    | undefined;

  return {
    id: ((msg.externalId || msg.id) as string) || '',
    role: role as UIMessage['role'],
    parts: mapParts(
      msg.parts as Array<Record<string, unknown>> | undefined,
      content,
    ),
    createdAt: timestamp ? new Date(timestamp) : new Date(),
  };
}

/**
 * Transform an array of backend messages to UIMessage format.
 * Filters out tool messages and empty assistant messages.
 *
 * @param messages - Array of backend messages
 * @returns Array of UIMessages (filtered)
 */
export function toUIMessages(
  messages: Record<string, unknown>[],
): UIMessage[] {
  if (!Array.isArray(messages)) return [];
  return messages
    .map(toUIMessage)
    .filter((msg): msg is UIMessage => msg !== null);
}

/**
 * Transform a UIMessage back to backend format for API calls.
 * Used when we need to send messages to a non-streaming endpoint.
 *
 * @param uiMessage - UIMessage from Vercel AI SDK
 * @returns Backend message format
 */
export function toBackendMessage(uiMessage: {
  id: string;
  role: string;
  parts?: Array<{ type: string; text?: string }>;
  createdAt?: Date;
}): {
  id: string;
  message_role: string;
  content: string;
  sent_date: string;
} {
  // Extract text content from parts
  const textContent =
    uiMessage.parts
      ?.filter(part => part.type === PART_TYPES.TEXT)
      .map(part => part.text)
      .join('') || '';

  return {
    id: uiMessage.id,
    message_role: uiMessage.role,
    content: textContent,
    sent_date: uiMessage.createdAt?.toISOString() || new Date().toISOString(),
  };
}
