<script setup>
import { reactive, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { required, helpers, url } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import AccessToken from 'dashboard/routes/dashboard/settings/profile/AccessToken.vue';
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import { BOT_TYPES } from '../constants';

const props = defineProps({
  employee: {
    type: Object,
    required: true,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['updated']);

const store = useStore();
const { t } = useI18n();

const formState = reactive({
  name: '',
  description: '',
  webhookUrl: '',
  avatar: null,
  avatarUrl: '',
});

const validationRules = {
  name: {
    required: helpers.withMessage(
      () => t('AI_EMPLOYEES.FORM.ERRORS.NAME_REQUIRED'),
      required
    ),
  },
  webhookUrl: {
    required: helpers.withMessage(
      () => t('AI_EMPLOYEES.FORM.ERRORS.URL_REQUIRED'),
      required
    ),
    url: helpers.withMessage(
      () => t('AI_EMPLOYEES.FORM.ERRORS.VALID_URL'),
      url
    ),
  },
};

const v$ = useVuelidate(validationRules, formState);

const nameError = computed(() =>
  v$.value.name.$error ? v$.value.name.$errors[0]?.$message : ''
);

const initializeForm = () => {
  if (props.employee?.id) {
    formState.name = props.employee.name || '';
    formState.description = props.employee.description || '';
    formState.webhookUrl = props.employee.outgoing_url || '';
    formState.avatarUrl = props.employee.thumbnail || '';
    formState.avatar = null;
  }
};

const resetForm = () => {
  initializeForm();
  v$.value.$reset();
};

const handleImageUpload = ({ file, url: avatarUrl }) => {
  formState.avatar = file;
  formState.avatarUrl = avatarUrl;
};

const handleAvatarDelete = async () => {
  if (props.employee?.id) {
    try {
      await store.dispatch('agentBots/deleteAgentBotAvatar', props.employee.id);
      formState.avatar = null;
      formState.avatarUrl = '';
      useAlert(t('AI_EMPLOYEES.AVATAR.SUCCESS_DELETE'));
      emit('updated');
    } catch (error) {
      useAlert(t('AI_EMPLOYEES.AVATAR.ERROR_DELETE'));
    }
  } else {
    formState.avatar = null;
    formState.avatarUrl = '';
  }
};

const handleSubmit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  const updatePayload = {
    name: formState.name,
    description: formState.description,
    outgoing_url: formState.webhookUrl,
    bot_type: BOT_TYPES.WEBHOOK,
    avatar: formState.avatar,
  };

  try {
    await store.dispatch('agentBots/update', {
      id: props.employee.id,
      data: updatePayload,
    });
    useAlert(t('AI_EMPLOYEES.UPDATE.SUCCESS'));
    emit('updated');
  } catch (error) {
    useAlert(t('AI_EMPLOYEES.UPDATE.ERROR'));
  }
};

const handleCopyToken = async value => {
  await copyTextToClipboard(value);
  useAlert(t('AI_EMPLOYEES.FORM.ACCESS_TOKEN.COPY_SUCCESS'));
};

const handleResetToken = async () => {
  try {
    const response = await store.dispatch(
      'agentBots/resetAccessToken',
      props.employee.id
    );
    if (response) {
      useAlert(t('AI_EMPLOYEES.FORM.ACCESS_TOKEN.RESET_SUCCESS'));
      emit('updated');
    } else {
      useAlert(t('AI_EMPLOYEES.FORM.ACCESS_TOKEN.RESET_ERROR'));
    }
  } catch (error) {
    useAlert(t('AI_EMPLOYEES.FORM.ACCESS_TOKEN.RESET_ERROR'));
  }
};

watch(
  () => props.employee,
  () => {
    initializeForm();
  },
  { immediate: true, deep: true }
);
</script>

<template>
  <form @submit.prevent="handleSubmit">
    <SettingsSection
      :title="$t('AI_EMPLOYEES.FORM.GENERAL.TITLE')"
      :sub-title="$t('AI_EMPLOYEES.FORM.GENERAL.DESCRIPTION')"
      :show-border="false"
    >
      <div class="flex flex-col mb-4 items-start gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AI_EMPLOYEES.FORM.AVATAR.LABEL') }}
        </label>
        <Avatar
          :src="formState.avatarUrl"
          :name="formState.name"
          :size="72"
          allow-upload
          rounded-full
          icon-name="i-lucide-bot-message-square"
          @upload="handleImageUpload"
          @delete="handleAvatarDelete"
        />
      </div>

      <woot-input
        v-model="formState.name"
        class="pb-4"
        :class="{ error: v$.name.$error }"
        :label="$t('AI_EMPLOYEES.FORM.NAME.LABEL')"
        :placeholder="$t('AI_EMPLOYEES.FORM.NAME.PLACEHOLDER')"
        :error="nameError"
        @blur="v$.name.$touch()"
      />

      <label class="block mb-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('AI_EMPLOYEES.FORM.DESCRIPTION.LABEL') }}
        </span>
        <textarea
          v-model="formState.description"
          rows="4"
          class="w-full mt-1 px-3 py-2 border border-n-weak rounded-md text-sm text-n-slate-12 bg-n-solid-1 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
          :placeholder="$t('AI_EMPLOYEES.FORM.DESCRIPTION.PLACEHOLDER')"
        />
      </label>

      <woot-input
        v-model="formState.webhookUrl"
        class="pb-4"
        :label="$t('AI_EMPLOYEES.FORM.WEBHOOK_URL.LABEL')"
        :placeholder="$t('AI_EMPLOYEES.FORM.WEBHOOK_URL.PLACEHOLDER')"
        disabled
      />

      <div v-if="employee.id" class="flex flex-col gap-2 pb-4">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('AI_EMPLOYEES.FORM.ACCESS_TOKEN.LABEL') }}
        </label>
        <AccessToken
          :value="employee.access_token"
          @on-copy="handleCopyToken"
          @on-reset="handleResetToken"
        />
      </div>

      <div class="flex items-center gap-2">
        <woot-submit-button
          :button-text="$t('AI_EMPLOYEES.FORM.SAVE')"
          :loading="isLoading"
          :disabled="v$.$invalid"
        />
        <Button
          type="button"
          slate
          faded
          :label="$t('AI_EMPLOYEES.FORM.CANCEL')"
          @click="resetForm"
        />
      </div>
    </SettingsSection>
  </form>
</template>
