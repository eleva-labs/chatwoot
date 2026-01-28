import { test, expect } from '../../fixtures';

/**
 * Conversation Detail Tests @smoke
 *
 * Tests that verify agents can view and interact with individual conversations.
 * These tests navigate from the dashboard to a specific conversation
 * and verify the conversation view is displayed correctly.
 *
 * Prerequisites:
 * - At least one conversation should exist in the test account
 * - Tests handle empty state gracefully
 */
test.describe('Conversation Detail @smoke', () => {
  test('agent can view conversation details from dashboard', async ({
    dashboardPage,
    conversationPage,
    page,
  }) => {
    // Navigate to dashboard
    await dashboardPage.goto();
    await dashboardPage.expectDashboardLoaded();

    // Check if any conversations exist
    await dashboardPage.waitForConversationsToLoad();
    const hasConversations = await dashboardPage.hasConversations();

    if (!hasConversations) {
      // Skip if no conversations - this is acceptable for a clean environment
      test.skip(!hasConversations, 'No conversations available to test');
      return;
    }

    // Open the first conversation
    await dashboardPage.openFirstConversation();

    // Verify conversation view is loaded
    await conversationPage.expectConversationLoaded();
  });

  test('conversation view displays reply input', async ({
    dashboardPage,
    conversationPage,
  }) => {
    await dashboardPage.goto();
    await dashboardPage.waitForConversationsToLoad();

    const hasConversations = await dashboardPage.hasConversations();
    if (!hasConversations) {
      test.skip(!hasConversations, 'No conversations available to test');
      return;
    }

    await dashboardPage.openFirstConversation();

    // The reply input should be visible for agent to respond
    await conversationPage.expectReplyInputVisible();
  });

  test('conversation URL contains conversation ID', async ({
    dashboardPage,
    page,
  }) => {
    await dashboardPage.goto();
    await dashboardPage.waitForConversationsToLoad();

    const hasConversations = await dashboardPage.hasConversations();
    if (!hasConversations) {
      test.skip(!hasConversations, 'No conversations available to test');
      return;
    }

    await dashboardPage.openFirstConversation();

    // URL should contain /conversations/{id}
    await expect(page).toHaveURL(/\/conversations\/\d+/);
  });

  test('conversation view shows message history area', async ({
    dashboardPage,
    conversationPage,
  }) => {
    await dashboardPage.goto();
    await dashboardPage.waitForConversationsToLoad();

    const hasConversations = await dashboardPage.hasConversations();
    if (!hasConversations) {
      test.skip(!hasConversations, 'No conversations available to test');
      return;
    }

    await dashboardPage.openFirstConversation();
    await conversationPage.expectConversationLoaded();

    // Conversation panel should be visible (contains messages and reply input)
    await expect(
      conversationPage.conversationPanel.or(conversationPage.replyInput)
    ).toBeVisible();
  });
});
