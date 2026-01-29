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

// Cross-browser testing: set E2E_ALL_BROWSERS=true to include Firefox/WebKit
// Or use --project=firefox or --project=webkit to run specific browsers
const ALL_BROWSERS = process.env.E2E_ALL_BROWSERS === 'true';

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
    // NOTE: testDir set to './e2e' so it can find auth.setup.ts (which is NOT in tests/)
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

    // Firefox - only included when E2E_ALL_BROWSERS=true or --project=firefox
    ...(ALL_BROWSERS ? [{
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        storageState: 'e2e/.auth/agent.json',
      },
      dependencies: ['setup'],
    }] : []),

    // WebKit (Safari) - only included when E2E_ALL_BROWSERS=true or --project=webkit
    ...(ALL_BROWSERS ? [{
      name: 'webkit',
      use: {
        ...devices['Desktop Safari'],
        storageState: 'e2e/.auth/agent.json',
      },
      dependencies: ['setup'],
    }] : []),
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
