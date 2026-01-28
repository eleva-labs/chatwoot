import { test as setup, expect } from '@playwright/test';
import { LoginPage } from './pages/login.page';

/**
 * Authentication Setup
 *
 * This file runs before all test projects to authenticate users and save
 * their session state. The saved state is then reused by test projects
 * to avoid logging in for every test.
 *
 * Required environment variables:
 *   - E2E_ADMIN_EMAIL: Admin user email
 *   - E2E_ADMIN_PASSWORD: Admin user password
 *   - E2E_AGENT_EMAIL: Agent user email
 *   - E2E_AGENT_PASSWORD: Agent user password
 */

const ADMIN_AUTH_FILE = 'e2e/.auth/admin.json';
const AGENT_AUTH_FILE = 'e2e/.auth/agent.json';

setup('authenticate as admin', async ({ page }) => {
  const adminEmail = process.env.E2E_ADMIN_EMAIL;
  const adminPassword = process.env.E2E_ADMIN_PASSWORD;

  if (!adminEmail || !adminPassword) {
    throw new Error(
      'E2E_ADMIN_EMAIL and E2E_ADMIN_PASSWORD environment variables are required. ' +
      'Copy .env.test.example to .env.test and configure credentials.'
    );
  }

  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login(adminEmail, adminPassword);
  await loginPage.expectLoginSuccess();

  // Save authentication state
  await page.context().storageState({ path: ADMIN_AUTH_FILE });
});

setup('authenticate as agent', async ({ page }) => {
  const agentEmail = process.env.E2E_AGENT_EMAIL;
  const agentPassword = process.env.E2E_AGENT_PASSWORD;

  if (!agentEmail || !agentPassword) {
    throw new Error(
      'E2E_AGENT_EMAIL and E2E_AGENT_PASSWORD environment variables are required. ' +
      'Copy .env.test.example to .env.test and configure credentials.'
    );
  }

  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login(agentEmail, agentPassword);
  await loginPage.expectLoginSuccess();

  // Save authentication state
  await page.context().storageState({ path: AGENT_AUTH_FILE });
});
