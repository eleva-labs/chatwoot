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

const step = ref('prompt'); // prompt | qr | success
const isRequestingAuthorization = ref(false);
const qrImageB64 = ref('');
const qrPollTimer = ref(null);
const qrRetryCount = ref(0);
const qrMaxRetries = ref(20);

const connectionStatus = computed(() => {
  const cfg = props.inbox.provider_config || {};
  return cfg.connection_status || 'disconnected';
});

const clearQrTimer = () => {
  if (qrPollTimer.value) {
    clearTimeout(qrPollTimer.value);
    qrPollTimer.value = null;
  }
};

const fetchQrAndStartPolling = async () => {
  if (isRequestingAuthorization.value) return;
  isRequestingAuthorization.value = true;

  try {
    const response = await store.dispatch(
      'inboxes/getWhapiQrCode',
      props.inbox.id
    );

    if (response.authenticated) {
      clearQrTimer();
      step.value = 'success';
      useAlert(t('INBOX.REAUTHORIZE.SUCCESS'));
      // Refresh inbox data
      await store.dispatch('inboxes/get', { inboxId: props.inbox.id });
      return;
    }

    const { image_base64: imageBase64, poll_in: pollIn } = response;

    if (imageBase64) {
      qrImageB64.value = `data:image/png;base64,${imageBase64}`;
    }

    clearQrTimer();
    qrRetryCount.value += 1;
    if (qrRetryCount.value > qrMaxRetries.value) {
      useAlert(t('INBOX_MGMT.ADD.WHAPI.QR_EXPIRED'));
      step.value = 'prompt';
      return;
    }
    qrPollTimer.value = setTimeout(fetchQrAndStartPolling, (pollIn || 15) * 1000);
  } catch (error) {
    useAlert(error?.message || t('INBOX.REAUTHORIZE.ERROR'));
  } finally {
    isRequestingAuthorization.value = false;
  }
};

const requestAuthorization = () => {
  step.value = 'qr';
  qrRetryCount.value = 0;
  fetchQrAndStartPolling();
};

// Watch for connection status changes via ActionCable
watch(connectionStatus, (newVal) => {
  if (step.value === 'qr' && newVal === 'connected') {
    clearQrTimer();
    step.value = 'success';
    useAlert(t('INBOX.REAUTHORIZE.SUCCESS'));
  }
});

onBeforeUnmount(() => {
  clearQrTimer();
});
</script>

<template>
  <div>
    <InboxReconnectionRequired
      v-if="step === 'prompt'"
      class="mx-8 mt-5"
      :is-loading="isRequestingAuthorization"
      @reauthorize="requestAuthorization"
    />

    <div
      v-else-if="step === 'qr'"
      class="flex flex-col items-center justify-center mx-8 mt-5"
    >
      <p class="mb-4 text-sm text-slate-600">
        {{ $t('INBOX_MGMT.ADD.WHAPI.QR_HELP_TEXT') }}
      </p>

      <div v-if="isRequestingAuthorization && !qrImageB64" class="flex items-center justify-center h-48 w-48">
        <Spinner :size="64" class="text-n-brand" />
      </div>

      <img
        v-else-if="qrImageB64"
        :src="qrImageB64"
        alt="WhatsApp QR Code"
        class="h-48 w-48 border border-gray-300 rounded"
      />

      <NextButton
        class="mt-4"
        outline
        :label="$t('INBOX.REAUTHORIZE.CANCEL')"
        @click="step = 'prompt'; clearQrTimer()"
      />
    </div>

    <div
      v-else-if="step === 'success'"
      class="flex flex-col items-center justify-center mx-8 mt-5"
    >
      <p class="text-green-600 font-medium">
        {{ $t('INBOX.REAUTHORIZE.SUCCESS') }}
      </p>
    </div>
  </div>
</template>

