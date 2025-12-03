/**
 * useAiAssistant.js
 *
 * Composable for AI Assistant domain logic.
 * Handles bot fetching, auth, chat state initialization.
 * Used by AiAssistant orchestrator component.
 */
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useVercelChat } from './useVercelChat';
import Auth from 'dashboard/api/auth';

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

  // Auth headers helper
  const getAuthHeaders = () => {
    const headers = { 'Content-Type': 'application/json' };
    if (Auth.hasAuthCookie()) {
      const authData = Auth.getAuthData();
      headers['access-token'] = authData['access-token'];
      headers['token-type'] = authData['token-type'];
      headers.client = authData.client;
      headers.expiry = authData.expiry;
      headers.uid = authData.uid;
    }
    return headers;
  };

  // Bot selection state
  const selectedBotId = ref(null);
  const availableBots = ref([]);
  const botsLoading = ref(false);

  // Session management
  const activeChatSessionId = ref(null);

  // Initialize Vercel AI SDK Chat
  const chat = useVercelChat({
    api: `/api/v1/accounts/${accountId.value}/ai_chat/stream`,
    body: () => ({
      agent_bot_id: selectedBotId.value,
      chat_session_id: activeChatSessionId.value,
    }),
    onSessionId: id => {
      activeChatSessionId.value = id;
    },
  });

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
      availableBots.value = data.bots || [];

      if (availableBots.value.length > 0 && !selectedBotId.value) {
        selectedBotId.value = availableBots.value[0].id;
      }
    } catch {
      availableBots.value = [];
    } finally {
      botsLoading.value = false;
    }
  };

  // Auto-fetch on mount
  onMounted(() => {
    fetchBots();
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

    // Methods
    fetchBots,
  };
}

export default useAiAssistant;
