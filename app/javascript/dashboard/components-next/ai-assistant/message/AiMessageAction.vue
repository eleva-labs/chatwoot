<script setup>
defineProps({
  icon: { type: String, required: true },
  label: { type: String, required: true },
});

const emit = defineEmits(['click']);
</script>

<template>
  <button
    v-tooltip="label"
    class="p-1.5 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
    @click="emit('click')"
  >
    <span class="size-4" :class="[icon]" />
  </button>
</template>
