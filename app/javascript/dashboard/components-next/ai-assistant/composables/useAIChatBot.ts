/**
 * useAIChatBot.ts
 *
 * Composable for managing AI chat bot selection and fetching.
 * Extracted from useAiAssistant for separation of concerns.
 *
 * Mobile equivalent: chatwoot-mobile-app/src/presentation/hooks/ai-assistant/useAIChatBot.ts
 */
import { ref, computed, type Ref, type ComputedRef } from 'vue';
import type { Bot } from '../types';
import { getAuthHeaders } from '../utils/auth';
import { parseBotsResponse } from '../schemas';

export interface UseAIChatBotReturn {
  selectedBotId: Ref<number | null>;
  availableBots: Ref<Bot[]>;
  botsLoading: Ref<boolean>;
  currentBot: ComputedRef<Bot | undefined>;
  fetchBots: () => Promise<void>;
}

export function useAIChatBot(
  accountId: Ref<number | null> | number | null,
): UseAIChatBotReturn {
  const selectedBotId = ref<number | null>(null);
  const availableBots = ref<Bot[]>([]);
  const botsLoading = ref(false);

  const currentBot = computed((): Bot | undefined =>
    availableBots.value.find(b => b.id === selectedBotId.value),
  );

  const getAccountIdValue = (): number | null => {
    if (accountId === null) return null;
    if (typeof accountId === 'number') return accountId;
    return accountId.value;
  };

  const fetchBots = async (): Promise<void> => {
    const acctId = getAccountIdValue();
    if (!acctId) return;

    botsLoading.value = true;
    try {
      const response = await fetch(
        `/api/v1/accounts/${acctId}/ai_chat/bots`,
        { method: 'GET', headers: getAuthHeaders() },
      );

      if (!response.ok) {
        throw new Error(`Failed to fetch bots: ${response.status}`);
      }

      const data = await response.json();
      const parsed = parseBotsResponse(data);
      availableBots.value = parsed.bots as Bot[];

      if (availableBots.value.length > 0 && !selectedBotId.value) {
        selectedBotId.value = availableBots.value[0].id;
      }
    } catch {
      availableBots.value = [];
    } finally {
      botsLoading.value = false;
    }
  };

  return {
    selectedBotId,
    availableBots,
    botsLoading,
    currentBot,
    fetchBots,
  };
}
