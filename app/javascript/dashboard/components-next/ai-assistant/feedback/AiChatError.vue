<script setup>
import { computed, ref, onUnmounted, watch } from 'vue';
import { useAiI18n } from '../i18n/aiChatI18n';
import { categorizeError } from '../utils/errorHelpers';

const props = defineProps({
  error: { type: Error, required: true },
  canRetry: { type: Boolean, default: true },
  canEdit: { type: Boolean, default: false },
  retryDelay: { type: Number, default: 0 },
});

const emit = defineEmits(['retry', 'edit', 'dismiss', 'fresh-start']);

const { t } = useAiI18n();

// Countdown timer for rate limiting
const countdown = ref(props.retryDelay);
let countdownInterval = null;

watch(
  () => props.retryDelay,
  newDelay => {
    countdown.value = newDelay;
    if (countdownInterval) {
      clearInterval(countdownInterval);
    }
    if (newDelay > 0) {
      countdownInterval = setInterval(() => {
        countdown.value -= 1;
        if (countdown.value <= 0) {
          clearInterval(countdownInterval);
        }
      }, 1000);
    }
  },
  { immediate: true }
);

onUnmounted(() => {
  if (countdownInterval) {
    clearInterval(countdownInterval);
  }
});

// Classify error for icon/color using shared pure function
const errorCategory = computed(() =>
  categorizeError(props.error.message || '')
);

const config = computed(() => {
  const configs = {
    network: {
      icon: 'i-lucide-wifi-off',
      title: t('AI_CHAT.ERROR.TITLE'),
      message: t('AI_CHAT.ERROR.NETWORK'),
      color: 'orange',
    },
    rate_limit: {
      icon: 'i-lucide-clock',
      title: t('AI_CHAT.ERROR.TITLE'),
      message:
        countdown.value > 0
          ? t('AI_CHAT.ERROR.RATE_LIMIT', { seconds: countdown.value })
          : t('AI_CHAT.ERROR.UNKNOWN'),
      color: 'yellow',
    },
    auth: {
      icon: 'i-lucide-lock',
      title: t('AI_CHAT.ERROR.TITLE'),
      message: t('AI_CHAT.ERROR.AUTH'),
      color: 'red',
    },
    server: {
      icon: 'i-lucide-server-off',
      title: t('AI_CHAT.ERROR.TITLE'),
      message: t('AI_CHAT.ERROR.SERVER'),
      color: 'red',
    },
    unknown: {
      icon: 'i-lucide-alert-circle',
      title: t('AI_CHAT.ERROR.TITLE'),
      message: t('AI_CHAT.ERROR.UNKNOWN'),
      color: 'red',
    },
  };
  return configs[errorCategory.value];
});

const colorClasses = computed(() => {
  const colors = {
    red: 'bg-n-ruby-3 border-n-ruby-4',
    orange: 'bg-n-amber-3 border-n-amber-4',
    yellow: 'bg-n-amber-3 border-n-amber-4',
  };
  return colors[config.value.color];
});

const iconColorClass = computed(() => {
  const colors = {
    red: 'text-n-ruby-11',
    orange: 'text-n-amber-11',
    yellow: 'text-n-amber-11',
  };
  return colors[config.value.color];
});

const canRetryNow = computed(() => {
  if (!props.canRetry) return false;
  if (errorCategory.value === 'auth') return false;
  if (errorCategory.value === 'rate_limit' && countdown.value > 0) return false;
  return true;
});
</script>

<template>
  <div class="border-t p-4" :class="[colorClasses]">
    <!-- Header -->
    <div class="flex items-start gap-3">
      <span class="mt-0.5 text-lg" :class="[config.icon, iconColorClass]" />
      <div class="flex-1">
        <h4 class="font-medium text-n-slate-12">{{ config.title }}</h4>
        <p class="mt-0.5 text-sm text-n-slate-11">{{ config.message }}</p>

        <!-- Technical details (collapsed) -->
        <details v-if="error.message" class="mt-2">
          <summary class="cursor-pointer text-xs text-n-slate-10">
            {{ t('AI_CHAT.ERROR.TECHNICAL_DETAILS') }}
          </summary>
          <pre class="mt-1 overflow-x-auto rounded bg-n-solid-3 p-2 text-xs">{{
            error.message
          }}</pre>
        </details>
      </div>
    </div>

    <!-- Actions -->
    <div class="mt-4 flex flex-wrap gap-2">
      <!-- Retry button -->
      <button
        v-if="canRetryNow"
        class="inline-flex items-center gap-1.5 rounded-lg bg-n-brand px-3 py-1.5 text-sm font-medium text-white hover:brightness-110"
        @click="emit('retry')"
      >
        <span class="i-lucide-refresh-cw text-sm" />
        {{ t('AI_CHAT.ERROR.RETRY') }}
      </button>

      <!-- Edit & Retry button -->
      <button
        v-if="canEdit && canRetryNow"
        class="inline-flex items-center gap-1.5 rounded-lg border border-n-weak bg-n-solid-2 px-3 py-1.5 text-sm font-medium text-n-slate-12 hover:bg-n-solid-3"
        @click="emit('edit')"
      >
        <span class="i-lucide-pencil text-sm" />
        {{ t('AI_CHAT.ERROR.EDIT_RETRY') }}
      </button>

      <!-- Fresh start (after multiple failures) -->
      <button
        class="inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm text-n-slate-11 hover:bg-n-solid-3"
        @click="emit('fresh-start')"
      >
        <span class="i-lucide-rotate-ccw text-sm" />
        {{ t('AI_CHAT.ERROR.FRESH_START') }}
      </button>

      <!-- Dismiss -->
      <button
        class="ltr:ml-auto rtl:mr-auto rounded-lg px-3 py-1.5 text-sm text-n-slate-10 hover:text-n-slate-12"
        @click="emit('dismiss')"
      >
        {{ t('AI_CHAT.ERROR.DISMISS') }}
      </button>
    </div>
  </div>
</template>
