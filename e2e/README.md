# E2E Testing with Playwright

End-to-end test automation for Chatwoot using Playwright.

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

## Prerequisites

- Docker running with Chatwoot stack (`docker compose up -d`)
- Node.js 23+ and pnpm
- Playwright browsers installed (`task e2e-install`)

## Running Tests

### Local (Docker)

```bash
# Run all tests against localhost:3000
task e2e-run-local

# Run with UI mode
task e2e-ui

# Run specific test file
pnpm e2e -- e2e/tests/auth/login.spec.ts
```

### Dev Environment

```bash
# Fetch credentials from SSM (requires AWS CLI configured)
task e2e-fetch-creds

# Run against dev.app.chatscommerce.com
task e2e-run-dev
```

### Exploratory Testing (Codegen)

```bash
# Record tests against local
task e2e-codegen

# Record tests against dev
task e2e-codegen-dev
```

## Available Commands

| Task Command | Description |
|--------------|-------------|
| `task e2e-install` | Install Playwright and browsers |
| `task e2e-seed` | Seed test users in database |
| `task e2e-run-local` | Run tests against Docker |
| `task e2e-run-dev` | Run tests against dev environment |
| `task e2e-codegen` | Launch codegen for local |
| `task e2e-fetch-creds` | Fetch credentials from AWS SSM |
| `task e2e-report` | View HTML test report |
| `task e2e-ui` | Run tests with UI mode |

## Directory Structure

```
e2e/
├── .auth/              # Auth state files (gitignored)
├── fixtures/           # Playwright fixtures
├── pages/              # Page Object Models
├── tests/              # Test specifications
│   ├── auth/           # Authentication tests
│   ├── conversations/  # Conversation tests
│   ├── inbox/          # Inbox tests
│   └── smoke/          # Smoke tests
├── utils/              # Helper utilities
├── exploratory/        # Codegen recordings (temporary)
├── auth.setup.ts       # Authentication setup
└── tsconfig.json       # TypeScript config
```

## Test Users

| Role | Email | Password |
|------|-------|----------|
| Admin | `e2e-admin@test.chatwoot.local` | See `.env.test` |
| Agent | `e2e-agent@test.chatwoot.local` | See `.env.test` |

## Environment Variables

Copy `.env.test.example` to `.env.test` and configure:

```env
E2E_ADMIN_EMAIL=e2e-admin@test.chatwoot.local
E2E_ADMIN_PASSWORD=Password1!
E2E_AGENT_EMAIL=e2e-agent@test.chatwoot.local
E2E_AGENT_PASSWORD=Password1!
BASE_URL=http://localhost:3000
```

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

## More Documentation

- Full design: `docs/ignored/poc-playwright-automation/DESIGN_PROPOSAL.md`
- Execution plan: `docs/ignored/poc-playwright-automation/EXECUTION.md`
