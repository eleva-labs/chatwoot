/**
 * Test Data Helpers
 *
 * Generate unique test data to avoid conflicts between test runs.
 */

/**
 * Generate a unique identifier with optional prefix
 */
export function uniqueId(prefix: string = 'test'): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`;
}

/**
 * Generate a unique test message
 */
export function testMessage(prefix: string = 'Test message'): string {
  return `${prefix} ${uniqueId()}`;
}

/**
 * Generate a unique email for testing
 */
export function testEmail(domain: string = 'test.chatwoot.local'): string {
  return `test-${uniqueId()}@${domain}`;
}

/**
 * Wait for a specified duration (use sparingly - prefer Playwright's auto-waiting)
 */
export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
