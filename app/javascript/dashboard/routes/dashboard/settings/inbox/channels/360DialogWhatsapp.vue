<script setup>
import { ref, computed } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import NextButton from 'dashboard/components-next/button/Button.vue';

import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import { useI18n } from 'vue-i18n';
import { useChannelPurchaseManager } from '../composables/useChannelPurchaseManager';

const store = useStore();
const { t } = useI18n();

// State (replaces data())
const inboxName = ref('');
const phoneNumber = ref('');
const apiKey = ref('');

// Store access (replaces mapGetters)
const uiFlags = useMapGetter('inboxes/getUIFlags');

// Validation setup
const rules = {
  inboxName: { required },
  phoneNumber: { required, isPhoneE164OrEmpty },
  apiKey: { required },
};

const v$ = useVuelidate(rules, { inboxName, phoneNumber, apiKey });

// Methods (converted to functions)
const baseLabel = computed(() => t('INBOX_MGMT.ADD.WHATSAPP.SUBMIT_BUTTON'));

const {
  primaryButtonLabel,
  noteMessage,
  showUsageLoadingMessage,
  usageErrorMessage,
  isPurchasingExtraChannel,
  isChannelInfoLoading,
  handleChannelCreation,
} = useChannelPurchaseManager({ store, baseLabel, t });

const createChannel = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) {
    return;
  }

  try {
    const whatsappChannel = await handleChannelCreation(() =>
      store.dispatch('inboxes/createChannel', {
        name: inboxName.value,
        channel: {
          type: 'whatsapp',
          phone_number: phoneNumber.value,
          provider_config: {
            api_key: apiKey.value,
          },
        },
      })
    );

    router.replace({
      name: 'settings_inboxes_invite_team',
      params: {
        page: 'new',
        inbox_id: whatsappChannel.id,
      },
    });
  } catch (error) {
    useAlert(
      error?.message || 'An error occurred while creating the channel'
    );
  }
};
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel()">
    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.inboxName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
          @blur="v$.inboxName.$touch"
        />
        <span v-if="v$.inboxName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.phoneNumber.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.LABEL') }}
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.PLACEHOLDER')"
          @blur="v$.phoneNumber.$touch"
        />
        <span v-if="v$.phoneNumber.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.apiKey.$error }">
        <span>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.LABEL') }}
        </span>
        <input
          v-model="apiKey"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.PLACEHOLDER')"
          @blur="v$.apiKey.$touch"
        />
        <span v-if="v$.apiKey.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.ERROR') }}
        </span>
      </label>
    </div>

    <div class="w-full mt-4">
      <div class="pt-4 border-t border-n-weak text-sm">
        <p v-if="showUsageLoadingMessage" class="text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.USAGE_LOADING') }}
        </p>
        <p v-else-if="usageErrorMessage" class="text-n-ruby-11">
          {{ usageErrorMessage }}
        </p>
      </div>
      <p
        v-if="!showUsageLoadingMessage && !usageErrorMessage && noteMessage"
        class="mt-3 text-xs text-n-amber-11 bg-n-amber-2 border border-n-amber-7 rounded-md px-3 py-2"
      >
        {{ noteMessage }}
      </p>
      <NextButton
        type="submit"
        :label="primaryButtonLabel"
        :is-loading="uiFlags.isCreating || isPurchasingExtraChannel"
        :disabled="
          uiFlags.isCreating || isPurchasingExtraChannel || isChannelInfoLoading
        "
      />
    </div>
  </form>
</template>
