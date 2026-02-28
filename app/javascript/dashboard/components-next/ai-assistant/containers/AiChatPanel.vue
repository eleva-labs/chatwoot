<script setup>
/**
 * AiChatPanel.vue
 *
 * Main chat panel container managing message display, bot selection,
 * session history, streaming states, and user input.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { OnClickOutside } from '@vueuse/components';
import { provideAiChatContext } from '../provider';
import { CHAT_STATUS, PART_TYPES, MESSAGE_ROLE } from '../constants';

import AiConversation from '../conversation/AiConversation.vue';
import AiConversationContent from '../conversation/AiConversationContent.vue';
import AiConversationEmptyState from '../conversation/AiConversationEmptyState.vue';
import AiMessage from '../message/AiMessage.vue';
import AiMessageContent from '../message/AiMessageContent.vue';
import AiMessageActions from '../message/AiMessageActions.vue';
import AiMessageAction from '../message/AiMessageAction.vue';
import AiPartRenderer from '../parts/AiPartRenderer.vue';
import AiPromptInput from '../input/AiPromptInput.vue';
import AiLoader from '../feedback/AiLoader.vue';
import AiChatError from '../feedback/AiChatError.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  chat: { type: Object, required: true },
  showHeader: { type: Boolean, default: true },
  title: { type: String, default: null },
  disabled: { type: Boolean, default: false },
  bots: { type: Array, default: () => [] },
  botsLoading: { type: Boolean, default: false },
  userName: { type: String, default: '' },
  userAvatar: { type: String, default: '' },
  botName: { type: String, default: '' },
  botAvatar: { type: String, default: '' },
  sessions: { type: Array, default: () => [] },
  activeSessionId: { type: String, default: null },
  sessionsLoading: { type: Boolean, default: false },
});

const emit = defineEmits([
  'close',
  'loadSession',
  'newSession',
  'deleteSession',
  'fetchSessions',
]);

// v-model for bot selection
const selectedBotId = defineModel('selectedBotId', {
  type: [Number, String],
  default: null,
});

const showBotSelector = computed(() => props.bots.length > 0);

// Get current selected bot for avatar display
const currentBot = computed(() =>
  props.bots.find(b => b.id === selectedBotId.value)
);

// Bot selector dropdown state (useToggle pattern)
const [isBotSelectorOpen, toggleBotSelector] = useToggle(false);

// Transform bots to dropdown menu format
const botMenuItems = computed(() =>
  props.bots.map(bot => ({
    value: bot.id,
    label: bot.name,
    action: 'select',
    thumbnail: {
      src: bot.avatar_url,
      name: bot.name,
    },
    isSelected: bot.id === selectedBotId.value,
  }))
);

const handleBotSelect = ({ value }) => {
  selectedBotId.value = Number(value);
  isBotSelectorOpen.value = false;
};

// Session history panel state (useToggle pattern)
const [showSessionHistory, toggleSessionHistoryValue] = useToggle(false);
const hasSessions = computed(() => props.sessions.length > 0);

const toggleSessionHistory = () => {
  toggleSessionHistoryValue();
  // Fetch sessions when opening the panel (lazy loading)
  if (showSessionHistory.value) {
    emit('fetchSessions');
  }
};

const handleLoadSession = sessionId => {
  emit('loadSession', sessionId);
  showSessionHistory.value = false;
};

const handleNewSession = () => {
  emit('newSession');
  showSessionHistory.value = false;
};

const handleDeleteSession = sessionId => {
  emit('deleteSession', sessionId);
};

const { t } = useI18n();

// Date formatting helpers for session list (localized)
const formatSessionDate = dateString => {
  if (!dateString) return '';
  const date = new Date(dateString);
  const now = new Date();
  const diffDays = Math.floor(
    (now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24)
  );

  if (diffDays === 0) return t('AI_CHAT.SESSIONS.TODAY');
  if (diffDays === 1) return t('AI_CHAT.SESSIONS.YESTERDAY');
  if (diffDays < 7) return date.toLocaleDateString([], { weekday: 'long' });
  return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
};

const formatSessionTime = dateString => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

const headerTitle = computed(() => props.title || t('AI_CHAT.HEADER.TITLE'));

// Unwrap chat refs for reactivity (chat properties are Vue refs)
const chatStatus = computed(() => props.chat.status.value || CHAT_STATUS.READY);
const chatMessages = computed(() => props.chat.messages.value || []);
const chatError = computed(() => props.chat.error.value);

const isLoading = computed(
  () =>
    chatStatus.value === CHAT_STATUS.SUBMITTED ||
    chatStatus.value === CHAT_STATUS.STREAMING
);

const isStreaming = computed(() => chatStatus.value === CHAT_STATUS.STREAMING);

const hasError = computed(() => !!chatError.value);

// Show loader when waiting for response or streaming but no content yet
const showLoader = computed(() => {
  // Always show when submitted (request sent, waiting for stream)
  if (chatStatus.value === CHAT_STATUS.SUBMITTED) return true;

  // During streaming, check if we have assistant content
  if (chatStatus.value === CHAT_STATUS.STREAMING) {
    const messages = chatMessages.value;
    if (messages.length === 0) return true;

    // Check if last message is from assistant and has text content
    const lastMessage = messages[messages.length - 1];
    if (lastMessage.role !== 'assistant') return true;

    // Check if assistant message has any text parts with content
    const hasTextContent = lastMessage.parts?.some(
      part => part.type === 'text' && part.text?.trim()
    );
    return !hasTextContent;
  }

  return false;
});

// Get avatar info for a message based on role
const getAvatarProps = role => {
  if (role === MESSAGE_ROLE.USER) {
    return {
      avatarName: props.userName,
      avatarSrc: props.userAvatar,
    };
  }
  return {
    avatarName: props.botName,
    avatarSrc: props.botAvatar,
  };
};

// Helper to check if a part is a tool part (type starts with 'tool-')
const isToolPart = part => part?.type?.startsWith('tool-') ?? false;

// Get reasoning parts from message
const getReasoningParts = message => {
  if (message.role !== MESSAGE_ROLE.ASSISTANT) return [];
  return (message.parts || []).filter(p => p.type === PART_TYPES.REASONING);
};

// Get tool parts from message (deduplicated by toolCallId, keep latest)
const getToolParts = message => {
  if (message.role !== MESSAGE_ROLE.ASSISTANT) return [];
  const toolParts = (message.parts || []).filter(isToolPart);

  // Dedupe by toolCallId - keep only the latest state for each tool
  const toolMap = new Map();
  toolParts.forEach(part => {
    const callId = part.toolCallId;
    if (callId) {
      toolMap.set(callId, part);
    }
  });

  return Array.from(toolMap.values());
};

// Get text/content parts (everything except reasoning and tools)
const getTextParts = message => {
  if (message.role !== MESSAGE_ROLE.ASSISTANT) return message.parts || [];
  return (message.parts || []).filter(
    p => p.type !== PART_TYPES.REASONING && !isToolPart(p)
  );
};

// Check if message has text content to display
const hasTextContent = message => {
  const textParts = getTextParts(message);
  return textParts.some(p => 'text' in p && p.text?.trim());
};

// Check if this message is the last one (for streaming indicators)
const isLastMessage = msgIdx => msgIdx === chatMessages.value.length - 1;

// Provide context to child components
provideAiChatContext({
  status: chatStatus,
  isStreaming,
  sendMessage: props.chat.sendMessage,
  clearError: () => {
    if (props.chat.clearError) {
      props.chat.clearError();
    }
  },
});

const handleSubmit = async text => {
  await props.chat.sendMessage({ text });
};

const handleRetry = () => {
  if (props.chat.clearError) {
    props.chat.clearError();
  }
  if (props.chat.regenerate) {
    props.chat.regenerate();
  }
};

const handleDismissError = () => {
  if (props.chat.clearError) {
    props.chat.clearError();
  }
};

const handleFreshStart = () => {
  if (props.chat.setMessages) {
    props.chat.setMessages([]);
  }
  if (props.chat.clearError) {
    props.chat.clearError();
  }
};
</script>

<template>
  <div class="relative flex h-full flex-col bg-n-solid-1">
    <!-- Header -->
    <header
      v-if="showHeader"
      class="flex flex-col gap-1 px-4 py-3 border-b border-n-weak"
    >
      <!-- Top row: Bot selector/title + close button -->
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-center gap-2 min-w-0 flex-1">
          <!-- Bot Selector or Title -->
          <template v-if="showBotSelector">
            <OnClickOutside @trigger="isBotSelectorOpen = false">
              <div class="relative flex items-center gap-2 min-w-0">
                <button
                  :disabled="isLoading || botsLoading"
                  :aria-label="t('AI_CHAT.BOT_SELECTOR.LABEL')"
                  class="flex items-center gap-2 min-w-0 hover:bg-n-alpha-1 rounded-lg px-1.5 py-1 -ml-1.5 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  @click="toggleBotSelector()"
                >
                  <Avatar
                    :src="currentBot?.avatar_url"
                    :name="currentBot?.name || 'AI'"
                    :size="28"
                    rounded-full
                    icon-name="i-lucide-bot"
                    class="flex-shrink-0"
                  />
                  <span
                    class="text-base font-semibold text-n-slate-12 truncate max-w-32"
                  >
                    {{
                      currentBot?.name || t('AI_CHAT.BOT_SELECTOR.PLACEHOLDER')
                    }}
                  </span>
                  <span
                    v-if="botsLoading"
                    class="i-lucide-loader-2 size-4 text-n-slate-10 animate-spin flex-shrink-0"
                  />
                  <span
                    v-else
                    class="i-lucide-chevron-down size-4 text-n-slate-10 flex-shrink-0 transition-transform"
                    :class="{ 'rotate-180': isBotSelectorOpen }"
                  />
                </button>
                <DropdownMenu
                  v-if="isBotSelectorOpen"
                  :menu-items="botMenuItems"
                  :thumbnail-size="24"
                  class="top-full mt-1 left-0"
                  @action="handleBotSelect"
                />
              </div>
            </OnClickOutside>
          </template>
          <h2 v-else class="text-lg font-semibold text-n-slate-12 truncate">
            {{ headerTitle }}
          </h2>
        </div>
        <div class="flex items-center gap-1 flex-shrink-0">
          <!-- New Chat button -->
          <button
            v-tooltip="t('AI_CHAT.SESSIONS.NEW_CHAT')"
            :aria-label="t('AI_CHAT.SESSIONS.NEW_CHAT')"
            :disabled="isLoading"
            class="p-1.5 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50 disabled:cursor-not-allowed"
            @click="handleNewSession"
          >
            <span class="i-lucide-plus size-5" />
          </button>
          <!-- Session History toggle -->
          <button
            v-tooltip="t('AI_CHAT.SESSIONS.HISTORY')"
            :aria-label="t('AI_CHAT.SESSIONS.HISTORY')"
            :disabled="isLoading"
            class="p-1.5 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50 disabled:cursor-not-allowed"
            :class="{ 'bg-n-alpha-2 text-n-slate-12': showSessionHistory }"
            @click="toggleSessionHistory"
          >
            <span class="i-lucide-history size-5" />
          </button>
          <!-- Close button -->
          <button
            v-tooltip="t('AI_CHAT.HEADER.CLOSE')"
            :aria-label="t('AI_CHAT.HEADER.CLOSE')"
            class="p-1.5 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2"
            @click="emit('close')"
          >
            <span class="i-lucide-x size-5" />
          </button>
        </div>
      </div>
      <!-- Status row -->
      <div class="flex items-center gap-1.5">
        <span
          class="size-2 rounded-full"
          :class="{
            'bg-n-teal-9': chatStatus === CHAT_STATUS.READY,
            'bg-n-amber-9 animate-pulse': chatStatus === CHAT_STATUS.SUBMITTED,
            'bg-n-amber-11 animate-pulse': chatStatus === CHAT_STATUS.STREAMING,
            'bg-n-ruby-9': chatStatus === CHAT_STATUS.ERROR,
          }"
        />
        <span class="text-xs text-n-slate-11">
          {{ t(`AI_CHAT.STATUS.${chatStatus.toUpperCase()}`) }}
        </span>
      </div>
    </header>

    <!-- Session History Panel (overlay) -->
    <div
      v-if="showSessionHistory"
      class="absolute inset-x-0 top-[76px] bottom-0 z-10 bg-n-solid-1 flex flex-col"
    >
      <!-- Session list header -->
      <div
        class="flex items-center justify-between px-4 py-3 border-b border-n-weak"
      >
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ t('AI_CHAT.SESSIONS.TITLE') }}
        </h3>
        <button
          v-tooltip="t('AI_CHAT.HEADER.CLOSE')"
          :aria-label="t('AI_CHAT.HEADER.CLOSE')"
          class="p-1 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2"
          @click="showSessionHistory = false"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>

      <!-- Session list -->
      <div class="flex-1 overflow-y-auto">
        <!-- Loading state -->
        <div
          v-if="sessionsLoading"
          class="flex items-center justify-center py-8"
        >
          <span class="i-lucide-loader-2 size-6 text-n-slate-10 animate-spin" />
        </div>

        <!-- Empty state -->
        <div
          v-else-if="!hasSessions"
          class="flex flex-col items-center justify-center py-8 px-4 text-center"
        >
          <span
            class="i-lucide-message-square-dashed size-10 text-n-slate-8 mb-2"
          />
          <p class="text-sm text-n-slate-11">
            {{ t('AI_CHAT.SESSIONS.EMPTY') }}
          </p>
        </div>

        <!-- Sessions list -->
        <ul v-else class="divide-y divide-n-weak">
          <li
            v-for="session in sessions"
            :key="session.chatSessionId"
            class="group"
          >
            <button
              class="w-full px-4 py-3 text-left hover:bg-n-alpha-2 transition-colors"
              :class="{
                'bg-n-alpha-3': session.chatSessionId === activeSessionId,
              }"
              @click="handleLoadSession(session.chatSessionId)"
            >
              <div class="flex items-start justify-between gap-2">
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium text-n-slate-12 truncate">
                    {{
                      formatSessionDate(session.createdAt || session.created_at)
                    }}
                  </p>
                  <p class="text-xs text-n-slate-10 mt-0.5">
                    {{
                      formatSessionTime(session.createdAt || session.created_at)
                    }}
                  </p>
                </div>
                <button
                  v-tooltip="t('AI_CHAT.SESSIONS.DELETE')"
                  :aria-label="t('AI_CHAT.SESSIONS.DELETE')"
                  class="p-1 rounded text-n-slate-9 hover:text-n-ruby-9 hover:bg-n-ruby-3 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity flex-shrink-0"
                  @click.stop="handleDeleteSession(session.chatSessionId)"
                >
                  <span class="i-lucide-trash-2 size-4" />
                </button>
              </div>
            </button>
          </li>
        </ul>
      </div>
    </div>

    <!-- Conversation -->
    <AiConversation :is-streaming="isStreaming" class="flex-1">
      <AiConversationContent>
        <AiConversationEmptyState v-if="chatMessages.length === 0" />

        <AiMessage
          v-for="(message, msgIdx) in chatMessages"
          :key="message.id"
          :from="message.role"
          v-bind="getAvatarProps(message.role)"
          class="group"
        >
          <!-- Assistant messages: split into reasoning, tools, and text -->
          <template v-if="message.role === MESSAGE_ROLE.ASSISTANT">
            <div class="flex flex-col gap-1 w-full">
              <!-- Reasoning parts - outside bubble -->
              <AiPartRenderer
                v-for="(part, idx) in getReasoningParts(message)"
                :key="`reasoning-${idx}`"
                :part="part"
                :role="message.role"
                :is-streaming="
                  isStreaming &&
                  isLastMessage(msgIdx) &&
                  idx === getReasoningParts(message).length - 1
                "
              />
              <!-- Tool parts - outside bubble -->
              <AiPartRenderer
                v-for="part in getToolParts(message)"
                :key="`tool-${part.toolCallId}`"
                :part="part"
                :role="message.role"
                :is-streaming="isStreaming && isLastMessage(msgIdx)"
              />
              <!-- Text content - inside bubble (only show when there's content) -->
              <AiMessageContent
                v-if="hasTextContent(message)"
                :from="message.role"
              >
                <AiPartRenderer
                  v-for="(part, idx) in getTextParts(message)"
                  :key="`text-${idx}`"
                  :part="part"
                  :role="message.role"
                  :is-streaming="
                    isStreaming &&
                    isLastMessage(msgIdx) &&
                    idx === getTextParts(message).length - 1
                  "
                />
              </AiMessageContent>
              <!-- Message Actions (Copy, Regenerate) -->
              <AiMessageActions>
                <AiMessageAction
                  icon="i-lucide-copy"
                  :label="t('AI_CHAT.MESSAGE.COPY')"
                  disabled
                />
                <AiMessageAction
                  icon="i-lucide-refresh-ccw"
                  :label="t('AI_CHAT.MESSAGE.REGENERATE')"
                  disabled
                />
              </AiMessageActions>
            </div>
          </template>
          <!-- User messages: all parts inside bubble -->
          <template v-else>
            <AiMessageContent :from="message.role">
              <AiPartRenderer
                v-for="(part, idx) in message.parts"
                :key="idx"
                :part="part"
                :role="message.role"
                :is-streaming="isStreaming && idx === message.parts.length - 1"
              />
            </AiMessageContent>
          </template>
        </AiMessage>

        <AiLoader v-if="showLoader" />
      </AiConversationContent>
    </AiConversation>

    <!-- Error -->
    <AiChatError
      v-if="hasError"
      :error="chatError"
      can-retry
      :can-edit="false"
      @retry="handleRetry"
      @dismiss="handleDismissError"
      @fresh-start="handleFreshStart"
    />

    <!-- Input -->
    <AiPromptInput
      :disabled="disabled"
      :is-loading="isLoading"
      @submit="handleSubmit"
    />
  </div>
</template>
