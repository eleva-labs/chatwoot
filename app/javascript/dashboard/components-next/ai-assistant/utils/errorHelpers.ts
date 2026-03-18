/**
 * Error Classification Helpers
 *
 * Pure functions for classifying error messages into categories
 * for display and retry logic.
 *
 * Ported from inline logic in AiChatError.vue for extraction.
 * Mobile equivalent: same categorizeError pattern in error display.
 *
 * Signature uses string (not Error) to match mobile and core package convention.
 */

export type ErrorCategory =
  | 'network'
  | 'rate_limit'
  | 'auth'
  | 'server'
  | 'unknown';

/**
 * Categorize an error message string into a display category.
 *
 * @param message - The error message string (e.g., error.message)
 * @returns One of: 'network', 'rate_limit', 'auth', 'server', 'unknown'
 */
export function categorizeError(message: string): ErrorCategory {
  const lower = message.toLowerCase();
  if (lower.includes('network') || lower.includes('fetch')) return 'network';
  if (lower.includes('429') || lower.includes('rate')) return 'rate_limit';
  if (lower.includes('401') || lower.includes('403')) return 'auth';
  if (/5\d{2}/.test(message)) return 'server';
  return 'unknown';
}
