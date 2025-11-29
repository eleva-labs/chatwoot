<script setup>
/**
 * FloatingAIAssistantPOC.vue
 *
 * Proof of Concept component using Vercel AI SDK's Chat class.
 * This is a simplified version to test SDK compatibility.
 */
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useVercelChat } from 'dashboard/composables/useVercelChatAdapter';
import Auth from 'dashboard/api/auth';
import Avatar from 'next/avatar/Avatar.vue';

const route = useRoute();
const store = useStore();

// Get current user info
const currentUser = computed(() => store.getters.getCurrentUser);

// Get accountId from route params
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

// UI State
const showChat = ref(false);
const showFAB = ref(true);
const input = ref('');

// Bot selection
const selectedBotId = ref(null);
const availableBots = ref([]);

// Session management
const activeChatSessionId = ref(null);

// Initialize Vercel AI SDK Chat
const chat = useVercelChat({
  api: computed(() => `/api/v1/accounts/${accountId.value}/ai_chat/stream`)
    .value,
  getAuthHeaders,
  body: () => ({
    agent_bot_id: selectedBotId.value,
    chat_session_id: activeChatSessionId.value,
  }),
  onFinish: message => {
    // eslint-disable-next-line no-console
    console.log('[POC] Stream finished:', message);
  },
  onError: error => {
    // eslint-disable-next-line no-console
    console.error('[POC] Stream error:', error);
  },
});

// Computed properties for UI
const currentBot = computed(() =>
  availableBots.value.find(b => b.id === selectedBotId.value)
);

const isStreaming = computed(() => chat.status === 'streaming');
const isLoading = computed(
  () => chat.status === 'submitted' || chat.status === 'streaming'
);

// Message submission
const handleSubmit = async event => {
  event.preventDefault();

  if (!input.value.trim() || isLoading.value || !selectedBotId.value) return;

  const userMessage = input.value.trim();
  input.value = '';

  try {
    await chat.sendMessage({ text: userMessage });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[POC] Send message error:', error);
  }
};

