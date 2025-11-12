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

export default {
  components: {
    PageHeader,
    NextButton,
  },
  setup() {
    const store = useStore();
    const { t } = useI18n();
    const baseLabel = computed(() =>
      t('INBOX_MGMT.ADD.LINE_CHANNEL.SUBMIT_BUTTON')
    );

    const {
      primaryButtonLabel,
      noteMessage,
      showUsageLoadingMessage,
      usageErrorMessage,
      isPurchasingExtraChannel,
      isChannelInfoLoading,
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
      lineChannelId: '',
      lineChannelSecret: '',
      lineChannelToken: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    channelName: { required },
    lineChannelId: { required },
    lineChannelSecret: { required },
    lineChannelToken: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const lineChannel = await this.handleChannelCreation(() =>
          this.$store.dispatch('inboxes/createChannel', {
            name: this.channelName,
            channel: {
              type: 'line',
              line_channel_id: this.lineChannelId,
              line_channel_secret: this.lineChannelSecret,
              line_channel_token: this.lineChannelToken,
            },
          })
        );

        router.replace({
          name: 'settings_inboxes_invite_team',
          params: {
            page: 'new',
            inbox_id: lineChannel.id,
          },
        });
      } catch (error) {
        const errorMessage =
          error?.message ||
          this.$t('INBOX_MGMT.ADD.LINE_CHANNEL.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.LINE_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.LINE_CHANNEL.DESC')"
    />
    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          {{ $t('INBOX_MGMT.ADD.LINE_CHANNEL.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.LINE_CHANNEL.CHANNEL_NAME.PLACEHOLDER')
            "
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">{{
            $t('INBOX_MGMT.ADD.LINE_CHANNEL.CHANNEL_NAME.ERROR')
          }}</span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.lineChannelId.$error }">
          {{ $t('INBOX_MGMT.ADD.LINE_CHANNEL.LINE_CHANNEL_ID.LABEL') }}
          <input
            v-model="lineChannelId"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.LINE_CHANNEL.LINE_CHANNEL_ID.PLACEHOLDER')
            "
            @blur="v$.lineChannelId.$touch"
          />
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.lineChannelSecret.$error }">
          {{ $t('INBOX_MGMT.ADD.LINE_CHANNEL.LINE_CHANNEL_SECRET.LABEL') }}
          <input
            v-model="lineChannelSecret"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.LINE_CHANNEL.LINE_CHANNEL_SECRET.PLACEHOLDER')
            "
            @blur="v$.lineChannelSecret.$touch"
          />
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.lineChannelToken.$error }">
          {{ $t('INBOX_MGMT.ADD.LINE_CHANNEL.LINE_CHANNEL_TOKEN.LABEL') }}
          <input
            v-model="lineChannelToken"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.LINE_CHANNEL.LINE_CHANNEL_TOKEN.PLACEHOLDER')
            "
            @blur="v$.lineChannelToken.$touch"
          />
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
            uiFlags.isCreating || isPurchasingExtraChannel || isChannelInfoLoading
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
