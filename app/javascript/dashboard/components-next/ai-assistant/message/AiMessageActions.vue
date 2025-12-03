<script setup>
// Container for message action buttons
// Shows on hover via group-hover class on parent
</script>

<template>
  <div
    class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
  >
    <slot />
  </div>
</template>
