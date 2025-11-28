<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAIStreaming } from 'dashboard/composables/useAIStreaming';
import { useI18n } from 'vue-i18n';
import Auth from '../api/auth';
import Avatar from 'next/avatar/Avatar.vue';

// Get route for accountId
const route = useRoute();
const store = useStore();
const { t: $t } = useI18n();

// Get current user info
const currentUser = computed(() => store.getters.getCurrentUser);
const userAvatar = computed(
  () => currentUser.value?.avatar_url || currentUser.value?.thumbnail
);
const userName = computed(() => currentUser.value?.name || 'User');

// Get accountId from route params OR window location
const accountId = computed(() => {
  // Try route params first
  if (route.params.accountId) {
    return Number(route.params.accountId);
  }

  // Fallback: Extract from URL path /app/accounts/:accountId/...
  const pathMatch = window.location.pathname.match(/\/accounts\/(\d+)/);
  if (pathMatch) {
    return Number(pathMatch[1]);
  }

  // Last resort: Try window.chatwootConfig
  return window.chatwootConfig?.accountId || null;
});

// Helper to get auth headers for API requests
const getAuthHeaders = () => {
  const headers = {
    'Content-Type': 'application/json',
  };

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

// Dragging state
const fabContainer = ref(null);
const messagesContainer = ref(null);
const isDragging = ref(false);
const hasDragged = ref(false);
const dragOffset = ref({ x: 0, y: 0 });
const fabPosition = ref({
  x: typeof window !== 'undefined' ? window.innerWidth - 80 : 0,
  y: typeof window !== 'undefined' ? window.innerHeight - 100 : 0,
});

// Chat state
const showChat = ref(false);
const showFAB = ref(true);
const showConversationList = ref(false);

// Conversation management (declare before use in composable)
const activeChatSessionId = ref(null);

// Initialize AI Streaming composable
const {
  messages,
  isLoading,
  isStreaming,
  error,
  currentToolCall,
  activeAssistantMessageId,
  currentReasoning,
  sendMessage: sendStreamingMessage,
  setMessages,
  clear: clearChat,
} = useAIStreaming({
  getAuthHeaders,
  onSessionIdExtracted: sessionId => {
    activeChatSessionId.value = sessionId;
  },
});

// Input state (managed separately)
const input = ref('');

// Bot selection state
const selectedBotId = ref(null);
const availableBots = ref([]);

// Conversation management
const conversations = ref({});

// Dark mode detection with reactivity
const themeChangeCounter = ref(0);

const isDarkMode = computed(() => {
  // eslint-disable-next-line no-unused-expressions
  themeChangeCounter.value; // Trigger reactivity
  return (
    document.documentElement.classList.contains('dark') ||
    document.body.classList.contains('dark') ||
    document.querySelector('.app-wrapper')?.classList.contains('dark') ||
    window.matchMedia('(prefers-color-scheme: dark)').matches
  );
});

// FAB positioning handled by existing fabStyle below

// Get current bot
const currentBot = computed(() =>
  availableBots.value.find(b => b.id === selectedBotId.value)
);

// Get conversations for selected bot
const currentBotConversations = computed(
  () => conversations.value[selectedBotId.value] || []
);

// ========================================
// Configuration
// ========================================
const SESSIONS_LIMIT = ref(25); // Configurable limit for session list
const MESSAGES_LIMIT = ref(100); // Optional limit for messages per session
const SCROLL_THRESHOLD_PX = 40;
const shouldAutoScroll = ref(true);
const thoughtsExpanded = ref(false);

const thoughtsTitle = computed(() => $t('GENERAL.AI_THOUGHTS_TITLE'));

const hasReasoning = computed(
  () => currentReasoning.value && currentReasoning.value.trim().length > 0
);

const shouldShowThoughtsPanel = computed(() => {
  const show = hasReasoning.value;
  // eslint-disable-next-line no-console
  console.log(
    '[Thoughts Panel] shouldShow:',
    show,
    'isStreaming:',
    isStreaming.value,
    'hasReasoning:',
    hasReasoning.value,
    'reasoning length:',
    currentReasoning.value?.length
  );
  return show;
});

const displayItems = computed(() => {
  const baseMessages = [...messages.value];

  if (!shouldShowThoughtsPanel.value) {
    return baseMessages;
  }

  let insertionIndex = baseMessages.length;

  for (let idx = baseMessages.length - 1; idx >= 0; idx -= 1) {
    if (baseMessages[idx].role === 'user') {
      insertionIndex = idx + 1;
      break;
    }
  }

  const itemsWithThoughts = [...baseMessages];
  itemsWithThoughts.splice(insertionIndex, 0, {
    id: '__thoughts__',
    type: 'thoughts',
  });

  return itemsWithThoughts;
});

const scrollToBottom = (behavior = 'smooth') => {
  const container = messagesContainer.value;
  if (!container || !shouldAutoScroll.value) {
    return;
  }

  window.requestAnimationFrame(() => {
    container.scrollTo({
      top: container.scrollHeight,
      behavior,
    });
  });
};

const onMessagesScroll = () => {
  const container = messagesContainer.value;
  if (!container) return;

  const distanceFromBottom =
    container.scrollHeight - (container.scrollTop + container.clientHeight);
  shouldAutoScroll.value = distanceFromBottom <= SCROLL_THRESHOLD_PX;
};

// ========================================
// localStorage Management Functions
// ========================================
const STORAGE_KEY = 'ai_assistant_conversations';

// Load conversations from localStorage
const loadConversationsFromStorage = () => {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      conversations.value = JSON.parse(stored);
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Failed to load conversations from storage:', e);
    conversations.value = {};
  }
};

