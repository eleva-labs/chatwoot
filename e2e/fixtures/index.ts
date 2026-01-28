/**
 * E2E Test Fixtures
 *
 * This file exports the combined test fixtures that include:
 * - Page object fixtures (loginPage, dashboardPage, inboxPage)
 * - Auth fixtures (adminContext, agentContext, adminPage, agentPage)
 *
 * Usage:
 *   import { test, expect } from '../../fixtures';
 *
 *   test('example test', async ({ dashboardPage, page }) => {
 *     await dashboardPage.goto();
 *     // ...
 *   });
 *
 * For tests requiring specific user roles:
 *   test('admin test', async ({ adminPage }) => {
 *     await adminPage.goto('/app/accounts/1/dashboard');
 *     // ...
 *   });
 */

export { test, expect } from './pages.fixture';

// Re-export auth fixture for tests that need only auth fixtures
export { test as authTest, expect as authExpect } from './auth.fixture';
