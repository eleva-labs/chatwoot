/**
 * AI Assistant Part Types and Helpers
 *
 * Type guards and utilities for working with message parts.
 * Handles both Vercel SDK format and Chatwoot backend format.
 *
 * Ported from mobile's types/ai-chat/parts.ts
 */

import type { UIMessage } from 'ai';
import { PART_TYPES, TOOL_STATES, type ToolState } from './constants';

// ============================================================================
// Part Type Definitions
// ============================================================================

/**
 * Base part structure (common to all parts)
 */
export interface BasePart {
  type: string;
}

/**
 * Text part - regular message content
 */
export interface TextPart extends BasePart {
  type: 'text';
  text: string;
}

/**
 * Reasoning part - AI thinking/reasoning content
 */
export interface ReasoningPart extends BasePart {
  type: 'reasoning';
  /** Primary text field - matches SDK v5 */
  text: string;
  /** @deprecated Use 'text' instead. Kept for backwards compatibility. */
  reasoning?: string;
  /** Streaming state */
  state?: 'streaming' | 'done';
  details?: { type: string; text: string }[];
}

/**
 * Tool call part - tool invocation request
 */
export interface ToolCallPart extends BasePart {
  type: string; // 'tool-call' or 'tool-invocation' or backend variants
  toolCallId: string;
  toolName: string;
  args?: Record<string, unknown>;
  state?: ToolState;
}

/**
 * Tool result part - tool execution result
 */
export interface ToolResultPart extends BasePart {
  type: string; // 'tool-result' or backend variants
  toolCallId: string;
  toolName?: string;
  result?: unknown;
  isError?: boolean;
  state?: ToolState;
}

/**
 * Union of tool-related parts
 */
export type ToolPart = ToolCallPart | ToolResultPart;

/**
 * Any message part
 */
export type MessagePart = TextPart | ReasoningPart | ToolPart | BasePart;

// ============================================================================
// Type Guards
// ============================================================================

/**
 * Check if a part is a text part
 */
export function isTextPart(part: MessagePart): part is TextPart {
  return part.type === PART_TYPES.TEXT;
}

/**
 * Check if a part is a reasoning/thinking part
 */
export function isReasoningPart(part: MessagePart): part is ReasoningPart {
  return part.type === PART_TYPES.REASONING;
}

/**
 * Check if a part is a tool-related part
 *
 * IMPORTANT: Uses startsWith('tool-') to handle both:
 * - SDK format: 'tool-call', 'tool-result', 'tool-invocation'
 * - Backend format: 'tool-input-available', 'tool-output-available', etc.
 */
export function isToolPart(part: MessagePart): part is ToolPart {
  return part.type?.startsWith('tool-') ?? false;
}

/**
 * Check if a part is a tool call (input)
 */
export function isToolCallPart(part: MessagePart): part is ToolCallPart {
  return (
    part.type === PART_TYPES.TOOL_CALL ||
    part.type === PART_TYPES.TOOL_INVOCATION ||
    part.type === PART_TYPES.TOOL_INPUT_STREAMING ||
    part.type === PART_TYPES.TOOL_INPUT_AVAILABLE
  );
}

/**
 * Check if a part is a tool result (output)
 */
export function isToolResultPart(part: MessagePart): part is ToolResultPart {
  return (
    part.type === PART_TYPES.TOOL_RESULT ||
    part.type === PART_TYPES.TOOL_OUTPUT_AVAILABLE ||
    part.type === PART_TYPES.TOOL_OUTPUT_ERROR
  );
}

// ============================================================================
// Part Extraction Helpers
// ============================================================================

/**
 * Get all parts of a specific type from a message
 */
export function filterPartsByType<T extends MessagePart>(
  parts: MessagePart[] | undefined,
  predicate: (part: MessagePart) => part is T,
): T[] {
  if (!parts) return [];
  return parts.filter(predicate);
}

/**
 * Get all text parts from a message
 */
export function getTextParts(parts: MessagePart[] | undefined): TextPart[] {
  return filterPartsByType(parts, isTextPart);
}

/**
 * Get all reasoning parts from a message
 */
