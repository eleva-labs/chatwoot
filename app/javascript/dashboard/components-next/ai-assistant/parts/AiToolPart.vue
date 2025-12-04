<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  part: { type: Object, required: true },
});

const { t } = useI18n();
const showDetails = ref(false);

const toolName = computed(
  () => props.part?.toolName || props.part?.output?.tool_name || ''
);
const hasInput = computed(() => props.part?.input);
const hasOutput = computed(() => props.part?.output);
</script>

<template>
  <div
    class="my-1 rounded-lg border border-n-weak bg-n-alpha-1 overflow-hidden"
  >
    <button
      class="flex w-full items-center gap-2 px-3 py-2 text-sm hover:bg-n-alpha-2"
      @click="showDetails = !showDetails"
    >
      <span class="i-lucide-wrench size-4 text-n-slate-9" />
      <span class="font-medium text-n-slate-12">
        {{ toolName || t('AI_CHAT.TOOL.LABEL') }}
      </span>
      <span
        class="i-lucide-chevron-down size-4 ml-auto text-n-slate-9 transition-transform"
        :class="{ 'rotate-180': showDetails }"
      />
    </button>

    <div
      v-if="showDetails"
      class="border-t border-n-weak overflow-hidden transition-all duration-200 ease-in-out"
    >
      <div v-if="hasInput" class="px-3 py-2 border-b border-n-weak">
        <div class="text-xs font-medium text-n-slate-10 mb-1">
          {{ t('AI_CHAT.TOOL.INPUT_LABEL') }}
        </div>
        <pre class="text-xs text-n-slate-11 overflow-x-auto">{{
          JSON.stringify(part.input, null, 2)
        }}</pre>
      </div>
      <div v-if="hasOutput" class="px-3 py-2">
        <div class="text-xs font-medium text-n-slate-10 mb-1">
          {{ t('AI_CHAT.TOOL.OUTPUT_LABEL') }}
        </div>
        <pre class="text-xs text-n-slate-11 overflow-x-auto">{{
          JSON.stringify(part.output, null, 2)
        }}</pre>
      </div>
    </div>
  </div>
</template>
