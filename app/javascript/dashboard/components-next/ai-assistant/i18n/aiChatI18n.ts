/**
 * AI Chat i18n Provider [CORE]
 *
 * Pluggable i18n for the AI chat package using Vue provide/inject.
 * Components use useAiI18n() instead of direct vue-i18n useI18n() calls,
 * allowing the package to be used without Chatwoot's i18n system.
 *
 * Aligned with mobile's useAIi18n.ts pattern but adapted for Vue.
 */

import { inject, provide, type InjectionKey } from 'vue';
import type { I18nProvider } from '../types/chatConfig';

const AI_I18N_KEY: InjectionKey<I18nProvider> = Symbol('ai-i18n');

// Default English strings — the AI chat subset
const defaultStrings: Record<string, string> = {
  'AI_CHAT.HEADER.TITLE': 'AI Employee',
  'AI_CHAT.HEADER.CLOSE': 'Close chat',
  'AI_CHAT.EMPTY_STATE.TITLE': 'Start a conversation with your AI Employee',
  'AI_CHAT.EMPTY_STATE.DESCRIPTION': 'Type a message below to begin',
  'AI_CHAT.INPUT.PLACEHOLDER': 'Type a message...',
  'AI_CHAT.INPUT.SEND': 'Send message',
  'AI_CHAT.VOICE_INPUT.START': 'Start voice input',
  'AI_CHAT.VOICE_INPUT.STOP': 'Stop recording',
  'AI_CHAT.VOICE_INPUT.TRANSCRIBING': 'Transcribing...',
  'AI_CHAT.VOICE_INPUT.COMING_SOON': 'Voice input (coming soon)',
  'AI_CHAT.STATUS.READY': 'Ready',
  'AI_CHAT.STATUS.SUBMITTED': 'Sending...',
  'AI_CHAT.STATUS.STREAMING': 'Responding...',
  'AI_CHAT.STATUS.ERROR': 'Error',
  'AI_CHAT.MESSAGE.COPY': 'Copy message',
  'AI_CHAT.MESSAGE.REGENERATE': 'Regenerate response',
  'AI_CHAT.REASONING.THINKING': 'Thinking...',
  'AI_CHAT.REASONING.VIEW': 'View reasoning',
  'AI_CHAT.TOOL.LABEL': 'Tool',
  'AI_CHAT.TOOL.INPUT_LABEL': 'Input',
  'AI_CHAT.TOOL.OUTPUT_LABEL': 'Output',
  'AI_CHAT.ERROR.TITLE': 'Something went wrong',
  'AI_CHAT.ERROR.NETWORK': 'Connection error. Please check your internet.',
  'AI_CHAT.ERROR.AUTH': 'Session expired. Please log in again.',
  'AI_CHAT.ERROR.RATE_LIMIT': 'Too many requests. Please wait {seconds} seconds.',
  'AI_CHAT.ERROR.SERVER': 'Server error. Our team has been notified.',
  'AI_CHAT.ERROR.UNKNOWN': 'An unexpected error occurred.',
  'AI_CHAT.ERROR.RETRY': 'Retry',
  'AI_CHAT.ERROR.EDIT_RETRY': 'Edit & Retry',
  'AI_CHAT.ERROR.DISMISS': 'Dismiss',
  'AI_CHAT.ERROR.FRESH_START': 'Start over',
  'AI_CHAT.ERROR.TECHNICAL_DETAILS': 'Technical details',
  'AI_CHAT.SUGGESTIONS.LABEL': 'Suggestions',
  'AI_CHAT.LOADER.WAITING': 'Processing...',
  'AI_CHAT.SCROLL_TO_TOP': 'Scroll to top',
  'AI_CHAT.SCROLL_TO_BOTTOM': 'Scroll to bottom',
  'AI_CHAT.BOT_SELECTOR.LABEL': 'Select AI Employee',
  'AI_CHAT.BOT_SELECTOR.PLACEHOLDER': 'Choose an AI Employee',
  'AI_CHAT.SESSIONS.TITLE': 'Chat History',
  'AI_CHAT.SESSIONS.HISTORY': 'View chat history',
  'AI_CHAT.SESSIONS.NEW_CHAT': 'New chat',
  'AI_CHAT.SESSIONS.EMPTY': 'No previous chats',
  'AI_CHAT.SESSIONS.DELETE': 'Delete chat',
  'AI_CHAT.SESSIONS.TODAY': 'Today',
  'AI_CHAT.SESSIONS.YESTERDAY': 'Yesterday',
  'AI_CHAT.COLLAPSIBLE.COLLAPSE': 'Collapse',
};

const defaultI18n: I18nProvider = {
  t: (key: string, params?: Record<string, unknown>) => {
    let str = defaultStrings[key] || key;
    if (params) {
      Object.entries(params).forEach(([k, v]) => {
        str = str.replace(`{${k}}`, String(v));
      });
    }
    return str;
  },
  locale: 'en',
  dir: 'ltr',
};

export function provideAiI18n(provider?: I18nProvider): void {
  provide(AI_I18N_KEY, provider || defaultI18n);
}

export function useAiI18n(): I18nProvider {
  return inject(AI_I18N_KEY, defaultI18n);
}

export { defaultI18n };
