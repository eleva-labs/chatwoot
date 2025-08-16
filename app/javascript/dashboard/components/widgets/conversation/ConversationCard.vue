<script setup>
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { useVoiceCallStatus } from 'dashboard/composables/useVoiceCallStatus';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import Avatar from 'next/avatar/Avatar.vue';
import MessagePreview from './MessagePreview.vue';
import InboxName from '../InboxName.vue';
import ConversationContextMenu from './contextMenu/Index.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import CardLabels from './conversationCardComponents/CardLabels.vue';
import PriorityMark from './PriorityMark.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import AIEnableBanner from 'dashboard/components/ui/AIEnableBanner.vue';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  activeLabel: { type: String, default: '' },
  chat: { type: Object, default: () => ({}) },
  hideInboxName: { type: Boolean, default: false },
  hideThumbnail: { type: Boolean, default: false },
  teamId: { type: [String, Number], default: 0 },
  foldersId: { type: [String, Number], default: 0 },
  showAssignee: { type: Boolean, default: false },
  conversationType: { type: String, default: '' },
  selected: { type: Boolean, default: false },
  compact: { type: Boolean, default: false },
  enableContextMenu: { type: Boolean, default: false },
  allowedContextMenuOptions: { type: Array, default: () => [] },
});
      type: String,
      default: '',
    },
    chat: {
      type: Object,
      default: () => {},
    },
    hideInboxName: {
      type: Boolean,
      default: false,
    },
    hideThumbnail: {
      type: Boolean,
      default: false,
    },
    teamId: {
      type: [String, Number],
      default: 0,
    },
    foldersId: {
      type: [String, Number],
      default: 0,
    },
    showAssignee: {
      type: Boolean,
      default: false,
    },
    conversationType: {
      type: String,
      default: '',
    },
    selected: {
      type: Boolean,
      default: false,
    },
    enableContextMenu: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'contextMenuToggle',
    'assignAgent',
    'assignLabel',
    'assignTeam',
    'markAsUnread',
    'markAsRead',
    'assignPriority',
    'updateConversationStatus',
    'deleteConversation',
  ],
  data() {
    return {
      hovered: false,
      showContextMenu: false,
      contextMenu: {
        x: null,
        y: null,
      },
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      inboxesList: 'inboxes/getInboxes',
      activeInbox: 'getSelectedInbox',
      accountId: 'getCurrentAccountId',
    }),
    chatMetadata() {
      return this.chat.meta || {};
    },
>>>>>>> 757ed077da (CU-86aadc3c7 Implement AI enable toggling)

const emit = defineEmits([
  'contextMenuToggle',
  'assignAgent',
  'assignLabel',
  'assignTeam',
  'markAsUnread',
  'markAsRead',
  'assignPriority',
  'updateConversationStatus',
  'deleteConversation',
  'selectConversation',
  'deSelectConversation',
]);

const router = useRouter();
const store = useStore();

const hovered = ref(false);
const showContextMenu = ref(false);
const contextMenu = ref({
  x: null,
  y: null,
});

const currentChat = useMapGetter('getSelectedChat');
const inboxesList = useMapGetter('inboxes/getInboxes');
const activeInbox = useMapGetter('getSelectedInbox');
const accountId = useMapGetter('getCurrentAccountId');
      return this.chat.unread_count;
    },
>>>>>>> 757ed077da (CU-86aadc3c7 Implement AI enable toggling)

const chatMetadata = computed(() => props.chat.meta || {});

const assignee = computed(() => chatMetadata.value.assignee || {});

const senderId = computed(() => chatMetadata.value.sender?.id);

const currentContact = computed(() => {
  return senderId.value
    ? store.getters['contacts/getContact'](senderId.value)
    : {};
});

