import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Login Page Object
 *
 * Encapsulates interactions with the Chatwoot login page.
 * Selectors are based on the actual Vue component at:
 * app/javascript/v3/views/login/Index.vue
 */
export class LoginPage extends BasePage {
  /** Email input field */
  readonly emailInput: Locator;
  /** Password input field */
  readonly passwordInput: Locator;
  /** Submit/Login button */
  readonly submitButton: Locator;
  /** Error alert message container */
  readonly errorMessage: Locator;
  /** Google OAuth button (if enabled) */
  readonly googleOAuthButton: Locator;
  /** SAML login link (if enabled) */
  readonly samlLoginLink: Locator;

  constructor(page: Page) {
    super(page);

    // Selectors based on actual data-testid attributes in Login.vue
    this.emailInput = page.getByTestId('email_input');
    this.passwordInput = page.getByTestId('password_input');
    this.submitButton = page.getByTestId('submit_button');

    // Error messages are shown via toast/alert, look for common patterns
    this.errorMessage = page.locator('[role="alert"], .alert-wrap, .toast-message');

    // OAuth and SAML options
    this.googleOAuthButton = page.locator('button:has-text("Google")');
    this.samlLoginLink = page.locator('a[href="/app/login/sso"]');
  }

  /**
   * Navigate to the login page
   *
   * This method handles the race condition where the Vue app may not have
   * mounted yet when the DOM is ready. It waits for network activity to
   * settle and retries navigation if the form doesn't appear.
   */
  async goto() {
    const maxRetries = 3;
    let lastError: Error | null = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Navigate to login page
        await super.goto('/app/login');

        // Wait for network to be mostly idle (Vue app needs JS bundles)
        // Use 'load' state which waits for all resources including scripts
        await this.page.waitForLoadState('load');

        // Additional wait for Vue to mount - check for the form with shorter timeout per attempt
        const attemptTimeout = attempt === maxRetries ? 30000 : 10000;
        await this.emailInput.waitFor({ state: 'visible', timeout: attemptTimeout });

        // Success - form is visible
        return;
      } catch (error) {
        lastError = error as Error;

        // Check if we got redirected (e.g., already authenticated)
        const currentUrl = this.page.url();
        if (currentUrl.includes('/dashboard') || currentUrl.includes('/accounts/')) {
          // Already logged in, not an error for login tests that clear storage
          throw new Error(
            `Already authenticated - redirected to ${currentUrl}. ` +
            'Ensure test uses storageState: { cookies: [], origins: [] }'
          );
        }

        if (attempt < maxRetries) {
          // Wait a bit before retry to let any pending operations complete
          await this.page.waitForTimeout(1000);
        }
      }
    }

    throw lastError || new Error('Failed to load login page after retries');
  }

  /**
   * Perform login with the given credentials
   */
  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  /**
   * Assert that login succeeded by checking for dashboard redirect
   */
  async expectLoginSuccess() {
    // After successful login, user is redirected to dashboard
    // URL pattern: /app/accounts/{accountId}/dashboard
    await this.page.waitForURL(/\/app\/accounts\/\d+\/dashboard/, {
      timeout: 30000,
    });
  }

  /**
   * Assert that an error message is visible
   */
  async expectErrorMessage() {
    await expect(this.errorMessage).toBeVisible({ timeout: 5000 });
  }

  /**
   * Assert that a specific error text is shown
   */
  async expectErrorText(text: string | RegExp) {
    const errorLocator = this.page.getByText(text);
    await expect(errorLocator).toBeVisible({ timeout: 5000 });
  }

  /**
   * Check if the login form is visible
   */
  async expectFormVisible() {
    await expect(this.emailInput).toBeVisible();
    await expect(this.passwordInput).toBeVisible();
    await expect(this.submitButton).toBeVisible();
  }

  /**
   * Check if Google OAuth button is available
   */
  async isGoogleOAuthAvailable(): Promise<boolean> {
    return await this.googleOAuthButton.isVisible();
  }

  /**
   * Check if SAML login is available
   */
  async isSamlLoginAvailable(): Promise<boolean> {
    return await this.samlLoginLink.isVisible();
  }
}
