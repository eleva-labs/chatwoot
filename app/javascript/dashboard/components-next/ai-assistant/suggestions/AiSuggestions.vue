<script setup>
import { useAiI18n } from '../i18n/aiChatI18n';

const { t } = useAiI18n();
</script>

<template>
  <div class="mt-4">
    <p class="text-xs text-n-slate-10 mb-2">
      {{ t('AI_CHAT.SUGGESTIONS.LABEL') }}
    </p>
    <div class="flex flex-wrap gap-2">
      <slot />
    </div>
  </div>
</template>