// Cleanup old conversations (keep last 50 per bot)
const cleanupOldConversations = () => {
  Object.keys(conversations.value).forEach(botId => {
    const botConvs = conversations.value[botId];
    if (botConvs.length > 50) {
      // Sort by lastMessageAt, keep newest 50
      botConvs.sort(
        (a, b) => new Date(b.lastMessageAt) - new Date(a.lastMessageAt)
      );
      conversations.value[botId] = botConvs.slice(0, 50);
    }
  });
};

// Save conversations to localStorage with quota handling
const saveConversationsToStorage = () => {
  try {
    const data = JSON.stringify(conversations.value);

    // Check size before saving (5MB = 5,000,000 bytes)
    if (data.length > 4500000) {
      cleanupOldConversations();
    }

    localStorage.setItem(STORAGE_KEY, data);
  } catch (e) {
    if (e.name === 'QuotaExceededError') {
      // eslint-disable-next-line no-console
      console.warn(
        'localStorage quota exceeded, cleaning up old conversations'
      );
      cleanupOldConversations();

      // Retry save after cleanup
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(conversations.value));
      } catch (retryError) {
        // eslint-disable-next-line no-console
        console.error(
          'Failed to save conversations after cleanup:',
          retryError
        );
      }
    } else {
      // eslint-disable-next-line no-console
      console.error('Failed to save conversations:', e);
    }
  }
};

// Cleanup null-id conversations when bot changes
const cleanupNullConversations = () => {
  Object.keys(conversations.value).forEach(botId => {
    conversations.value[botId] = conversations.value[botId].filter(
      c => c.id !== null
    );
  });
};

// Watch conversations and auto-save to localStorage
watch(
  conversations,
  () => {
    saveConversationsToStorage();
  },
  { deep: true }
);

// ========================================
// API Functions (Backend Integration)
// ========================================

// Fetch sessions from AI Backend via Rails API
const fetchSessions = async () => {
  if (!selectedBotId.value || !accountId.value) return [];

  try {
    const response = await fetch(
      `/api/v1/accounts/${accountId.value}/ai_chat/sessions?agent_bot_id=${selectedBotId.value}&limit=${SESSIONS_LIMIT.value}`,
      {
        method: 'GET',
        headers: getAuthHeaders(),
      }
    );

    if (!response.ok) {
      throw new Error('Failed to fetch sessions');
    }

    const data = await response.json();
    return data.sessions || [];
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to fetch sessions from backend:', err);
    // Fallback to localStorage if API fails
    return currentBotConversations.value;
  }
};

