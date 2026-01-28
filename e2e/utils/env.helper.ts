/**
 * Environment Helpers
 *
 * Utilities for environment detection and configuration.
 */

export interface TestEnvironment {
  baseUrl: string;
  isLocal: boolean;
  isDev: boolean;
  isCI: boolean;
}

/**
 * Detect current test environment
 */
export function getTestEnvironment(): TestEnvironment {
  const baseUrl = process.env.BASE_URL
    ?? process.env.FRONTEND_URL
    ?? 'http://localhost:3000';

  const isLocal = baseUrl.includes('localhost') || baseUrl.includes('0.0.0.0');
  const isDev = baseUrl.includes('dev.app.chatscommerce.com');
  const isCI = !!process.env.CI;

  return {
    baseUrl,
    isLocal,
    isDev,
    isCI,
  };
}

/**
 * Get required environment variable or throw
 */
export function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Required environment variable ${name} is not set`);
  }
  return value;
}

/**
 * Get optional environment variable with default
 */
export function getEnv(name: string, defaultValue: string = ''): string {
  return process.env[name] ?? defaultValue;
}