// Fetch available bots
const fetchBots = async () => {
  if (!accountId.value) return;

  try {
    const response = await fetch(
      `/api/v1/accounts/${accountId.value}/ai_chat/bots`,
      {
        method: 'GET',
        headers: getAuthHeaders(),
      }
    );

    if (!response.ok) {
      throw new Error('Failed to fetch bots');
    }

    const data = await response.json();
    availableBots.value = data.bots || [];

    if (availableBots.value.length > 0 && !selectedBotId.value) {
      selectedBotId.value = availableBots.value[0].id;
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[POC] Failed to fetch bots:', err);
  }
};

// Toggle chat visibility
const toggleChat = () => {
  showChat.value = !showChat.value;
};

// Lifecycle
onMounted(() => {
  fetchBots();
});

// Expose for debugging in devtools
defineExpose({ chat, isStreaming });
</script>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<template>
  <!-- POC Badge -->
  <div v-if="showFAB" class="fixed bottom-24 right-6 z-50">
    <span
      class="rounded-full bg-orange-500 px-2 py-1 text-xs font-bold text-white"
    >
      POC
    </span>
  </div>

  <!-- FAB Button -->
  <div v-if="showFAB" class="fixed bottom-6 right-6 z-50">
    <button
      class="flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-lg hover:brightness-110"
      :class="{ 'animate-pulse': isLoading }"
      @click="toggleChat"
    >
      <span class="i-lucide-sparkles text-2xl" />
    </button>
  </div>

  <!-- Chat Popup -->
  <div
    v-if="showChat"
    class="fixed bottom-24 right-6 z-40 flex h-[550px] w-96 flex-col rounded-lg border border-gray-200 bg-white shadow-2xl dark:border-n-weak dark:bg-n-solid-2"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between rounded-t-lg border-b border-gray-200 bg-gradient-to-r from-purple-500 to-pink-500 px-4 py-3 dark:border-n-weak"
    >
      <div class="flex items-center gap-2">
        <span
          class="rounded bg-white px-2 py-0.5 text-xs font-bold text-purple-700"
          >POC</span
        >
        <h3 class="text-sm font-semibold text-white">
          {{ currentBot?.name || 'AI Assistant (Vercel SDK)' }}
        </h3>
      </div>
      <button
        class="rounded-md p-2 text-white/80 transition-colors hover:text-white"
        @click="toggleChat"
      >
        <span class="i-lucide-x text-xl" />
      </button>
    </div>

    <!-- Status Bar -->
    <div
      class="border-b border-gray-200 bg-gray-50 px-4 py-2 text-xs dark:border-n-weak dark:bg-n-solid-1"
    >
      <span class="font-medium">Status:</span>
      <span
        class="ml-2 rounded-full px-2 py-0.5"
        :class="{
          'bg-green-100 text-green-700': chat.status === 'ready',
          'bg-yellow-100 text-yellow-700': chat.status === 'submitted',
          'bg-blue-100 text-blue-700': chat.status === 'streaming',
          'bg-red-100 text-red-700': chat.status === 'error',
        }"
      >
        {{ chat.status }}
      </span>
    </div>

    <!-- Bot Selector -->
    <div
      v-if="availableBots.length > 1"
      class="border-b border-gray-200 px-4 py-2 dark:border-n-weak"
    >
      <select
        v-model="selectedBotId"
        class="w-full rounded-md border px-3 py-2 text-sm dark:border-n-weak dark:bg-n-solid-3"
      >
        <option v-for="bot in availableBots" :key="bot.id" :value="bot.id">
          {{ bot.name }}
        </option>
      </select>
    </div>

    <!-- Messages -->
    <div class="flex-1 space-y-4 overflow-y-auto p-4">
      <!-- Empty state -->
      <div
        v-if="chat.messages.length === 0"
        class="flex h-full flex-col items-center justify-center text-center"
      >
        <span class="i-lucide-sparkles mb-3 text-5xl text-purple-300" />
        <p class="text-sm font-medium text-gray-700 dark:text-n-slate-11">
          Vercel AI SDK POC
        </p>
        <p class="text-xs text-gray-500 dark:text-n-slate-10">
          Testing @ai-sdk/vue Chat class
        </p>
      </div>

      <!-- Message list using parts[] structure -->
      <div
        v-for="message in chat.messages"
        :key="message.id"
        class="flex gap-2"
        :class="message.role === 'user' ? 'justify-end' : 'justify-start'"
      >
        <!-- Avatar for assistant -->
        <div v-if="message.role === 'assistant'" class="flex-shrink-0">
          <Avatar
            :src="currentBot?.avatar_url"
            :name="currentBot?.name || 'AI'"
            :size="32"
            rounded-full
          />
        </div>

        <!-- Message content -->
        <div
          class="flex max-w-[75%] flex-col gap-1"
          :class="message.role === 'user' ? 'items-end' : 'items-start'"
        >
          <!-- Render each part -->
          <template v-for="(part, idx) in message.parts" :key="idx">
            <!-- Text part -->
            <div
              v-if="part.type === 'text'"
              class="rounded-2xl px-4 py-2"
              :class="
                message.role === 'user'
                  ? 'rounded-br-sm bg-purple-500 text-white'
                  : 'rounded-bl-sm bg-gray-100 text-gray-800 dark:bg-n-solid-3 dark:text-n-slate-12'
              "
            >
              <p class="whitespace-pre-wrap text-sm">{{ part.text }}</p>
              <span
                v-if="part.state === 'streaming'"
                class="ml-1 inline-block h-4 w-2 animate-pulse bg-current"
              />
            </div>

            <!-- Reasoning part -->
            <div
              v-else-if="part.type === 'reasoning'"
              class="w-full rounded-lg border border-purple-200 bg-purple-50 px-3 py-2 text-xs dark:border-purple-800 dark:bg-purple-900/20"
            >
              <details :open="part.state === 'streaming'">
                <summary
                  class="cursor-pointer font-medium text-purple-700 dark:text-purple-300"
                >
                  {{
                    part.state === 'streaming'
                      ? 'Thinking...'
                      : 'View reasoning'
                  }}
                </summary>
                <p
                  class="mt-2 whitespace-pre-wrap text-gray-600 dark:text-gray-400"
                >
                  {{ part.text }}
                </p>
              </details>
            </div>

            <!-- Tool part -->
            <div
              v-else-if="part.type?.startsWith('tool-')"
              class="w-full rounded-lg border border-blue-200 bg-blue-50 px-3 py-2 text-xs dark:border-blue-800 dark:bg-blue-900/20"
            >
              <div class="flex items-center gap-2">
                <span class="i-lucide-wrench text-blue-500" />
                <span class="font-medium text-blue-700 dark:text-blue-300">
                  {{ part.type.replace('tool-', '') }}
                </span>
                <span
                  class="rounded-full px-2 py-0.5 text-xs"
                  :class="{
                    'bg-yellow-100 text-yellow-700':
                      part.state === 'input-streaming',
                    'bg-blue-100 text-blue-700':
                      part.state === 'input-available',
                    'bg-green-100 text-green-700':
                      part.state === 'output-available',
                    'bg-red-100 text-red-700': part.state === 'output-error',
                  }"
                >
                  {{ part.state }}
                </span>
              </div>
            </div>
          </template>
        </div>

        <!-- Avatar for user -->
        <div v-if="message.role === 'user'" class="flex-shrink-0">
          <Avatar
            :src="currentUser?.avatar_url"
            :name="currentUser?.name || 'User'"
            :size="32"
            rounded-full
          />
        </div>
      </div>
    </div>

    <!-- Error display -->
    <div
      v-if="chat.error"
      class="border-t border-red-200 bg-red-50 px-4 py-2 text-xs text-red-600 dark:bg-red-900/20"
    >
      {{ chat.error.message || 'An error occurred' }}
    </div>

    <!-- Input form -->
    <form
      class="border-t border-gray-200 p-4 dark:border-n-weak"
      @submit="handleSubmit"
    >
      <div class="flex items-center gap-3">
        <textarea
          v-model="input"
          placeholder="Type a message..."
          :disabled="isLoading || !selectedBotId"
          rows="1"
          class="flex-1 resize-none rounded-2xl border px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 dark:border-n-weak dark:bg-n-solid-3"
          @keydown.enter.exact.prevent="handleSubmit"
        />
        <button
          type="submit"
          class="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-r from-purple-500 to-pink-500 text-white hover:brightness-110 disabled:opacity-50"
          :disabled="!input?.trim() || isLoading || !selectedBotId"
        >
          <span class="i-lucide-arrow-up text-lg" />
        </button>
      </div>
    </form>
  </div>

  <!-- Backdrop -->
  <div
    v-if="showChat"
    class="fixed inset-0 z-30 bg-black/10"
    @click="toggleChat"
  />
</template>
