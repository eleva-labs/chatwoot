/**
 * AI Chat Zod Schemas
 *
 * Single source of truth for AI chat API response shapes.
 * Zod schemas match the existing DTO interfaces exactly.
 * Types are inferred from schemas — no manual type duplication.
 *
 * Ported from mobile's store/ai-chat/aiChatSchemas.ts
 */

import { z } from 'zod';

// === Bot Schemas ===

export const AIChatBotApiSchema = z.object({
  id: z.number(),
  name: z.string(),
  avatar_url: z.string().optional(),
  description: z.string().optional(),
});

export const AIChatBotsResponseSchema = z.object({
  bots: z.array(AIChatBotApiSchema),
});

// === Session Schemas ===

export const AIChatSessionApiSchema = z.object({
  chat_session_id: z.string(),
  updated_at: z.string(),
  created_at: z.string().optional(),
  agent_bot_id: z.number().optional(),
  account_id: z.number().optional(),
});

export const AIChatSessionsResponseSchema = z.object({
  sessions: z.array(AIChatSessionApiSchema),
});

// === Message Part Schema ===

export const AIChatMessagePartApiSchema = z.object({
  type: z.string(),
  text: z.string().optional(),
  toolName: z.string().optional(),
  toolCallId: z.string().optional(),
  args: z.record(z.string(), z.unknown()).optional(),
  result: z.unknown().optional(),
  state: z.string().optional(),
});

// === Message Schema ===

export const AIChatMessageApiSchema = z.object({
  id: z.string(),
  role: z.enum(['user', 'assistant', 'system']),
  content: z.string(),
  timestamp: z.string(),
  chat_session_id: z.string().optional(),
  parts: z.array(AIChatMessagePartApiSchema).optional(),
});

export const AIChatMessagesResponseSchema = z.object({
  messages: z.array(AIChatMessageApiSchema),
});

// === Inferred Types (single source of truth) ===

export type AIChatBot = z.infer<typeof AIChatBotApiSchema>;
export type AIChatBotsResponse = z.infer<typeof AIChatBotsResponseSchema>;
export type AIChatSession = z.infer<typeof AIChatSessionApiSchema>;
export type AIChatSessionsResponse = z.infer<typeof AIChatSessionsResponseSchema>;
export type AIChatMessagePart = z.infer<typeof AIChatMessagePartApiSchema>;
export type AIChatMessage = z.infer<typeof AIChatMessageApiSchema>;
export type AIChatMessagesResponse = z.infer<typeof AIChatMessagesResponseSchema>;

// === Transform Functions ===

export const parseBotsResponse = (raw: unknown) =>
  AIChatBotsResponseSchema.parse(raw);
export const parseSessionsResponse = (raw: unknown) =>
  AIChatSessionsResponseSchema.parse(raw);
export const parseMessagesResponse = (raw: unknown) =>
  AIChatMessagesResponseSchema.parse(raw);
