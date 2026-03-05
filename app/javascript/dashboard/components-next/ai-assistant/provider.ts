import type { I18nProvider } from './types/chatConfig';
import type { PartRegistryConfig } from './registry/partRegistry';
import { providePartRegistry } from './registry/partRegistry';
import { provideAiI18n } from './i18n/aiChatI18n';

/**
 * Unified provider for AI chat sub-contexts.
 * Composes i18n and registry into a single call.
 */
export function provideAiChat(options?: {
  i18n?: I18nProvider;
  registry?: PartRegistryConfig;
}): void {
  if (options?.i18n) provideAiI18n(options.i18n);
  if (options?.registry) providePartRegistry(options.registry);
}
