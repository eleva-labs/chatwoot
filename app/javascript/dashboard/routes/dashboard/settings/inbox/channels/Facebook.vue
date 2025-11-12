<script>
/* eslint-env browser */
/* global FB */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { required } from '@vuelidate/validators';
import { useStore } from 'dashboard/composables/store';
import LoadingState from 'dashboard/components/widgets/LoadingState.vue';

import ChannelApi from '../../../../../api/channels';
import PageHeader from '../../SettingsSubPageHeader.vue';
import router from '../../../../index';
import { useBranding } from 'shared/composables/useBranding';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useChannelPurchaseManager } from '../composables/useChannelPurchaseManager';

import { loadScript } from 'dashboard/helper/DOMHelpers';
import * as Sentry from '@sentry/vue';

export default {
  components: {
    LoadingState,
    PageHeader,
    NextButton,
  },
  setup() {
    const { accountId } = useAccount();
    const { replaceInstallationName } = useBranding();
    const v$ = useVuelidate();
    const store = useStore();
    const { t } = useI18n();
    const baseLabel = computed(() =>
      t('INBOX_MGMT.ADD.FB.CREATE_INBOX')
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
      accountId,
      replaceInstallationName,
      v$,
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
      isCreating: false,
      hasError: false,
      omniauth_token: '',
      user_access_token: '',
      channel: 'facebook',
      selectedPage: { name: null, id: null },
      pageName: '',
      pageList: [],
      emptyStateMessage: this.$t('INBOX_MGMT.DETAILS.LOADING_FB'),
      errorStateMessage: '',
      errorStateDescription: '',
      hasLoginStarted: false,
    };
  },

  validations: {
    pageName: {
      required,
    },

    selectedPage: {
      isEmpty() {
        return this.selectedPage !== null && !!this.selectedPage.name;
      },
    },
  },

  computed: {
    showLoader() {
      return !this.user_access_token || this.isCreating;
    },
    getSelectablePages() {
      return this.pageList.filter(item => !item.exists);
    },
  },

  mounted() {
    window.fbAsyncInit = this.runFBInit;
  },

  methods: {
    async startLogin() {
      this.hasLoginStarted = true;
      try {
        // this will load the SDK in a promise, and resolve it when the sdk is loaded
        // in case the SDK is already present, it will resolve immediately
        await this.loadFBsdk();
        this.runFBInit(); // run init anyway, `tryFBlogin` won't wait for `fbAsyncInit` otherwise.
        this.tryFBlogin(); // make an attempt to login
      } catch (error) {
        if (error.name === 'ScriptLoaderError') {
          // if the error was related to script loading, we show a toast
          useAlert(this.$t('INBOX_MGMT.DETAILS.ERROR_FB_LOADING'));
        } else {
          // if the error was anything else, we capture it and show a toast
          Sentry.captureException(error);
          useAlert(this.$t('INBOX_MGMT.DETAILS.ERROR_FB_AUTH'));
        }
      }
    },

    setPageName({ name }) {
      this.v$.selectedPage.$touch();
      this.pageName = name;
    },

    initChannelAuth(channel) {
      if (channel === 'facebook') {
        this.loadFBsdk();
      }
    },

    runFBInit() {
      FB.init({
        appId: window.chatwootConfig.fbAppId,
        xfbml: true,
        version: window.chatwootConfig.fbApiVersion,
        status: true,
      });
      window.fbSDKLoaded = true;
      FB.AppEvents.logPageView();
    },

    async loadFBsdk() {
      return loadScript('https://connect.facebook.net/en_US/sdk.js', {
        id: 'facebook-jssdk',
      });
    },

    tryFBlogin() {
      FB.login(
        response => {
          this.hasError = false;
          if (response.status === 'connected') {
            this.fetchPages(response.authResponse.accessToken);
          } else if (response.status === 'not_authorized') {
            // eslint-disable-next-line no-console
            console.error('FACEBOOK AUTH ERROR', response);
            this.hasError = true;
            // The person is logged into Facebook, but not your app.
            this.errorStateMessage = this.$t(
              'INBOX_MGMT.DETAILS.ERROR_FB_UNAUTHORIZED'
            );
            this.errorStateDescription = this.$t(
              'INBOX_MGMT.DETAILS.ERROR_FB_UNAUTHORIZED_HELP'
            );
          } else {
            // eslint-disable-next-line no-console
            console.error('FACEBOOK AUTH ERROR', response);
            this.hasError = true;
            // The person is not logged into Facebook, so we're not sure if
            // they are logged into this app or not.
            this.errorStateMessage = this.$t(
              'INBOX_MGMT.DETAILS.ERROR_FB_AUTH'
            );
            this.errorStateDescription = '';
          }
        },
        {
          scope:
            'pages_manage_metadata,business_management,pages_messaging,instagram_basic,pages_show_list,pages_read_engagement,instagram_manage_messages',
        }
      );
    },

    async fetchPages(_token) {
      try {
        const response = await ChannelApi.fetchFacebookPages(
          _token,
          this.accountId
        );
        const {
          data: { data },
        } = response;
        this.pageList = data.page_details;
        this.user_access_token = data.user_access_token;
      } catch (error) {
        // Ignore error
      }
    },

    channelParams() {
      return {
        user_access_token: this.user_access_token,
        page_access_token: this.selectedPage.access_token,
        page_id: this.selectedPage.id,
        inbox_name: this.selectedPage.name,
      };
    },

    async createChannel() {
      this.v$.$touch();
      if (!this.v$.$error) {
        this.emptyStateMessage = this.$t('INBOX_MGMT.DETAILS.CREATING_CHANNEL');
        this.isCreating = true;
        try {
          const data = await this.handleChannelCreation(() =>
            this.$store.dispatch('inboxes/createFBChannel', this.channelParams())
          );
          router.replace({
            name: 'settings_inboxes_invite_team',
            params: { page: 'new', inbox_id: data.id },
          });
        } catch (error) {
          this.isCreating = false;
          if (error?.message) {
            useAlert(error.message);
          }
        }
      }
    },
  },
};
</script>