// Fetch messages for a specific session
const fetchSessionMessages = async sessionId => {
  if (!accountId.value) return [];

  try {
    const url = `/api/v1/accounts/${accountId.value}/ai_chat/sessions/${sessionId}/messages`;
    const queryParams = MESSAGES_LIMIT.value
      ? `?limit=${MESSAGES_LIMIT.value}`
      : '';

    const response = await fetch(url + queryParams, {
      method: 'GET',
      headers: getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to fetch messages');
    }

    const data = await response.json();
    return data.messages || [];
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to fetch messages from backend:', err);
    return [];
  }
};

// Helper to generate title from backend session
const generateTitleFromSession = () => {
  // Simple generic title - date/time shown separately via formatDate
  return 'Conversation';
};

// ========================================
// Conversation Management Functions
// ========================================

const loadConversation = async conversationId => {
  try {
    // Fetch messages from AI Backend
    const backendMessages = await fetchSessionMessages(conversationId);

    if (backendMessages.length > 0) {
      // Use backend messages (source of truth)
      // Backend returns newest-first, so reverse to oldest-first for chat UI
      const formattedMessages = backendMessages
        .map(msg => ({
          id: msg.id || Date.now(),
          role: msg.role,
          content: msg.content,
          timestamp: msg.timestamp,
        }))
        .reverse(); // ← Fix message order

      setMessages(formattedMessages);
    } else {
      // Fallback to localStorage (for offline support)
      const conv = currentBotConversations.value.find(
        c => c.id === conversationId
      );
      if (conv) {
        setMessages([...conv.messages]);
      }
    }

    activeChatSessionId.value = conversationId;
    showConversationList.value = false;
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to load conversation:', err);
  }
};

const loadOrCreateConversation = async () => {
  if (!selectedBotId.value) return;

  try {
    // Fetch sessions from AI Backend
    const backendSessions = await fetchSessions();

    if (backendSessions.length > 0) {
      // Merge backend sessions with localStorage (backend is source of truth)
      const mergedSessions = backendSessions.map(bs => {
        // Check if we have local messages for this session
        const localConv = currentBotConversations.value.find(
          c => c.id === bs.chat_session_id
        );

        return {
          id: bs.chat_session_id,
          title: localConv?.title || generateTitleFromSession(bs),
          messages: localConv?.messages || [], // Will be loaded on-demand
          lastMessageAt: bs.updated_at,
          source: 'backend', // Track data source
        };
      });

      // Update conversations in state
      conversations.value[selectedBotId.value] = mergedSessions;

      // Load most recent conversation
      if (mergedSessions.length > 0) {
        await loadConversation(mergedSessions[0].id);
      }
    } else {
      // No backend sessions - check localStorage
      const botConvs = currentBotConversations.value;
      if (botConvs.length === 0) {
        clearChat();
        activeChatSessionId.value = null;
      } else {
        await loadConversation(botConvs[0].id);
      }
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to load conversations:', err);
    // Fallback to localStorage on error
    const botConvs = currentBotConversations.value;
    if (botConvs.length > 0) {
      await loadConversation(botConvs[0].id);
    }
  }
};

const createNewConversation = () => {
  if (!selectedBotId.value) return;

  // Clear current chat using composable
  clearChat();
  activeChatSessionId.value = null;
  showConversationList.value = false;
};

const deleteConversation = async conversationId => {
  // eslint-disable-next-line no-alert
  if (!window.confirm('Are you sure you want to delete this conversation?'))
    return;

  try {
    // Delete from backend first
    const response = await fetch(
      `/api/v1/accounts/${accountId.value}/ai_chat/sessions/${conversationId}`,
      {
        method: 'DELETE',
        headers: getAuthHeaders(),
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to delete conversation');
    }

    // Remove from localStorage after successful backend deletion
    const botConvs = currentBotConversations.value;
    conversations.value[selectedBotId.value] = botConvs.filter(
      c => c.id !== conversationId
    );

    // If deleting active conversation, clear it
    if (activeChatSessionId.value === conversationId) {
      createNewConversation();
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to delete conversation:', err);
    // Error handling done by composable
  }
};

const handleBotChange = async () => {
  showConversationList.value = false;

  // Clean up null-id conversations from previous bot
  cleanupNullConversations();

  await loadOrCreateConversation();
};

const toggleConversationList = () => {
  showConversationList.value = !showConversationList.value;
};

const generateConversationTitle = firstMessage => {
  const maxLength = 50;
  if (firstMessage.length <= maxLength) return firstMessage;
  return `${firstMessage.substring(0, maxLength).trim()}...`;
};

const autoResizeTextarea = event => {
  const textarea = event.target;
  textarea.style.height = 'auto';
  textarea.style.height = `${Math.min(textarea.scrollHeight, 128)}px`;
};

const updateConversationInStorage = (sessionId, firstMessage) => {
  if (!selectedBotId.value) return;

  const botConvs = currentBotConversations.value;
  const isFirstMessage = !activeChatSessionId.value;

  if (isFirstMessage && sessionId) {
    // Create new conversation
    const newConv = {
      id: sessionId,
      title: generateConversationTitle(firstMessage),
      messages: [...messages.value],
      lastMessageAt: new Date().toISOString(),
    };
    conversations.value[selectedBotId.value] = [newConv, ...botConvs];
  } else {
    // Update existing conversation
    const conv = botConvs.find(c => c.id === activeChatSessionId.value);
    if (conv) {
      conv.messages = [...messages.value];
      conv.lastMessageAt = new Date().toISOString();
    }
  }
};

// Format date for conversation list - shows date and time
const formatDate = dateString => {
  if (!dateString) return '';

  const date = new Date(dateString);
  const now = new Date();

  // Compare just the date parts (ignoring time)
  // eslint-disable-next-line prettier/prettier
  const dateOnly = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  // eslint-disable-next-line prettier/prettier
  const nowOnly = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diffMs = nowOnly - dateOnly;
  const diffDays = Math.floor(diffMs / 86400000);

  const time = date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  });

  if (diffDays === 0) return time; // Just show time if today (e.g., "3:54 PM")
  if (diffDays === 1) return `Yesterday ${time}`; // e.g., "Yesterday 3:54 PM"

  // For older: Show date + time (e.g., "Oct 30 3:54 PM")
  const dateStr = date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  });

  return `${dateStr} ${time}`;
};