<<<<<<< HEAD
const isActiveChat = computed(() => {
  return currentChat.value.id === props.chat.id;
});
=======
    showInboxName() {
      return (
        !this.hideInboxName &&
        this.isInboxNameVisible &&
        this.inboxesList.length > 1
      );
    },
    inboxName() {
      const stateInbox = this.inbox;
      return stateInbox.name || '';
    },
    hasSlaPolicyId() {
      return this.chat?.sla_policy_id;
    },
  },
  mounted() {
    // Load all agent bots first, then fetch the specific inbox relationship
    this.$store.dispatch('agentBots/get').then(() => {
      this.$store.dispatch('agentBots/fetchAgentBotInbox', this.chat.inbox_id);
    });
  },
  methods: {
    onCardClick(e) {
      const { activeInbox, chat } = this;
      const path = frontendURL(
        conversationUrl({
          accountId: this.accountId,
          activeInbox,
          id: chat.id,
          label: this.activeLabel,
          teamId: this.teamId,
          foldersId: this.foldersId,
          conversationType: this.conversationType,
        })
      );
>>>>>>> ba7c372e75 (CU-86aadc3c7 Implement AI enable toggling)

const unreadCount = computed(() => props.chat.unread_count);

<<<<<<< HEAD
const hasUnread = computed(() => unreadCount.value > 0);

const isInboxNameVisible = computed(() => !activeInbox.value);

const lastMessageInChat = computed(() => getLastMessage(props.chat));

const callStatus = computed(
  () => props.chat.additional_attributes?.call_status
);
const callDirection = computed(
  () => props.chat.additional_attributes?.call_direction
);

const { labelKey: voiceLabelKey, listIconColor: voiceIconColor } =
  useVoiceCallStatus(callStatus, callDirection);

const inboxId = computed(() => props.chat.inbox_id);

const inbox = computed(() => {
  return inboxId.value ? store.getters['inboxes/getInbox'](inboxId.value) : {};
});

const showInboxName = computed(() => {
  return (
    !props.hideInboxName &&
    isInboxNameVisible.value &&
    inboxesList.value.length > 1
  );
});

const showMetaSection = computed(() => {
  return (
    showInboxName.value ||
    (props.showAssignee && assignee.value.name) ||
    props.chat.priority
  );
});

const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);

const showLabelsSection = computed(() => {
  return props.chat.labels?.length > 0 || hasSlaPolicyId.value;
});

const messagePreviewClass = computed(() => {
  return [
    hasUnread.value ? 'font-medium text-n-slate-12' : 'text-n-slate-11',
    !props.compact && hasUnread.value ? 'ltr:pr-4 rtl:pl-4' : '',
    props.compact && hasUnread.value ? 'ltr:pr-6 rtl:pl-6' : '',
  ];
});

const conversationPath = computed(() => {
  return frontendURL(
    conversationUrl({
      accountId: accountId.value,
      activeInbox: activeInbox.value,
      id: props.chat.id,
      label: props.activeLabel,
      teamId: props.teamId,
      conversationType: props.conversationType,
      foldersId: props.foldersId,
    })
  );
});

const onCardClick = e => {
  const path = conversationPath.value;
  if (!path) return;

  // Handle Ctrl/Cmd + Click for new tab
  if (e.metaKey || e.ctrlKey) {
    e.preventDefault();
    window.open(
      `${window.chatwootConfig.hostURL}${path}`,
      '_blank',
      'noopener,noreferrer'
    );
    return;
  }

  // Skip if already active
  if (isActiveChat.value) return;

  router.push({ path });
};

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const onSelectConversation = checked => {
  if (checked) {
    emit('selectConversation', props.chat.id, inbox.value.id);
  } else {
    emit('deSelectConversation', props.chat.id, inbox.value.id);
  }
};

const openContextMenu = e => {
  if (!props.enableContextMenu) return;
  e.preventDefault();
  emit('contextMenuToggle', true);
  contextMenu.value.x = e.pageX || e.clientX;
  contextMenu.value.y = e.pageY || e.clientY;
  showContextMenu.value = true;
};

const closeContextMenu = () => {
  emit('contextMenuToggle', false);
  showContextMenu.value = false;
  contextMenu.value.x = null;
  contextMenu.value.y = null;
};

const onUpdateConversation = (status, snoozedUntil) => {
  closeContextMenu();
  emit('updateConversationStatus', props.chat.id, status, snoozedUntil);
};

const onAssignAgent = agent => {
  emit('assignAgent', agent, [props.chat.id]);
  closeContextMenu();
};

const onAssignLabel = label => {
  emit('assignLabel', [label.title], [props.chat.id]);
  closeContextMenu();
};

const onAssignTeam = team => {
  emit('assignTeam', team, props.chat.id);
  closeContextMenu();
};

const markAsUnread = () => {
  emit('markAsUnread', props.chat.id);
  closeContextMenu();
};

const markAsRead = () => {
  emit('markAsRead', props.chat.id);
  closeContextMenu();
};

const assignPriority = priority => {
  emit('assignPriority', priority, props.chat.id);
  closeContextMenu();
};

const deleteConversation = () => {
  emit('deleteConversation', props.chat.id);
  closeContextMenu();
=======
      router.push({ path });
    },
    onThumbnailHover() {
      this.hovered = !this.hideThumbnail;
    },
    onThumbnailLeave() {
      this.hovered = false;
    },
    onSelectConversation(checked) {
      const action = checked ? 'selectConversation' : 'deSelectConversation';
      this.$emit(action, this.chat.id, this.inbox.id);
    },
    openContextMenu(e) {
      if (!this.enableContextMenu) return;
      e.preventDefault();
      this.$emit('contextMenuToggle', true);
      this.contextMenu.x = e.pageX || e.clientX;
      this.contextMenu.y = e.pageY || e.clientY;
      this.showContextMenu = true;
    },
    closeContextMenu() {
      this.$emit('contextMenuToggle', false);
      this.showContextMenu = false;
      this.contextMenu.x = null;
      this.contextMenu.y = null;
    },
    onUpdateConversation(status, snoozedUntil) {
      this.closeContextMenu();
      this.$emit(
        'updateConversationStatus',
        this.chat.id,
        status,
        snoozedUntil
      );
    },
    async onAssignAgent(agent) {
      this.$emit('assignAgent', agent, [this.chat.id]);
      this.closeContextMenu();
    },
    async onAssignLabel(label) {
      this.$emit('assignLabel', [label.title], [this.chat.id]);
      this.closeContextMenu();
    },
    async onAssignTeam(team) {
      this.$emit('assignTeam', team, this.chat.id);
      this.closeContextMenu();
    },
    async markAsUnread() {
      this.$emit('markAsUnread', this.chat.id);
      this.closeContextMenu();
    },
    async markAsRead() {
      this.$emit('markAsRead', this.chat.id);
      this.closeContextMenu();
    },
    notAiImplementedNotification() {
      useAlert(this.$t('AI_NOT_IMPLEMENTED_NOTIFICATION'));
    },
    async assignPriority(priority) {
      this.$emit('assignPriority', priority, this.chat.id);
      this.closeContextMenu();
    },
    async deleteConversation() {
      this.$emit('deleteConversation', this.chat.id);
      this.closeContextMenu();
    },
    async onToggleAi() {
      const contactId = this.chatMetadata?.sender?.id;
      if (!contactId) return;
      const next = !this.isAiEnabled;

      await this.$store.dispatch('contacts/toggleAi', {
        id: contactId,
        aiEnabled: next,
      });
    },
  },