export function getReasoningParts(
  parts: MessagePart[] | undefined,
): ReasoningPart[] {
  return filterPartsByType(parts, isReasoningPart);
}

/**
 * Get all tool parts from a message
 */
export function getToolParts(parts: MessagePart[] | undefined): ToolPart[] {
  return filterPartsByType(parts, isToolPart);
}

/**
 * Check if message has any reasoning parts
 */
export function hasReasoningParts(
  parts: MessagePart[] | undefined,
): boolean {
  return getReasoningParts(parts).length > 0;
}

/**
 * Check if message has any tool parts
 */
export function hasToolParts(parts: MessagePart[] | undefined): boolean {
  return getToolParts(parts).length > 0;
}

/**
 * Get deduplicated tool parts (latest state per toolCallId)
 *
 * When a tool goes through multiple states (streaming -> available -> result),
 * this returns only the latest state for each unique tool call.
 */
export function getDeduplicatedToolParts(
  parts: MessagePart[] | undefined,
): ToolPart[] {
  const toolParts = getToolParts(parts);
  const byCallId = new Map<string, ToolPart>();

  for (const part of toolParts) {
    const callId = (part as ToolCallPart).toolCallId;
    if (callId) {
      byCallId.set(callId, part);
    }
  }

  return Array.from(byCallId.values());
}

// ============================================================================
// Tool State Helpers
// ============================================================================

/**
 * Derive the display state for a tool part
 *
 * Handles both SDK format (part.state) and backend format (encoded in part.type)
 */
export function deriveToolDisplayState(part: ToolPart): ToolState {
  // If part has explicit state, use it
  if ('state' in part && part.state) {
    return part.state;
  }

  // Otherwise derive from type
  const type = part.type;

  if (type === PART_TYPES.TOOL_INPUT_STREAMING) {
    return TOOL_STATES.INPUT_STREAMING;
  }
  if (
    type === PART_TYPES.TOOL_INPUT_AVAILABLE ||
    type === PART_TYPES.TOOL_CALL
  ) {
    return TOOL_STATES.INPUT_AVAILABLE;
  }
  if (
    type === PART_TYPES.TOOL_OUTPUT_AVAILABLE ||
    type === PART_TYPES.TOOL_RESULT
  ) {
    return TOOL_STATES.OUTPUT_AVAILABLE;
  }
  if (type === PART_TYPES.TOOL_OUTPUT_ERROR) {
    return TOOL_STATES.OUTPUT_ERROR;
  }

  // Fallback
  return TOOL_STATES.PENDING;
}

/**
 * Check if a tool is currently executing (streaming or pending result)
 */
export function isToolExecuting(state: ToolState): boolean {
  return (
    state === TOOL_STATES.INPUT_STREAMING ||
    state === TOOL_STATES.INPUT_AVAILABLE
  );
}

/**
 * Check if a tool has completed (success or error)
 */
export function isToolComplete(state: ToolState): boolean {
  return (
    state === TOOL_STATES.OUTPUT_AVAILABLE ||
    state === TOOL_STATES.OUTPUT_ERROR
  );
}

/**
 * Check if a tool failed
 */
export function isToolFailed(state: ToolState): boolean {
  return state === TOOL_STATES.OUTPUT_ERROR;
}

// ============================================================================
// Message Helpers
// ============================================================================

/**
 * Get the combined text content from a message
 */
export function getMessageTextContent(message: UIMessage): string {
  const textParts = getTextParts(message.parts as MessagePart[] | undefined);
  return textParts.map(part => part.text).join('');
}

/**
 * Get the last assistant message from a list
 */
export function getLastAssistantMessage(
  messages: UIMessage[],
): UIMessage | undefined {
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === 'assistant') {
      return messages[i];
    }
  }
  return undefined;
}

// ============================================================================
// Additional web-specific types
// ============================================================================

/**
 * Chat session from backend API (snake_case to match Zod schemas and API)
 */
export interface ChatSession {
  chat_session_id: string;
  updated_at: string;
  created_at?: string;
  agent_bot_id?: number;
  account_id?: number;
}

/**
 * Bot from backend API
 */
export interface Bot {
  id: number;
  name: string;
  avatar_url?: string;
  description?: string;
}


