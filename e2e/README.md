# E2E Testing with Playwright

End-to-end test automation for Chatwoot using Playwright.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Directory Structure](#directory-structure)
4. [Running Tests](#running-tests)
5. [Writing Tests](#writing-tests)
6. [Exploratory Testing](#exploratory-testing)
7. [Test Users](#test-users)
8. [Environment Variables](#environment-variables)
9. [CI/CD Integration](#cicd-integration-github-actions)
10. [Troubleshooting](#troubleshooting)
11. [More Documentation](#more-documentation)

---

## Quick Start

```bash
# Install Playwright and browsers
task e2e-install

# Copy credentials template
cp .env.test.example .env.test

# Seed test users (requires Docker running)
task e2e-seed

# Run tests
task e2e-run-local
```

---

## Prerequisites

Before running E2E tests, ensure you have:

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Docker** | Latest | For running local Chatwoot stack |
| **Node.js** | 23+ | JavaScript runtime |
| **pnpm** | Latest | Package manager |
| **Playwright browsers** | Auto-installed | Chromium (default) |
| **AWS CLI** (optional) | Latest | For fetching dev credentials from SSM |

### Installation Steps

```bash
# 1. Install Node dependencies (if not already done)
pnpm install

# 2. Install Playwright and Chromium browser
task e2e-install

# 3. Start Docker services
docker compose up -d

# 4. Seed test users
task e2e-seed

# 5. Copy and configure credentials
cp .env.test.example .env.test
```

---

## Directory Structure

```
e2e/
├── .auth/                    # Auth state files (gitignored)
│   ├── admin.json            # Admin user session state
│   └── agent.json            # Agent user session state
├── fixtures/                 # Playwright fixtures
│   ├── auth.fixture.ts       # Role-based auth contexts
│   ├── pages.fixture.ts      # Page object fixtures
│   └── index.ts              # Combined fixture exports
├── pages/                    # Page Object Models
│   ├── base.page.ts          # Base page class
│   ├── login.page.ts         # Login page
│   ├── dashboard.page.ts     # Dashboard/conversations list
│   ├── conversation.page.ts  # Conversation detail view
│   ├── inbox.page.ts         # Inbox management
│   └── index.ts              # Page exports
├── tests/                    # Test specifications
│   ├── auth/                 # Authentication tests
│   │   └── login.spec.ts     # Login flow tests
│   ├── conversations/        # Conversation tests
│   │   ├── detail.spec.ts    # View conversation
│   │   ├── reply.spec.ts     # Reply to conversation
│   │   └── assign.admin.spec.ts  # Admin assignment tests
│   ├── inbox/                # Inbox tests (placeholder)
│   └── smoke/                # Quick smoke tests
│       ├── conversations.spec.ts
│       └── inbox.spec.ts
├── utils/                    # Helper utilities
│   ├── data.helper.ts        # Test data generators
│   ├── env.helper.ts         # Environment helpers
│   └── index.ts              # Utility exports
├── exploratory/              # Codegen recordings (temporary)
├── auth.setup.ts             # Authentication setup project
├── tsconfig.json             # TypeScript config for e2e
└── README.md                 # This file
```

### Key Files at Project Root

```
chatwoot/
├── playwright.config.ts      # Main Playwright configuration
├── .env.test.example         # Template for E2E credentials
├── .env.test                  # Your E2E credentials (gitignored)
├── playwright-report/        # Generated HTML reports (gitignored)
└── test-results/             # Test artifacts (gitignored)
```

---

## Running Tests

### Local (Docker)

Run tests against your local Docker environment (`http://localhost:3000`).

```bash
# Run all tests (waits for Rails to be ready)
task e2e-run-local

# Run with Playwright UI mode (interactive)
task e2e-ui

# Run specific test file
pnpm e2e -- e2e/tests/auth/login.spec.ts

# Run tests by tag
pnpm e2e -- --grep @smoke

# Run excluding a tag
pnpm e2e -- --grep-invert @slow

# Run in debug mode
pnpm e2e:debug

# Run with headed browser (visible)
pnpm e2e -- --headed
```

### Dev Environment

Run tests against the deployed dev environment (`https://dev.app.chatscommerce.com`).

```bash
# Fetch credentials from AWS SSM (requires AWS CLI configured)
task e2e-fetch-creds

# Run against dev environment
task e2e-run-dev

# Run specific tests against dev
task e2e-run-dev -- --grep @smoke

# Or manually set the environment
BASE_URL=https://dev.app.chatscommerce.com pnpm e2e
```

### UI Mode

Interactive test runner with time-travel debugging:

```bash
task e2e-ui
```

Features:
- Watch mode for development
- Step through test timeline
- Inspect locators visually
- View network requests
- Re-run failed tests instantly

### Running Specific Tests

```bash
# By file path
pnpm e2e -- e2e/tests/auth/login.spec.ts

# By tag (in describe block name)
pnpm e2e -- --grep @smoke
pnpm e2e -- --grep @regression

# By test name
pnpm e2e -- --grep "can login"

# By project (browser/auth config)
pnpm e2e -- --project=chromium
pnpm e2e -- --project=chromium-admin

# Run only setup (authentication)
pnpm e2e -- --project=setup
```

### Viewing Reports

```bash
# View HTML report after test run
task e2e-report
# or
pnpm e2e:report

# Report is generated at playwright-report/index.html
```

---

## Writing Tests

For comprehensive guidance on writing tests, see:
**[E2E Testing Patterns](../docs/architecture/testing/e2e-testing-patterns.md)**

### Quick Example

```typescript
// e2e/tests/conversations/example.spec.ts
import { test, expect } from '../../fixtures';
import { testMessage } from '../../utils';

test.describe('Conversation Features @smoke', () => {
  test('agent can reply to conversation', async ({ page, dashboardPage, conversationPage }) => {
    // Navigate to dashboard
    await dashboardPage.goto();

    // Open first conversation
    await dashboardPage.openFirstConversation();

    // Send a reply
    const message = testMessage('E2E Test');
    await conversationPage.sendMessage(message);

    // Verify message appears
    await expect(page.getByText(message)).toBeVisible();
  });
});
```

### Key Patterns

| Pattern | When to Use |
|---------|-------------|
| **Page Object Model** | Reusable interactions with pages |
| **Fixtures** | Inject authenticated contexts and page objects |
| **data-testid selectors** | Stable element selection |
| **Web-first assertions** | Auto-waiting assertions (`expect(x).toBeVisible()`) |
| **Test isolation** | Each test is independent |

---

## Exploratory Testing

### Using Codegen (Record & Playback)

Record interactions and generate test code automatically:

```bash
# Record against local Docker
task e2e-codegen

# Record against dev environment
task e2e-codegen-dev

# Record starting from specific URL
pnpm exec playwright codegen http://localhost:3000/app/login
```

This opens a browser where you can:
1. Interact with the app normally
2. See generated Playwright code in real-time
3. Copy code snippets to create formal tests

**Workflow for converting recordings to tests:**

1. Run codegen and perform the user flow
2. Copy the generated code
3. Create a new `.spec.ts` file in the appropriate `tests/` subdirectory
4. Refactor the code:
   - Use Page Objects instead of raw selectors
   - Replace generated selectors with `getByTestId()` or `getByRole()`
   - Add proper assertions
   - Use fixtures for authentication

### Using Playwright MCP with Claude

For AI-assisted exploratory testing, configure Playwright MCP in your Claude settings.

**1. Ensure MCP is configured:**

Add to `~/.claude.json` (or `.claude/settings.json`):

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

**2. Use Claude to interact with the app:**

Example prompts:
- "Navigate to the inbox and verify conversations are listed"
- "Try logging in with invalid credentials and check the error message"
- "Create a new conversation and send a test message"
- "Verify the sidebar navigation links work correctly"
- "Check what happens when opening a conversation without messages"

**3. Convert findings to formal tests:**

Claude can help identify:
- Edge cases to test
- Elements that need `data-testid` attributes
- User flows that should be automated
- Accessibility issues

---

## Test Users

### Local (Docker)

| Role | Email | Password |
|------|-------|----------|
| Admin | `e2e-admin@test.chatwoot.local` | `Password1!` |
| Agent | `e2e-agent@test.chatwoot.local` | `Password1!` |

Seed these users with:
```bash
task e2e-seed
```

### Dev Environment

| Role | Email | Password |
|------|-------|----------|
| Admin | `e2e-admin@chatscommerce.com` | (stored in SSM) |
| Agent | `e2e-agent@chatscommerce.com` | (stored in SSM) |

Fetch credentials with:
```bash
task e2e-fetch-creds
```

---

## Environment Variables

Copy `.env.test.example` to `.env.test` and configure:

```env
# Test User Credentials
E2E_ADMIN_EMAIL=e2e-admin@test.chatwoot.local
E2E_ADMIN_PASSWORD=Password1!
E2E_AGENT_EMAIL=e2e-agent@test.chatwoot.local
E2E_AGENT_PASSWORD=Password1!

# Override base URL (optional - defaults to FRONTEND_URL from .env)
# BASE_URL=http://localhost:3000

# For dev environment testing
# BASE_URL=https://dev.app.chatscommerce.com
```

---

## CI/CD Integration (GitHub Actions)

E2E tests run automatically in CI against the live dev environment (`https://dev.app.chatscommerce.com`).

**Important**: CI does NOT spin up Docker - it tests the actual deployed application.

### Workflow Triggers

| Trigger | Tests Run | When |
|---------|-----------|------|
| Pull Request | Smoke tests (`@smoke`) | PR to develop/main |
| Manual Dispatch | Configurable filter | On-demand via GitHub UI |
| Schedule | Full suite | Weekdays 6am UTC |

### Manual Trigger

Go to **Actions > E2E Tests > Run workflow** and select:
- **Environment**: `dev` (currently only option)
- **Test filter**: `@smoke`, `@regression`, or empty for all tests

### GitHub Secrets Required

The following secrets must be configured in the repository (Settings > Secrets and variables > Actions):

| Secret Name | Description |
|-------------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key with SSM read permissions |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key |

### IAM Policy for CI

The AWS credentials need the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParameter"],
      "Resource": [
        "arn:aws:ssm:us-east-1:*:parameter/chatwoot/e2e/*"
      ]
    }
  ]
}
```

### SSM Parameters Setup (One-Time)

Before CI can run, the following SSM parameters must be created in AWS:

| Parameter Path | Type | Description |
|----------------|------|-------------|
| `/chatwoot/e2e/admin-email` | String | Admin test user email |
| `/chatwoot/e2e/admin-password` | SecureString | Admin test user password |
| `/chatwoot/e2e/agent-email` | String | Agent test user email |
| `/chatwoot/e2e/agent-password` | SecureString | Agent test user password |

**AWS CLI Commands to Create Parameters**:

```bash
# Create admin email parameter
aws ssm put-parameter \
  --name "/chatwoot/e2e/admin-email" \
  --type "String" \
  --value "e2e-admin@chatscommerce.com" \
  --description "E2E Admin test user email"

# Create admin password parameter (SecureString)
aws ssm put-parameter \
  --name "/chatwoot/e2e/admin-password" \
  --type "SecureString" \
  --value "YOUR_SECURE_PASSWORD_HERE" \
  --description "E2E Admin test user password"

# Create agent email parameter
aws ssm put-parameter \
  --name "/chatwoot/e2e/agent-email" \
  --type "String" \
  --value "e2e-agent@chatscommerce.com" \
  --description "E2E Agent test user email"

# Create agent password parameter (SecureString)
aws ssm put-parameter \
  --name "/chatwoot/e2e/agent-password" \
  --type "SecureString" \
  --value "YOUR_SECURE_PASSWORD_HERE" \
  --description "E2E Agent test user password"
```

**Note**: Replace `YOUR_SECURE_PASSWORD_HERE` with the actual passwords used when creating test users in dev.app.chatscommerce.com.

### Dev Environment Test Users (One-Time)

Before running E2E tests against dev, test users must be manually created:

1. Log into https://dev.app.chatscommerce.com as administrator
2. Create **Admin Test User**:
   - Email: `e2e-admin@chatscommerce.com`
   - Role: Administrator
   - Strong password (store in SSM)
3. Create **Agent Test User**:
   - Email: `e2e-agent@chatscommerce.com`
   - Role: Agent
   - Strong password (store in SSM)
4. Store credentials in AWS SSM (see commands above)

### Verifying SSM Parameters

```bash
# List all E2E parameters
aws ssm get-parameters-by-path \
  --path "/chatwoot/e2e/" \
  --with-decryption \
  --query "Parameters[*].[Name,Value]" \
  --output table

# Test the fetch-creds task locally
task e2e-fetch-creds
cat .env.test
```

### Viewing Test Reports

After a CI run:
1. Go to the workflow run in GitHub Actions
2. Download the `playwright-report` artifact
3. Extract and open `index.html` in a browser

---

## Troubleshooting

### Authentication Issues

#### Auth state files missing or expired

**Symptoms**: Tests fail immediately with "storageState file not found" or redirect to login.

**Solution**:
```bash
# Re-run the setup project to regenerate auth files
pnpm e2e -- --project=setup

# Verify files were created
ls -la e2e/.auth/
```

#### Login fails during setup

**Symptoms**: Setup tests fail with "Invalid credentials" or timeout on login.

**Checklist**:
1. Verify `.env.test` exists and has correct credentials
2. For local: Ensure test users are seeded (`task e2e-seed`)
3. For dev: Ensure SSM credentials match the actual user passwords
4. Check that the app is accessible at BASE_URL

```bash
# Verify credentials are loaded
cat .env.test | grep E2E_

# Re-seed local test users
task e2e-seed

# Re-fetch dev credentials
task e2e-fetch-creds
```

### Selector Issues

#### Element not found

**Symptoms**: Test fails with "locator.click: Target closed" or "timeout waiting for element".

**Solutions**:

1. **Check if element exists**: Use Playwright Inspector
   ```bash
   pnpm e2e:debug -- e2e/tests/path/to/test.spec.ts
   ```

2. **Use more specific selectors**:
   ```typescript
   // Instead of generic selector
   await page.locator('button').click();

   // Use specific selector
   await page.getByRole('button', { name: 'Submit' }).click();
   // Or
   await page.getByTestId('submit_button').click();
   ```

3. **Wait for element to be ready**:
   ```typescript
   await expect(page.getByTestId('my-element')).toBeVisible();
   await page.getByTestId('my-element').click();
   ```

#### Multiple elements found

**Symptoms**: Test clicks wrong element or fails with "strict mode violation".

**Solution**: Make selector more specific
```typescript
// Scope to parent element
const modal = page.getByRole('dialog');
await modal.getByRole('button', { name: 'Confirm' }).click();

// Or use .first() / .nth() when appropriate
await page.getByTestId('conversation-item').first().click();
```

### Timeout Issues

#### Test times out

**Symptoms**: Test fails after 60 seconds with "Test timeout of 60000ms exceeded".

**Solutions**:

1. **Increase timeout for slow operations**:
   ```typescript
   test('slow test', async ({ page }) => {
     test.setTimeout(120000); // 2 minutes
     // ... test code
   });
   ```

2. **Check for missing await**:
   ```typescript
   // BAD - missing await causes next line to run before action completes
   page.getByRole('button').click();

   // GOOD
   await page.getByRole('button').click();
   ```

3. **Avoid waitForTimeout()** - use web-first assertions:
   ```typescript
   // BAD
   await page.waitForTimeout(2000);

   // GOOD
   await expect(page.getByText('Success')).toBeVisible();
   ```

#### Navigation timeout

**Symptoms**: Test fails with "page.goto: Timeout 30000ms exceeded".

**Solution**:
```typescript
// Increase navigation timeout
await page.goto('/dashboard', { timeout: 60000 });

// Or wait for specific element instead of full load
await page.goto('/dashboard', { waitUntil: 'commit' });
await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
```

### Browser Issues

#### Chromium not installed

**Symptoms**: Test fails with "browserType.launch: Executable doesn't exist".

**Solution**:
```bash
# Install browsers
task e2e-install
# or
pnpm exec playwright install chromium
```

#### Browser crashes in CI

**Symptoms**: Test fails with "browser has been closed" in GitHub Actions.

**Solution**: The workflow uses `--with-deps` flag which should handle this. If issues persist:
```yaml
# In .github/workflows/e2e.yml
- name: Install Playwright browsers
  run: pnpm exec playwright install --with-deps chromium
```

### Environment Issues

#### Wrong BASE_URL

**Symptoms**: Tests run against wrong environment.

**Solution**:
```bash
# Check current configuration
echo $BASE_URL
cat .env.test | grep BASE_URL

# Override for single run
BASE_URL=http://localhost:3000 pnpm e2e
```

#### Missing environment variables

**Symptoms**: Setup fails with "Required environment variable X is not set".

**Solution**:
```bash
# Ensure .env.test exists
cp .env.test.example .env.test

# Edit with actual values
# For dev, fetch from SSM
task e2e-fetch-creds
```

### CI-Specific Issues

#### Tests pass locally but fail in CI

**Checklist**:
1. **Different BASE_URL**: CI runs against dev, not localhost
2. **Different test data**: Dev environment may have different data
3. **Network differences**: CI may have higher latency
4. **Screenshot differences**: Use thresholds for visual tests

**Debug in CI**:
- Download `test-results` artifact for traces and screenshots
- Download `playwright-report` for detailed HTML report
- Check workflow logs for environment variable issues

#### Workflow doesn't trigger

**Checklist**:
1. Check PR is not in draft mode
2. Verify file changes match path filters in workflow
3. Ensure secrets are configured in repository settings

### Debugging Tips

```bash
# Run with headed browser (visible)
pnpm e2e -- --headed

# Run in debug mode (step through)
pnpm e2e:debug

# Run with trace (generates trace.zip)
pnpm e2e -- --trace on

# View trace file
pnpm exec playwright show-trace test-results/path/trace.zip

# Enable verbose logging
DEBUG=pw:api pnpm e2e
```

---

## More Documentation

| Document | Description |
|----------|-------------|
| [E2E Testing Patterns](../docs/architecture/testing/e2e-testing-patterns.md) | Comprehensive guide for writing tests |
| [Design Proposal](../docs/ignored/poc-playwright-automation/DESIGN_PROPOSAL.md) | Original POC design decisions |
| [Execution Plan](../docs/ignored/poc-playwright-automation/EXECUTION.md) | Implementation tracking |

### External Resources

- [Playwright Documentation](https://playwright.dev/docs/intro)
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Playwright Locators](https://playwright.dev/docs/locators)

---

## Available Task Commands

| Task Command | Description |
|--------------|-------------|
| `task e2e-install` | Install Playwright and browsers |
| `task e2e-seed` | Seed test users in database |
| `task e2e-run-local` | Run tests against Docker |
| `task e2e-run-dev` | Run tests against dev environment |
| `task e2e-run` | Run tests (basic, no wait) |
| `task e2e-codegen` | Launch codegen for local |
| `task e2e-codegen-dev` | Launch codegen for dev |
| `task e2e-fetch-creds` | Fetch credentials from AWS SSM |
| `task e2e-report` | View HTML test report |
| `task e2e-ui` | Run tests with UI mode |
| `task e2e-cleanup` | Remove E2E test data |

## pnpm Scripts

| Script | Description |
|--------|-------------|
| `pnpm e2e` | Run all tests |
| `pnpm e2e:ui` | Run with UI mode |
| `pnpm e2e:debug` | Run in debug mode |
| `pnpm e2e:codegen` | Launch codegen |
| `pnpm e2e:codegen:local` | Codegen for localhost |
| `pnpm e2e:codegen:dev` | Codegen for dev |
| `pnpm e2e:report` | Show HTML report |
| `pnpm e2e:install` | Install browsers |
