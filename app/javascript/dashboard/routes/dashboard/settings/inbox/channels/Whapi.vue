<script setup>
import {
  ref,
  computed,
  watch,
  onMounted,
  onBeforeUnmount,
  nextTick,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { required, minLength } from '@vuelidate/validators';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import router from '../../../../index';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { DotLottieVue } from '@lottiefiles/dotlottie-vue';
import { useChannelPurchaseManager } from '../composables/useChannelPurchaseManager';
const props = defineProps({
  disabledAutoRoute: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['stepChanged']);

const SetupMode = {
  MANUAL: 'manual',
  QR: 'qr',
};

const store = useStore();
const { t } = useI18n();

// State (replaces data())
const setupMode = ref(SetupMode.QR); // 'qr' | 'manual'
const step = ref('name'); // name | waiting | qr | success
const inboxName = ref('');
const phoneNumber = ref('');
const apiKey = ref('');
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

// Validation setup for QR mode
const qrRules = {
  inboxName: {
    required,
    minLength: minLength(2),
  },
};

// Validation setup for manual mode
const manualRules = {
  inboxName: {
    required,
    minLength: minLength(2),
  },
  phoneNumber: {
    required,
    isPhoneE164OrEmpty,
  },
  apiKey: {
    required,
  },
};

const qrV$ = useVuelidate(qrRules, { inboxName });
const manualV$ = useVuelidate(manualRules, { inboxName, phoneNumber, apiKey });

const isContinueButtonDisabled = computed(() => {
  if (setupMode.value === SetupMode.MANUAL) {
    return manualV$.value.$invalid || uiFlags.value.isCreating;
  }
  return (
    qrV$.value.inboxName.$invalid ||
    uiFlags.value.isCreating ||
    isPurchasingExtraChannel.value ||
    isChannelInfoLoading.value ||
    isTrialLimitReached.value
  );
});

// Initiate connection via websocket after channel creation
const initiateConnection = async () => {
  if (!createdInbox.value || isInitiatingConnection.value) {
    return;
  }

  isInitiatingConnection.value = true;

  try {
    const response = await store.dispatch(
      'inboxes/initiateWhapiReconnection',
      createdInbox.value.id
    );

    // If the response contains the QR code directly, display it immediately
    if (response.image_base64) {
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
      step.value = 'success';
    }

    // Otherwise, wait for QR via websocket - no polling
  } catch (error) {
    useAlert(error?.message || t('INBOX_MGMT.ADD.WHAPI.CONNECTION_ERROR'));
  } finally {
    isInitiatingConnection.value = false;
  }
};

// Watch for webhook configuration success
watch(
  () => currentInbox.value.provider_config?.webhook_configured,
  (isConfigured, wasConfigured) => {
    if (isConfigured && !wasConfigured && step.value === 'waiting') {
      initiateConnection();
    }
  }
);

// Methods for QR code flow
const createQrChannel = async () => {
  qrV$.value.$touch();
  if (qrV$.value.$invalid) return;
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
    useAlert(error?.message || 'An error occurred while creating the channel');
  }
};

// Methods for manual API key flow
const createManualChannel = async () => {
  manualV$.value.$touch();
  if (manualV$.value.$invalid) return;
  try {
    const created = await handleChannelCreation(() =>
      store.dispatch('inboxes/createChannel', {
        name: inboxName.value?.trim(),
        channel: {
          type: 'whatsapp',
          phone_number: phoneNumber.value,
          provider: 'whapi',
          provider_config: {
            api_key: apiKey.value,
          },
        },
      })
    );
    createdInbox.value = created;
    // For manual mode, go directly to invite team (no QR step needed)
    if (props.disabledAutoRoute) return;
    router.replace({
      name: 'settings_inboxes_invite_team',
      params: { page: 'new', inbox_id: created.id },
    });
  } catch (error) {
    useAlert(error.message || t('INBOX_MGMT.ADD.WHAPI.CHANNEL_CREATE_ERROR'));
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
  if (
    (step.value === 'waiting' || step.value === 'qr') &&
    newVal === 'connected'
  ) {
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
    <!-- Setup Mode Selector (only show on name step) -->
    <div v-if="step === 'name'" class="mb-6">
      <p class="text-sm text-n-slate-11 mb-3">
        {{ $t('INBOX_MGMT.ADD.WHAPI.SETUP_MODE.TITLE') }}
      </p>

      <!-- Segmented Toggle Container -->
      <div
        class="relative flex w-full items-center p-1 rounded-lg border border-n-weak bg-n-alpha-1"
      >
        <!-- Sliding background indicator -->
        <div
          class="absolute top-1 bottom-1 w-[calc(50%-6px)] rounded-md bg-n-brand transition-all duration-300 ease-in-out"
          :class="
            setupMode === SetupMode.QR ? 'left-1' : 'left-[calc(50%+2px)]'
          "
        />
        <button
          type="button"
          class="relative z-10 flex-1 px-6 py-3 text-left rounded-md transition-colors duration-300"
          :class="
            setupMode === SetupMode.QR
              ? 'text-white'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="setupMode = SetupMode.QR"
        >
          <span class="block text-sm font-medium">
            {{ $t('INBOX_MGMT.ADD.WHAPI.SETUP_MODE.QR_CODE') }}
          </span>
          <span
            class="block text-xs mt-1 transition-colors duration-300"
            :class="
              setupMode === SetupMode.QR ? 'text-white/80' : 'text-n-slate-10'
            "
          >
            {{ $t('INBOX_MGMT.ADD.WHAPI.SETUP_MODE.QR_CODE_DESC') }}
          </span>
        </button>
        <button
          type="button"
          class="relative z-10 flex-1 px-6 py-3 text-left rounded-md transition-colors duration-300"
          :class="
            setupMode === SetupMode.MANUAL
              ? 'text-white'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="setupMode = SetupMode.MANUAL"
        >
          <span class="block text-sm font-medium">
            {{ $t('INBOX_MGMT.ADD.WHAPI.SETUP_MODE.MANUAL') }}
          </span>
          <span
            class="block text-xs mt-1 transition-colors duration-300"
            :class="
              setupMode === SetupMode.MANUAL
                ? 'text-white/80'
                : 'text-n-slate-10'
            "
          >
            {{ $t('INBOX_MGMT.ADD.WHAPI.SETUP_MODE.MANUAL_DESC') }}
          </span>
        </button>
      </div>
    </div>

    <!-- QR Code Flow Form -->
    <form
      v-if="step === 'name' && setupMode === SetupMode.QR"
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createQrChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: qrV$.inboxName.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
            @blur="qrV$.inboxName.$touch"
          />
          <span v-if="qrV$.inboxName.$error" class="message">
            {{
              qrV$.inboxName.$errors[0].$validator === 'required'
                ? $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR')
                : $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.MIN_LENGTH_ERROR')
            }}
          </span>
          <p
            v-if="!qrV$.inboxName.$error && inboxName.length > 0"
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

    <!-- Manual API Key Flow Form -->
    <form
      v-if="step === 'name' && setupMode === SetupMode.MANUAL"
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createManualChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: manualV$.inboxName.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
            @blur="manualV$.inboxName.$touch"
          />
          <span v-if="manualV$.inboxName.$error" class="message">
            {{
              manualV$.inboxName.$errors[0].$validator === 'required'
                ? $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR')
                : $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.MIN_LENGTH_ERROR')
            }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: manualV$.phoneNumber.$error }">
          {{ $t('INBOX_MGMT.ADD.WHAPI.PHONE_NUMBER.LABEL') }}
          <input
            v-model="phoneNumber"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.WHAPI.PHONE_NUMBER.PLACEHOLDER')"
            @blur="manualV$.phoneNumber.$touch"
          />
          <span v-if="manualV$.phoneNumber.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.WHAPI.PHONE_NUMBER.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: manualV$.apiKey.$error }">
          <span>{{ $t('INBOX_MGMT.ADD.WHAPI.API_KEY.LABEL') }}</span>
          <p class="text-sm text-slate-11 mb-1">
            {{ $t('INBOX_MGMT.ADD.WHAPI.API_KEY.SUBTITLE') }}
          </p>
          <input
            v-model="apiKey"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.WHAPI.API_KEY.PLACEHOLDER')"
            @blur="manualV$.apiKey.$touch"
          />
          <span v-if="manualV$.apiKey.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.WHAPI.API_KEY.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.WHAPI.MANUAL_SUBMIT_BUTTON')"
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
      v-else-if="step === SetupMode.QR"
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
