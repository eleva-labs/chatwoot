<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
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