>>>>>>> 757ed077da (CU-86aadc3c7 Implement AI enable toggling)
};
</script>

<template>
  <div
    class="relative flex items-start flex-grow-0 flex-shrink-0 w-auto max-w-full py-0 border-t-0 border-b-0 border-l-0 border-r-0 border-transparent border-solid cursor-pointer conversation hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3 group"
    :class="{
      'active animate-card-select bg-n-alpha-1 dark:bg-n-alpha-3 border-n-weak':
        isActiveChat,
      'bg-n-slate-2 dark:bg-n-slate-3': selected,
      'px-0': compact,
      'px-3': !compact,
    }"
    @click="onCardClick"
    @contextmenu="openContextMenu($event)"
  >
    <div
      class="relative"
      @mouseenter="onThumbnailHover"
      @mouseleave="onThumbnailLeave"
    >
      <Avatar
        v-if="!hideThumbnail"
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="32"
        :status="currentContact.availability_status"
        :class="!showInboxName ? 'mt-4' : 'mt-8'"
        hide-offline-status
        rounded-full
      >
        <template #overlay="{ size }">
          <label
            v-if="hovered || selected"
            class="flex items-center justify-center rounded-full cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px]"
            :style="{ width: `${size}px`, height: `${size}px` }"
            @click.stop
          >
            <input
              :value="selected"
              :checked="selected"
              class="!m-0 cursor-pointer"
              type="checkbox"
              @change="onSelectConversation($event.target.checked)"
            />
          </label>
        </template>
      </Avatar>
    </div>
    <div
      class="px-0 py-3 border-b group-hover:border-transparent flex-1 border-n-slate-3 min-w-0"
    >
      <div
        v-if="showMetaSection"
        class="flex items-center min-w-0 gap-1"
        :class="{
          'ltr:ml-2 rtl:mr-2': !compact,
          'mx-2': compact,
        }"
      >
        <InboxName v-if="showInboxName" :inbox="inbox" class="flex-1 min-w-0" />
        <div
          class="flex items-center gap-2 flex-shrink-0"
          :class="{
            'flex-1 justify-between': !showInboxName,
          }"
        >
          <span
            v-if="showAssignee && assignee.name"
            class="text-n-slate-11 text-xs font-medium leading-3 py-0.5 px-0 inline-flex items-center truncate"
          >
            <fluent-icon icon="person" size="12" class="text-n-slate-11" />
            {{ assignee.name }}
          </span>
          <PriorityMark :priority="chat.priority" class="flex-shrink-0" />
        </div>
      </div>
      <h4
        class="conversation--user text-sm my-0 mx-2 capitalize pt-0.5 text-ellipsis overflow-hidden whitespace-nowrap flex-1 min-w-0 ltr:pr-16 rtl:pl-16 text-n-slate-12"
        :class="hasUnread ? 'font-semibold' : 'font-medium'"
      >
        {{ currentContact.name }}
      </h4>
      <div
        v-if="callStatus"
        key="voice-status-row"
        class="my-0 mx-2 leading-6 h-6 flex-1 min-w-0 text-sm overflow-hidden text-ellipsis whitespace-nowrap"
        :class="messagePreviewClass"
      >
        <span
          class="inline-block -mt-0.5 align-middle text-[16px] i-ph-phone-incoming"
          :class="[voiceIconColor]"
        />
        <span class="mx-1">
          {{ $t(voiceLabelKey) }}
        </span>
      </div>
      <MessagePreview
        v-else-if="lastMessageInChat"
        key="message-preview"
        :message="lastMessageInChat"
        class="my-0 mx-2 leading-6 h-6 flex-1 min-w-0 text-sm"
        :class="messagePreviewClass"
      />
      <p
        v-else
        key="no-messages"
        class="text-n-slate-11 text-sm my-0 mx-2 leading-6 h-6 flex-1 min-w-0 overflow-hidden text-ellipsis whitespace-nowrap"
        :class="messagePreviewClass"
      >
        <fluent-icon
          size="16"
          class="-mt-0.5 align-middle inline-block text-n-slate-10"
          icon="info"
        />
        <span class="mx-0.5">
          {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
        </span>
      </p>
      <div
<<<<<<< HEAD
        class="absolute flex flex-col ltr:right-3 rtl:left-3"
        :class="showMetaSection ? 'top-8' : 'top-4'"
=======
        class="absolute flex flex-col justify-end ltr:right-4 rtl:left-4 top-4"
>>>>>>> 757ed077da (CU-86aadc3c7 Implement AI enable toggling)
      >
        <span class="ml-auto font-normal leading-4 text-xxs">
          <TimeAgo
            :last-activity-timestamp="chat.timestamp"
            :created-at-timestamp="chat.created_at"
          />
          <div
            :class="hasAiImplemented ? 'opacity-100' : 'opacity-40'"
            class="w-full flex justify-end items-end gap-2"
            @click="!hasAiImplemented && notAiImplementedNotification()"
          >
            <AIEnableBanner
              :ai-enable="isAiEnabled && hasAiImplemented"
              @toggle-ai="onToggleAi"
            />
          </div>
        </span>
        <span
<<<<<<< HEAD
          class="shadow-lg rounded-full text-xxs font-semibold h-4 leading-4 ltr:ml-auto rtl:mr-auto mt-1 min-w-[1rem] px-1 py-0 text-center text-white bg-n-teal-9"
          :class="hasUnread ? 'block' : 'hidden'"
=======
          class="unread hidden absolute -right-3 -bottom-4 shadow-lg rounded-full text-xxs font-semibold h-4 leading-4 ltr:ml-auto rtl:mr-auto mt-1 min-w-[1rem] px-1 py-0 text-center text-white bg-n-teal-9"
>>>>>>> 757ed077da (CU-86aadc3c7 Implement AI enable toggling)
        >
          {{ unreadCount > 9 ? '9+' : unreadCount }}
        </span>
      </div>
      <CardLabels
        v-if="showLabelsSection"
        :conversation-labels="chat.labels"
        class="mt-0.5 mx-2 mb-0"
      >
        <template v-if="hasSlaPolicyId" #before>
          <SLACardLabel :chat="chat" class="ltr:mr-1 rtl:ml-1" />
        </template>
      </CardLabels>
    </div>
    <ContextMenu
      v-if="showContextMenu"
      :x="contextMenu.x"
      :y="contextMenu.y"
      @close="closeContextMenu"
    >
      <ConversationContextMenu
        :status="chat.status"
        :inbox-id="inbox.id"
        :priority="chat.priority"
        :chat-id="chat.id"
        :has-unread-messages="hasUnread"
        :conversation-url="conversationPath"
        :allowed-options="allowedContextMenuOptions"
        @update-conversation="onUpdateConversation"
        @assign-agent="onAssignAgent"
        @assign-label="onAssignLabel"
        @assign-team="onAssignTeam"
        @mark-as-unread="markAsUnread"
        @mark-as-read="markAsRead"
        @assign-priority="assignPriority"
        @delete-conversation="deleteConversation"
        @close="closeContextMenu"
      />
    </ContextMenu>
  </div>
</template>
