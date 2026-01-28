/**
 * Global Teardown for Playwright Tests
 *
 * This file runs once after all tests complete.
 * Currently unused - test data is isolated via unique identifiers.
 *
 * Future uses:
 * - Test data cleanup via API
 * - Report aggregation
 * - Environment reset
 */

import { FullConfig } from '@playwright/test';

async function globalTeardown(config: FullConfig) {
  // Currently empty - using unique IDs for test isolation
  console.log('Global teardown completed.');

  // Future: Add post-test cleanup here
  // Example: Clean up test conversations
  // Example: Reset test user state
}

export default globalTeardown;
