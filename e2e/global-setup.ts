/**
 * Global Setup for Playwright Tests
 *
 * This file runs once before all tests.
 * Currently unused - we use the 'setup' project pattern for authentication.
 *
 * Future uses:
 * - Database seeding via API
 * - Test environment validation
 * - Global test data creation
 */

import { FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  // Currently empty - authentication handled by setup project
  console.log('Global setup started...');

  // Future: Add pre-test setup here
  // Example: Validate test environment is accessible
  // Example: Create test data via API
}

export default globalSetup;
