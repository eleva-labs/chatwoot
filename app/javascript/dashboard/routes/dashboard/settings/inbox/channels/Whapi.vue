<script setup>
import {
  ref,
  computed,
  watch,
  onMounted,
  onBeforeUnmount,
  nextTick,
} from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { required, minLength } from '@vuelidate/validators';
import router from '../../../../index';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { DotLottieVue } from '@lottiefiles/dotlottie-vue';
import { useI18n } from 'vue-i18n';
import { useChannelPurchaseManager } from '../composables/useChannelPurchaseManager';

const props = defineProps({
  disabledAutoRoute: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['stepChanged']);

const store = useStore();
const { t } = useI18n();

// State (replaces data())
const step = ref('name'); // name | waiting | qr | success
const inboxName = ref('');
const createdInbox = ref(null);
const lottieTimer = ref(null);
const isInitiatingConnection = ref(false);
const showLottieAnimation = ref(true);
const isLottieComplete = ref(false);

// Store access (replaces mapGetters)
const uiFlags = useMapGetter('inboxes/getUIFlags');

const baseLabel = computed(() => t('INBOX_MGMT.ADD.WHAPI.CONTINUE_BUTTON'));

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

// Computed properties - updated via ActionCable
const currentInbox = computed(() => {
  if (!createdInbox.value) return {};
  return store.getters['inboxes/getInbox'](createdInbox.value.id) || {};
});

const whapiStatus = computed(() => {
  return currentInbox.value.provider_config?.whapi_status;
});

const connectionStatus = computed(() => {
  const cfg = currentInbox.value.provider_config || {};
  return cfg.connection_status || 'pending';
});

const qrFromWebsocket = computed(() => {
  if (!createdInbox.value) return null;
  return store.getters['inboxes/getWhapiQrCode'](createdInbox.value.id);
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

// Helper functions
const clearLottieTimer = () => {
  if (lottieTimer.value) {
    clearTimeout(lottieTimer.value);
    lottieTimer.value = null;
  }
};

const onLottieComplete = () => {
  // Hide the animation and show the success content
  showLottieAnimation.value = false;
  isLottieComplete.value = true;
};

const startLottieTimer = () => {
  // Fallback timer in case @complete event doesn't fire
  // Most Lottie animations are 2-3 seconds, so we'll wait 2.5 seconds
  lottieTimer.value = setTimeout(() => {
    if (showLottieAnimation.value && !isLottieComplete.value) {
      onLottieComplete();
    }
  }, 2500);
};

const clearQrCode = () => {
  if (createdInbox.value) {
    store.commit('inboxes/CLEAR_WHAPI_QR_CODE', createdInbox.value.id);
  }
};

// Validation setup
const rules = {
  inboxName: {
    required,
    minLength: minLength(2), // Minimum 2 characters for a valid name
  },
};

const v$ = useVuelidate(rules, { inboxName });

const isContinueButtonDisabled = computed(() => {
  // Button is disabled if validation fails or if creating/purchasing is in progress
  return (
    v$.value.inboxName.$invalid ||
    uiFlags.value.isCreating ||
    isPurchasingExtraChannel.value ||
    isChannelInfoLoading.value ||
    isTrialLimitReached.value
  );
});

// Watch for webhook configuration success
watch(
  () => currentInbox.value.provider_config?.webhook_configured,
  (isConfigured, wasConfigured) => {
    console.log('[Whapi.vue] Webhook configured watcher:', { isConfigured, wasConfigured, currentStep: step.value });
    if (isConfigured && !wasConfigured && step.value === 'waiting') {
      console.log('[Whapi.vue] Webhook configured, initiating connection');
      initiateConnection();
    }
  }
);

// Initiate connection via websocket after channel creation
const initiateConnection = async () => {
  console.log('[Whapi.vue] initiateConnection called', { createdInbox: createdInbox.value?.id, isInitiating: isInitiatingConnection.value });
  if (!createdInbox.value || isInitiatingConnection.value) {
    console.log('[Whapi.vue] initiateConnection skipped - no inbox or already initiating');
    return;
  }

  isInitiatingConnection.value = true;

  try {
    console.log('[Whapi.vue] Dispatching initiateWhapiReconnection for inbox:', createdInbox.value.id);
    const response = await store.dispatch(
      'inboxes/initiateWhapiReconnection',
      createdInbox.value.id
    );
    console.log('[Whapi.vue] initiateWhapiReconnection response:', response);

    // If the response contains the QR code directly, display it immediately
    if (response.image_base64) {
      console.log('[Whapi.vue] QR code received directly in response, storing it');
      const qrCodeData = {
        qrBase64: response.image_base64,
        expiresIn: response.expires_in,
      };
      store.commit('inboxes/SET_WHAPI_QR_CODE', {
        inboxId: createdInbox.value.id,
        ...qrCodeData,
      });
      step.value = 'qr';
      isInitiatingConnection.value = false;
      return;
    }

    // If already connected, show success immediately
    if (response.status === 'connected') {
      console.log('[Whapi.vue] Channel already connected');
      step.value = 'success';
      return;
    }

    console.log('[Whapi.vue] Waiting for QR via websocket');
    // Otherwise, wait for QR via websocket - no polling
  } catch (error) {
    console.error('[Whapi.vue] initiateConnection error:', error);
    useAlert(error?.message || t('INBOX_MGMT.ADD.WHAPI.CONNECTION_ERROR'));
  } finally {
    isInitiatingConnection.value = false;
  }
};

// Methods (converted to functions)
const createChannel = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;
  try {
    const created = await handleChannelCreation(() =>
      store.dispatch('inboxes/createWhapiChannel', {
        name: inboxName.value,
      })
    );
    createdInbox.value = created;
    // Don't initiate connection here, wait for webhook configured event
    // The watcher will trigger initiateConnection()
    step.value = 'waiting';
  } catch (error) {
    useAlert(
      error?.message || 'An error occurred while creating the channel'
    );
  }
};

const proceedOnSuccess = () => {
  clearQrCode();
  if (props.disabledAutoRoute) return;
  router.replace({
    name: 'settings_inboxes_invite_team',
    params: { page: 'new', inbox_id: createdInbox.value.id },
  });
};

// Watch for QR arrival via websocket
watch(qrFromWebsocket, qr => {
  if (qr?.qrBase64 && step.value === 'waiting') {
    step.value = 'qr';
  }
});

// Watch for connection success via websocket
watch(connectionStatus, newVal => {
  if ((step.value === 'waiting' || step.value === 'qr') && newVal === 'connected') {
    clearQrCode();
    step.value = 'success';
  }
});

watch(step, newVal => {
  emit('stepChanged', newVal);
  // Reset animation state when entering success step
  if (newVal === 'success') {
    showLottieAnimation.value = true;
    isLottieComplete.value = false;
    // Start the fallback timer
    nextTick(() => {
      startLottieTimer();
    });
  }
});

// Lifecycle hooks
onMounted(() => {
  emit('stepChanged', step.value);
});

onBeforeUnmount(() => {
  clearLottieTimer();
  clearQrCode();
});
</script>

<template>
  <div class="flex flex-col mx-0">
    <form
      v-if="step === 'name'"
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.inboxName.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
            @blur="v$.inboxName.$touch"
          />
          <span v-if="v$.inboxName.$error" class="message">
            {{
              v$.inboxName.$errors[0].$validator === 'required'
                ? $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR')
                : $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.MIN_LENGTH_ERROR')
            }}
          </span>
          <p
            v-if="!v$.inboxName.$error && inboxName.length > 0"
            class="help-text text-green-600"
          >
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.VALID') }}
          </p>
        </label>
      </div>

      <div class="w-full mt-4 space-y-3">
        <div class="pt-4 border-t border-n-weak text-sm">
          <p v-if="showUsageLoadingMessage" class="text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.USAGE_LOADING') }}
          </p>
          <p v-else-if="usageErrorMessage" class="text-n-ruby-11">
            {{ usageErrorMessage }}
          </p>
        </div>
        <p
          v-if="!showUsageLoadingMessage && !usageErrorMessage && noteMessage"
          class="text-xs text-n-amber-11 bg-n-amber-2 border border-n-amber-7 rounded-md px-3 py-2"
        >
          {{ noteMessage }}
        </p>
        <NextButton
          :is-loading="uiFlags.isCreating || isPurchasingExtraChannel"
          type="submit"
          solid
          blue
          :label="primaryButtonLabel"
          :disabled="isContinueButtonDisabled"
          :class="{ 'opacity-50 cursor-not-allowed': isContinueButtonDisabled }"
        />
      </div>
    </form>

    <!-- Waiting for QR via websocket -->
    <div
      v-else-if="step === 'waiting'"
      class="flex flex-col items-center justify-center"
    >
      <Spinner :size="64" class="text-n-brand" />
      <p class="mt-4 text-slate-600">
        {{ statusMessage }}
      </p>
    </div>

    <!-- QR Code display -->
    <div
      v-else-if="step === 'qr'"
      class="flex flex-col items-center justify-center"
    >
      <img
        v-if="qrImageSrc"
        :src="qrImageSrc"
        alt="WhatsApp QR Code"
        class="h-48 w-48 border border-gray-300 rounded"
      />

      <p v-if="qrImageSrc" class="mt-3 text-slate-600">
        {{ $t('INBOX_MGMT.ADD.WHAPI.QR_HELP_TEXT') }}
      </p>
    </div>

    <div
      v-else-if="step === 'success'"
      class="flex flex-col items-center justify-center"
    >
      <DotLottieVue
        v-if="showLottieAnimation"
        class="h-48 w-48"
        autoplay
        :loop="false"
        src="https://lottie.host/bc4d2cc8-bf76-47a0-a9f9-63abebc62420/gj5OjtX7ZL.lottie"
        @complete="onLottieComplete"
        @finished="onLottieComplete"
        @end="onLottieComplete"
      />

      <p
        v-if="isLottieComplete"
        class="mt-3 text-slate-600 text-center font-medium"
      >
        {{ $t('INBOX_MGMT.ADD.WHAPI.SUCCESS_MESSAGE') }}
      </p>
      <div v-if="isLottieComplete" class="w-full mt-4">
        <NextButton
          solid
          green
          :label="$t('INBOX_MGMT.ADD.WHAPI.CONTINUE_BUTTON')"
          @click="proceedOnSuccess"
        />
      </div>
    </div>
  </div>
</template>
