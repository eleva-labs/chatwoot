<script setup>
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  employee: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['configure', 'delete']);

const handleConfigure = () => {
  emit('configure');
};
</script>

<template>
  <CardLayout class="cursor-pointer" @click="handleConfigure">
    <div class="flex items-start gap-3">
      <Avatar
        :src="employee.thumbnail"
        :name="employee.name"
        :size="48"
        icon-name="i-lucide-bot-message-square"
      />
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-1">
          <h3 class="font-medium text-n-slate-12 truncate">
            {{ employee.name }}
          </h3>
          <span
            v-if="employee.is_system"
            class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md bg-n-blue-2 text-n-blue-11"
          >
            {{ $t('AI_EMPLOYEES.SYSTEM_BADGE') }}
          </span>
        </div>

        <p class="text-sm text-n-slate-11 line-clamp-2 mb-2">
          {{ employee.description || $t('AI_EMPLOYEES.CARD.NO_DESCRIPTION') }}
        </p>

        <div class="flex items-center gap-2">
          <span class="text-xs text-n-slate-10 font-mono">
            {{ employee.bot_type }}
          </span>
        </div>
      </div>
    </div>

    <template #after>
      <div class="flex gap-2 px-6 pb-4 border-t border-n-weak pt-3">
        <Button
          size="small"
          icon="i-lucide-settings"
          :label="$t('AI_EMPLOYEES.CARD.CONFIGURE')"
          @click.stop="$emit('configure')"
        />
        <Button
          v-if="!employee.is_system"
          size="small"
          slate
          faded
          icon="i-lucide-trash-2"
          :label="$t('AI_EMPLOYEES.CARD.DELETE')"
          @click.stop="$emit('delete')"
        />
      </div>
    </template>
  </CardLayout>
</template>
