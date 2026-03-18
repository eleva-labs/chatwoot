<script>
import { computed, watch } from 'vue';
import { mapGetters } from 'vuex';
import { useStore } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import { useRoute, useRouter } from 'vue-router';
import EmptyStateMessage from './EmptyStateMessage.vue';

export default {
  components: {
    EmptyStateMessage,
  },
  props: {
    isOnExpandedLayout: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const { isAdmin } = useAdmin();
    const { accountScopedUrl } = useAccount();
    const route = useRoute();
    const router = useRouter();
    const store = useStore();

    const isOnboardingCompleted = computed(() =>
      store.getters['accounts/isOnboardingCompleted']()
    );

    // Get inbox loading state to prevent race condition
    const inboxesUIFlags = computed(() => store.getters['inboxes/getUIFlags']);

    const shouldRedirectToOnboarding = computed(
      () =>
        !isOnboardingCompleted.value &&
        isAdmin.value &&
        !inboxesUIFlags.value.isFetching // Guard: don't redirect while loading
    );

    watch(
      shouldRedirectToOnboarding,
      shouldRedirect => {
        if (shouldRedirect && route.name !== 'settings_inbox_new') {
          router.push({
            name: 'settings_inbox_new',
            query: { onboarding: 'true' },
          });
        }
      },
      { immediate: true }
    );

    return {
      isAdmin,
      accountScopedUrl,
      isOnboardingCompleted,
      shouldRedirectToOnboarding,
      inboxesUIFlags,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      allConversations: 'getAllConversations',
      inboxesList: 'inboxes/getInboxes',
      uiFlags: 'inboxes/getUIFlags',
      loadingChatList: 'getChatListLoadingStatus',
    }),
    loadingIndicatorMessage() {
      if (this.uiFlags.isFetching) {
        return this.$t('CONVERSATION.LOADING_INBOXES');
      }
      return this.$t('CONVERSATION.LOADING_CONVERSATIONS');
    },
    conversationMissingMessage() {
      if (!this.isOnExpandedLayout) {
        return this.$t('CONVERSATION.SELECT_A_CONVERSATION');
      }
      return this.$t('CONVERSATION.404');
    },
    newInboxURL() {
      return this.accountScopedUrl('settings/inboxes/new');
    },
    emptyClassName() {
      if (
        !this.inboxesList.length &&
        !this.uiFlags.isFetching &&
        !this.loadingChatList &&
        this.isAdmin
      ) {
        return 'h-full overflow-auto w-full';
      }
      return 'flex-1 min-w-0 px-0 flex flex-col items-center justify-center h-full w-full';
    },
  },
};
</script>

<template>
  <div :class="emptyClassName">
    <woot-loading-state
      v-if="uiFlags.isFetching || loadingChatList"
      :message="loadingIndicatorMessage"
    />
    <!-- Onboarding not completed -->
    <div
      v-if="!isOnboardingCompleted && !loadingChatList"
      class="clearfix mx-auto w-full flex justify-center items-center h-full"
    >
      <!-- Show loading while redirecting to Standard Inbox flow -->
      <woot-loading-state
        v-if="isAdmin && shouldRedirectToOnboarding"
        message="Starting your onboarding..."
      />
      <EmptyStateMessage
        v-else-if="!isAdmin"
        :message="$t('CONVERSATION.NO_INBOX_AGENT')"
      />
    </div>
    <!-- Show empty state images if not loading -->

    <div
      v-else-if="!uiFlags.isFetching"
      class="flex flex-col items-center justify-center h-full"
    >
      <!-- No conversations available -->
      <EmptyStateMessage
        v-if="!allConversations.length"
        :message="$t('CONVERSATION.NO_MESSAGE_1')"
      />
      <EmptyStateMessage
        v-else-if="allConversations.length && !currentChat.id"
        :message="conversationMissingMessage"
      />
    </div>
  </div>
</template>
