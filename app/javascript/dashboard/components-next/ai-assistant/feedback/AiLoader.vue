<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  text: { type: String, default: null },
});

const { t } = useI18n();
</script>

<template>
  <div class="flex items-center gap-2 px-4 py-2 text-n-slate-11">
    <span class="i-lucide-loader-2 size-4 animate-spin" />
    <span class="text-sm">{{ text || t('AI_CHAT.LOADER.WAITING') }}</span>
  </div>
</template>
