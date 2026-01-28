# E2E Testing Patterns (Playwright)

## Table of Contents
1. [Setup and Configuration](#setup-and-configuration)
2. [Testing Framework and Tools](#testing-framework-and-tools)
3. [Test Structure and Organization](#test-structure-and-organization)
4. [Page Object Model Pattern](#page-object-model-pattern)
5. [Fixtures Pattern](#fixtures-pattern)
6. [Authentication Pattern](#authentication-pattern)
7. [Selector Strategy](#selector-strategy)
8. [Assertion Patterns](#assertion-patterns)
9. [Wait Strategies](#wait-strategies)
10. [Test Isolation](#test-isolation)
11. [Running Tests](#running-tests)
12. [Common Patterns Summary](#common-patterns-summary)
13. [Troubleshooting](#troubleshooting)

---

## Setup and Configuration

### Configuration Files

#### `playwright.config.ts`

The main Playwright configuration file at the project root:

```typescript
import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';
import path from 'path';

// Load base .env (same as Rails/Docker)
dotenv.config({ path: path.resolve(__dirname, '.env') });

// Load test-specific overrides
dotenv.config({
  path: path.resolve(__dirname, '.env.test'),
  override: true
});

// Environment detection
const BASE_URL = process.env.BASE_URL
  ?? process.env.FRONTEND_URL
  ?? 'http://localhost:3000';
const IS_CI = !!process.env.CI;
const IS_LOCAL = BASE_URL.includes('localhost') || BASE_URL.includes('0.0.0.0');

export default defineConfig({
  testDir: './e2e/tests',
  fullyParallel: true,
  forbidOnly: IS_CI,
  retries: IS_CI ? 2 : 0,
  workers: IS_CI ? 1 : undefined,

  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ...(IS_CI ? [['github'] as const] : []),
  ],

  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: IS_CI ? 'retain-on-failure' : 'off',
    viewport: { width: 1280, height: 720 },
    actionTimeout: 10000,
    navigationTimeout: 30000,
    testIdAttribute: 'data-testid',
  },

  projects: [
    // Setup project - authenticate users
    {
      name: 'setup',
      testDir: './e2e',
      testMatch: /.*\.setup\.ts/,
    },

    // Main tests with agent auth (default)
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'e2e/.auth/agent.json',
      },
      dependencies: ['setup'],
    },

    // Admin-only tests
    {
      name: 'chromium-admin',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'e2e/.auth/admin.json',
      },
      dependencies: ['setup'],
      testMatch: /.*\.admin\.spec\.ts/,
    },
  ],

  // Only use webServer for local development (not CI)
  ...(IS_LOCAL && !IS_CI
    ? {
        webServer: {
          command: 'docker compose up',
          url: BASE_URL,
          reuseExistingServer: true,
          timeout: 120000,
        },
      }
    : {}),

  outputDir: 'test-results',
  timeout: 60000,
  expect: { timeout: 10000 },
});
```

**Key Configuration Options:**

| Option | Purpose |
|--------|---------|
| `testDir` | Directory containing test files |
| `fullyParallel` | Run tests in parallel for faster execution |
| `forbidOnly` | Fail CI if `test.only` is left in code |
| `retries` | Retry failed tests in CI to handle flakiness |
| `workers` | Number of parallel workers (1 in CI for stability) |
| `testIdAttribute` | Custom attribute for `getByTestId()` selector |
| `trace` | Capture traces for debugging failures |
| `screenshot` | Take screenshots on failure |
| `video` | Record video on failure (CI only) |

### Environment Variables

#### `.env.test.example` (Template)

```env
# Playwright E2E Test Environment Variables
# ==========================================
# Copy this file to .env.test and fill in your values

# Test User Credentials
# ---------------------
# Admin user (administrator role)
E2E_ADMIN_EMAIL=e2e-admin@test.chatwoot.local
E2E_ADMIN_PASSWORD=Password1!

# Agent user (agent role)
E2E_AGENT_EMAIL=e2e-agent@test.chatwoot.local
E2E_AGENT_PASSWORD=Password1!

# Override base URL (optional - defaults to FRONTEND_URL from .env)
# BASE_URL=http://localhost:3000

# For dev environment testing
# BASE_URL=https://dev.app.chatscommerce.com
```

### Browser Installation

```bash
# Install Playwright and browsers
pnpm add -D @playwright/test dotenv

# Install Chromium only (faster, recommended for development)
pnpm exec playwright install chromium

# Install all browsers (for cross-browser testing)
pnpm exec playwright install

# Install browsers with system dependencies (CI)
pnpm exec playwright install --with-deps chromium
```

### Project Structure

```
chatwoot/
├── e2e/                              # Playwright E2E tests
│   ├── .auth/                        # Auth state files (gitignored)
│   │   ├── admin.json                # Admin user session
│   │   └── agent.json                # Agent user session
│   ├── fixtures/                     # Custom Playwright fixtures
│   │   ├── auth.fixture.ts           # Role-based auth fixtures
│   │   ├── pages.fixture.ts          # Page object fixtures
│   │   └── index.ts                  # Combined fixture exports
│   ├── pages/                        # Page Object Models
│   │   ├── base.page.ts              # Base page class
│   │   ├── login.page.ts             # Login page
│   │   ├── dashboard.page.ts         # Dashboard/conversations
│   │   ├── conversation.page.ts      # Conversation view
│   │   ├── inbox.page.ts             # Inbox management
│   │   └── index.ts                  # Page exports
│   ├── tests/                        # Test specifications
│   │   ├── auth/                     # Authentication tests
│   │   │   └── login.spec.ts         # Login flow tests
│   │   ├── conversations/            # Conversation tests
│   │   │   ├── reply.spec.ts         # Reply to conversation
│   │   │   └── assign.admin.spec.ts  # Admin assignment tests
│   │   ├── inbox/                    # Inbox tests
│   │   │   └── inbox.spec.ts         # Inbox management
│   │   └── smoke/                    # Quick smoke tests
│   │       └── health.spec.ts        # App health check
│   ├── utils/                        # Helper utilities
│   │   ├── data.helper.ts            # Test data generators
│   │   └── env.helper.ts             # Environment helpers
│   ├── auth.setup.ts                 # Authentication setup project
│   ├── global-setup.ts               # Global setup (optional)
│   └── global-teardown.ts            # Global teardown (optional)
├── playwright.config.ts              # Main Playwright configuration
├── .env.test.example                 # Template for E2E credentials
├── playwright-report/                # Generated reports (gitignored)
└── test-results/                     # Test artifacts (gitignored)
```

---

## Testing Framework and Tools

### Core Testing Tools

| Tool | Purpose |
|------|---------|
| **@playwright/test** | Main test runner and assertion library |
| **Page** | Browser page interface for interactions |
| **Locator** | Element locator with auto-waiting |
| **expect** | Web-first assertions with auto-retry |
| **BrowserContext** | Isolated browser session with cookies/storage |
| **fixtures** | Dependency injection for test setup |
| **dotenv** | Environment variable management |

### Import Patterns

```typescript
// Standard test file imports
import { test, expect } from '@playwright/test';

// Using custom fixtures (recommended)
import { test, expect } from '../../fixtures';

// Page Object imports
import { LoginPage, DashboardPage } from '../../pages';

// Utility imports
import { TestData, generateUniqueEmail } from '../../utils/data.helper';
```

---

## Test Structure and Organization

### Directory Structure

```
e2e/tests/
├── auth/                         # Authentication tests
│   └── login.spec.ts
├── conversations/                # Conversation-related tests
│   ├── create.spec.ts
│   ├── reply.spec.ts
│   └── assign.admin.spec.ts      # Admin-only tests (uses admin auth)
├── inbox/                        # Inbox management tests
│   └── inbox.spec.ts
└── smoke/                        # Quick smoke tests for CI
    ├── health.spec.ts
    └── conversations.spec.ts
```

### File Naming Conventions

| Pattern | Description | Auth State |
|---------|-------------|------------|
| `*.spec.ts` | Standard tests | Agent (default) |
| `*.admin.spec.ts` | Admin-only tests | Admin |
| `*.setup.ts` | Setup projects | None (creates auth) |

### Test File Structure

```typescript
import { test, expect } from '../../fixtures';

/**
 * Test Suite Description
 *
 * Brief description of what this test suite covers.
 * Include any tags like @smoke, @regression in the describe block.
 */
test.describe('Feature Name @smoke', () => {
  // Optional: Override storage state for login tests
  // test.use({ storageState: { cookies: [], origins: [] } });

  test.beforeEach(async ({ page }) => {
    // Common setup for all tests in this describe block
  });

  test('should perform expected behavior', async ({ page, dashboardPage }) => {
    // Arrange: Set up test conditions
    await dashboardPage.goto();

    // Act: Perform the action being tested
    await dashboardPage.openFirstConversation();

    // Assert: Verify the expected outcome
    await expect(page.getByRole('textbox', { name: 'Message' })).toBeVisible();
  });

  test('should handle edge case', async ({ page }) => {
    // Test implementation
  });
});
```

### Test Tags

Use tags in describe blocks for test filtering:

```typescript
test.describe('Critical Path @smoke', () => {
  // These tests run on every PR
});

test.describe('Full Coverage @regression', () => {
  // These tests run on scheduled builds
});

test.describe('Admin Features @admin', () => {
  // These tests require admin authentication
});
```

Run tagged tests:

```bash
pnpm e2e -- --grep @smoke
pnpm e2e -- --grep @regression
pnpm e2e -- --grep-invert @slow
```

---

## Page Object Model Pattern

### BasePage Class

All page objects extend the BasePage class for common functionality:

```typescript
// e2e/pages/base.page.ts
import { Page, Locator } from '@playwright/test';

export class BasePage {
  readonly page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async goto(path: string = '/') {
    await this.page.goto(path);
  }

  async waitForPageLoad() {
    await this.page.waitForLoadState('networkidle');
  }

  getByTestId(testId: string): Locator {
    return this.page.getByTestId(testId);
  }

  async takeScreenshot(name: string) {
    await this.page.screenshot({ path: `test-results/screenshots/${name}.png` });
  }
}
```

### Page Object Structure

A well-structured page object includes:

1. **Locator definitions** as readonly properties
2. **Constructor** that initializes locators
3. **Action methods** for user interactions
4. **Assertion methods** (prefixed with `expect`) for verification

```typescript
// e2e/pages/login.page.ts
import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

export class LoginPage extends BasePage {
  // Locator definitions - use readonly for immutability
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    super(page);

    // PREFERRED: Use data-testid selectors (most stable)
    this.emailInput = page.getByTestId('email_input');
    this.passwordInput = page.getByTestId('password_input');
    this.submitButton = page.getByTestId('submit_button');

    // FALLBACK: Use role-based selector for error alerts
    this.errorMessage = page.getByRole('alert');
  }

  // Navigation method
  async goto() {
    await super.goto('/app/login');
    await this.emailInput.waitFor({ state: 'visible', timeout: 10000 });
  }

  // Action methods - perform user interactions
  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  // Assertion methods - verify expected state (prefix with 'expect')
  async expectLoginSuccess() {
    await this.page.waitForURL(/\/app\/accounts\/\d+\/dashboard/, {
      timeout: 30000,
    });
  }

  async expectErrorMessage() {
    await expect(this.errorMessage).toBeVisible({ timeout: 5000 });
  }

  async expectFormVisible() {
    await expect(this.emailInput).toBeVisible();
    await expect(this.passwordInput).toBeVisible();
    await expect(this.submitButton).toBeVisible();
  }
}
```

### Selector Strategy in Page Objects

**Priority Order** (most stable to least stable):

| Priority | Selector Type | Example | When to Use |
|----------|--------------|---------|-------------|
| 1 | `getByTestId()` | `page.getByTestId('submit_button')` | Custom elements, forms |
| 2 | `getByRole()` | `page.getByRole('button', { name: 'Save' })` | Semantic elements |
| 3 | `getByLabel()` | `page.getByLabel('Email')` | Form fields with labels |
| 4 | `getByPlaceholder()` | `page.getByPlaceholder('Search...')` | Input fields |
| 5 | `getByText()` | `page.getByText('Welcome')` | Static text content |
| 6 | CSS/XPath | `page.locator('.class-name')` | Last resort only |

### When to Create Page Objects

**DO create page objects for:**
- Pages with multiple interactions (forms, dashboards)
- Reusable navigation flows
- Complex components used across tests

**DON'T create page objects for:**
- One-off test scenarios
- Simple single-element assertions
- Tests that don't reuse interactions

### Page Object Export Pattern

```typescript
// e2e/pages/index.ts
export { BasePage } from './base.page';
export { LoginPage } from './login.page';
export { DashboardPage } from './dashboard.page';
export { InboxPage } from './inbox.page';
export { ConversationPage } from './conversation.page';
```

---

## Fixtures Pattern

### Auth Fixtures

Provide pre-authenticated browser contexts for different user roles:

```typescript
// e2e/fixtures/auth.fixture.ts
import { test as base, Page, BrowserContext } from '@playwright/test';

type AuthFixtures = {
  adminContext: BrowserContext;
  agentContext: BrowserContext;
  adminPage: Page;
  agentPage: Page;
};

export const test = base.extend<AuthFixtures>({
  // Admin browser context with pre-loaded auth state
  adminContext: async ({ browser }, use) => {
    const context = await browser.newContext({
      storageState: 'e2e/.auth/admin.json',
    });
    await use(context);
    await context.close();
  },

  // Agent browser context with pre-loaded auth state
  agentContext: async ({ browser }, use) => {
    const context = await browser.newContext({
      storageState: 'e2e/.auth/agent.json',
    });
    await use(context);
    await context.close();
  },

  // Page from admin context
  adminPage: async ({ adminContext }, use) => {
    const page = await adminContext.newPage();
    await use(page);
    await page.close();
  },

  // Page from agent context
  agentPage: async ({ agentContext }, use) => {
    const page = await agentContext.newPage();
    await use(page);
    await page.close();
  },
});

export { expect } from '@playwright/test';
```

### Page Object Fixtures

Inject page objects as fixtures for cleaner test code:

```typescript
// e2e/fixtures/pages.fixture.ts
import { test as authTest } from './auth.fixture';
import { LoginPage, DashboardPage, InboxPage } from '../pages';

type PageFixtures = {
  loginPage: LoginPage;
  dashboardPage: DashboardPage;
  inboxPage: InboxPage;
};

export const test = authTest.extend<PageFixtures>({
  loginPage: async ({ page }, use) => {
    await use(new LoginPage(page));
  },

  dashboardPage: async ({ page }, use) => {
    await use(new DashboardPage(page));
  },

  inboxPage: async ({ page }, use) => {
    await use(new InboxPage(page));
  },
});

export { expect } from '@playwright/test';
```

### Combined Fixtures Export

```typescript
// e2e/fixtures/index.ts
export { test, expect } from './pages.fixture';

// Re-export auth fixture for tests that need only auth fixtures
export { test as authTest, expect as authExpect } from './auth.fixture';
```

### Using Fixtures in Tests

```typescript
import { test, expect } from '../../fixtures';

test.describe('Dashboard Features', () => {
  test('agent can view conversation list', async ({ dashboardPage }) => {
    // dashboardPage is automatically injected
    await dashboardPage.goto();
    await dashboardPage.expectConversationListVisible();
  });

  test('admin can access settings', async ({ adminPage }) => {
    // adminPage uses admin authentication
    await adminPage.goto('/app/accounts/1/settings');
    await expect(adminPage.getByRole('heading', { name: 'Settings' })).toBeVisible();
  });
});
```

### Custom Fixture Creation

Create fixtures for common test setup:

```typescript
// e2e/fixtures/data.fixture.ts
import { test as base } from '@playwright/test';
import { TestData } from '../utils/data.helper';

type DataFixtures = {
  testConversation: { id: number; subject: string };
  testContact: { email: string; name: string };
};

export const test = base.extend<DataFixtures>({
  testConversation: async ({ request }, use) => {
    // Create test conversation via API
    const response = await request.post('/api/v1/conversations', {
      data: {
        inbox_id: 1,
        contact: { email: TestData.uniqueEmail() },
      },
    });
    const conversation = await response.json();

    await use(conversation);

    // Cleanup after test
    await request.delete(`/api/v1/conversations/${conversation.id}`);
  },

  testContact: async ({}, use) => {
    // Generate unique test data
    const contact = {
      email: TestData.uniqueEmail(),
      name: TestData.uniqueName(),
    };
    await use(contact);
  },
});
```

---

## Authentication Pattern

### Setup Project Pattern (Recommended)

The setup project runs before all other test projects to authenticate users:

```typescript
// e2e/auth.setup.ts
import { test as setup, expect } from '@playwright/test';
import { LoginPage } from './pages/login.page';

const ADMIN_AUTH_FILE = 'e2e/.auth/admin.json';
const AGENT_AUTH_FILE = 'e2e/.auth/agent.json';

setup('authenticate as admin', async ({ page }) => {
  const adminEmail = process.env.E2E_ADMIN_EMAIL;
  const adminPassword = process.env.E2E_ADMIN_PASSWORD;

  if (!adminEmail || !adminPassword) {
    throw new Error(
      'E2E_ADMIN_EMAIL and E2E_ADMIN_PASSWORD environment variables are required.'
    );
  }

  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login(adminEmail, adminPassword);
  await loginPage.expectLoginSuccess();

  // Save authentication state for reuse
  await page.context().storageState({ path: ADMIN_AUTH_FILE });
});

setup('authenticate as agent', async ({ page }) => {
  const agentEmail = process.env.E2E_AGENT_EMAIL;
  const agentPassword = process.env.E2E_AGENT_PASSWORD;

  if (!agentEmail || !agentPassword) {
    throw new Error(
      'E2E_AGENT_EMAIL and E2E_AGENT_PASSWORD environment variables are required.'
    );
  }

  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login(agentEmail, agentPassword);
  await loginPage.expectLoginSuccess();

  await page.context().storageState({ path: AGENT_AUTH_FILE });
});
```

### storageState Usage

The `storageState` feature saves and restores:
- Cookies
- Local storage
- Session storage (with additional config)

```typescript
// In playwright.config.ts - project configuration
projects: [
  // Setup creates auth state files
  {
    name: 'setup',
    testDir: './e2e',
    testMatch: /.*\.setup\.ts/,
  },

  // Tests use the saved auth state
  {
    name: 'chromium',
    use: {
      ...devices['Desktop Chrome'],
      storageState: 'e2e/.auth/agent.json',
    },
    dependencies: ['setup'], // Ensures setup runs first
  },
],
```

### Multi-Role Testing

Test features that require different user roles:

```typescript
import { test, expect } from '../../fixtures';

test.describe('Role-Based Access', () => {
  test('admin can access settings', async ({ adminPage }) => {
    await adminPage.goto('/app/accounts/1/settings');
    await expect(adminPage.getByRole('heading', { name: 'Settings' })).toBeVisible();
  });

  test('agent cannot access admin settings', async ({ agentPage }) => {
    await agentPage.goto('/app/accounts/1/settings/agents');
    // Should redirect or show error
    await expect(agentPage).not.toHaveURL(/\/settings\/agents/);
  });

  test('admin assigns conversation to agent', async ({ adminPage, agentPage }) => {
    // Admin performs assignment
    await adminPage.goto('/app/accounts/1/conversations/1');
    await adminPage.getByRole('button', { name: 'Assign' }).click();
    await adminPage.getByRole('option', { name: 'Test Agent' }).click();

    // Agent verifies assignment
    await agentPage.goto('/app/accounts/1/conversations');
    await expect(agentPage.getByText('Assigned to you')).toBeVisible();
  });
});
```

### Testing Login Flow (Without Auth State)

For tests that need to test the login process itself:

```typescript
test.describe('Login Flow', () => {
  // Clear auth state for this describe block
  test.use({ storageState: { cookies: [], origins: [] } });

  test('user can login with valid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login('user@example.com', 'password');
    await loginPage.expectLoginSuccess();
  });

  test('shows error for invalid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login('invalid@example.com', 'wrong');
    await loginPage.expectErrorMessage();
  });
});
```

---

## Selector Strategy

### Priority Order

Use this priority order for selecting elements (most stable to least stable):

| Priority | Method | Example | Best For |
|----------|--------|---------|----------|
| 1 | `getByTestId()` | `page.getByTestId('submit-btn')` | Custom elements, complex components |
| 2 | `getByRole()` | `page.getByRole('button', { name: 'Save' })` | Buttons, links, headings, dialogs |
| 3 | `getByLabel()` | `page.getByLabel('Email')` | Form inputs with labels |
| 4 | `getByPlaceholder()` | `page.getByPlaceholder('Search')` | Input fields without labels |
| 5 | `getByText()` | `page.getByText('Welcome')` | Static text, messages |
| 6 | CSS/XPath | `page.locator('.class-name')` | **Last resort only** |

### Accessibility Tree Usage

Role-based selectors use the accessibility tree, which mirrors how assistive technologies see the page:

```typescript
// GOOD: Role-based selectors
await page.getByRole('button', { name: 'Submit' }).click();
await page.getByRole('heading', { level: 2, name: 'Settings' });
await page.getByRole('link', { name: 'Sign Up' }).click();
await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');
await page.getByRole('checkbox', { name: 'Remember me' }).check();
await page.getByRole('dialog', { name: 'Confirm Delete' });
await page.getByRole('listbox').getByRole('option', { name: 'Option 1' }).click();
```

### When to Add data-testid Attributes

Add `data-testid` to Vue components when:

1. **No semantic role exists** for the element
2. **Text content is dynamic** or localized
3. **Multiple similar elements** need distinction
4. **Component structure is complex** (dropdowns, cards)

```vue
<!-- Vue component with data-testid -->
<template>
  <div class="conversation-card" :data-testid="`conversation-card-${id}`">
    <button data-testid="resolve-button" @click="resolve">
      {{ $t('conversations.resolve') }}
    </button>
  </div>
</template>
```

### data-testid Naming Convention

Follow this pattern: `{feature}-{component}-{identifier}`

```
conversation-card-{id}
inbox-selector-dropdown
contact-form-submit
settings-label-delete-{id}
modal-confirm-button
modal-cancel-button
```

### Anti-Patterns to Avoid

```typescript
// BAD: CSS class selectors (especially Tailwind classes)
await page.locator('.bg-blue-500.text-white').click();

// BAD: DOM hierarchy dependency
await page.locator('form > div:nth-child(3) > button').click();

// BAD: Positional selectors
await page.locator('.item').nth(2).click();

// BAD: Generated class names
await page.locator('[class*="Button_primary_"]').click();

// BAD: XPath with position
await page.locator('//div[3]/button').click();
```

### Locator Chaining and Filtering

Chain locators to narrow scope:

```typescript
// Find button within a specific dialog
const modal = page.getByRole('dialog');
await modal.getByRole('button', { name: 'Confirm' }).click();

// Filter list items by text
const row = page.getByRole('row').filter({ hasText: 'John Doe' });
await row.getByRole('button', { name: 'Edit' }).click();

// Filter by child element
await page
  .getByRole('listitem')
  .filter({ has: page.getByRole('img', { name: 'Verified' }) })
  .click();
```

---

## Assertion Patterns

### Web-First Assertions (Preferred)

Web-first assertions automatically wait and retry until the condition is met:

```typescript
// GOOD: Web-first assertions (auto-wait and retry)
await expect(page.getByRole('heading')).toBeVisible();
await expect(page.getByText('Success')).toBeVisible();
await expect(page).toHaveURL(/\/dashboard/);
await expect(page).toHaveTitle(/Chatwoot/);
await expect(locator).toHaveText('Expected text');
await expect(locator).toBeEnabled();
await expect(locator).toBeChecked();
await expect(locator).toHaveCount(5);
await expect(locator).toHaveValue('input value');
await expect(locator).toContainText('partial text');
await expect(locator).toHaveAttribute('href', '/path');
await expect(locator).toHaveClass(/active/);
```

### Manual vs Web-First Assertions

```typescript
// BAD: Manual assertion (no auto-wait, can be flaky)
const isVisible = await locator.isVisible();
expect(isVisible).toBe(true);

// GOOD: Web-first assertion (auto-waits)
await expect(locator).toBeVisible();

// BAD: Manual text extraction
const text = await locator.textContent();
expect(text).toBe('Expected');

// GOOD: Web-first text assertion
await expect(locator).toHaveText('Expected');
```

### Soft Assertions

Use soft assertions when you want to check multiple conditions without stopping at the first failure:

```typescript
test('verify form fields', async ({ page }) => {
  // Soft assertions don't fail immediately - all are evaluated
  await expect.soft(page.getByLabel('Email')).toBeVisible();
  await expect.soft(page.getByLabel('Password')).toBeVisible();
  await expect.soft(page.getByRole('button', { name: 'Submit' })).toBeEnabled();

  // Test fails at the end if any soft assertion failed
});
```

### Negation Assertions

```typescript
await expect(locator).not.toBeVisible();
await expect(locator).not.toHaveText('Error');
await expect(page).not.toHaveURL(/\/login/);
```

### Timeout Configuration

```typescript
// Per-assertion timeout
await expect(locator).toBeVisible({ timeout: 15000 });

// Global expect timeout in config
export default defineConfig({
  expect: { timeout: 10000 },
});
```

### Screenshot Assertions

Visual regression testing:

```typescript
// Compare entire page
await expect(page).toHaveScreenshot('dashboard.png');

// Compare specific element
await expect(page.getByTestId('sidebar')).toHaveScreenshot('sidebar.png');

// With options
await expect(page).toHaveScreenshot('dashboard.png', {
  maxDiffPixels: 100,
  threshold: 0.2,
});
```

---

## Wait Strategies

### Auto-Wait (Preferred)

Playwright automatically waits for elements to be ready before performing actions:

```typescript
// Auto-wait: Playwright waits for button to be visible, stable, and enabled
await page.getByRole('button', { name: 'Submit' }).click();

// Auto-wait: Playwright waits for input to be visible and editable
await page.getByLabel('Email').fill('user@example.com');
```

### Web-First Assertions (Preferred)

Use expect assertions instead of explicit waits:

```typescript
// GOOD: Web-first assertion with auto-retry
await expect(page.getByText('Success')).toBeVisible();
await expect(page).toHaveURL(/\/dashboard/);

// AVOID: Explicit wait followed by assertion
await page.waitForSelector('.success-message');
expect(await page.locator('.success-message').isVisible()).toBe(true);
```

### Explicit Waits (When Necessary)

Use these only when auto-wait and assertions are insufficient:

```typescript
// Wait for element state
await page.getByRole('dialog').waitFor({ state: 'visible' });
await page.getByRole('dialog').waitFor({ state: 'hidden' });
await page.getByRole('button').waitFor({ state: 'attached' });

// Wait for navigation
await page.waitForURL(/\/dashboard/);
await page.waitForURL('**/settings');

// Wait for network
await page.waitForLoadState('networkidle');
await page.waitForLoadState('domcontentloaded');

// Wait for API response
const responsePromise = page.waitForResponse('/api/v1/conversations');
await page.getByRole('button', { name: 'Refresh' }).click();
await responsePromise;
```

### Anti-Pattern: waitForTimeout()

**Never use `waitForTimeout()` - it creates flaky tests:**

```typescript
// BAD: Fixed timeout (flaky, slow)
await page.waitForTimeout(2000);
await expect(element).toBeVisible();

// GOOD: Web-first assertion (auto-wait)
await expect(element).toBeVisible();

// BAD: Timeout before checking state
await page.waitForTimeout(500);
const count = await locator.count();

// GOOD: Wait for stable state
await expect(locator).toHaveCount(5);
// or
await locator.first().waitFor({ state: 'visible' });
const count = await locator.count();
```

### When Explicit Waits Are Acceptable

1. **Waiting for animations/transitions** that don't have testable end states
2. **Waiting for third-party scripts** to load
3. **Debugging** during test development (remove before commit)

```typescript
// Acceptable: Waiting for Vue transition to complete
await page.getByRole('dialog').waitFor({ state: 'hidden' });

// Acceptable: Waiting for specific API response before proceeding
const response = await page.waitForResponse('**/api/v1/messages');
const data = await response.json();
```

---

## Test Isolation

### Each Test Independent

Every test should be able to run independently in any order:

```typescript
// GOOD: Self-contained test
test('user can create conversation', async ({ page, dashboardPage }) => {
  // Setup within test
  await dashboardPage.goto();

  // Action
  await dashboardPage.createNewConversation('Test Subject');

  // Assertion
  await expect(page.getByText('Test Subject')).toBeVisible();
});

// BAD: Test depends on previous test
test('user can view list', async ({ page }) => {
  await page.goto('/conversations');
  // Assumes conversation from previous test exists
});

test('user can delete conversation', async ({ page }) => {
  // Fails if previous test didn't create the conversation
  await page.getByRole('button', { name: 'Delete' }).click();
});
```

### No Shared State Between Tests

```typescript
// BAD: Shared mutable state
let conversationId: number;

test('create conversation', async ({ request }) => {
  const response = await request.post('/api/v1/conversations', { data: {} });
  conversationId = (await response.json()).id;
});

test('view conversation', async ({ page }) => {
  // Fails if first test didn't run
  await page.goto(`/conversations/${conversationId}`);
});

// GOOD: Each test creates its own data
test('user can view conversation', async ({ page, request }) => {
  // Create test data within the test
  const response = await request.post('/api/v1/conversations', { data: {} });
  const { id } = await response.json();

  await page.goto(`/conversations/${id}`);
  await expect(page.getByRole('heading')).toBeVisible();

  // Optional cleanup
  await request.delete(`/api/v1/conversations/${id}`);
});
```

### Fresh Browser Context

Each test gets a fresh browser context by default:

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    // Each test starts with storageState, but isolated context
    storageState: 'e2e/.auth/agent.json',
  },
});
```

### Proper Cleanup

Use fixtures or afterEach for cleanup:

```typescript
test.describe('Conversation Tests', () => {
  let createdIds: number[] = [];

  test.afterEach(async ({ request }) => {
    // Cleanup created data
    for (const id of createdIds) {
      await request.delete(`/api/v1/conversations/${id}`);
    }
    createdIds = [];
  });

  test('create conversation', async ({ request }) => {
    const response = await request.post('/api/v1/conversations', { data: {} });
    const { id } = await response.json();
    createdIds.push(id);

    // Test assertions...
  });
});
```

---

## Running Tests

### Local Execution

```bash
# Run all tests
pnpm e2e

# Run specific test file
pnpm e2e -- e2e/tests/auth/login.spec.ts

# Run tests matching pattern
pnpm e2e -- --grep "login"
pnpm e2e -- --grep @smoke

# Run with UI mode (interactive debugging)
pnpm e2e:ui

# Run in debug mode (step through tests)
pnpm e2e:debug

# Run and keep browser open on failure
pnpm e2e -- --headed --debug

# Run specific project
pnpm e2e -- --project=chromium
pnpm e2e -- --project=chromium-admin
```

### Dev Environment Execution

```bash
# Set environment and run
export BASE_URL=https://dev.app.chatscommerce.com
pnpm e2e

# Or use task command
task e2e-run-dev
```

### CI Execution

```bash
# CI runs with these defaults from config
# - retries: 2
# - workers: 1
# - video: 'retain-on-failure'
# - Runs against dev.app.chatscommerce.com

pnpm e2e
```

### Debugging Tools

#### UI Mode

Interactive test runner with time-travel debugging:

```bash
pnpm e2e:ui
```

Features:
- Watch mode for development
- Step through test timeline
- Inspect locators
- View network requests

#### Trace Viewer

View detailed test execution traces:

```bash
# View trace from failed test
pnpm exec playwright show-trace test-results/path-to-trace.zip

# Enable traces for all tests (development)
pnpm e2e -- --trace on
```

#### Debug Mode

Step through tests with breakpoints:

```bash
pnpm e2e:debug
```

Or add `page.pause()` in test code:

```typescript
test('debug this test', async ({ page }) => {
  await page.goto('/');
  await page.pause(); // Opens inspector
  await page.getByRole('button').click();
});
```

### Test Reports

```bash
# View HTML report after test run
pnpm e2e:report

# Report is generated at playwright-report/index.html
```

### Codegen (Record Tests)

```bash
# Record interactions against local
pnpm e2e:codegen:local

# Record against dev environment
pnpm e2e:codegen:dev

# Record with specific starting URL
pnpm exec playwright codegen http://localhost:3000/app/login
```

---

## Common Patterns Summary

| Pattern | Example |
|---------|---------|
| **Create page object** | `const loginPage = new LoginPage(page)` |
| **Navigate** | `await dashboardPage.goto()` |
| **Fill input** | `await page.getByLabel('Email').fill('user@example.com')` |
| **Click button** | `await page.getByRole('button', { name: 'Submit' }).click()` |
| **Visibility assertion** | `await expect(locator).toBeVisible()` |
| **URL assertion** | `await expect(page).toHaveURL(/\/dashboard/)` |
| **Text assertion** | `await expect(locator).toHaveText('Welcome')` |
| **Wait for element** | `await locator.waitFor({ state: 'visible' })` |
| **Wait for navigation** | `await page.waitForURL(/\/success/)` |
| **Get by test ID** | `page.getByTestId('submit_button')` |
| **Get by role** | `page.getByRole('button', { name: 'Save' })` |
| **Get by label** | `page.getByLabel('Password')` |
| **Filter locator** | `page.getByRole('row').filter({ hasText: 'John' })` |
| **Chain locators** | `modal.getByRole('button', { name: 'Confirm' })` |
| **Soft assertion** | `await expect.soft(locator).toBeVisible()` |
| **Screenshot** | `await expect(page).toHaveScreenshot('name.png')` |
| **Use auth context** | `test.use({ storageState: 'e2e/.auth/admin.json' })` |
| **Clear auth** | `test.use({ storageState: { cookies: [], origins: [] } })` |
| **Skip test** | `test.skip(condition, 'reason')` |
| **Tag test** | `test.describe('Feature @smoke', () => {})` |

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Tests fail due to timing issues

**Problem**: Element not found or interaction fails intermittently.

**Solution**: Use web-first assertions instead of explicit waits.

```typescript
// BAD
await page.waitForTimeout(2000);
await element.click();

// GOOD
await expect(element).toBeVisible();
await element.click();
```

#### 2. Authentication state not persisting

**Problem**: Tests start without authentication.

**Solution**: Ensure setup project runs first and storageState paths are correct.

```typescript
// playwright.config.ts
projects: [
  { name: 'setup', testMatch: /.*\.setup\.ts/ },
  {
    name: 'chromium',
    dependencies: ['setup'], // Critical!
    use: { storageState: 'e2e/.auth/agent.json' },
  },
],
```

#### 3. Element is covered by another element

**Problem**: Click intercepted by overlay or modal.

**Solution**: Wait for overlay to disappear or use force option.

```typescript
// Wait for overlay to disappear
await page.getByTestId('loading-overlay').waitFor({ state: 'hidden' });
await button.click();

// Or force click (use sparingly)
await button.click({ force: true });
```

#### 4. Selector finds multiple elements

**Problem**: Locator matches more than expected.

**Solution**: Make selector more specific using chaining or filtering.

```typescript
// TOO GENERIC
await page.getByRole('button').click(); // Multiple buttons!

// MORE SPECIFIC
await page.getByRole('button', { name: 'Submit' }).click();

// OR SCOPE TO PARENT
const form = page.getByTestId('login-form');
await form.getByRole('button', { name: 'Submit' }).click();
```

#### 5. Test works locally but fails in CI

**Problem**: Environment differences cause failures.

**Solutions**:
- Use same browser version in CI
- Add retries for network flakiness
- Check for hardcoded URLs or ports
- Verify environment variables are set

```typescript
// playwright.config.ts
export default defineConfig({
  retries: process.env.CI ? 2 : 0,
  timeout: process.env.CI ? 60000 : 30000,
});
```

#### 6. Modal/dialog not found

**Problem**: Teleported components (Vue portals) not found.

**Solution**: Search from page root, not parent scope.

```typescript
// BAD: Dialog teleports to body, not inside button's parent
const parent = page.getByTestId('parent');
await parent.getByRole('dialog').click(); // Won't find it!

// GOOD: Search from page root
await page.getByRole('dialog', { name: 'Confirm Delete' }).waitFor();
```

#### 7. Network requests timing out

**Problem**: API calls slow or failing.

**Solution**: Increase navigation timeout or mock slow APIs.

```typescript
// Increase timeout
await page.goto('/dashboard', { timeout: 60000 });

// Or mock slow API
await page.route('**/api/slow-endpoint', route => {
  route.fulfill({ status: 200, body: JSON.stringify({ data: [] }) });
});
```

#### 8. Screenshot tests failing

**Problem**: Visual differences due to fonts, animations, or timing.

**Solution**: Use threshold options and wait for stable state.

```typescript
await expect(page).toHaveScreenshot('page.png', {
  maxDiffPixels: 100,
  threshold: 0.2,
  animations: 'disabled',
});
```

### Debugging Strategies

```typescript
// Add screenshot at failure point
await page.screenshot({ path: 'debug.png' });

// Log element state
console.log(await locator.innerHTML());
console.log(await locator.boundingBox());
console.log(await locator.isVisible());

// Pause for manual inspection
await page.pause();

// Slow down execution
test.use({ launchOptions: { slowMo: 500 } });

// Enable verbose logging
DEBUG=pw:api pnpm e2e
```

---

## References

### Official Documentation
- [Playwright Documentation](https://playwright.dev/docs/intro)
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Playwright Locators](https://playwright.dev/docs/locators)
- [Playwright Assertions](https://playwright.dev/docs/test-assertions)
- [Playwright Authentication](https://playwright.dev/docs/auth)
- [Playwright Fixtures](https://playwright.dev/docs/test-fixtures)
- [Page Object Model](https://playwright.dev/docs/pom)

### Community Best Practices
- [15 Best Practices for Playwright Testing | BrowserStack](https://www.browserstack.com/guide/playwright-best-practices)
- [9 Playwright Best Practices and Pitfalls | Better Stack](https://betterstack.com/community/guides/testing/playwright-best-practices/)
- [How to Avoid Flaky Tests | Semaphore](https://semaphore.io/blog/flaky-tests-playwright)
- [Playwright E2E Testing Cheatsheet | DEV Community](https://dev.to/olhapi/playwright-e2e-testing-cheatsheet-15gl)

### Internal Documentation
- `/docs/ignored/poc-playwright-automation/DESIGN_PROPOSAL.md` - Design decisions
- `/docs/ignored/poc-playwright-automation/research/RT1_playwright_setup.md` - Setup research
- `/docs/ignored/poc-playwright-automation/research/RT3_auth_session.md` - Auth patterns
- `/docs/ignored/poc-playwright-automation/research/RT6_selectors_stability.md` - Selector best practices
