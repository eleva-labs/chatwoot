<script setup>
/**
 * AiChatPanel.vue
 *
 * Main chat panel container managing message display, streaming states,
 * and user input. Header and session history are delegated to child components.
 */
import { computed } from 'vue';
import { useAiI18n } from '../i18n/aiChatI18n';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { useToggle } from '@vueuse/core';
import { CHAT_STATUS, MESSAGE_ROLE } from '../constants';
import {
  getReasoningParts,
  getDeduplicatedToolParts,
  getTextParts,
  getMessageTextContent,
} from '../types';
import { validateAndNormalizeMessages } from '../utils/messageValidation';

import AiChatHeader from './AiChatHeader.vue';
import AiSessionHistoryPanel from './AiSessionHistoryPanel.vue';
import AiConversation from '../conversation/AiConversation.vue';
import AiConversationContent from '../conversation/AiConversationContent.vue';
import AiConversationEmptyState from '../conversation/AiConversationEmptyState.vue';
import AiMessage from '../message/AiMessage.vue';
import AiMessageContent from '../message/AiMessageContent.vue';
import AiMessageActions from '../message/AiMessageActions.vue';
import AiMessageAction from '../message/AiMessageAction.vue';
import AiPartRenderer from '../parts/AiPartRenderer.vue';
import AiPromptInput from '../input/AiPromptInput.vue';
// TODO: Re-enable when suggestion chips are finalized
// import AiSuggestions from '../suggestions/AiSuggestions.vue';
// import AiSuggestion from '../suggestions/AiSuggestion.vue';
import AiLoader from '../feedback/AiLoader.vue';
import AiChatError from '../feedback/AiChatError.vue';

const props = defineProps({
  chat: { type: Object, required: true },
  chatMode: { type: String, default: 'admin' },
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
  'toggleChatMode',
]);

const renderMarkdown = text => new MessageFormatter(text).formattedMessage;

// v-model for bot selection
const selectedBotId = defineModel('selectedBotId', {
  type: [Number, String],
  default: null,
});

const { t } = useAiI18n();

// Session history panel state (useToggle pattern)
const [showSessionHistory, toggleSessionHistoryValue] = useToggle(false);

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

const handleBotSelect = botId => {
  selectedBotId.value = botId;
};

// Unwrap chat refs for reactivity (chat properties are Vue refs)
const chatStatus = computed(() => props.chat.status.value || CHAT_STATUS.READY);
const rawMessages = computed(() => props.chat.messages.value || []);
const chatMessages = computed(() =>
  validateAndNormalizeMessages(rawMessages.value)
);
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

// Use imported helpers from types.ts for part splitting
const getMessageReasoningParts = message => {
  if (message.role !== MESSAGE_ROLE.ASSISTANT) return [];
  return getReasoningParts(message.parts);
};

const getMessageToolParts = message => {
  if (message.role !== MESSAGE_ROLE.ASSISTANT) return [];
  return getDeduplicatedToolParts(message.parts);
};

const getMessageTextParts = message => {
  if (message.role !== MESSAGE_ROLE.ASSISTANT) return message.parts || [];
  return getTextParts(message.parts);
};

// Check if message has text content to display
const hasTextContent = message => {
  const textParts = getMessageTextParts(message);
  return textParts.some(p => 'text' in p && p.text?.trim());
};

// Check if this message is the last one (for streaming indicators)
const isLastMessage = msgIdx => msgIdx === chatMessages.value.length - 1;

// Copy action handler
const handleCopy = async message => {
  const text = getMessageTextContent(message);
  if (text) {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      // Clipboard API may be unavailable in non-secure contexts
    }
  }
};

// TODO: Re-enable when suggestion chips are finalized
// const suggestionKeys = [
//   'AI_CHAT.SUGGESTIONS.SUMMARIZE',
//   'AI_CHAT.SUGGESTIONS.DRAFT_REPLY',
//   'AI_CHAT.SUGGESTIONS.FIND_SIMILAR',
// ];
//
// const handleSuggestionClick = async label => {
//   await props.chat.sendMessage({ text: label });
// };

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
    <AiChatHeader
      v-if="showHeader"
      :title="title"
      :status="chatStatus"
      :chat-mode="chatMode"
      :is-loading="isLoading"
      :bots="bots"
      :bots-loading="botsLoading"
      :selected-bot-id="selectedBotId"
      :show-session-history="showSessionHistory"
      @update:selected-bot-id="handleBotSelect"
      @toggle-session-history="toggleSessionHistory"
      @toggle-chat-mode="emit('toggleChatMode')"
      @new-session="handleNewSession"
      @close="emit('close')"
    />

    <!-- Session History Panel (overlay) -->
    <AiSessionHistoryPanel
      v-if="showSessionHistory"
      :sessions="sessions"
      :active-session-id="activeSessionId"
      :is-loading="sessionsLoading"
      @load-session="handleLoadSession"
      @delete-session="handleDeleteSession"
      @close="showSessionHistory = false"
    />

    <!-- Conversation -->
    <AiConversation :is-streaming="isStreaming" class="flex-1">
      <AiConversationContent>
        <AiConversationEmptyState v-if="chatMessages.length === 0" />
        <!-- TODO: Re-enable suggestion chips when prompt list is finalized
        <AiConversationEmptyState v-if="chatMessages.length === 0">
          <template #suggestions>
            <AiSuggestions>
              <AiSuggestion
                v-for="key in suggestionKeys"
                :key="key"
                :label="t(key)"
                @click="handleSuggestionClick(t(key))"
              />
            </AiSuggestions>
          </template>
        </AiConversationEmptyState>
        -->

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
                v-for="(part, idx) in getMessageReasoningParts(message)"
                :key="`reasoning-${idx}`"
                :part="part"
                :role="message.role"
                :is-streaming="
                  isStreaming &&
                  isLastMessage(msgIdx) &&
                  idx === getMessageReasoningParts(message).length - 1
                "
                :render-markdown="renderMarkdown"
              />
              <!-- Tool parts - outside bubble -->
              <AiPartRenderer
                v-for="part in getMessageToolParts(message)"
                :key="`tool-${part.toolCallId}`"
                :part="part"
                :role="message.role"
                :is-streaming="isStreaming && isLastMessage(msgIdx)"
                :render-markdown="renderMarkdown"
              />
              <!-- Text content - inside bubble (only show when there's content) -->
              <AiMessageContent
                v-if="hasTextContent(message)"
                :from="message.role"
              >
                <AiPartRenderer
                  v-for="(part, idx) in getMessageTextParts(message)"
                  :key="`text-${idx}`"
                  :part="part"
                  :role="message.role"
                  :is-streaming="
                    isStreaming &&
                    isLastMessage(msgIdx) &&
                    idx === getMessageTextParts(message).length - 1
                  "
                  :render-markdown="renderMarkdown"
                />
              </AiMessageContent>
              <!-- Message Actions (Copy, Regenerate) -->
              <AiMessageActions>
                <AiMessageAction
                  icon="i-lucide-copy"
                  :label="t('AI_CHAT.MESSAGE.COPY')"
                  @click="handleCopy(message)"
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
                :render-markdown="renderMarkdown"
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
      :is-streaming="isStreaming"
      @submit="handleSubmit"
      @stop="chat.stop?.()"
    />
  </div>
</template>
