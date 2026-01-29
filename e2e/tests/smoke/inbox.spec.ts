import { test, expect } from '../../fixtures';

/**
 * Inbox Verification Tests @smoke
 *
 * Smoke tests that verify the inbox settings page is accessible
 * and displays correctly for authenticated users.
 *
 * These tests use the stored auth state (agent by default).
 */
// TODO: Fix - inbox navigation and selectors need updating
test.describe.skip('Inbox Verification @smoke', () => {
  test('agent can navigate to inbox settings and see inbox list', async ({
    dashboardPage,
    inboxPage,
    page,
  }) => {
    // Start at the dashboard
    await dashboardPage.goto();
    await dashboardPage.expectSidebarVisible();

    // Navigate to inbox settings
    await dashboardPage.navigateToInboxes();

    // Verify inbox page loaded
    await inboxPage.expectInboxListVisible();

    // URL should contain /settings/inboxes
    await expect(page).toHaveURL(/\/settings\/inboxes/);
  });

  test('inbox settings page displays header correctly', async ({
    inboxPage,
  }) => {
    // Navigate directly to inbox settings
    await inboxPage.goto();

    // Verify the header with "Inboxes" title is visible
    await inboxPage.expectInboxListVisible();

    // Page should have the settings layout
    await expect(inboxPage.settingsLayout).toBeVisible();
  });

  test('inbox list shows inboxes or empty state', async ({ inboxPage }) => {
    await inboxPage.goto();
    await inboxPage.waitForInboxPageLoad();

    // Either inboxes exist (table visible) or no-records message shows
    const hasInboxes = await inboxPage.hasInboxes();

    if (hasInboxes) {
      // If inboxes exist, table should be visible
      await inboxPage.expectInboxTableVisible();

      // Should have at least one row
      const count = await inboxPage.getInboxCount();
      expect(count).toBeGreaterThan(0);
    } else {
      // If no inboxes, should show appropriate message or empty table
      // The page should still have loaded correctly
      await inboxPage.expectInboxListVisible();
    }
  });
});
