/**
 * useAiAssistant.js
 *
 * Composable for AI Assistant domain logic.
 * Handles bot fetching, auth, chat state initialization, and session management.
 * Used by AiAssistant orchestrator component.
 */
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useVercelChat } from './useVercelChat';
import { useAiChatSessionManager } from './useAiChatSessionManager';
import { getAuthHeaders } from '../utils/auth';
import { parseBotsResponse } from '../schemas';

export function useAiAssistant() {
  const route = useRoute();
  const store = useStore();

  // Current user
  const currentUser = computed(() => store.getters.getCurrentUser);

  // Account ID extraction
  const accountId = computed(() => {
    if (route.params.accountId) {
      return Number(route.params.accountId);
    }
    const pathMatch = window.location.pathname.match(/\/accounts\/(\d+)/);
    if (pathMatch) {
      return Number(pathMatch[1]);
    }
    return window.chatwootConfig?.accountId || null;
  });

  // Bot selection state
  const selectedBotId = ref(null);
  const availableBots = ref([]);
  const botsLoading = ref(false);

  // Session management - use dedicated composable
  const sessionManager = useAiChatSessionManager(accountId.value);

  // Initialize Vercel AI SDK Chat
  const chat = useVercelChat({
    api: `/api/v1/accounts/${accountId.value}/ai_chat/stream`,
    body: () => ({
      agent_bot_id: selectedBotId.value,
      chat_session_id: sessionManager.activeSessionId.value,
    }),
    onSessionId: id => {
      // Persist session ID when received from backend
      sessionManager.setActiveSessionId(id, selectedBotId.value);
    },
  });

  // Watch for bot changes to restore session ID from localStorage
  // Sessions list is fetched lazily when user opens history panel
  watch(
    selectedBotId,
    (newBotId, oldBotId) => {
      // Only react to actual bot changes, not initial mount
      if (newBotId && oldBotId && newBotId !== oldBotId) {
        // Clear current sessions (will be re-fetched when history panel opens)
        sessionManager.sessions.value = [];
        // Restore session ID from localStorage for new bot
        const storedSessionId = sessionManager.getStoredSessionId(newBotId);
        if (storedSessionId) {
          sessionManager.setActiveSessionId(storedSessionId, newBotId);
        } else {
          sessionManager.activeSessionId.value = null;
        }
        // Clear chat messages for new bot context
        chat.setMessages([]);
      }
    },
    { immediate: false }
  );

  // Computed properties
  const currentBot = computed(() =>
    availableBots.value.find(b => b.id === selectedBotId.value)
  );

  const chatTitle = computed(() => currentBot.value?.name || 'AI Assistant');

  const userName = computed(() => currentUser.value?.name || '');
  const userAvatar = computed(() => currentUser.value?.avatar_url || '');
  const botName = computed(() => currentBot.value?.name || 'AI');
  const botAvatar = computed(() => currentBot.value?.avatar_url || '');

  const isDisabled = computed(() => !selectedBotId.value);

  // Fetch bots
  const fetchBots = async () => {
    if (!accountId.value) return;

    botsLoading.value = true;
    try {
      const response = await fetch(
        `/api/v1/accounts/${accountId.value}/ai_chat/bots`,
        { method: 'GET', headers: getAuthHeaders() }
      );

      if (!response.ok) {
        throw new Error(`Failed to fetch bots: ${response.status}`);
      }

      const data = await response.json();
      const parsed = parseBotsResponse(data);
      availableBots.value = parsed.bots;

      if (availableBots.value.length > 0 && !selectedBotId.value) {
        selectedBotId.value = availableBots.value[0].id;
      }
    } catch {
      availableBots.value = [];
    } finally {
      botsLoading.value = false;
    }
  };

  // Auto-fetch bots on mount
  // Sessions are fetched lazily when user opens history panel
  onMounted(async () => {
    await fetchBots();
    // Restore previous session from localStorage (includes loading messages)
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
    loadSession: sessionId =>
      sessionManager.loadSession(sessionId, selectedBotId.value, chat),
    startNewSession: () =>
      sessionManager.startNewSession(selectedBotId.value, chat),
    deleteSession: sessionId =>
      sessionManager.deleteSession(sessionId, selectedBotId.value),
    fetchSessions: () => sessionManager.fetchSessions(selectedBotId.value),

    // Methods
    fetchBots,
  };
}
