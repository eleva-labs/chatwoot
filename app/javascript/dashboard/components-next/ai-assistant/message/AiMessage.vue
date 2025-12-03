<script setup>
import { computed } from 'vue';
import { MESSAGE_ROLE } from '../constants';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  from: {
    type: String,
    required: true,
    validator: v => Object.values(MESSAGE_ROLE).includes(v),
  },
  avatarName: {
    type: String,
    default: '',
  },
  avatarSrc: {
    type: String,
    default: '',
  },
});

const isUser = computed(() => props.from === MESSAGE_ROLE.USER);

const alignmentClass = computed(() => ({
  'flex-row-reverse': isUser.value,
  'flex-row': !isUser.value,
}));

const avatarName = computed(() => {
  if (props.avatarName) return props.avatarName;
  return isUser.value ? 'User' : 'AI';
});

const avatarIcon = computed(() => {
  if (props.avatarSrc || props.avatarName) return null;
  return isUser.value ? 'i-lucide-user' : 'i-lucide-bot';
});
</script>

<template>
  <div class="flex w-full items-end gap-2 px-4 py-2" :class="alignmentClass">
    <Avatar
      :name="avatarName"
      :src="avatarSrc"
      :icon-name="avatarIcon"
      :size="28"
      rounded-full
      class="flex-shrink-0 mb-1"
    />
    <slot />
  </div>
</template>
