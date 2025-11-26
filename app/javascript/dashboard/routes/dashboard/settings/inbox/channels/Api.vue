<script>
import { computed } from 'vue';
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useChannelPurchaseManager } from '../composables/useChannelPurchaseManager';

const shouldBeWebhookUrl = (value = '') =>
  value ? value.startsWith('http') : true;

export default {
  components: {
    PageHeader,
    NextButton,
  },
  setup() {
    const store = useStore();
    const { t } = useI18n();
    const baseLabel = computed(() =>
      t('INBOX_MGMT.ADD.API_CHANNEL.SUBMIT_BUTTON')
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
      handleChannelCreation,
    };
  },
  data() {
    return {
      channelName: '',
      webhookUrl: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    channelName: { required },
    webhookUrl: { shouldBeWebhookUrl },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const apiChannel = await this.handleChannelCreation(() =>
          this.$store.dispatch('inboxes/createChannel', {
            name: this.channelName,
            channel: {
              type: 'api',
              webhook_url: this.webhookUrl,
            },
          })
        );

        router.replace({
          name: 'settings_inboxes_invite_team',
          params: {
            page: 'new',
            inbox_id: apiChannel.id,
          },
        });
      } catch (error) {
        const errorMessage =
          error?.message ||
          this.$t('INBOX_MGMT.ADD.API_CHANNEL.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.API_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.API_CHANNEL.DESC')"
    />
    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.PLACEHOLDER')
            "
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">{{
            $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.ERROR')
          }}</span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.webhookUrl.$error }">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.LABEL') }}
          <input
            v-model="webhookUrl"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.PLACEHOLDER')
            "
            @blur="v$.webhookUrl.$touch"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.SUBTITLE') }}
        </p>
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
          v-if="
            !showUsageLoadingMessage && !usageErrorMessage && noteMessage
          "
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
  </div>
</template>
