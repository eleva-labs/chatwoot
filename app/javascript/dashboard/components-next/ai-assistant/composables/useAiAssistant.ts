/**
 * useAiAssistant.ts
 *
 * Composable for AI Assistant domain logic.
 * Handles chat state initialization and session management.
 * Delegates bot fetching to useAIChatBot.
 *
 * All Chatwoot-specific transport/session logic is injected via
 * chatwootChatConfig factories — composables are framework-agnostic.
 */
import { computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAiChat } from './useAiChat';
import { useAiChatSessions } from './useAiChatSessions';
import { useAIChatBot } from './useAIChatBot';
import {
  createChatwootTransportConfig,
  createChatwootSessionsAdapter,
  createChatwootPersistenceAdapter,
  chatwootBehaviorConfig,
} from '../chatwootChatConfig';

export function useAiAssistant() {
  const route = useRoute();
  const store = useStore();

  // Current user
  const currentUser = computed(
    () =>
      store.getters.getCurrentUser as {
        name?: string;
        avatar_url?: string;
      },
  );

  // Account ID extraction
  const accountId = computed((): number | null => {
    if (route.params.accountId) {
      return Number(route.params.accountId);
    }
    const pathMatch = window.location.pathname.match(/\/accounts\/(\d+)/);
    if (pathMatch) {
      return Number(pathMatch[1]);
    }
    return (window as unknown as Record<string, unknown>).chatwootConfig
      ? (
          (
            window as unknown as Record<
              string,
              Record<string, unknown>
            >
          ).chatwootConfig.accountId as number | null
        )
      : null;
  });

  // Bot selection — delegated to useAIChatBot
  const {
    selectedBotId,
    availableBots,
    botsLoading,
    currentBot,
    fetchBots,
  } = useAIChatBot(accountId);

  // Create Chatwoot-specific sessions adapter (getter keeps accountId reactive)
  const sessionsAdapter = createChatwootSessionsAdapter(
    () => accountId.value,
  );

  // Create Chatwoot-specific persistence adapter (wraps LocalStorage)
  const persistenceAdapter = createChatwootPersistenceAdapter();

  // Session management — uses adapter, no hardcoded fetch
  const sessionManager = useAiChatSessions(
    sessionsAdapter,
    persistenceAdapter,
  );

  // Create Chatwoot-specific transport config (getter keeps accountId reactive)
  const transportConfig = createChatwootTransportConfig(
    () => accountId.value,
    () => ({
      agentBotId: selectedBotId.value,
      sessionId: sessionManager.activeSessionId.value,
    }),
  );

  // Initialize Vercel AI SDK Chat via config
  const chat = useAiChat(transportConfig, chatwootBehaviorConfig, {
    onSessionId: (id: string) => {
      // Persist session ID when received from backend
      sessionManager.setActiveSessionId(id, selectedBotId.value);
    },
  });

  // Watch for bot changes to restore session ID from persistent storage
  // Sessions list is fetched lazily when user opens history panel
  watch(
    selectedBotId,
    (newBotId: number | null, oldBotId: number | null) => {
      // Only react to actual bot changes, not initial mount
      if (newBotId && oldBotId && newBotId !== oldBotId) {
        // Clear current sessions (will be re-fetched when history panel opens)
        sessionManager.sessions.value = [];
        // Restore session ID from persistent storage for new bot
        const storedSessionId =
          sessionManager.getStoredSessionId(newBotId);
        if (storedSessionId) {
          sessionManager.setActiveSessionId(storedSessionId, newBotId);
        } else {
          sessionManager.activeSessionId.value = null;
        }
        // Clear chat messages for new bot context
        chat.setMessages([]);
      }
    },
    { immediate: false },
  );

  // Computed properties
  const chatTitle = computed(
    () => currentBot.value?.name || 'AI Assistant',
  );

  const userName = computed(() => currentUser.value?.name || '');
  const userAvatar = computed(() => currentUser.value?.avatar_url || '');
  const botName = computed(() => currentBot.value?.name || 'AI');
  const botAvatar = computed(() => currentBot.value?.avatar_url || '');

  const isDisabled = computed(() => !selectedBotId.value);

  // Auto-fetch bots on mount
  // Sessions are fetched lazily when user opens history panel
  onMounted(async () => {
    await fetchBots();
    // Restore previous session from persistent storage (includes loading messages)
    if (selectedBotId.value) {
      await sessionManager.restoreSession(selectedBotId.value, chat);
    }
  });

  return {
    // Chat instance
    chat,

    // Bot state
    selectedBotId,
    availableBots,
    botsLoading,
    currentBot,

    // Computed props for UI
    chatTitle,
    userName,
    userAvatar,
    botName,
    botAvatar,
    isDisabled,

    // Session management
    sessions: sessionManager.sessions,
    activeSessionId: sessionManager.activeSessionId,
    isLoadingSessions: sessionManager.isLoadingSessions,
    loadSession: (sessionId: string) =>
      sessionManager.loadSession(sessionId, selectedBotId.value!, chat),
    startNewSession: () =>
      sessionManager.startNewSession(selectedBotId.value!, chat),
    deleteSession: (sessionId: string) =>
      sessionManager.deleteSession(sessionId, selectedBotId.value!),
    fetchSessions: () =>
      sessionManager.fetchSessions(selectedBotId.value!),

    // Methods
    fetchBots,
  };
}
