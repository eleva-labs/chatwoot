<!-- Deprecated in favour of separate files for SMS and Whatsapp and also to implement new providers for each platform in the future-->
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
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import { useChannelPurchaseManager } from '../composables/useChannelPurchaseManager';

export default {
  components: {
    NextButton,
  },
  props: {
    type: {
      type: String,
      required: true,
    },
  },
  setup() {
    const store = useStore();
    const { t } = useI18n();
    const baseLabel = computed(() => t('INBOX_MGMT.ADD.TWILIO.SUBMIT_BUTTON'));

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
      accountSID: '',
      apiKeySID: '',
      authToken: '',
      medium: this.type,
      channelName: '',
      messagingServiceSID: '',
      useMessagingService: false,
      useAPIKey: false,
      phoneNumber: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
    authTokeni18nKey() {
      return this.useAPIKey ? 'API_KEY_SECRET' : 'AUTH_TOKEN';
    },
  },
  validations() {
    let validations = {
      channelName: { required },

      authToken: { required },
      accountSID: { required },
      medium: { required },
    };
    if (this.phoneNumber) {
      validations = {
        ...validations,
        phoneNumber: { required, isPhoneE164OrEmpty },
        messagingServiceSID: {},
      };
    } else {
      validations = {
        ...validations,
        messagingServiceSID: { required },
        phoneNumber: {},
      };
    }

    if (this.useAPIKey) {
      validations = {
        ...validations,
        apiKeySID: { required },
      };
    }
    return validations;
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const twilioChannel = await this.handleChannelCreation(() =>
          this.$store.dispatch('inboxes/createTwilioChannel', {
            twilio_channel: {
              name: this.channelName?.trim(),
              medium: this.medium,
              account_sid: this.accountSID,
              api_key_sid: this.apiKeySID,
              auth_token: this.authToken,
              messaging_service_sid: this.messagingServiceSID,
              phone_number: this.messagingServiceSID
                ? null
                : `+${this.phoneNumber.replace(/\D/g, '')}`,
            },
          })
        );

        router.replace({
          name: 'settings_inboxes_invite_team',
          params: {
            page: 'new',
            inbox_id: twilioChannel.id,
          },
        });
      } catch (error) {
        const errorMessage =
          parseAPIErrorResponse(error) ||
          this.$t('INBOX_MGMT.ADD.TWILIO.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel()">
    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.channelName.$error }">
        {{ $t('INBOX_MGMT.ADD.TWILIO.CHANNEL_NAME.LABEL') }}
        <input
          v-model="channelName"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.TWILIO.CHANNEL_NAME.PLACEHOLDER')"
          @blur="v$.channelName.$touch"
        />
        <span v-if="v$.channelName.$error" class="message">{{
          $t('INBOX_MGMT.ADD.TWILIO.CHANNEL_NAME.ERROR')
        }}</span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label
        v-if="useMessagingService"
        :class="{ error: v$.messagingServiceSID.$error }"
      >
        {{ $t('INBOX_MGMT.ADD.TWILIO.MESSAGING_SERVICE_SID.LABEL') }}
        <input
          v-model="messagingServiceSID"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.TWILIO.MESSAGING_SERVICE_SID.PLACEHOLDER')
          "
          @blur="v$.messagingServiceSID.$touch"
        />
        <span v-if="v$.messagingServiceSID.$error" class="message">{{
          $t('INBOX_MGMT.ADD.TWILIO.MESSAGING_SERVICE_SID.ERROR')
        }}</span>
      </label>
    </div>

    <div v-if="!useMessagingService" class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.phoneNumber.$error }">
        {{ $t('INBOX_MGMT.ADD.TWILIO.PHONE_NUMBER.LABEL') }}
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.TWILIO.PHONE_NUMBER.PLACEHOLDER')"
          @blur="v$.phoneNumber.$touch"
        />
        <span v-if="v$.phoneNumber.$error" class="message">{{
          $t('INBOX_MGMT.ADD.TWILIO.PHONE_NUMBER.ERROR')
        }}</span>
      </label>
    </div>

    <div class="max-w-[65%] w-full messagingServiceHelptext">
      <label for="useMessagingService">
        <input
          id="useMessagingService"
          v-model="useMessagingService"
          type="checkbox"
          class="checkbox"
        />
        {{
          $t(
            'INBOX_MGMT.ADD.TWILIO.MESSAGING_SERVICE_SID.USE_MESSAGING_SERVICE'
          )
        }}
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.accountSID.$error }">
        {{ $t('INBOX_MGMT.ADD.TWILIO.ACCOUNT_SID.LABEL') }}
        <input
          v-model="accountSID"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.TWILIO.ACCOUNT_SID.PLACEHOLDER')"
          @blur="v$.accountSID.$touch"
        />
        <span v-if="v$.accountSID.$error" class="message">{{
          $t('INBOX_MGMT.ADD.TWILIO.ACCOUNT_SID.ERROR')
        }}</span>
      </label>
    </div>
    <div class="max-w-[65%] w-full messagingServiceHelptext">
      <label for="useAPIKey">
        <input
          id="useAPIKey"
          v-model="useAPIKey"
          type="checkbox"
          class="checkbox"
        />
        {{ $t('INBOX_MGMT.ADD.TWILIO.API_KEY.USE_API_KEY') }}
      </label>
    </div>
    <div v-if="useAPIKey" class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.apiKeySID.$error }">
        {{ $t('INBOX_MGMT.ADD.TWILIO.API_KEY.LABEL') }}
        <input
          v-model="apiKeySID"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.TWILIO.API_KEY.PLACEHOLDER')"
          @blur="v$.apiKeySID.$touch"
        />
        <span v-if="v$.apiKeySID.$error" class="message">{{
          $t('INBOX_MGMT.ADD.TWILIO.API_KEY.ERROR')
        }}</span>
      </label>
    </div>
    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.authToken.$error }">
        <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
        {{ $t(`INBOX_MGMT.ADD.TWILIO.${authTokeni18nKey}.LABEL`) }}
        <input
          v-model="authToken"
          type="text"
          :placeholder="
            /* eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys */
            $t(`INBOX_MGMT.ADD.TWILIO.${authTokeni18nKey}.PLACEHOLDER`)
          "
          @blur="v$.authToken.$touch"
        />
        <span v-if="v$.authToken.$error" class="message">
          <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
          {{ $t(`INBOX_MGMT.ADD.TWILIO.${authTokeni18nKey}.ERROR`) }}
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

<style lang="scss" scoped>
.messagingServiceHelptext {
  margin-top: -10px;
  margin-bottom: 15px;

  .checkbox {
    margin: 0px 4px;
  }
}
</style>