// Format time for messages
const formatTime = timestamp => {
  return new Date(timestamp).toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  });
};

// Message submission - Uses streaming composable
const handleSubmit = async event => {
  event.preventDefault();

  if (!input.value.trim() || isLoading.value || !selectedBotId.value) return;

  const userMessage = input.value.trim();
  const isFirstMessage = messages.value.length === 0;

  // Clear input immediately
  input.value = '';

  // Reset textarea height
  nextTick(() => {
    const textarea = document.querySelector('textarea');
    if (textarea) {
      textarea.style.height = 'auto';
    }
  });

  shouldAutoScroll.value = true;
  nextTick(() => {
    scrollToBottom('smooth');
  });
  thoughtsExpanded.value = true;

  // Validate accountId
  if (!accountId.value) {
    // eslint-disable-next-line no-console
    console.error('Account ID not available');
    return;
  }

  // Send message using streaming composable (handles fallback automatically)
  const result = await sendStreamingMessage({
    url: `/api/v1/accounts/${accountId.value}/ai_chat/stream`,
    body: {
      messages: [{ role: 'user', content: userMessage }],
      agent_bot_id: selectedBotId.value,
      chat_session_id: activeChatSessionId.value,
    },
    fallbackToNonStreaming: true, // Silent fallback on error
  });

  // Update conversation in storage
  if (result.success) {
    if (isFirstMessage && result.sessionId) {
      activeChatSessionId.value = result.sessionId;
      updateConversationInStorage(result.sessionId, userMessage);
    } else {
      updateConversationInStorage(activeChatSessionId.value, userMessage);
    }
    saveConversationsToStorage();
  }
};

