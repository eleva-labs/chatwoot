<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
// import { useMapGetter } from 'dashboard/composables/store'; // Commented out - used by API channel

import { useAccount } from 'dashboard/composables/useAccount';

import ChannelItem from 'dashboard/components/widgets/ChannelItem.vue';

const { t } = useI18n();
const router = useRouter();
const { accountId, currentAccount } = useAccount();

// const globalConfig = useMapGetter('globalConfig/get'); // Commented out - used by API channel

const enabledFeatures = ref({});

const channelList = computed(() => {
  // const { apiChannelName } = globalConfig.value; // Commented out - used by API channel
  return [
    {
      key: 'whatsapp',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.DESCRIPTION'),
      icon: 'i-woot-whatsapp',
    },
    {
      key: 'instagram',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.DESCRIPTION'),
      icon: 'i-woot-instagram',
    },
    {
      key: 'facebook',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.DESCRIPTION'),
      icon: 'i-woot-messenger',
    },
    {
      key: 'telegram',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.DESCRIPTION'),
      icon: 'i-woot-telegram',
    },
    // Commented out - to be enabled later
    // {
    //   key: 'email',
    //   title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.TITLE'),
    //   description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.DESCRIPTION'),
    //   icon: 'i-woot-mail',
    // },
    // {
    //   key: 'sms',
    //   title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.SMS.TITLE'),
    //   description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.SMS.DESCRIPTION'),
    //   icon: 'i-woot-sms',
    // },
    // {
    //   key: 'website',
    //   title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.TITLE'),
    //   description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.DESCRIPTION'),
    //   icon: 'i-woot-website',
    // },
    // {
    //   key: 'api',
    //   title: apiChannelName || t('INBOX_MGMT.ADD.AUTH.CHANNEL.API.TITLE'),
    //   description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.API.DESCRIPTION'),
    //   icon: 'i-woot-api',
    // },
    // {
    //   key: 'line',
    //   title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.LINE.TITLE'),
    //   description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.LINE.DESCRIPTION'),
    //   icon: 'i-woot-line',
    // },
    // {
    //   key: 'voice',
    //   title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.VOICE.TITLE'),
    //   description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.VOICE.DESCRIPTION'),
    //   icon: 'i-ri-phone-fill',
    // },
  ];
});

const initializeEnabledFeatures = async () => {
  enabledFeatures.value = currentAccount.value.features;
};

const initChannelAuth = channel => {
  const params = {
    sub_page: channel,
    accountId: accountId.value,
  };
  router.push({ name: 'settings_inboxes_page_channel', params });
};

onMounted(() => {
  initializeEnabledFeatures();
});
</script>

<template>
  <div class="w-full p-8 overflow-auto">
    <div
      class="grid max-w-3xl grid-cols-1 xs:grid-cols-2 mx-0 gap-6 sm:grid-cols-3"
    >
      <ChannelItem
        v-for="channel in channelList"
        :key="channel.key"
        :channel="channel"
        :enabled-features="enabledFeatures"
        @channel-item-click="initChannelAuth"
      />
    </div>
  </div>
</template>
