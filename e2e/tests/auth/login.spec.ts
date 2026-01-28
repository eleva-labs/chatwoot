import { test, expect } from '@playwright/test';
import { LoginPage } from '../../pages';

/**
 * Login Flow Tests @smoke
 *
 * Tests the authentication flow including:
 * - Valid credentials login
 * - Invalid credentials error handling
 */
test.describe('Login Flow @smoke', () => {
  // These tests don't use stored auth state - they test the login process itself
  test.use({ storageState: { cookies: [], origins: [] } });

  test('admin can login with valid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);

    // Navigate to login page
    await loginPage.goto();
    await loginPage.expectFormVisible();

    // Get credentials from environment
    const adminEmail = process.env.E2E_ADMIN_EMAIL;
    const adminPassword = process.env.E2E_ADMIN_PASSWORD;

    if (!adminEmail || !adminPassword) {
      test.skip(true, 'E2E_ADMIN_EMAIL and E2E_ADMIN_PASSWORD not set');
      return;
    }

    // Perform login
    await loginPage.login(adminEmail, adminPassword);

    // Verify successful login - redirects to dashboard
    await loginPage.expectLoginSuccess();

    // Additional verification: URL should contain /dashboard
    await expect(page).toHaveURL(/\/dashboard/);
  });

  test('shows error for invalid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);

    // Navigate to login page
    await loginPage.goto();
    await loginPage.expectFormVisible();

    // Attempt login with invalid credentials
    await loginPage.login('invalid@example.com', 'wrongpassword123');

    // Should still be on login page after failed login attempt
    // Web-first assertion auto-waits for URL condition
    await expect(page).toHaveURL(/\/login/);

    // Error message should be visible (toast or alert)
    // Chatwoot shows errors via toast notifications using role="alert"
    // Use web-first assertion with soft check - if no error visible, being on login page is sufficient
    const errorMessage = page.getByRole('alert').or(page.getByText(/invalid|error|unauthorized|incorrect/i));
    await expect.soft(errorMessage).toBeVisible({ timeout: 3000 });

    // Final assertion: we must still be on the login page (confirms login failed)
    await expect(page).toHaveURL(/\/login/);
  });

  test('login form displays all required elements', async ({ page }) => {
    const loginPage = new LoginPage(page);

    await loginPage.goto();

    // Verify all form elements are present
    await loginPage.expectFormVisible();
    await expect(loginPage.emailInput).toBeEnabled();
    await expect(loginPage.passwordInput).toBeEnabled();
    await expect(loginPage.submitButton).toBeEnabled();
  });
});
