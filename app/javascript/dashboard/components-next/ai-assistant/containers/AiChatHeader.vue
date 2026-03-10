<script setup>
/**
 * AiChatHeader.vue
 *
 * Header component for the AI Chat Panel.
 * Contains bot selector dropdown, status indicator, and action buttons
 * (new chat, session history, close).
 *
 * Extracted from AiChatPanel.vue for separation of concerns.
 */
import { computed } from 'vue';
import { useAiI18n } from '../i18n/aiChatI18n';
import { useToggle } from '@vueuse/core';
import { OnClickOutside } from '@vueuse/components';
import { CHAT_STATUS } from '../constants';

const props = defineProps({
  title: { type: String, default: null },
  status: { type: String, required: true },
  isLoading: { type: Boolean, default: false },
  bots: { type: Array, default: () => [] },
  botsLoading: { type: Boolean, default: false },
  selectedBotId: { type: [Number, String], default: null },
  showSessionHistory: { type: Boolean, default: false },
});

const emit = defineEmits([
  'update:selectedBotId',
  'toggleSessionHistory',
  'newSession',
  'close',
]);

const { t } = useAiI18n();

const showBotSelector = computed(() => props.bots.length > 0);

// Get current selected bot for avatar display
const currentBot = computed(() =>
  props.bots.find(b => b.id === props.selectedBotId)
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
    isSelected: bot.id === props.selectedBotId,
  }))
);

const handleBotSelect = ({ value }) => {
  emit('update:selectedBotId', Number(value));
  isBotSelectorOpen.value = false;
};

const headerTitle = computed(() => props.title || t('AI_CHAT.HEADER.TITLE'));
</script>

<template>
  <header class="flex flex-col gap-1 px-4 py-3 border-b border-n-weak">
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
                <slot name="bot-avatar" :bot="currentBot" :size="28">
                  <span
                    v-if="currentBot?.avatar_url"
                    class="flex-shrink-0 size-7 rounded-full overflow-hidden"
                  >
                    <img
                      :src="currentBot.avatar_url"
                      :alt="currentBot.name"
                      class="w-full h-full object-cover"
                    />
                  </span>
                  <span
                    v-else
                    class="flex-shrink-0 size-7 rounded-full bg-n-alpha-3 flex items-center justify-center text-xs font-semibold text-n-slate-11"
                  >
                    {{ (currentBot?.name || 'AI').charAt(0).toUpperCase() }}
                  </span>
                </slot>
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
              <slot
                name="bot-selector"
                :is-open="isBotSelectorOpen"
                :items="botMenuItems"
                :on-select="handleBotSelect"
              >
                <ul
                  v-if="isBotSelectorOpen"
                  class="absolute top-full mt-1 left-0 z-50 min-w-40 rounded-lg border border-n-weak bg-n-solid-1 shadow-lg py-1"
                >
                  <li
                    v-for="item in botMenuItems"
                    :key="item.value"
                    class="flex items-center gap-2 px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 cursor-pointer"
                    :class="{ 'bg-n-alpha-2 font-medium': item.isSelected }"
                    @click="handleBotSelect({ value: item.value })"
                  >
                    <span
                      v-if="item.thumbnail?.src"
                      class="size-6 rounded-full overflow-hidden flex-shrink-0"
                    >
                      <img
                        :src="item.thumbnail.src"
                        :alt="item.label"
                        class="w-full h-full object-cover"
                      />
                    </span>
                    <span
                      v-else
                      class="size-6 rounded-full bg-n-alpha-3 flex items-center justify-center text-xs font-semibold text-n-slate-11 flex-shrink-0"
                    >
                      {{ (item.label || '?').charAt(0).toUpperCase() }}
                    </span>
                    {{ item.label }}
                  </li>
                </ul>
              </slot>
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
          @click="emit('newSession')"
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
          @click="emit('toggleSessionHistory')"
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
          'bg-n-teal-9': status === CHAT_STATUS.READY,
          'bg-n-amber-9 animate-pulse': status === CHAT_STATUS.SUBMITTED,
          'bg-n-teal-9 animate-pulse': status === CHAT_STATUS.STREAMING,
          'bg-n-ruby-9': status === CHAT_STATUS.ERROR,
        }"
      />
      <span class="text-xs text-n-slate-11">
        {{ t(`AI_CHAT.STATUS.${status.toUpperCase()}`) }}
      </span>
    </div>
  </header>
</template>
