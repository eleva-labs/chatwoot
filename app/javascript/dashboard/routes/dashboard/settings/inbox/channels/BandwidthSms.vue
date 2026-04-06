<script>
import { computed } from 'vue';
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import router from '../../../../index';

import NextButton from 'dashboard/components-next/button/Button.vue';
import { useChannelPurchaseManager } from '../composables/useChannelPurchaseManager';

const shouldStartWithPlusSign = (value = '') => value.startsWith('+');

export default {
  components: {
    NextButton,
  },
  setup() {
    const store = useStore();
    const { t } = useI18n();
    const baseLabel = computed(() =>
      t('INBOX_MGMT.ADD.SMS.BANDWIDTH.SUBMIT_BUTTON')
    );

    const {
      primaryButtonLabel,
      noteMessage,
      showUsageLoadingMessage,
      usageErrorMessage,
      isPurchasingExtraChannel,
      isChannelInfoLoading,
      isTrialLimitReached,
      handleChannelCreation,
    } = useChannelPurchaseManager({ store, baseLabel, t });

    return {
      v$: useVuelidate(),
      primaryButtonLabel,
      noteMessage,
      showUsageLoadingMessage,
      usageErrorMessage,
      isPurchasingExtraChannel,
      isChannelInfoLoading,
      isTrialLimitReached,
      handleChannelCreation,
    };
  },
  data() {
    return {
      accountId: '',
      apiKey: '',
      apiSecret: '',
      applicationId: '',
      inboxName: '',
      phoneNumber: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    inboxName: { required },
    phoneNumber: { required, shouldStartWithPlusSign },
    apiKey: { required },
    apiSecret: { required },
    applicationId: { required },
    accountId: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const smsChannel = await this.handleChannelCreation(() =>
          this.$store.dispatch('inboxes/createChannel', {
            name: this.inboxName,
            channel: {
              type: 'sms',
              phone_number: this.phoneNumber,
              provider_config: {
                api_key: this.apiKey,
                api_secret: this.apiSecret,
                application_id: this.applicationId,
                account_id: this.accountId,
              },
            },
          })
        );

        router.replace({
          name: 'settings_inboxes_invite_team',
          params: {
            page: 'new',
            inbox_id: smsChannel.id,
          },
        });
      } catch (error) {
        const errorMessage =
          error?.message || this.$t('INBOX_MGMT.ADD.SMS.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel()">
    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.inboxName.$error }">
        {{ $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.INBOX_NAME.PLACEHOLDER')
          "
          @blur="v$.inboxName.$touch"
        />
        <span v-if="v$.inboxName.$error" class="message">{{
          $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.INBOX_NAME.ERROR')
        }}</span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.phoneNumber.$error }">
        {{ $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.PHONE_NUMBER.LABEL') }}
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.PHONE_NUMBER.PLACEHOLDER')
          "
          @blur="v$.phoneNumber.$touch"
        />
        <span v-if="v$.phoneNumber.$error" class="message">{{
          $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.PHONE_NUMBER.ERROR')
        }}</span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.accountId.$error }">
        {{ $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.ACCOUNT_ID.LABEL') }}
        <input
          v-model="accountId"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.ACCOUNT_ID.PLACEHOLDER')
          "
          @blur="v$.accountId.$touch"
        />
        <span v-if="v$.accountId.$error" class="message">{{
          $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.ACCOUNT_ID.ERROR')
        }}</span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.applicationId.$error }">
        {{ $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.APPLICATION_ID.LABEL') }}
        <input
          v-model="applicationId"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.APPLICATION_ID.PLACEHOLDER')
          "
          @blur="v$.applicationId.$touch"
        />
        <span v-if="v$.applicationId.$error" class="message">{{
          $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.APPLICATION_ID.ERROR')
        }}</span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.apiKey.$error }">
        {{ $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.API_KEY.LABEL') }}
        <input
          v-model="apiKey"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.SMS.BANDWIDTH.API_KEY.PLACEHOLDER')"
          @blur="v$.apiKey.$touch"
        />
        <span v-if="v$.apiKey.$error" class="message">{{
          $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.API_KEY.ERROR')
        }}</span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.apiSecret.$error }">
        {{ $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.API_SECRET.LABEL') }}
        <input
          v-model="apiSecret"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.API_SECRET.PLACEHOLDER')
          "
          @blur="v$.apiSecret.$touch"
        />
        <span v-if="v$.apiSecret.$error" class="message">{{
          $t('INBOX_MGMT.ADD.SMS.BANDWIDTH.API_SECRET.ERROR')
        }}</span>
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
        :is-loading="uiFlags.isCreating || isPurchasingExtraChannel"
        :disabled="
          uiFlags.isCreating ||
          isPurchasingExtraChannel ||
          isChannelInfoLoading ||
          isTrialLimitReached
        "
        type="submit"
        solid
        blue
        :label="primaryButtonLabel"
      />
    </div>
  </form>
</template>
