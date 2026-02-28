import { inject, provide, type InjectionKey } from 'vue';
import type { AiChatContext } from './types';
import type { I18nProvider } from './types/chatConfig';
import type { PartRegistryConfig } from './registry/partRegistry';
import { providePartRegistry } from './registry/partRegistry';
import { provideAiI18n } from './i18n/aiChatI18n';

const AI_CHAT_KEY: InjectionKey<AiChatContext> = Symbol('ai-chat');

/**
 * Retrieves the AI chat context from parent AiChatPanel.
 * @throws If used outside of AiChatPanel context
 */
export function useAiChatContext(): AiChatContext {
  const context = inject(AI_CHAT_KEY, null);
  if (context === null) {
    throw new Error('Component is missing a parent <AiChatPanel /> component.');
  }
  return context;
}

export function provideAiChatContext(context: AiChatContext): void {
  provide(AI_CHAT_KEY, context);
}

/**
 * Unified provider for AI chat sub-contexts.
 * Composes i18n and registry into a single call.
 * Chat context (status, isStreaming, etc.) is still provided
 * separately by AiChatPanel.vue at runtime via provideAiChatContext.
 */
export function provideAiChat(options?: {
  i18n?: I18nProvider;
  registry?: PartRegistryConfig;
}): void {
  if (options?.i18n) provideAiI18n(options.i18n);
  if (options?.registry) providePartRegistry(options.registry);
}
