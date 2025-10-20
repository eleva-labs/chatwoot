<script setup>
import { ref, reactive, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { required, helpers, url } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { BOT_TYPES } from '../constants';

const emit = defineEmits(['created', 'close']);

const store = useStore();
const { t } = useI18n();

const dialogRef = ref(null);
const currentAccount = useMapGetter('getCurrentAccount');
const uiFlags = useMapGetter('agentBots/getUIFlags');

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

const initializeWebhookUrl = () => {
  const storeId = currentAccount.value.store_id;
  formState.webhookUrl = `${window.chatwootConfig.aiBackendUrl}/api/webhooks/chatwoot/message?store_id=${storeId}&agent_system_id=pending&id_type=external`;
};

const resetForm = () => {
  Object.assign(formState, {
    name: '',
    description: '',
    webhookUrl: '',
    avatar: null,
    avatarUrl: '',
  });
  initializeWebhookUrl();
  v$.value.$reset();
};

const handleImageUpload = ({ file, url: avatarUrl }) => {
  formState.avatar = file;
  formState.avatarUrl = avatarUrl;
};

const handleAvatarDelete = () => {
  formState.avatar = null;
  formState.avatarUrl = '';
};

const handleSubmit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  const createPayload = {
    name: formState.name,
    description: formState.description,
    outgoing_url: formState.webhookUrl,
    bot_type: BOT_TYPES.WEBHOOK,
    avatar: formState.avatar,
  };

  try {
    const response = await store.dispatch('agentBots/create', createPayload);
    useAlert(t('AI_EMPLOYEES.CREATE.SUCCESS'));

    if (response?.id) {
      emit('created', response.id);
    }

    resetForm();
    dialogRef.value.close();
  } catch (error) {
    useAlert(t('AI_EMPLOYEES.CREATE.ERROR'));
  }
};

const handleClose = () => {
  resetForm();
  emit('close');
};

onMounted(() => {
  initializeWebhookUrl();
  dialogRef.value?.open();
});

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="$t('AI_EMPLOYEES.CREATE.TITLE')"
    :description="$t('AI_EMPLOYEES.CREATE.DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="handleClose"
  >
    <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('AI_EMPLOYEES.FORM.AVATAR.LABEL') }}
        </span>
        <Avatar
          :src="formState.avatarUrl"
          :name="formState.name"
          :size="68"
          allow-upload
          icon-name="i-lucide-bot-message-square"
          @upload="handleImageUpload"
          @delete="handleAvatarDelete"
        />
      </div>

      <Input
        id="new-employee-name"
        v-model="formState.name"
        :label="$t('AI_EMPLOYEES.FORM.NAME.LABEL')"
        :placeholder="$t('AI_EMPLOYEES.FORM.NAME.PLACEHOLDER')"
        :message="nameError"
        :message-type="nameError ? 'error' : 'info'"
        @blur="v$.name.$touch()"
      />

      <TextArea
        id="new-employee-description"
        v-model="formState.description"
        :label="$t('AI_EMPLOYEES.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('AI_EMPLOYEES.FORM.DESCRIPTION.PLACEHOLDER')"
        rows="3"
      />

      <Input
        id="new-employee-webhook-url"
        v-model="formState.webhookUrl"
        :label="$t('AI_EMPLOYEES.FORM.WEBHOOK_URL.LABEL')"
        disabled
      />

      <div class="flex items-center justify-end gap-2 pt-2">
        <Button
          slate
          faded
          type="button"
          :label="$t('AI_EMPLOYEES.FORM.CANCEL')"
          @click="handleClose"
        />
        <Button
          type="submit"
          :label="$t('AI_EMPLOYEES.FORM.CREATE')"
          :is-loading="uiFlags.isCreating"
          :disabled="v$.$invalid"
        />
      </div>
    </form>
  </Dialog>
</template>
