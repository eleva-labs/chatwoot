import { inject, provide, type InjectionKey } from 'vue';
import type { AiChatContext } from './types';

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
