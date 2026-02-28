<script setup>
/**
 * AiSessionHistoryPanel.vue
 *
 * Session history overlay panel showing list of past chat sessions.
 * Supports loading, empty state, session selection, and deletion.
 *
 * Extracted from AiChatPanel.vue for separation of concerns.
 */
import { computed } from 'vue';
import { useAiI18n } from '../i18n/aiChatI18n';
import { formatSessionDate, formatSessionTime } from '../utils/formatHelpers';

const props = defineProps({
  sessions: { type: Array, default: () => [] },
  activeSessionId: { type: String, default: null },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['loadSession', 'deleteSession', 'close']);

const { t } = useAiI18n();

const hasSessions = computed(() => props.sessions.length > 0);

const dateLabels = computed(() => ({
  today: t('AI_CHAT.SESSIONS.TODAY'),
  yesterday: t('AI_CHAT.SESSIONS.YESTERDAY'),
}));

const getSessionDate = dateString => {
  return formatSessionDate(dateString, dateLabels.value);
};

const getSessionTime = dateString => {
  return formatSessionTime(dateString);
};
</script>

<template>
  <div
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
        @click="emit('close')"
      >
        <span class="i-lucide-x size-4" />
      </button>
    </div>

    <!-- Session list -->
    <div class="flex-1 overflow-y-auto">
      <!-- Loading state -->
      <div v-if="isLoading" class="flex items-center justify-center py-8">
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
          :key="session.chat_session_id"
          class="group"
        >
          <button
            class="w-full px-4 py-3 text-left hover:bg-n-alpha-2 transition-colors"
            :class="{
              'bg-n-alpha-3': session.chat_session_id === activeSessionId,
            }"
            @click="emit('loadSession', session.chat_session_id)"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0 flex-1">
                <p class="text-sm font-medium text-n-slate-12 truncate">
                  {{ getSessionDate(session.created_at) }}
                </p>
                <p class="text-xs text-n-slate-10 mt-0.5">
                  {{ getSessionTime(session.created_at) }}
                </p>
              </div>
              <button
                v-tooltip="t('AI_CHAT.SESSIONS.DELETE')"
                :aria-label="t('AI_CHAT.SESSIONS.DELETE')"
                class="p-1 rounded text-n-slate-9 hover:text-n-ruby-9 hover:bg-n-ruby-3 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity flex-shrink-0"
                @click.stop="emit('deleteSession', session.chat_session_id)"
              >
                <span class="i-lucide-trash-2 size-4" />
              </button>
            </div>
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>
