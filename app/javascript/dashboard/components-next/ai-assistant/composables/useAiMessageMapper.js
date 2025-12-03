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
import { PART_TYPES } from '../constants';

/**
 * Transform a single backend message to UIMessage format.
 * UIMessage is the Vercel AI SDK format with parts[] array.
 *
 * @param {Object} backendMsg - Message from backend API
 * @returns {Object} UIMessage format for Vercel AI SDK
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

  // Handle various timestamp field names from backend
  const timestamp = msg.sentDate || msg.timestamp || msg.createdAt;

  return {
    id: msg.externalId || msg.id,
    role: msg.messageRole || msg.role,
    parts: [{ type: PART_TYPES.TEXT, text: msg.content || '' }],
    createdAt: timestamp ? new Date(timestamp) : new Date(),
  };
}

/**
 * Transform an array of backend messages to UIMessage format.
 *
 * @param {Array} messages - Array of backend messages
 * @returns {Array} Array of UIMessages
 */
export function toUIMessages(messages) {
  if (!Array.isArray(messages)) return [];
  return messages.map(toUIMessage);
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
