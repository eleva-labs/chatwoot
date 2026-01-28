import { test, expect } from '../../fixtures';

/**
 * Conversation List Tests @smoke
 *
 * Smoke tests that verify the conversation list is accessible
 * and displays correctly for authenticated users.
 *
 * These tests use the stored auth state (agent by default).
 */
test.describe('Conversation List @smoke', () => {
  test('agent can view the conversation list on dashboard', async ({
    dashboardPage,
  }) => {
    // Navigate to dashboard (which shows conversation list)
    await dashboardPage.goto();

    // Wait for dashboard to load
    await dashboardPage.expectDashboardLoaded();

    // Conversation list should be visible
    await dashboardPage.expectConversationListVisible();
  });

  test('dashboard displays sidebar navigation', async ({ dashboardPage }) => {
    await dashboardPage.goto();

    // Sidebar should be visible
    await dashboardPage.expectSidebarVisible();

    // Sidebar should contain navigation elements
    await expect(dashboardPage.sidebar).toBeVisible();
  });

  test('conversation list shows conversations or empty state', async ({
    dashboardPage,
  }) => {
    await dashboardPage.goto();
    await dashboardPage.waitForConversationsToLoad();

    const hasConversations = await dashboardPage.hasConversations();

    if (hasConversations) {
      // If conversations exist, we should be able to count them
      const count = await dashboardPage.getConversationCount();
      expect(count).toBeGreaterThan(0);
    } else {
      // If no conversations, the conversation list area should still be visible
      // (might show empty state message)
      await dashboardPage.expectConversationListVisible();
    }
  });

  test('agent can navigate between conversations and settings', async ({
    dashboardPage,
    page,
  }) => {
    // Start at dashboard
    await dashboardPage.goto();
    await dashboardPage.expectDashboardLoaded();

    // Navigate to inbox settings
    await dashboardPage.navigateToInboxes();
    await expect(page).toHaveURL(/\/settings\/inboxes/);

    // Navigate back to conversations (by going to dashboard)
    await dashboardPage.goto();
    await dashboardPage.expectConversationListVisible();
  });
});