// Fetch available bots from API (Hybrid: AI Backend + Chatwoot)
const fetchBots = async () => {
  try {
    // Check if accountId is available
    if (!accountId.value) {
      throw new Error('Account ID not available');
    }

    const response = await fetch(
      `/api/v1/accounts/${accountId.value}/ai_chat/bots`,
      {
        method: 'GET',
        headers: getAuthHeaders(),
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to fetch bots');
    }

    const data = await response.json();
    availableBots.value = data.bots || [];

    // Auto-select first bot if available
    if (availableBots.value.length > 0 && !selectedBotId.value) {
      selectedBotId.value = availableBots.value[0].id;
      loadOrCreateConversation();
    } else if (availableBots.value.length === 0) {
      // eslint-disable-next-line no-console
      console.warn('No AI assistants are currently configured');
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to fetch bots:', err);
  }
};

// Computed styles
const fabStyle = computed(() => {
  return {
    left: `${fabPosition.value.x}px`,
    top: `${fabPosition.value.y}px`,
    'z-index': '9999 !important',
  };
});

const chatStyleWithTheme = computed(() => {
  const fabX = fabPosition.value.x;
  const fabY = fabPosition.value.y;
  const chatWidth = 380;
  const chatHeight = 550;

  // Position chat popup relative to FAB
  let chatX = fabX - chatWidth + 56;
  let chatY = fabY - chatHeight - 26;

  // Adjust if chat would go off screen
  if (chatX < 10) chatX = 10;
  if (chatX + chatWidth > window.innerWidth - 10) {
    chatX = window.innerWidth - chatWidth - 10;
  }
  if (chatY < 10) {
    chatY = fabY + 66;
  }

  return {
    left: `${chatX}px`,
    top: `${chatY}px`,
    width: `${chatWidth}px`,
    height: `${chatHeight}px`,
    boxShadow:
      '0 0 0 1px rgba(139, 92, 246, 0.8), 0 0 20px rgba(139, 92, 246, 0.5), 0 0 40px rgba(139, 92, 246, 0.3), 0 0 60px rgba(139, 92, 246, 0.15)',
    border: '1px solid transparent',
    backgroundImage: `linear-gradient(${
      isDarkMode.value ? 'rgb(29, 30, 36)' : 'white'
    }, ${
      isDarkMode.value ? 'rgb(29, 30, 36)' : 'white'
    }), linear-gradient(135deg, #ec4899, #8b5cf6, #6366f1)`,
    backgroundOrigin: 'border-box',
    backgroundClip: 'padding-box, border-box',
  };
});

// Drag functionality - Define functions first
const drag = event => {
  if (!isDragging.value) return;

  hasDragged.value = true; // Mark that actual dragging occurred

  const clientX = event.touches ? event.touches[0].clientX : event.clientX;
  const clientY = event.touches ? event.touches[0].clientY : event.clientY;

  let newX = clientX - dragOffset.value.x;
  let newY = clientY - dragOffset.value.y;

  // Constrain to viewport
  const fabSize = 56;
  newX = Math.max(0, Math.min(window.innerWidth - fabSize, newX));
  newY = Math.max(0, Math.min(window.innerHeight - fabSize, newY));

  fabPosition.value = { x: newX, y: newY };

  if (event.touches) {
    event.preventDefault();
  }
};

const stopDrag = () => {
  isDragging.value = false;
  document.removeEventListener('mousemove', drag);
  document.removeEventListener('mouseup', stopDrag);
  document.removeEventListener('touchmove', drag);
  document.removeEventListener('touchend', stopDrag);

  // Reset hasDragged after a short delay to allow click handler to check it
  setTimeout(() => {
    hasDragged.value = false;
  }, 100);
};

const startDrag = event => {
  if (showChat.value) return; // Don't drag when chat is open

  isDragging.value = true;
  hasDragged.value = false; // Reset drag flag
  const clientX = event.touches ? event.touches[0].clientX : event.clientX;
  const clientY = event.touches ? event.touches[0].clientY : event.clientY;

  dragOffset.value = {
    x: clientX - fabPosition.value.x,
    y: clientY - fabPosition.value.y,
  };

  document.addEventListener('mousemove', drag);
  document.addEventListener('mouseup', stopDrag);
  document.addEventListener('touchmove', drag, { passive: false });
  document.addEventListener('touchend', stopDrag);

  event.preventDefault();
};

watch(
  messages,
  () => {
    nextTick(() => {
      scrollToBottom('smooth');
    });
  },
  { deep: true }
);

watch(isStreaming, (newVal, oldVal) => {
  if (newVal) {
    thoughtsExpanded.value = true;
  }
  if (!newVal && oldVal) {
    nextTick(() => {
      shouldAutoScroll.value = true;
      scrollToBottom('smooth');
    });
  }
});

watch(
  () => hasReasoning.value,
  newVal => {
    if (newVal) {
      thoughtsExpanded.value = true;
      if (shouldAutoScroll.value) {
        nextTick(() => {
          scrollToBottom('smooth');
        });
      }
    }
  }
);

watch(currentReasoning, newVal => {
  if (!newVal && !isStreaming.value) {
    thoughtsExpanded.value = false;
    return;
  }

  if (newVal && shouldShowThoughtsPanel.value && shouldAutoScroll.value) {
    nextTick(() => {
      scrollToBottom('auto');
    });
  }
});

const toggleChat = () => {
  // Don't toggle if we just finished dragging
  if (hasDragged.value) return;
  showChat.value = !showChat.value;

  // Close conversation list when closing chat
  if (!showChat.value) {
    showConversationList.value = false;
  } else {
    shouldAutoScroll.value = true;
    nextTick(() => {
      scrollToBottom('auto');
    });
  }
};

const toggleThoughts = () => {
  if (!shouldShowThoughtsPanel.value) return;
  thoughtsExpanded.value = !thoughtsExpanded.value;
};

// Handle window resize
const handleResize = () => {
  const fabSize = 56;
  fabPosition.value.x = Math.min(
    fabPosition.value.x,
    window.innerWidth - fabSize
  );
  fabPosition.value.y = Math.min(
    fabPosition.value.y,
    window.innerHeight - fabSize
  );
};

// Lifecycle hooks
onMounted(() => {
  window.addEventListener('resize', handleResize);
  loadConversationsFromStorage(); // Load from localStorage
  fetchBots(); // Fetch real bots from API
  nextTick(() => {
    scrollToBottom('auto');
  });

  // Watch for theme changes
  const themeObserver = new MutationObserver(() => {
    themeChangeCounter.value += 1;
  });

  // Observe class changes on documentElement and body
  themeObserver.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
  });
  themeObserver.observe(document.body, {
    attributes: true,
    attributeFilter: ['class'],
  });

  // Also watch for app-wrapper if it exists
  const appWrapper = document.querySelector('.app-wrapper');
  if (appWrapper) {
    themeObserver.observe(appWrapper, {
      attributes: true,
      attributeFilter: ['class'],
    });
  }

  // Watch for system theme changes
  const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
  const handleThemeChange = () => {
    themeChangeCounter.value += 1;
  };
  mediaQuery.addEventListener('change', handleThemeChange);

  // Cleanup observer on unmount
  onUnmounted(() => {
    themeObserver.disconnect();
    mediaQuery.removeEventListener('change', handleThemeChange);
  });
});

