import { inject, provide } from 'vue';

const AiChatControl = Symbol('AiChatControl');

/**
 * @typedef {Object} AiChatContext
 * @property {import('vue').ComputedRef<boolean>} isStreaming
 * @property {import('vue').Ref<string>} status
 * @property {Function} sendMessage
 * @property {Function} clearError
 */

/**
 * Retrieves the AI chat context from parent AiChatPanel.
 * @returns {AiChatContext}
 * @throws {Error} If used outside of AiChatPanel context
 */
export function useAiChatContext() {
  const context = inject(AiChatControl, null);
  if (context === null) {
    throw new Error('Component is missing a parent <AiChatPanel /> component.');
  }
  return context;
}

export function provideAiChatContext(context) {
  provide(AiChatControl, context);
}
