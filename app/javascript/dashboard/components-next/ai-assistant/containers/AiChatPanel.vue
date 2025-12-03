<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { provideAiChatContext } from '../provider';
import { CHAT_STATUS } from '../constants';

import AiConversation from '../conversation/AiConversation.vue';
import AiConversationContent from '../conversation/AiConversationContent.vue';
import AiConversationEmptyState from '../conversation/AiConversationEmptyState.vue';
import AiMessage from '../message/AiMessage.vue';
import AiMessageContent from '../message/AiMessageContent.vue';
import AiPartRenderer from '../parts/AiPartRenderer.vue';
import AiPromptInput from '../input/AiPromptInput.vue';
import AiLoader from '../feedback/AiLoader.vue';
import AiChatError from '../feedback/AiChatError.vue';

const props = defineProps({
  chat: { type: Object, required: true },
  showHeader: { type: Boolean, default: true },
  title: { type: String, default: null },
  disabled: { type: Boolean, default: false },
  // Bot selector props
  bots: { type: Array, default: () => [] },
  selectedBotId: { type: [Number, String], default: null },
  botsLoading: { type: Boolean, default: false },
  // Avatar props
  userName: { type: String, default: '' },
  userAvatar: { type: String, default: '' },
  botName: { type: String, default: '' },
  botAvatar: { type: String, default: '' },
});

const emit = defineEmits(['close', 'update:selectedBotId']);

const showBotSelector = computed(() => props.bots.length > 0);

const { t } = useI18n();

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
  if (role === 'user') {
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
  <div class="flex h-full flex-col bg-n-solid-1">
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
            <span class="i-lucide-bot size-6 text-n-slate-10 flex-shrink-0" />
            <select
              :value="selectedBotId"
              :disabled="isLoading || botsLoading"
              :aria-label="t('AI_CHAT.BOT_SELECTOR.LABEL')"
              class="flex-1 min-w-0 text-base font-semibold bg-transparent border-none text-n-slate-12 focus:outline-none focus:ring-0 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed truncate"
              @change="
                emit('update:selectedBotId', Number($event.target.value))
              "
            >
              <option
                v-for="bot in bots"
                :key="bot.id"
                :value="bot.id"
                class="bg-n-solid-2 text-n-slate-12"
              >
                {{ bot.name }}
              </option>
            </select>
            <span
              v-if="botsLoading"
              class="i-lucide-loader-2 size-4 text-n-slate-10 animate-spin flex-shrink-0"
            />
          </template>
          <h2 v-else class="text-lg font-semibold text-n-slate-12 truncate">
            {{ headerTitle }}
          </h2>
        </div>
        <button
          v-tooltip="t('AI_CHAT.HEADER.CLOSE')"
          :aria-label="t('AI_CHAT.HEADER.CLOSE')"
          class="p-1.5 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 flex-shrink-0"
          @click="emit('close')"
        >
          <span class="i-lucide-x size-5" />
        </button>
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

    <!-- Conversation -->
    <AiConversation
      :messages="chatMessages"
      :is-streaming="isStreaming"
      class="flex-1"
    >
      <AiConversationContent>
        <AiConversationEmptyState v-if="chatMessages.length === 0" />

        <AiMessage
          v-for="message in chatMessages"
          :key="message.id"
          :from="message.role"
          v-bind="getAvatarProps(message.role)"
        >
          <AiMessageContent :from="message.role">
            <AiPartRenderer
              v-for="(part, idx) in message.parts"
              :key="idx"
              :part="part"
              :role="message.role"
              :is-streaming="isStreaming && idx === message.parts.length - 1"
            />
          </AiMessageContent>
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
