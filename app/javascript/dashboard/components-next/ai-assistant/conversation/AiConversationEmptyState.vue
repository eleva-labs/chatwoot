<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  title: { type: String, default: null },
  description: { type: String, default: null },
  icon: { type: String, default: 'i-lucide-message-circle' },
});

const { t } = useI18n();
</script>

<template>
  <div class="flex flex-1 flex-col items-center justify-center p-8 text-center">
    <div class="mb-4 rounded-full bg-n-alpha-1 p-4">
      <span class="size-8 text-n-slate-9" :class="[icon]" />
    </div>
    <h3 class="text-lg font-semibold text-n-slate-12 mb-2">
      {{ title || t('AI_CHAT.EMPTY_STATE.TITLE') }}
    </h3>
    <p class="text-sm text-n-slate-11 max-w-sm">
      {{ description || t('AI_CHAT.EMPTY_STATE.DESCRIPTION') }}
    </p>
    <slot name="suggestions" />
  </div>
</template>
