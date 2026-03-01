/**
 * Message Validation Pipeline
 *
 * Validates and normalizes UIMessages before rendering.
 * Filters out malformed messages and parts gracefully.
 *
 * Ported from mobile's aiChatMessageUtils.ts for cross-platform alignment.
 */
import type { UIMessage } from 'ai';

/**
 * Validate a single message has required fields and at least one part.
 */
export function validateMessage(message: UIMessage): boolean {
  if (!message.id || !message.role) return false;
  if (!Array.isArray(message.parts) || message.parts.length === 0) return false;
  return true;
}

/**
 * Filter parts to only those with valid structure (object with 'type' property).
 */
export function validateAndNormalizeParts(parts: unknown[]): unknown[] {
  return parts.filter(
    part => part && typeof part === 'object' && 'type' in part,
  );
}

/**
 * Validate and normalize an array of messages.
 * Filters out invalid messages and normalizes their parts.
 */
export function validateAndNormalizeMessages(
  messages: UIMessage[],
): UIMessage[] {
  return messages.filter(validateMessage).map(msg => ({
    ...msg,
    parts: validateAndNormalizeParts(msg.parts) as UIMessage['parts'],
  }));
}