<template>
  <div class="w-full h-full col-span-6 p-6 overflow-auto">
    <div
      v-if="!hasLoginStarted"
      class="flex flex-col items-center justify-center h-full text-center"
    >
      <a href="#" @click="startLogin()">
        <img
          class="w-auto h-10 rounded-md"
          src="~dashboard/assets/images/channels/facebook_login.png"
          alt="Facebook-logo"
        />
      </a>
      <p class="py-6">
        {{ replaceInstallationName($t('INBOX_MGMT.ADD.FB.HELP')) }}
      </p>
    </div>
    <div v-else>
      <div v-if="hasError" class="max-w-lg mx-auto text-center">
        <h5>{{ errorStateMessage }}</h5>
        <p
          v-if="errorStateDescription"
          v-dompurify-html="errorStateDescription"
        />
      </div>
      <LoadingState v-else-if="showLoader" :message="emptyStateMessage" />
      <form
        v-else
        class="flex flex-col flex-wrap mx-0"
        @submit.prevent="createChannel()"
      >
        <div class="w-full">
          <PageHeader
            :header-title="$t('INBOX_MGMT.ADD.DETAILS.TITLE')"
            :header-content="
              replaceInstallationName($t('INBOX_MGMT.ADD.DETAILS.DESC'))
            "
          />
        </div>
        <div class="w-3/5">
          <div class="w-full">
            <div class="input-wrap" :class="{ error: v$.selectedPage.$error }">
              {{ $t('INBOX_MGMT.ADD.FB.CHOOSE_PAGE') }}
              <multiselect
                v-model="selectedPage"
                close-on-select
                allow-empty
                :options="getSelectablePages"
                track-by="id"
                label="name"
                :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
                :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
                :placeholder="$t('INBOX_MGMT.ADD.FB.PICK_A_VALUE')"
                selected-label
                @select="setPageName"
              />
              <span v-if="v$.selectedPage.$error" class="message">
                {{ $t('INBOX_MGMT.ADD.FB.CHOOSE_PLACEHOLDER') }}
              </span>
            </div>
          </div>
          <div class="w-full">
            <label :class="{ error: v$.pageName.$error }">
              {{ $t('INBOX_MGMT.ADD.FB.INBOX_NAME') }}
              <input
                v-model="pageName"
                type="text"
                :placeholder="$t('INBOX_MGMT.ADD.FB.PICK_NAME')"
                @input="v$.pageName.$touch"
              />
              <span v-if="v$.pageName.$error" class="message">
                {{ $t('INBOX_MGMT.ADD.FB.ADD_NAME') }}
              </span>
            </label>
          </div>
          <div class="w-full text-right space-y-3">
            <div class="pt-4 border-t border-n-weak text-sm text-left">
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
              class="text-xs text-n-amber-11 bg-n-amber-2 border border-n-amber-7 rounded-md px-3 py-2 text-left"
            >
              {{ noteMessage }}
            </p>
            <NextButton
              type="submit"
              solid
              blue
              :label="primaryButtonLabel"
              :is-loading="isCreating || isPurchasingExtraChannel"
              :disabled="
                isCreating ||
                isPurchasingExtraChannel ||
                isChannelInfoLoading ||
                v$.$error
              "
            />
          </div>
        </div>
      </form>
    </div>
  </div>
</template>
