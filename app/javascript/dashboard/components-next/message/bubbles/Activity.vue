<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { messageTimestamp } from 'shared/helpers/timeHelper';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';
import { localizeActivityMessage } from '../helpers/activityMessage.js';

const { t } = useI18n();
const { content, createdAt } = useMessageContext();

const localizedContent = computed(() =>
  localizeActivityMessage(content.value, t)
);

const readableTime = computed(() =>
  messageTimestamp(createdAt.value, 'LLL d, h:mm a')
);
</script>

<template>
  <BaseBubble
    v-tooltip.top="readableTime"
    class="px-3 py-1 !rounded-xl flex min-w-0 items-center gap-2"
    data-bubble-name="activity"
  >
    <span v-dompurify-html="localizedContent" :title="localizedContent" />
  </BaseBubble>
</template>
