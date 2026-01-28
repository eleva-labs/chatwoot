import { test, expect } from '../../fixtures';
import { testMessage } from '../../utils/data.helper';

/**
 * Conversation Reply Tests @smoke
 *
 * Tests that verify agents can send messages/replies in conversations.
 * Uses unique message identifiers to verify the message appears.
 *
 * Prerequisites:
 * - At least one conversation should exist in the test account
 * - Tests handle empty state gracefully
 */
test.describe('Conversation Reply @smoke', () => {
  test('agent can type message in reply input', async ({
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

    // Open a conversation
    await dashboardPage.openFirstConversation();
    await conversationPage.expectReplyInputVisible();

    // Type a message without sending
    const testText = 'Test typing - will not send';
    await conversationPage.typeMessage(testText);

    // Verify input has the text
    await expect(conversationPage.replyInput).toHaveValue(testText);
  });

  test('agent can send reply message in conversation', async ({
    dashboardPage,
    conversationPage,
    page,
  }) => {
    await dashboardPage.goto();
    await dashboardPage.waitForConversationsToLoad();

    const hasConversations = await dashboardPage.hasConversations();
    if (!hasConversations) {
      test.skip(!hasConversations, 'No conversations available to test');
      return;
    }

    // Open a conversation
    await dashboardPage.openFirstConversation();
    await conversationPage.expectReplyInputVisible();

    // Generate unique message to identify it later
    const uniqueMessage = testMessage('E2E reply test');

    // Send the message
    await conversationPage.sendMessage(uniqueMessage);

    // Verify the message appears in the conversation
    // The message should be visible after sending
    await conversationPage.expectMessageSent(uniqueMessage);
  });

  test('reply input is cleared after sending message', async ({
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
    await conversationPage.expectReplyInputVisible();

    const uniqueMessage = testMessage('E2E clear test');
    await conversationPage.sendMessage(uniqueMessage);

    // After sending, the input should be cleared
    // Use a soft assertion since the message might still be sending
    await expect.soft(conversationPage.replyInput).toHaveValue('');

    // Verify message was sent
    await conversationPage.expectMessageSent(uniqueMessage);
  });

  test('send button is present in conversation view', async ({
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
    await conversationPage.expectReplyInputVisible();

    // Send button should be visible
    await expect(conversationPage.sendButton).toBeVisible();
  });
});
