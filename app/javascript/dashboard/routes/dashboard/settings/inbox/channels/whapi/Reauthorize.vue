<script setup>
import { ref, computed, watch, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'vuex';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();

const step = ref('prompt'); // prompt | waiting | qr | success
const isInitiating = ref(false);

// Computed from store - updated via ActionCable
const whapiStatus = computed(() => {
  return props.inbox.provider_config?.whapi_status;
});

const connectionStatus = computed(() => {
  return props.inbox.provider_config?.connection_status || 'disconnected';
});

const qrFromWebsocket = computed(() => {
  return store.getters['inboxes/getWhapiQrCode'](props.inbox.id);
});

const qrImageSrc = computed(() => {
  const qr = qrFromWebsocket.value;
  return qr?.qrBase64 ? `data:image/png;base64,${qr.qrBase64}` : null;
});

const statusMessage = computed(() => {
  switch (whapiStatus.value) {
    case 'INIT':
      return t('INBOX_MGMT.ADD.WHAPI.STATUS.INIT');
    case 'LAUNCH':
      return t('INBOX_MGMT.ADD.WHAPI.STATUS.LAUNCH');
    case 'QR':
      return t('INBOX_MGMT.ADD.WHAPI.STATUS.QR');
    case 'AUTH':
      return t('INBOX_MGMT.ADD.WHAPI.STATUS.AUTH');
    default:
      return t('INBOX_MGMT.ADD.WHAPI.STATUS.WAITING');
  }
});

// Watch for QR arrival via websocket
watch(qrFromWebsocket, qr => {
  if (qr?.qrBase64 && step.value === 'waiting') {
    step.value = 'qr';
  }
});

// Watch for connection success via websocket
watch(connectionStatus, status => {
  if (status === 'connected' && (step.value === 'waiting' || step.value === 'qr')) {
    step.value = 'success';
    store.commit('inboxes/CLEAR_WHAPI_QR_CODE', props.inbox.id);
    useAlert(t('INBOX.REAUTHORIZE.SUCCESS'));
  }
});

const initiateReconnection = async () => {
  isInitiating.value = true;
  step.value = 'waiting';

  try {
    const response = await store.dispatch(
      'inboxes/initiateWhapiReconnection',
      props.inbox.id
    );

    // If the response contains the QR code directly, display it immediately
    if (response.image_base64) {
      const qrCodeData = {
        qrBase64: response.image_base64,
        expiresIn: response.expires_in,
      };
      store.commit('inboxes/SET_WHAPI_QR_CODE', {
        inboxId: props.inbox.id,
        ...qrCodeData,
      });
      step.value = 'qr';
      isInitiating.value = false;
      return;
    }

    // If already connected, show success immediately
    if (response.status === 'connected') {
      step.value = 'success';
      useAlert(t('INBOX.REAUTHORIZE.SUCCESS'));
      return;
    }

    // Otherwise, wait for QR via websocket - no polling
  } catch (error) {
    useAlert(error?.message || t('INBOX.REAUTHORIZE.ERROR'));
    step.value = 'prompt';
  } finally {
    isInitiating.value = false;
  }
};

const cancel = () => {
  step.value = 'prompt';
  store.commit('inboxes/CLEAR_WHAPI_QR_CODE', props.inbox.id);
};

onBeforeUnmount(() => {
  store.commit('inboxes/CLEAR_WHAPI_QR_CODE', props.inbox.id);
});
</script>

<template>
  <div>
    <!-- Prompt step -->
    <InboxReconnectionRequired
      v-if="step === 'prompt'"
      class="mx-8 mt-5"
      :is-loading="isInitiating"
      @reauthorize="initiateReconnection"
    />

    <!-- Waiting for QR via websocket -->
    <div
      v-else-if="step === 'waiting'"
      class="flex flex-col items-center justify-center mx-8 mt-5"
    >
      <Spinner :size="64" class="text-n-brand" />
      <p class="mt-4 text-slate-600">
        {{ statusMessage }}
      </p>
      <NextButton
        class="mt-4"
        outline
        :label="$t('INBOX.REAUTHORIZE.CANCEL')"
        @click="cancel"
      />
    </div>

    <!-- QR Code display -->
    <div
      v-else-if="step === 'qr'"
      class="flex flex-col items-center justify-center mx-8 mt-5"
    >
      <p class="mb-4 text-sm text-slate-600">
        {{ $t('INBOX_MGMT.ADD.WHAPI.QR_HELP_TEXT') }}
      </p>

      <img
        v-if="qrImageSrc"
        :src="qrImageSrc"
        alt="WhatsApp QR Code"
        class="h-48 w-48 border border-gray-300 rounded"
      />

      <NextButton
        class="mt-4"
        outline
        :label="$t('INBOX.REAUTHORIZE.CANCEL')"
        @click="cancel"
      />
    </div>

  </div>
</template>
