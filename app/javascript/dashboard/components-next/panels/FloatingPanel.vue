<script setup>
/**
 * FloatingPanel.vue
 *
 * Generic floating panel container with FAB trigger.
 * Can hold any content via slots.
 */
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';

const props = defineProps({
  position: {
    type: String,
    default: 'bottom-right',
    validator: v =>
      ['bottom-right', 'bottom-left', 'top-right', 'top-left'].includes(v),
  },
  initialOpen: { type: Boolean, default: false },
  panelClass: { type: String, default: 'h-[550px] w-96' },
  showBackdrop: { type: Boolean, default: true },
  fabClass: { type: String, default: 'size-14' },
});

const emit = defineEmits(['open', 'close', 'update:modelValue']);

const isOpen = ref(props.initialOpen);

// RTL-aware position classes for FAB
const positionClasses = computed(() => {
  const positions = {
    'bottom-right': 'bottom-6 ltr:right-6 rtl:left-6',
    'bottom-left': 'bottom-6 ltr:left-6 rtl:right-6',
    'top-right': 'top-6 ltr:right-6 rtl:left-6',
    'top-left': 'top-6 ltr:left-6 rtl:right-6',
  };
  return positions[props.position];
});

// RTL-aware position classes for panel
const panelPositionClasses = computed(() => {
  const positions = {
    'bottom-right': 'bottom-24 ltr:right-6 rtl:left-6',
    'bottom-left': 'bottom-24 ltr:left-6 rtl:right-6',
    'top-right': 'top-24 ltr:right-6 rtl:left-6',
    'top-left': 'top-24 ltr:left-6 rtl:right-6',
  };
  return positions[props.position];
});

const toggle = () => {
  isOpen.value = !isOpen.value;
};

const close = () => {
  isOpen.value = false;
};

const open = () => {
  isOpen.value = true;
};

// Keyboard navigation - Escape to close
const handleKeydown = e => {
  if (e.key === 'Escape' && isOpen.value) {
    close();
  }
};

onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});

watch(isOpen, newValue => {
  emit('update:modelValue', newValue);
  if (newValue) {
    emit('open');
  } else {
    emit('close');
  }
});

defineExpose({ isOpen, toggle, close, open });
</script>

<template>
  <!-- FAB Button -->
  <div class="fixed z-50" :class="positionClasses">
    <button
      :aria-expanded="isOpen"
      aria-haspopup="dialog"
      class="flex items-center justify-center rounded-full bg-n-brand text-white shadow-lg transition-colors hover:brightness-110"
      :class="fabClass"
      @click="toggle"
    >
      <slot name="trigger" :is-open="isOpen" :toggle="toggle" :close="close" />
    </button>
  </div>

  <!-- Panel Popup -->
  <Transition
    enter-active-class="transition-all duration-300 ease-out"
    leave-active-class="transition-all duration-200 ease-in"
    enter-from-class="opacity-0 translate-y-4"
    leave-to-class="opacity-0 translate-y-4"
  >
    <div
      v-if="isOpen"
      role="dialog"
      aria-modal="true"
      class="fixed z-40 overflow-hidden rounded-xl border border-n-weak bg-n-solid-2 shadow-xl"
      :class="[panelPositionClasses, panelClass]"
    >
      <slot :close="close" :toggle="toggle" :is-open="isOpen" />
    </div>
  </Transition>

  <!-- Backdrop -->
  <Transition
    enter-active-class="transition-opacity duration-200 ease-out"
    leave-active-class="transition-opacity duration-150 ease-in"
    enter-from-class="opacity-0"
    leave-to-class="opacity-0"
  >
    <div
      v-if="isOpen && showBackdrop"
      class="fixed inset-0 z-30 bg-n-alpha-black1"
      @click="close"
    />
  </Transition>
</template>
