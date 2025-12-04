/**
 * useAiMessageMapper.js
 *
 * Composable for transforming messages between backend format and
 * Vercel AI SDK UIMessage format.
 *
 * Backend returns flat message objects, while Vercel AI SDK expects
 * UIMessage format with parts[] array for streaming support.
 */
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { PART_TYPES, MESSAGE_ROLE } from '../constants';

/**
 * Transform a single backend message to UIMessage format.
 * UIMessage is the Vercel AI SDK format with parts[] array.
 *
 * @param {Object} backendMsg - Message from backend API
 * @returns {Object|null} UIMessage format for Vercel AI SDK, or null if should be filtered
 *
 * @example
 * // Backend format:
 * { id: "123", message_role: "user", content: "Hello", sent_date: "2025-01-15T10:30:00Z" }
 *
 * // UIMessage format:
 * { id: "123", role: "user", parts: [{ type: "text", text: "Hello" }], createdAt: Date }
 */
export function toUIMessage(backendMsg) {
  // Normalize keys to camelCase
  const msg = useCamelCase(backendMsg, { deep: true });
  const role = msg.messageRole || msg.role;
  const content = msg.content || '';

  // Skip tool messages from backend - they don't have the rich format we need
  // Tool execution info is only available during streaming, not from history
  if (role === MESSAGE_ROLE.TOOL) {
    return null;
  }

  // Skip assistant messages with empty content (these were tool-call placeholders)
  if (role === MESSAGE_ROLE.ASSISTANT && !content.trim()) {
    return null;
  }

  // Handle various timestamp field names from backend
  const timestamp = msg.sentDate || msg.timestamp || msg.createdAt;

  return {
    id: msg.externalId || msg.id,
    role,
    parts: [{ type: PART_TYPES.TEXT, text: content }],
    createdAt: timestamp ? new Date(timestamp) : new Date(),
  };
}

/**
 * Transform an array of backend messages to UIMessage format.
 * Filters out tool messages and empty assistant messages.
 *
 * @param {Array} messages - Array of backend messages
 * @returns {Array} Array of UIMessages (filtered)
 */
export function toUIMessages(messages) {
  if (!Array.isArray(messages)) return [];
  return messages.map(toUIMessage).filter(Boolean);
}

/**
 * Transform a UIMessage back to backend format for API calls.
 * Used when we need to send messages to a non-streaming endpoint.
 *
 * @param {Object} uiMessage - UIMessage from Vercel AI SDK
 * @returns {Object} Backend message format
 */
export function toBackendMessage(uiMessage) {
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

/**
 * Composable hook for message transformation utilities.
 * Use this in components that need access to all mappers.
 *
 * @returns {Object} Message transformation functions
 */
export function useAiMessageMapper() {
  return {
    toUIMessage,
    toUIMessages,
    toBackendMessage,
  };
}

export default useAiMessageMapper;
