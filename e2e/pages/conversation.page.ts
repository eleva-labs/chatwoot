import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Conversation Page Object
 *
 * Encapsulates interactions with the Chatwoot conversation view.
 * This page displays an individual conversation with message history
 * and reply functionality.
 */
export class ConversationPage extends BasePage {
  /** Conversation panel container */
  readonly conversationPanel: Locator;
  /** Conversation header with contact info */
  readonly conversationHeader: Locator;
  /** Contact name in header */
  readonly contactName: Locator;
  /** Message list container */
  readonly messageList: Locator;
  /** Individual message items */
  readonly messageItems: Locator;
  /** Reply input textarea/editor */
  readonly replyInput: Locator;
  /** Send message button */
  readonly sendButton: Locator;
  /** Attachment button */
  readonly attachmentButton: Locator;
  /** Emoji picker button */
  readonly emojiButton: Locator;
  /** Assign agent dropdown */
  readonly assignDropdown: Locator;
  /** Status/resolve button */
  readonly statusButton: Locator;
  /** Loading indicator */
  readonly loadingIndicator: Locator;

  constructor(page: Page) {
    super(page);

    // Conversation panel - use role or data-testid
    this.conversationPanel = page.getByRole('main').or(page.getByTestId('conversation-panel'));

    // Header elements
    this.conversationHeader = page.getByRole('banner').or(page.getByTestId('conversation-header'));
    this.contactName = page.getByRole('heading', { level: 3 }).or(page.getByTestId('contact-name'));

    // Message list - messages are in a scrollable container
    this.messageList = page.getByRole('list').or(page.getByTestId('message-list')).or(
      page.locator('[class*="conversation-panel"]')
    );
    this.messageItems = page.getByRole('listitem').or(page.getByTestId('message-item'));

    // Reply box elements - use accessible patterns
    this.replyInput = page.getByRole('textbox', { name: /message|reply|type/i })
      .or(page.getByPlaceholder(/message|reply|type/i))
      .or(page.getByTestId('reply-input'));
    this.sendButton = page.getByRole('button', { name: /send/i })
      .or(page.getByTestId('send-button'))
      .or(page.getByLabel(/send/i));
    this.attachmentButton = page.getByRole('button', { name: /attach|file|upload/i })
      .or(page.getByLabel(/attach/i));
    this.emojiButton = page.getByRole('button', { name: /emoji|emoticon/i })
      .or(page.getByLabel(/emoji/i));

    // Action buttons
    this.assignDropdown = page.getByRole('button', { name: /assign|agent/i })
      .or(page.getByTestId('assign-dropdown'))
      .or(page.getByLabel(/assign/i));
    this.statusButton = page.getByRole('button', { name: /resolve|status|open|close/i })
      .or(page.getByTestId('status-button'));

    // Loading state
    this.loadingIndicator = page.getByRole('progressbar')
      .or(page.getByLabel(/loading/i))
      .or(page.getByText(/loading/i));
  }

  /**
   * Navigate to a specific conversation
   * URL pattern: /app/accounts/{accountId}/conversations/{conversationId}
   */
  async gotoConversation(conversationId: number, accountId: number = 1) {
    await super.goto(`/app/accounts/${accountId}/conversations/${conversationId}`);
    await this.waitForConversationLoad();
  }

  /**
   * Wait for the conversation to fully load
   */
  async waitForConversationLoad() {
    // Wait for either the message list or reply input to be visible
    await this.replyInput.or(this.messageList).waitFor({ state: 'visible', timeout: 15000 });
  }

  /**
   * Send a message in the conversation
   */
  async sendMessage(message: string) {
    await this.replyInput.fill(message);
    await this.sendButton.click();
  }

  /**
   * Assert that a specific message is visible in the conversation
   */
  async expectMessageVisible(message: string) {
    const messageLocator = this.page.getByText(message, { exact: false });
    await expect(messageLocator).toBeVisible({ timeout: 10000 });
  }

  /**
   * Assert that the message was sent successfully
   * Checks for message text in the conversation
   */
  async expectMessageSent(message: string) {
    // Wait for the message to appear in the conversation
    await this.expectMessageVisible(message);
  }

  /**
   * Assert that the reply input is visible and ready for input
   */
  async expectReplyInputVisible() {
    await expect(this.replyInput).toBeVisible({ timeout: 10000 });
  }

  /**
   * Assert that the conversation panel is loaded
   */
  async expectConversationLoaded() {
    await expect(this.replyInput.or(this.conversationPanel)).toBeVisible({ timeout: 15000 });
  }

  /**
   * Get the count of visible messages
   */
  async getMessageCount(): Promise<number> {
    await this.messageList.waitFor({ state: 'visible' });
    return await this.messageItems.count();
  }

  /**
   * Get the text content of a message by index (0 = oldest visible)
   */
  async getMessageText(index: number = 0): Promise<string> {
    const message = this.messageItems.nth(index);
    return await message.textContent() || '';
  }

  /**
   * Get the last message in the conversation
   */
  async getLastMessageText(): Promise<string> {
    const count = await this.getMessageCount();
    if (count === 0) return '';
    return await this.getMessageText(count - 1);
  }

  /**
   * Assign conversation to an agent by name
   */
  async assignToAgent(agentName: string) {
    await this.assignDropdown.click();
    await this.page.getByRole('option', { name: new RegExp(agentName, 'i') })
      .or(this.page.getByText(agentName))
      .click();
  }

  /**
   * Assert that conversation is assigned to a specific agent
   */
  async expectAssignedTo(agentName: string) {
    const assigneeIndicator = this.page.getByText(agentName, { exact: false });
    await expect(assigneeIndicator).toBeVisible({ timeout: 5000 });
  }

  /**
   * Resolve/close the conversation
   */
  async resolveConversation() {
    await this.statusButton.click();
    // Wait for status change
    await this.page.waitForResponse(response =>
      response.url().includes('/conversations/') &&
      response.request().method() === 'PATCH'
    );
  }

  /**
   * Check if conversation is in resolved state
   */
  async isResolved(): Promise<boolean> {
    const resolvedIndicator = this.page.getByText(/resolved|closed/i);
    return await resolvedIndicator.isVisible();
  }

  /**
   * Add an attachment to the message
   * @param filePath Path to the file to attach
   */
  async addAttachment(filePath: string) {
    // Get the file input (hidden input element)
    const fileInput = this.page.locator('input[type="file"]');
    await fileInput.setInputFiles(filePath);
  }

  /**
   * Open emoji picker
   */
  async openEmojiPicker() {
    await this.emojiButton.click();
    await this.page.getByRole('dialog').or(this.page.getByLabel(/emoji picker/i)).waitFor({ state: 'visible' });
  }

  /**
   * Type in the reply input without sending
   */
  async typeMessage(message: string) {
    await this.replyInput.fill(message);
  }

  /**
   * Clear the reply input
   */
  async clearReplyInput() {
    await this.replyInput.clear();
  }
}