onUnmounted(() => {
  window.removeEventListener('resize', handleResize);
  document.removeEventListener('mousemove', drag);
  document.removeEventListener('mouseup', stopDrag);
  document.removeEventListener('touchmove', drag);
  document.removeEventListener('touchend', stopDrag);

  // Cleanup null-id conversations before leaving
  cleanupNullConversations();
  saveConversationsToStorage();
});
</script>

<template>
  <!-- Floating Action Button -->
  <div
    v-if="showFAB"
    ref="fabContainer"
    :style="fabStyle"
    class="fixed z-50 select-none"
    @mousedown="startDrag"
    @touchstart="startDrag"
  >
    <button
      class="w-14 h-14 bg-n-brand hover:brightness-110 text-white rounded-full shadow-lg hover:shadow-xl transition-all duration-200 flex items-center justify-center cursor-move"
      :class="{ 'animate-pulse': isLoading }"
      @click="toggleChat"
    >
      <span class="i-lucide-bot text-2xl" />
    </button>
  </div>

  <!-- Chat Popup -->
  <div
    v-if="showChat"
    :style="chatStyleWithTheme"
    class="fixed z-40 rounded-lg flex flex-col"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between px-4 py-3 border-b rounded-t-lg"
      :class="[
        isDarkMode
          ? 'border-n-weak bg-n-solid-1'
          : 'border-gray-200 bg-gray-50',
      ]"
    >
      <button
        class="p-2 rounded-md transition-colors"
        :class="[
          isDarkMode
            ? 'text-n-slate-11 hover:bg-n-alpha-2'
            : 'text-gray-600 hover:bg-gray-200',
        ]"
        :title="$t('GENERAL.AI_CONVERSATIONS')"
        @click="toggleConversationList"
      >
        <span class="i-lucide-message-square-text text-xl" />
      </button>

      <h3
        class="text-sm font-semibold"
        :class="[isDarkMode ? 'text-n-slate-12' : 'text-gray-800']"
      >
        {{ currentBot?.name || $t('GENERAL.AI_ASSISTANT') }}
      </h3>

      <button
        class="p-2 rounded-md transition-colors"
        :class="[
          isDarkMode
            ? 'text-n-slate-11 hover:bg-n-alpha-2'
            : 'text-gray-600 hover:bg-gray-200',
        ]"
        :title="$t('GENERAL.CLOSE')"
        @click="toggleChat"
      >
        <span class="i-lucide-x text-xl" />
      </button>
    </div>

    <!-- Conversation History Sidebar (Overlay) -->
    <div
      v-if="showConversationList"
      class="absolute inset-0 z-10 rounded-lg flex flex-col"
      :class="[isDarkMode ? 'bg-n-solid-2' : 'bg-white']"
    >
      <!-- History Header -->
      <div
        class="flex items-center justify-between px-4 py-3 border-b"
        :class="[isDarkMode ? 'border-n-weak' : 'border-gray-200']"
      >
        <h3
          class="text-sm font-semibold"
          :class="[isDarkMode ? 'text-n-slate-12' : 'text-gray-800']"
        >
          {{ $t('GENERAL.AI_CONVERSATIONS') }}
        </h3>
        <button
          class="p-1 rounded-md transition-colors"
          :class="[
            isDarkMode
              ? 'text-n-slate-11 hover:bg-n-alpha-2'
              : 'text-gray-600 hover:bg-gray-200',
          ]"
          :title="$t('GENERAL.CLOSE')"
          @click="showConversationList = false"
        >
          <span class="i-lucide-x text-xl" />
        </button>
      </div>

      <!-- Bot Selector in History View -->
      <div
        class="px-4 py-3 border-b"
        :class="[isDarkMode ? 'border-n-weak' : 'border-gray-200']"
      >
        <select
          v-model="selectedBotId"
          class="w-full px-3 py-2 text-sm border rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500"
          :class="[
            isDarkMode
              ? 'bg-n-solid-3 border-n-weak text-n-slate-12'
              : 'bg-white border-gray-300 text-gray-800',
          ]"
          @change="handleBotChange"
        >
          <option v-for="bot in availableBots" :key="bot.id" :value="bot.id">
            {{ bot.name }}
          </option>
        </select>
      </div>

      <!-- New Conversation Button -->
      <div class="px-4 py-3">
        <button
          class="w-full flex items-center justify-center gap-2 px-4 py-2 bg-n-brand hover:brightness-110 text-white text-sm rounded-md transition-colors"
          @click="createNewConversation"
        >
          <span class="i-lucide-plus text-lg" />
          {{ $t('GENERAL.AI_NEW_CONVERSATION') }}
        </button>
      </div>

      <!-- Conversation List -->
      <div class="flex-1 overflow-y-auto px-4 pb-4">
        <div
          v-if="currentBotConversations.length === 0"
          class="text-center py-8"
        >
          <p
            class="text-sm"
            :class="[isDarkMode ? 'text-n-slate-11' : 'text-gray-500']"
          >
            {{ $t('GENERAL.AI_NO_CONVERSATIONS') }}
          </p>
        </div>

        <div
          v-for="conv in currentBotConversations"
          :key="conv.id"
          class="mb-2 p-3 rounded-lg border cursor-pointer transition-all"
          :class="[
            conv.id === activeChatSessionId
              ? isDarkMode
                ? 'bg-n-iris-3 border-n-iris-6'
                : 'bg-blue-50 border-blue-300'
              : isDarkMode
                ? 'bg-n-solid-3 border-n-weak hover:bg-n-alpha-2'
                : 'bg-gray-50 border-gray-200 hover:bg-gray-100',
          ]"
          @click="loadConversation(conv.id)"
        >
          <div class="flex items-center justify-between gap-2">
            <div class="flex-1 min-w-0 flex items-baseline gap-2">
              <p
                class="text-sm font-medium truncate"
                :class="[isDarkMode ? 'text-n-slate-12' : 'text-gray-800']"
                :title="conv.title"
              >
                {{ conv.title }}
              </p>
              <p
                class="text-xs flex-shrink-0"
                :class="[isDarkMode ? 'text-n-slate-10' : 'text-gray-400']"
              >
                {{ formatDate(conv.lastMessageAt) }}
              </p>
            </div>
            <button
              class="flex-shrink-0 p-1 rounded-md transition-colors"
              :class="[
                isDarkMode
                  ? 'text-n-slate-11 hover:bg-n-ruby-3 hover:text-n-ruby-11'
                  : 'text-gray-500 hover:bg-red-100 hover:text-red-600',
              ]"
              :title="$t('GENERAL.DELETE')"
              @click.stop="deleteConversation(conv.id)"
            >
              <span class="i-lucide-trash-2 text-base" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Main Chat View -->
    <div v-if="!showConversationList" class="flex-1 flex flex-col min-h-0">
      <!-- Bot Info Bar -->
      <div
        v-if="currentBot"
        class="px-4 py-3 border-b"
        :class="[
          isDarkMode
            ? 'border-n-weak bg-n-solid-1'
            : 'border-gray-200 bg-gray-50',
        ]"
      >
        <p
          class="text-xs"
          :class="[isDarkMode ? 'text-n-slate-11' : 'text-gray-600']"
        >
          {{ currentBot.description }}
        </p>
      </div>

      <!-- Messages Display -->
      <div
        ref="messagesContainer"
        class="flex-1 overflow-y-auto p-4 space-y-3"
        :class="[isDarkMode ? 'bg-n-background' : 'bg-white']"
        @scroll="onMessagesScroll"
      >
        <!-- Welcome message when no messages -->
        <div
          v-if="messages.length === 0"
          class="flex flex-col items-center justify-center h-full text-center px-4"
        >
          <span
            class="i-lucide-bot text-5xl mb-3"
            :class="[isDarkMode ? 'text-n-slate-8' : 'text-gray-400']"
          />
          <p
            class="text-sm font-medium mb-1"
            :class="[isDarkMode ? 'text-n-slate-11' : 'text-gray-700']"
          >
            {{ $t('GENERAL.AI_START_CONVERSATION') }}
          </p>
          <p
            class="text-xs"
            :class="[isDarkMode ? 'text-n-slate-10' : 'text-gray-500']"
          >
            {{ $t('GENERAL.AI_ASK_ANYTHING') }}
          </p>
        </div>

        <!-- Chat messages and thoughts -->
        <template v-for="item in displayItems" :key="item.id">
          <div
            v-if="item.type !== 'thoughts'"
            class="mb-4 flex gap-2"
            :class="item.role === 'user' ? 'justify-end' : 'justify-start'"
          >
            <!-- Avatar (left side for AI, right side for user) -->
            <div
              v-if="item.role === 'assistant'"
              class="flex-shrink-0 flex items-end"
            >
              <Avatar
                :src="currentBot?.avatar_url"
                :name="currentBot?.name || 'AI'"
                :size="32"
                rounded-full
              />
            </div>

            <div
              class="flex flex-col max-w-[70%]"
              :class="item.role === 'user' ? 'items-end' : 'items-start'"
            >
              <!-- Message Bubble -->
              <div
                class="px-4 py-3 rounded-2xl shadow-sm"
                :class="
                  item.role === 'user'
                    ? isDarkMode
                      ? 'bg-n-iris-9 text-white rounded-br-md'
                      : 'bg-n-brand text-white rounded-br-md'
                    : isDarkMode
                      ? 'bg-n-solid-3 text-n-slate-12 rounded-bl-md'
                      : 'bg-n-alpha-2 text-gray-800 rounded-bl-md'
                "
              >
                <div
                  class="text-sm whitespace-pre-wrap break-words leading-relaxed"
                >
                  {{ item.content }}
                </div>
              </div>
              <!-- Timestamp -->
              <div
                class="text-xs mt-1.5 px-2"
                :class="[isDarkMode ? 'text-n-slate-10' : 'text-gray-400']"
              >
                {{ formatTime(item.timestamp) }}
              </div>

              <div
                v-if="
                  item.role === 'assistant' &&
                  item.id === activeAssistantMessageId &&
                  currentToolCall
                "
                class="flex flex-col items-start gap-1 px-2"
              >
                <div
                  v-if="currentToolCall"
                  class="px-3 py-1 text-xs rounded-full"
                  :class="[
                    isDarkMode
                      ? 'bg-n-iris-3 text-n-iris-11'
                      : 'bg-blue-50 text-blue-700',
                  ]"
                >
                  {{ currentToolCall.name }}
                </div>
              </div>
            </div>

            <!-- Avatar (right side for user) -->
            <div
              v-if="item.role === 'user'"
              class="flex-shrink-0 flex items-end"
            >
              <Avatar
                :src="userAvatar"
                :name="userName"
                :size="32"
                rounded-full
              />
            </div>
          </div>

          <div v-else class="mb-4">
            <button
              type="button"
              class="w-full flex items-center justify-between text-xs font-medium uppercase tracking-wide px-2 py-1"
              :class="[isDarkMode ? 'text-n-slate-10' : 'text-gray-500']"
              @click="toggleThoughts"
            >
              <span>{{ thoughtsTitle }}</span>
              <span
                class="i-lucide-chevron-down transition-transform duration-200"
                :class="thoughtsExpanded ? 'rotate-180' : ''"
              />
            </button>
            <transition name="fade">
              <div
                v-show="thoughtsExpanded"
                class="mt-2 rounded-lg border px-3 py-2 text-xs whitespace-pre-wrap break-words max-h-[200px] overflow-y-auto"
                :class="[
                  isDarkMode
                    ? 'border-n-weak bg-n-solid-2 text-n-slate-11'
                    : 'border-gray-200 bg-gray-50 text-gray-700',
                ]"
              >
                {{ currentReasoning }}
              </div>
            </transition>
          </div>
        </template>
      </div>

      <!-- Error message -->
      <div
        v-if="error"
        class="px-4 py-2 border-t"
        :class="[
          isDarkMode
            ? 'bg-n-ruby-3 border-n-ruby-6'
            : 'bg-red-50 border-red-200',
        ]"
      >
        <p
          class="text-xs"
          :class="[isDarkMode ? 'text-n-ruby-11' : 'text-red-600']"
        >
          {{ error }}
        </p>
      </div>

      <!-- Input Form -->
      <form
        class="border-t p-4"
        :class="[isDarkMode ? 'border-n-weak' : 'border-gray-200']"
        @submit="handleSubmit"
      >
        <div class="flex gap-3 items-center">
          <textarea
            v-model="input"
            :placeholder="$t('GENERAL.AI_INPUT_PLACEHOLDER')"
            :disabled="isLoading || !selectedBotId"
            rows="1"
            class="flex-1 px-4 py-2.5 text-sm border rounded-2xl focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent resize-none max-h-32 overflow-y-auto"
            :class="[
              isDarkMode
                ? 'bg-n-solid-3 border-n-weak text-n-slate-12 placeholder-n-slate-10'
                : 'bg-white border-gray-300 text-gray-800 placeholder-gray-500',
            ]"
            @keydown.enter.exact.prevent="handleSubmit"
            @input="autoResizeTextarea"
          />
          <button
            type="submit"
            class="flex-shrink-0 w-12 h-12 bg-n-brand hover:brightness-110 text-white rounded-full disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md flex items-center justify-center"
            :title="$t('GENERAL.SEND')"
            :disabled="!input?.trim() || isLoading || !selectedBotId"
          >
            <span class="i-lucide-arrow-up text-xl" />
          </button>
        </div>
      </form>
    </div>
  </div>

  <!-- Backdrop -->
  <div
    v-if="showChat"
    class="fixed inset-0 bg-black bg-opacity-10 z-30"
    @click="toggleChat"
  />
</template>
