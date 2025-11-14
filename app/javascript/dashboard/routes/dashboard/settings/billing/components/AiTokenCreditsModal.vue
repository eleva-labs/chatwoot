<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  packs: {
    type: Array,
    required: true,
  },
  isPurchasing: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'purchase']);

const { t } = useI18n();
const show = ref(false);
const selectedPackLookupKey = ref(null);

const showModal = () => {
  show.value = true;
  if (props.packs.length > 0) {
    selectedPackLookupKey.value = props.packs[0].lookup_key;
  }
};

const closeModal = () => {
  show.value = false;
  selectedPackLookupKey.value = null;
  emit('close');
};

const confirmPurchase = () => {
  if (selectedPackLookupKey.value) {
    emit('purchase', selectedPackLookupKey.value);
  }
};

const selectedPack = computed(() => {
  return props.packs.find(pack => pack.lookup_key === selectedPackLookupKey.value);
});

const packOptions = computed(() => {
  return props.packs.map(pack => ({
    value: pack.lookup_key,
    label: `${pack.display_name} - ${pack.formatted_price || t('BILLING_SETTINGS.LIMITS.AI_TOKENS.PRICE_NOT_AVAILABLE')}`,
    tokenCredits: pack.token_credits,
    price: pack.formatted_price,
  }));
});

defineExpose({
  showModal,
  closeModal,
});
</script>

<template>
  <Modal v-model:show="show" :on-close="closeModal">
    <div class="h-auto overflow-auto flex flex-col">
      <woot-modal-header
        :header-title="t('BILLING_SETTINGS.LIMITS.AI_TOKENS.MODAL_TITLE')"
        :header-content="t('BILLING_SETTINGS.LIMITS.AI_TOKENS.MODAL_DESCRIPTION')"
      />

      <div class="px-6 py-4">
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ t('BILLING_SETTINGS.LIMITS.AI_TOKENS.PACK_SIZE_LABEL') }}
        </label>
        <select
          v-model="selectedPackLookupKey"
          class="w-full pl-3 pr-10 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-blue-9"
          :disabled="isPurchasing"
        >
          <option
            v-for="option in packOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>

        <div
          v-if="selectedPack"
          class="mt-4 p-3 bg-n-solid-2 border border-n-weak rounded-md"
        >
          <p class="text-xs text-n-slate-11">
            {{ t('BILLING_SETTINGS.LIMITS.AI_TOKENS.YOU_WILL_RECEIVE') }}
          </p>
          <p class="text-lg font-semibold text-n-slate-12 mt-1 tabular-nums">
            {{ Number(selectedPack.token_credits || 0).toLocaleString() }}
            {{ t('BILLING_SETTINGS.LIMITS.AI_TOKENS.TOKEN_UNIT') }}
          </p>
          <p class="text-xs text-n-slate-11 mt-2">
            {{ t('BILLING_SETTINGS.LIMITS.AI_TOKENS.ONE_TIME_CHARGE') }}
            <span class="font-semibold text-n-slate-12">
              {{ selectedPack.formatted_price || t('BILLING_SETTINGS.LIMITS.AI_TOKENS.PRICE_NOT_AVAILABLE') }}
            </span>
          </p>
        </div>
      </div>

      <div class="flex flex-row justify-end gap-2 py-4 px-6 w-full border-t border-n-weak">
        <NextButton
          faded
          type="reset"
          :label="t('BILLING_SETTINGS.LIMITS.CANCEL_PURCHASE_BUTTON')"
          :disabled="isPurchasing"
          @click="closeModal"
        />
        <NextButton
          type="submit"
          :label="t('BILLING_SETTINGS.LIMITS.CONFIRM_PURCHASE_BUTTON')"
          :disabled="!selectedPackLookupKey || isPurchasing"
          :loading="isPurchasing"
          @click="confirmPurchase"
        />
      </div>
    </div>
  </Modal>
</template>

