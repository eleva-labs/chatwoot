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

## More Documentation

- Full design: `docs/ignored/poc-playwright-automation/DESIGN_PROPOSAL.md`
- Execution plan: `docs/ignored/poc-playwright-automation/EXECUTION.md`
