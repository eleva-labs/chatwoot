import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Dashboard Page Object
 *
 * Encapsulates interactions with the Chatwoot dashboard.
 * This is the main landing page after login, containing the sidebar
 * navigation and conversation list.
 */
export class DashboardPage extends BasePage {
  /** Main sidebar navigation */
  readonly sidebar: Locator;
  /** Conversations section in sidebar */
  readonly conversationsNavItem: Locator;
  /** Contacts section in sidebar */
  readonly contactsNavItem: Locator;
  /** Settings section in sidebar */
  readonly settingsNavItem: Locator;
  /** Inboxes link in settings */
  readonly inboxesNavItem: Locator;
  /** Conversation list container */
  readonly conversationList: Locator;
  /** Individual conversation items in the list */
  readonly conversationItems: Locator;
  /** First conversation in the list */
  readonly firstConversation: Locator;
  /** Chat list header */
  readonly chatListHeader: Locator;
  /** Profile menu in sidebar */
  readonly profileMenu: Locator;
  /** Account switcher */
  readonly accountSwitcher: Locator;
  /** Search input in sidebar */
  readonly searchLink: Locator;

  constructor(page: Page) {
    super(page);

    // Sidebar navigation - use semantic role selector
    this.sidebar = page.getByRole('complementary');
    this.conversationsNavItem = page.getByRole('link', { name: /All Conversations|Conversations/i }).first();
    this.contactsNavItem = page.getByRole('link', { name: /All Contacts|Contacts/i }).first();
    this.settingsNavItem = page.getByRole('link', { name: /Settings/i }).first();
    this.inboxesNavItem = page.getByRole('link', { name: /Inboxes/i });

    // Conversation list - use data-testid when available, fall back to role-based selectors
    this.conversationList = page.getByTestId('conversation-list').or(page.getByRole('list').filter({ has: page.getByRole('button') }));
    this.conversationItems = page.getByRole('button').filter({ hasText: /.+/ }).locator('visible=true');
    this.firstConversation = this.conversationItems.first();

    // Chat list header - use heading role
    this.chatListHeader = page.getByRole('heading', { level: 2 }).or(page.getByRole('banner'));

    // Profile and account - use accessible patterns
    this.profileMenu = page.getByRole('button', { name: /profile|account|menu/i }).or(page.getByLabel(/profile/i));
    this.accountSwitcher = page.getByRole('button', { name: /switch.*account|account.*switch/i }).or(page.getByLabel(/account/i));
    this.searchLink = page.getByRole('link', { name: /search/i }).or(page.getByLabel(/search/i));
  }

  /**
   * Navigate to the dashboard
   * URL pattern: /app/accounts/{accountId}/dashboard
   */
  async goto(path?: string) {
    const accountId = 1;
    await super.goto(path ?? `/app/accounts/${accountId}/dashboard`);
    // Wait for the sidebar to be visible
    await this.sidebar.waitFor({ state: 'visible', timeout: 30000 });
  }

  /**
   * Navigate to dashboard for a specific account
   */
  async gotoAccount(accountId: number) {
    await super.goto(`/app/accounts/${accountId}/dashboard`);
    await this.sidebar.waitFor({ state: 'visible', timeout: 30000 });
  }

  /**
   * Navigate to the conversations page (home)
   */
  async gotoConversations(accountId: number = 1) {
    await this.gotoAccount(accountId);
  }

  /**
   * Navigate to Settings > Inboxes
   */
  async navigateToInboxes() {
    // Click on Settings in the sidebar
    await this.settingsNavItem.click();
    // Wait for settings submenu to expand and click Inboxes
    await this.inboxesNavItem.click();
    await this.page.waitForURL(/\/settings\/inboxes/);
  }

  /**
   * Navigate to Contacts
   */
  async navigateToContacts() {
    await this.contactsNavItem.click();
    await this.page.waitForURL(/\/contacts/);
  }

  /**
   * Navigate to All Conversations
   */
  async navigateToAllConversations() {
    await this.conversationsNavItem.click();
    // Wait for the conversations page
    await this.page.waitForURL(/\/dashboard|\/conversations/);
  }

  /**
   * Open the first conversation in the list
   */
  async openFirstConversation() {
    await this.firstConversation.waitFor({ state: 'visible', timeout: 10000 });
    await this.firstConversation.click();
    // Wait for conversation view to load - URL changes to include conversation ID
    await this.page.waitForURL(/\/conversations\/\d+/);
  }

  /**
   * Open a conversation by index (0-based)
   */
  async openConversationByIndex(index: number) {
    const conversation = this.conversationItems.nth(index);
    await conversation.waitFor({ state: 'visible', timeout: 10000 });
    await conversation.click();
    await this.page.waitForURL(/\/conversations\/\d+/);
  }

  /**
   * Assert that the conversation list is visible
   */
  async expectConversationListVisible() {
    await expect(this.conversationList).toBeVisible({ timeout: 15000 });
  }

  /**
   * Assert that the sidebar is visible
   */
  async expectSidebarVisible() {
    await expect(this.sidebar).toBeVisible({ timeout: 10000 });
  }

  /**
   * Assert that the dashboard has loaded
   */
  async expectDashboardLoaded() {
    await expect(this.sidebar).toBeVisible({ timeout: 15000 });
  }

  /**
   * Get the count of conversations in the list
   */
  async getConversationCount(): Promise<number> {
    return await this.conversationItems.count();
  }

  /**
   * Check if conversations exist in the list
   */
  async hasConversations(): Promise<boolean> {
    const count = await this.getConversationCount();
    return count > 0;
  }

  /**
   * Wait for conversations to load
   */
  async waitForConversationsToLoad() {
    // Wait for either conversations to appear or empty state message
    // Using web-first assertions which auto-wait
    await this.conversationList.or(this.page.getByText(/no conversations|empty/i)).waitFor({ state: 'visible', timeout: 15000 });
  }
}
