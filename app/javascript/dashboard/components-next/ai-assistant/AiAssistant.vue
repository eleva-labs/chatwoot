<script setup>
/**
 * AiAssistant.vue
 *
 * Orchestrator component that combines layout + chat content.
 * Uses generic panel containers and injects AiChatPanel as content.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAiAssistant } from './composables/useAiAssistant';
import { FloatingPanel, SidebarPanel } from 'dashboard/components-next/panels';
import { CHAT_STATUS } from './constants';
import { provideAiChat } from './provider';
import AiChatPanel from './containers/AiChatPanel.vue';

const props = defineProps({
  layout: {
    type: String,
    default: 'floating',
    validator: v => ['floating', 'sidebar', 'inline'].includes(v),
  },
  position: { type: String, default: null },
  panelClass: { type: String, default: null },
  width: { type: String, default: null },
  fabIcon: { type: String, default: 'i-lucide-sparkles' },
});

const { t, locale } = useI18n();

// Bridge Chatwoot's vue-i18n into the AI chat i18n provider
// so all descendant components use useAiI18n() instead of useI18n()
provideAiChat({
  i18n: {
    t,
    get locale() {
      return locale.value;
    },
    dir: 'ltr',
  },
});

const panels = {
  floating: FloatingPanel,
  sidebar: SidebarPanel,
};

const {
  chat,
  selectedBotId,
  availableBots,
  botsLoading,
  chatTitle,
  userName,
  userAvatar,
  botName,
  botAvatar,
  isDisabled,
  // Session management
  sessions,
  activeSessionId,
  isLoadingSessions,
  loadSession,
  startNewSession,
  deleteSession,
  fetchSessions,
} = useAiAssistant();

// Check if chat is loading (for pulse animation on FAB)
const isLoading = computed(
  () =>
    chat.status.value === CHAT_STATUS.SUBMITTED ||
    chat.status.value === CHAT_STATUS.STREAMING
);

// Layout-specific defaults
const layoutProps = computed(() => {
  if (props.layout === 'floating') {
    return {
      position: props.position || 'bottom-right',
      panelClass: props.panelClass || 'h-[600px] w-[768px]',
      fabClass: isLoading.value ? 'size-14 animate-pulse' : 'size-14',
    };
  }
  if (props.layout === 'sidebar') {
    return {
      position: props.position || 'right',
      width: props.width || 'w-96',
    };
  }
  return {};
});
</script>

<template>
  <!-- Inline layout - no panel wrapper -->
  <AiChatPanel
    v-if="layout === 'inline'"
    v-model:selected-bot-id="selectedBotId"
    :chat="chat"
    :title="chatTitle"
    :disabled="isDisabled"
    :bots="availableBots"
    :bots-loading="botsLoading"
    :user-name="userName"
    :user-avatar="userAvatar"
    :bot-name="botName"
    :bot-avatar="botAvatar"
    :sessions="sessions"
    :active-session-id="activeSessionId"
    :sessions-loading="isLoadingSessions"
    @load-session="loadSession"
    @new-session="startNewSession"
    @delete-session="deleteSession"
    @fetch-sessions="fetchSessions"
  />

  <!-- Panel layouts (floating, sidebar) -->
  <component :is="panels[layout]" v-else v-bind="layoutProps">
    <!-- Trigger slot (only for FloatingPanel) -->
    <template v-if="layout === 'floating'" #trigger="{ isOpen }">
      <span
        v-tooltip="t('AI_CHAT.HEADER.TITLE')"
        :class="isOpen ? 'i-lucide-x' : fabIcon"
        class="size-6"
      />
    </template>

    <!-- Content slot -->
    <template #default="{ close }">
      <AiChatPanel
        v-model:selected-bot-id="selectedBotId"
        :chat="chat"
        :title="chatTitle"
        :disabled="isDisabled"
        :bots="availableBots"
        :bots-loading="botsLoading"
        :user-name="userName"
        :user-avatar="userAvatar"
        :bot-name="botName"
        :bot-avatar="botAvatar"
        :sessions="sessions"
        :active-session-id="activeSessionId"
        :sessions-loading="isLoadingSessions"
        @load-session="loadSession"
        @new-session="startNewSession"
        @delete-session="deleteSession"
        @fetch-sessions="fetchSessions"
        @close="close"
      />
    </template>
  </component>
</template>
