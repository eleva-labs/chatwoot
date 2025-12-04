<script setup>
import { computed } from 'vue';
import { MESSAGE_ROLE } from '../constants';

const props = defineProps({
  from: {
    type: String,
    required: true,
    validator: v => Object.values(MESSAGE_ROLE).includes(v),
  },
});

const bubbleClass = computed(() => ({
  'bg-n-brand text-white rounded-2xl rounded-br-sm':
    props.from === MESSAGE_ROLE.USER,
  'bg-n-solid-3 text-n-slate-12 rounded-2xl rounded-bl-sm':
    props.from === MESSAGE_ROLE.ASSISTANT,
}));
</script>

<template>
  <div class="px-4 py-2" :class="bubbleClass">
    <slot />
  </div>
</template>
