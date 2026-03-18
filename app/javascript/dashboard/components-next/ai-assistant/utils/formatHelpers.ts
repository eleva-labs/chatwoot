/**
 * AI Chat Format Helpers
 *
 * Pure formatting functions for AI chat display.
 * Ported from mobile's aiChatFormatUtils.ts for cross-platform alignment.
 */

/**
 * Format tool name for display. Converts snake_case/camelCase to Title Case.
 *
 * @param name - The raw tool name (e.g. 'search_web', 'getWeather')
 * @param fallback - Fallback string if name is empty
 */
export function formatToolName(name: string, fallback?: string): string {
  if (!name) return fallback ?? 'Unknown Tool';

  return name
    .replace(/_/g, ' ')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/\b\w/g, char => char.toUpperCase());
}

/**
 * Format a date string to a human-readable date label.
 * Returns "Today", "Yesterday", weekday name, or short date.
 *
 * @param dateString - ISO date string
 * @param labels - Localized labels for today/yesterday
 */
export function formatSessionDate(
  dateString: string | undefined,
  labels: { today: string; yesterday: string },
): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  const now = new Date();
  const diffDays = Math.floor(
    (now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24),
  );

  if (diffDays === 0) return labels.today;
  if (diffDays === 1) return labels.yesterday;
  if (diffDays < 7) return date.toLocaleDateString([], { weekday: 'long' });
  return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
}

/**
 * Format a date string to a time string (HH:MM).
 *
 * @param dateString - ISO date string
 */
export function formatSessionTime(dateString: string | undefined): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}
