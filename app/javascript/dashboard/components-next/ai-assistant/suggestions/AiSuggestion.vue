<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['click']);
</script>

<template>
  <button
    class="px-3 py-1.5 text-sm rounded-full border border-n-weak bg-n-solid-2 text-n-slate-11 hover:bg-n-solid-3 hover:text-n-slate-12 transition-colors"
    @click="emit('click', label)"
  >
    {{ label }}
  </button>
</template>
