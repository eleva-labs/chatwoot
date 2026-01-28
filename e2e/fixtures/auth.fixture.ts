import { test as base, Page, BrowserContext } from '@playwright/test';

/**
 * Auth Fixtures
 *
 * Provides pre-authenticated browser contexts for different user roles.
 * Uses storageState files created by auth.setup.ts.
 *
 * Usage:
 *   import { test, expect } from '../fixtures/auth.fixture';
 *
 *   test('admin can do something', async ({ adminPage }) => {
 *     await adminPage.goto('/app/accounts/1/dashboard');
 *     // ...
 *   });
 */

type AuthFixtures = {
  /** Browser context with admin authentication */
  adminContext: BrowserContext;
  /** Browser context with agent authentication */
  agentContext: BrowserContext;
  /** Page with admin authentication */
  adminPage: Page;
  /** Page with agent authentication */
  agentPage: Page;
};

export const test = base.extend<AuthFixtures>({
  adminContext: async ({ browser }, use) => {
    const context = await browser.newContext({
      storageState: 'e2e/.auth/admin.json',
    });
    await use(context);
    await context.close();
  },

  agentContext: async ({ browser }, use) => {
    const context = await browser.newContext({
      storageState: 'e2e/.auth/agent.json',
    });
    await use(context);
    await context.close();
  },

  adminPage: async ({ adminContext }, use) => {
    const page = await adminContext.newPage();
    await use(page);
    await page.close();
  },

  agentPage: async ({ agentContext }, use) => {
    const page = await agentContext.newPage();
    await use(page);
    await page.close();
  },
});

export { expect } from '@playwright/test';
