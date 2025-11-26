<script>
import { computed } from 'vue';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import router from '../../../../index';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';
import GreetingsEditor from 'shared/components/GreetingsEditor.vue';
import { WIDGET_BUILDER_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import { useChannelPurchaseManager } from '../composables/useChannelPurchaseManager';

export default {
  components: {
    PageHeader,
    GreetingsEditor,
    NextButton,
    Editor,
  },
  setup() {
    const store = useStore();
    const { t } = useI18n();
    const baseLabel = computed(() =>
      t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.SUBMIT_BUTTON')
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
      inboxName: '',
      channelWebsiteUrl: '',
      channelWidgetColor: '#009CE0',
      channelWelcomeTitle: '',
      channelWelcomeTagline: '',
      greetingEnabled: false,
      greetingMessage: '',
      welcomeTaglineEditorMenuOptions: WIDGET_BUILDER_EDITOR_MENU_OPTIONS,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
    textAreaChannels() {
      if (
        this.isATwilioChannel ||
        this.isATwitterInbox ||
        this.isAFacebookInbox
      )
        return true;
      return false;
    },
  },
  methods: {
    async createChannel() {
      try {
        const website = await this.handleChannelCreation(() =>
          this.$store.dispatch('inboxes/createWebsiteChannel', {
            name: this.inboxName,
            greeting_enabled: this.greetingEnabled,
            greeting_message: this.greetingMessage,
            channel: {
              type: 'web_widget',
              website_url: this.channelWebsiteUrl,
              widget_color: this.channelWidgetColor,
              welcome_title: this.channelWelcomeTitle,
              welcome_tagline: this.channelWelcomeTagline,
            },
          })
        );
        router.replace({
          name: 'settings_inboxes_invite_team',
          params: {
            page: 'new',
            inbox_id: website.id,
          },
        });
      } catch (error) {
        const errorMessage =
          error?.message ||
          this.$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.DESC')"
    />
    <woot-loading-state
      v-if="uiFlags.isCreating"
      :message="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.LOADING_MESSAGE')"
    />
    <form
      v-if="!uiFlags.isCreating"
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel"
    >
      <div class="w-full">
        <label>
          {{ $t('INBOX_MGMT.ADD.WEBSITE_NAME.LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.WEBSITE_NAME.PLACEHOLDER')"
          />
        </label>
      </div>
      <div class="w-full">
        <label>
          {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.LABEL') }}
          <input
            v-model="channelWebsiteUrl"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.PLACEHOLDER')
            "
          />
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.WIDGET_COLOR.LABEL') }}
          <woot-color-picker v-model="channelWidgetColor" />
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.LABEL') }}
          <input
            v-model="channelWelcomeTitle"
            type="text"
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.PLACEHOLDER'
              )
            "
          />
        </label>
      </div>
      <Editor
        v-model="channelWelcomeTagline"
        :label="
          $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.LABEL')
        "
        :placeholder="
          $t(
            'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.PLACEHOLDER'
          )
        "
        :max-length="255"
        :enabled-menu-options="welcomeTaglineEditorMenuOptions"
        class="mb-4"
      />

      <label class="w-full">
        {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.LABEL') }}
        <select v-model="greetingEnabled">
          <option :value="true">
            {{
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.ENABLED'
              )
            }}
          </option>
          <option :value="false">
            {{
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.DISABLED'
              )
            }}
          </option>
        </select>
        <p class="help-text">
          {{
            $t(
              'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.HELP_TEXT'
            )
          }}
        </p>
      </label>
      <GreetingsEditor
        v-if="greetingEnabled"
        v-model="greetingMessage"
        class="w-full"
        :label="
          $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.LABEL')
        "
        :placeholder="
          $t(
            'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.PLACEHOLDER'
          )
        "
        :richtext="!textAreaChannels"
      />
      <div class="flex flex-col w-full gap-3 px-0 py-2 mt-4">
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
          class="text-xs text-n-amber-11 bg-n-amber-2 border border-n-amber-7 rounded-md px-3 py-2"
        >
          {{ noteMessage }}
        </p>
        <div class="flex justify-end w-full">
          <NextButton
            type="submit"
            :is-loading="uiFlags.isCreating || isPurchasingExtraChannel"
            :disabled="
              !channelWebsiteUrl ||
              !inboxName ||
              uiFlags.isCreating ||
              isPurchasingExtraChannel ||
              isChannelInfoLoading
              || isTrialLimitReached
            "
            solid
            blue
            :label="primaryButtonLabel"
          />
        </div>
      </div>
    </form>
  </div>
</template>
