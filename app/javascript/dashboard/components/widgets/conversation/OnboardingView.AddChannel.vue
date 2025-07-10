<script setup>
import { defineProps, ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ChannelList from '../../../routes/dashboard/settings/inbox/ChannelList.vue';
import AddAgents from '../../../routes/dashboard/settings/inbox/AddAgents.vue';
import Whatsapp from '../../../routes/dashboard/settings/inbox/channels/Whatsapp.vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const store = useStore();

const props = defineProps({
    stepNumber:{
      type: Number,
      required: true
    },
    currentStep: {
        type: Number,
        required: true
    },
})
const channelSelectedFactory = ref({
  "whatsapp": {component: Whatsapp, props: {disabled_auto_route: true}},
})

const channelSelected = ref(null)
const inboxes = computed(() => store.getters['inboxes/getInboxes'])
const channelAlreadyCreated = computed(() => {
  return inboxes.value.length > 0
})

const handleAgentsAdded = () => {
  useAlert( t('ONBOARDING.ADD_CHANNEL.CHANNEL_AGENTS_UPDATED'))
}

</script>

<template>
   <div v-if="currentStep === stepNumber">
          <ChannelList v-if="!channelSelected && !channelAlreadyCreated" :disabled_auto_route="true" @channelItemClick="channelSelected = $event" />
          <div v-else>
            <component v-if="!channelAlreadyCreated" :is="channelSelectedFactory[channelSelected].component" v-bind="channelSelectedFactory[channelSelected].props"/> 
            <div v-else>
              <h2 class="text-lg font-semibold">Adding agents to {{ inboxes[0].channel_type.split("::")[1] }}</h2>
              <AddAgents :inboxId="inboxes[inboxes.length-1].id" :disabled_auto_route="true" @agents_added="handleAgentsAdded" />
            </div>
          </div>
    </div>

</template>