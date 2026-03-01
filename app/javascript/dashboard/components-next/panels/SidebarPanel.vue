<script setup>
/**
 * SidebarPanel.vue
 *
 * Generic slide-in sidebar panel container.
 * Can hold any content via slots.
 */
import { computed, watch, onMounted, onUnmounted } from 'vue';

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  position: {
    type: String,
    default: 'right',
    validator: v => ['left', 'right'].includes(v),
  },
  width: { type: String, default: 'w-96' },
  showBackdrop: { type: Boolean, default: true },
});

const emit = defineEmits(['update:modelValue', 'open', 'close']);

const isOpen = computed({
  get: () => props.modelValue,
  set: val => emit('update:modelValue', val),
});

const close = () => {
  isOpen.value = false;
};

const open = () => {
  isOpen.value = true;
};

// RTL-aware position classes
const positionClasses = computed(() => {
  return props.position === 'right'
    ? 'ltr:right-0 rtl:left-0'
    : 'ltr:left-0 rtl:right-0';
});

// RTL-aware slide animation
const slideClasses = computed(() => {
  if (props.position === 'right') {
    return {
      enter: 'ltr:translate-x-full rtl:-translate-x-full',
      leave: 'ltr:translate-x-full rtl:-translate-x-full',
    };
  }
  return {
    enter: 'ltr:-translate-x-full rtl:translate-x-full',
    leave: 'ltr:-translate-x-full rtl:translate-x-full',
  };
});

// RTL-aware border
const borderClasses = computed(() => {
  return props.position === 'right'
    ? 'ltr:border-l rtl:border-r'
    : 'ltr:border-r rtl:border-l';
});

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
  if (newValue) {
    emit('open');
  } else {
    emit('close');
  }
});

defineExpose({ isOpen, close, open });
</script>

<template>
  <!-- Sidebar Panel -->
  <Transition
    enter-active-class="transition-transform duration-300 ease-out"
    leave-active-class="transition-transform duration-200 ease-in"
    :enter-from-class="slideClasses.enter"
    :leave-to-class="slideClasses.leave"
  >
    <aside
      v-if="isOpen"
      role="dialog"
      aria-modal="true"
      class="fixed top-0 z-40 h-full overflow-hidden border-n-weak bg-n-solid-2 shadow-xl"
      :class="[positionClasses, width, borderClasses]"
    >
      <slot :close="close" :is-open="isOpen" />
    </aside>
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
