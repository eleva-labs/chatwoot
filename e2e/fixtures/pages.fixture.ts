import { test as base, Page, BrowserContext } from '@playwright/test';
import { LoginPage, DashboardPage, InboxPage, ConversationPage } from '../pages';

/**
 * Page Fixtures
 *
 * Provides page objects as test fixtures, making it easy to use
 * page objects in tests without manual instantiation.
 *
 * These are combined with auth fixtures to provide both
 * page objects and authentication contexts.
 *
 * Usage:
 *   import { test, expect } from '../fixtures';
 *
 *   test('can view dashboard', async ({ dashboardPage }) => {
 *     await dashboardPage.goto();
 *     await dashboardPage.expectDashboardLoaded();
 *   });
 */

type PageFixtures = {
  /** LoginPage page object */
  loginPage: LoginPage;
  /** DashboardPage page object */
  dashboardPage: DashboardPage;
  /** InboxPage page object */
  inboxPage: InboxPage;
  /** ConversationPage page object */
  conversationPage: ConversationPage;
};

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

export const test = base.extend<PageFixtures & AuthFixtures>({
  // Page object fixtures - use the default page from test context
  loginPage: async ({ page }, use) => {
    const loginPage = new LoginPage(page);
    await use(loginPage);
  },

  dashboardPage: async ({ page }, use) => {
    const dashboardPage = new DashboardPage(page);
    await use(dashboardPage);
  },

  inboxPage: async ({ page }, use) => {
    const inboxPage = new InboxPage(page);
    await use(inboxPage);
  },

  conversationPage: async ({ page }, use) => {
    const conversationPage = new ConversationPage(page);
    await use(conversationPage);
  },

  // Auth fixtures (for multi-role scenarios)
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
