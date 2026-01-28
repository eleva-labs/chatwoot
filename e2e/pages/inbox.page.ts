import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Inbox Page Object
 *
 * Encapsulates interactions with the Chatwoot inbox settings page.
 * This page shows the list of configured inboxes (channels) for the account.
 */
export class InboxPage extends BasePage {
  /** Page header with title */
  readonly pageHeader: Locator;
  /** Header title text */
  readonly headerTitle: Locator;
  /** Inbox table containing all inboxes */
  readonly inboxTable: Locator;
  /** Individual inbox rows in the table */
  readonly inboxRows: Locator;
  /** Create/Add new inbox button */
  readonly createInboxButton: Locator;
  /** Settings layout container */
  readonly settingsLayout: Locator;
  /** No records message when no inboxes exist */
  readonly noRecordsMessage: Locator;
  /** Loading spinner */
  readonly loadingSpinner: Locator;

  constructor(page: Page) {
    super(page);

    // Page structure - use semantic role selectors
    this.settingsLayout = page.getByRole('main');
    this.pageHeader = page.getByRole('banner').or(page.getByRole('heading').first());
    this.headerTitle = page.getByRole('heading', { name: /Inboxes/i });

    // Inbox table - use semantic table role
    this.inboxTable = page.getByRole('table');
    this.inboxRows = page.getByRole('row').filter({ hasNotText: /^Name|^Channel|^Actions/i });

    // Buttons
    this.createInboxButton = page.getByRole('link', { name: /New Inbox|Add Inbox/i });

    // States - use accessible text patterns
    this.noRecordsMessage = page.getByText(/No inboxes|not connected/i);
    this.loadingSpinner = page.getByRole('progressbar').or(page.getByLabel(/loading/i));
  }

  /**
   * Navigate to the inbox settings page
   * URL pattern: /app/accounts/{accountId}/settings/inboxes
   */
  async goto(path?: string) {
    const accountId = 1;
    await super.goto(path ?? `/app/accounts/${accountId}/settings/inboxes`);
    // Wait for either the table or no-records message
    await this.waitForPageLoad();
  }

  /**
   * Navigate to inbox settings for a specific account
   */
  async gotoAccount(accountId: number) {
    await super.goto(`/app/accounts/${accountId}/settings/inboxes`);
    await this.waitForPageLoad();
  }

  /**
   * Wait for the inbox page to fully load
   */
  async waitForInboxPageLoad() {
    // Wait for the header or table to be visible
    await Promise.race([
      this.headerTitle.waitFor({ state: 'visible', timeout: 15000 }),
      this.inboxTable.waitFor({ state: 'visible', timeout: 15000 }),
      this.noRecordsMessage.waitFor({ state: 'visible', timeout: 15000 }),
    ]);
  }

  /**
   * Assert that the inbox list is visible (header with "Inboxes" title)
   */
  async expectInboxListVisible() {
    await expect(this.headerTitle).toBeVisible({ timeout: 15000 });
  }

  /**
   * Assert that the inbox table is visible
   */
  async expectInboxTableVisible() {
    await expect(this.inboxTable).toBeVisible({ timeout: 15000 });
  }

  /**
   * Get the count of inboxes in the list
   */
  async getInboxCount(): Promise<number> {
    // Wait for the table to be visible before counting rows
    await this.inboxTable.waitFor({ state: 'visible' });
    return await this.inboxRows.count();
  }

  /**
   * Check if any inboxes exist
   */
  async hasInboxes(): Promise<boolean> {
    const count = await this.getInboxCount();
    return count > 0;
  }

  /**
   * Select/click an inbox by index (0-based)
   */
  async selectInbox(index: number = 0) {
    await this.inboxRows.nth(index).click();
  }

  /**
   * Get inbox name by index
   */
  async getInboxName(index: number = 0): Promise<string> {
    const row = this.inboxRows.nth(index);
    // Get first cell content which typically contains the inbox name
    const nameCell = row.getByRole('cell').first();
    return await nameCell.textContent() || '';
  }

  /**
   * Click the settings button for an inbox by index
   */
  async openInboxSettings(index: number = 0) {
    const row = this.inboxRows.nth(index);
    // Use role-based selector for settings link
    const settingsButton = row.getByRole('link', { name: /settings|configure|edit/i });
    await settingsButton.click();
    await this.page.waitForURL(/\/settings\/inboxes\/\d+/);
  }

  /**
   * Click the create new inbox button
   */
  async clickCreateInbox() {
    await this.createInboxButton.click();
    await this.page.waitForURL(/\/settings\/inboxes\/new/);
  }

  /**
   * Find inbox by name and return its index, or -1 if not found
   */
  async findInboxByName(name: string): Promise<number> {
    const count = await this.getInboxCount();
    for (let i = 0; i < count; i++) {
      const inboxName = await this.getInboxName(i);
      if (inboxName.toLowerCase().includes(name.toLowerCase())) {
        return i;
      }
    }
    return -1;
  }
}
