<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Avatar from 'next/avatar/Avatar.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  useMapGetter,
  useStoreGetters,
  useStore,
} from 'dashboard/composables/store';
import ChannelName from './components/ChannelName.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useInboxLimits } from './composables/useInboxLimits';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const showDeletePopup = ref(false);
const selectedInbox = ref({});
const isPreviewingRemoval = ref(false);
const removalPreview = ref(null);
const removalError = ref(null);

const {
  isLoading: limitsLoading,
  hasLoadedData,
  includedLimit,
  includedUsage,
  extraInboxesPurchased,
  extraInboxesUsed,
  fetchLimits,
  fetchAddOns,
} = useInboxLimits(store);

const inboxes = useMapGetter('inboxes/getInboxes');

const inboxesList = computed(() => {
  return inboxes.value?.slice().sort((a, b) => a.name.localeCompare(b.name));
});

const uiFlags = computed(() => getters['inboxes/getUIFlags'].value);

const deleteConfirmText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.YES')} ${selectedInbox.value.name}`
);

const deleteRejectText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.NO')} ${selectedInbox.value.name}`
);

const confirmDeleteMessage = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.MESSAGE')} ${selectedInbox.value.name}?`
);

const confirmPlaceHolderText = computed(
  () =>
    `${t('INBOX_MGMT.DELETE.CONFIRM.PLACE_HOLDER', {
      inboxName: selectedInbox.value.name,
    })}`
);

const fetchRemovalPreview = async () => {
  try {
    isPreviewingRemoval.value = true;
    removalError.value = null;

    const response = await store.dispatch('accounts/previewAddOnRemoval', {
      add_on_type: 'inbox',
      action: 'remove',
    });

    if (response?.data) {
      removalPreview.value = {
        estimated_credit: response.data.estimated_credit || null,
        details: response.data.details || null,
      };
    }
  } catch (error) {
    removalError.value = error?.message || 'Preview failed';
  } finally {
    isPreviewingRemoval.value = false;
  }
};

const confirmationDetails = computed(() => {
  const details = [];

  if (extraInboxesUsed.value > 0 && removalPreview.value?.estimated_credit) {
    details.push(
      t('INBOX_MGMT.DELETE.EXTRA_CONFIRM', {
        credit: removalPreview.value.estimated_credit,
      })
    );
  } else if (extraInboxesUsed.value > 0 && removalError.value) {
    details.push(t('INBOX_MGMT.DELETE.EXTRA_CONFIRM_FALLBACK'));
  }

  return details;
});

const removeExtraInboxSeat = async () => {
  try {
    await store.dispatch('accounts/purchaseAddOn', {
      add_on_type: 'inbox',
      action: 'remove',
    });
    return true;
  } catch (error) {
    useAlert(t('INBOX_MGMT.DELETE.API.EXTRA_REMOVE_ERROR'));
    return false;
  }
};

const deleteInbox = async ({ id }) => {
  // Check if we need to remove from Stripe based on preview result
  // Preview is always fetched when opening delete modal - if it succeeded, there's a subscription item
  const hadExtraSeat = !!removalPreview.value?.estimated_credit;

  try {
    // Delete the inbox first (frees the seat)
    await store.dispatch('inboxes/delete', id);

    // Then remove the extra seat from Stripe
    // If this fails, the inbox is already deleted (safe: user has an unused extra seat)
    if (hadExtraSeat) {
      await removeExtraInboxSeat();
      await Promise.all([fetchLimits(true), fetchAddOns(true)]);
    }

    useAlert(t('INBOX_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.DELETE.API.ERROR_MESSAGE'));
  } finally {
    // Reset preview state
    removalPreview.value = null;
    removalError.value = null;
  }
};
const closeDelete = () => {
  showDeletePopup.value = false;
  selectedInbox.value = {};
};

const confirmDeletion = async () => {
  await deleteInbox(selectedInbox.value);
  closeDelete();
};

const openDelete = async inbox => {
  selectedInbox.value = inbox;
  removalPreview.value = null;
  removalError.value = null;

  // Always try to fetch preview to check if there's a Stripe subscription item to remove
  // This works even when limits haven't loaded yet
  // The preview API will check Stripe directly and return success if there's a subscription item
  await fetchRemovalPreview();

  // Show confirmation modal
  showDeletePopup.value = true;
};

const inboxUsageLoading = computed(() => {
  return !hasLoadedData.value && limitsLoading.value;
});

const includedUsageDisplay = computed(
  () => `${includedUsage.value}/${includedLimit.value}`
);

const extraInboxesDisplay = computed(
  () => `+${extraInboxesPurchased.value || 0}`
);
</script>

<template>
  <SettingsLayout
    :no-records-found="!inboxesList.length"
    :no-records-message="$t('INBOX_MGMT.LIST.404')"
    :is-loading="uiFlags.isFetching"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INBOX_MGMT.HEADER')"
        :description="$t('INBOX_MGMT.DESCRIPTION')"
        :link-text="$t('INBOX_MGMT.LEARN_MORE')"
        feature-name="inboxes"
      >
        <template #actions>
          <router-link v-if="isAdmin" :to="{ name: 'settings_inbox_new' }">
            <Button
              icon="i-lucide-circle-plus"
              :label="$t('SETTINGS.INBOXES.NEW_INBOX')"
            />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #preBody>
      <section class="mb-6">
        <div class="rounded-lg border border-n-weak bg-n-solid-2 p-4 shadow-sm">
          <div class="mb-3">
            <h3 class="text-base font-semibold text-n-slate-12 mb-1">
              {{ $t('BILLING_SETTINGS.LIMITS.INBOXES') }}
            </h3>
            <p class="text-xs text-n-slate-11">
              {{ $t('BILLING_SETTINGS.LIMITS.TRACK_CHANNELS') }}
            </p>
          </div>
          <p v-if="inboxUsageLoading" class="text-sm text-n-slate-11">
            {{ $t('AGENT_MGMT.ADD.USAGE_LOADING') }}
          </p>
          <div
            v-else
            class="grid grid-cols-1 gap-3 sm:grid-cols-2"
            data-testid="channels-usage-summary"
          >
            <div class="bg-n-solid-1 rounded-md border border-n-weak p-3">
              <p class="text-xs text-n-slate-11 mb-1">
                {{ $t('BILLING_SETTINGS.LIMITS.INCLUDED_INBOXES_USAGE') }}
              </p>
              <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
                {{ includedUsageDisplay }}
              </p>
            </div>
            <div class="bg-n-solid-1 rounded-md border border-n-weak p-3">
              <p class="text-xs text-n-slate-11 mb-1">
                {{ $t('BILLING_SETTINGS.LIMITS.EXTRA_INBOXES') }}
              </p>
              <p class="text-lg font-semibold text-n-slate-12 tabular-nums">
                {{ extraInboxesDisplay }}
              </p>
            </div>
          </div>
        </div>
      </section>
    </template>
    <template #body>
      <table class="min-w-full overflow-x-auto">
        <tbody class="divide-y divide-n-weak flex-1 text-n-slate-12">
          <tr v-for="inbox in inboxesList" :key="inbox.id">
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <div class="flex items-center flex-row gap-4">
                <div
                  v-if="inbox.avatar_url"
                  class="bg-n-alpha-3 rounded-full size-12 p-2 ring ring-n-solid-1 border border-n-strong shadow-sm"
                >
                  <Avatar
                    :src="inbox.avatar_url"
                    :name="inbox.name"
                    :size="30"
                    rounded-full
                  />
                </div>
                <div
                  v-else
                  class="size-12 flex justify-center items-center bg-n-alpha-3 rounded-full p-2 ring ring-n-solid-1 border border-n-strong shadow-sm"
                >
                  <ChannelIcon class="size-5 text-n-slate-10" :inbox="inbox" />
                </div>
                <div>
                  <span class="block font-medium capitalize">
                    {{ inbox.name }}
                  </span>
                  <ChannelName
                    :channel-type="inbox.channel_type"
                    :medium="inbox.medium"
                  />
                </div>
              </div>
            </td>

            <td class="py-4">
              <div class="flex gap-1 justify-end">
                <router-link
                  :to="{
                    name: 'settings_inbox_show',
                    params: { inboxId: inbox.id },
                  }"
                >
                  <Button
                    v-if="isAdmin"
                    v-tooltip.top="$t('INBOX_MGMT.SETTINGS')"
                    icon="i-lucide-settings"
                    slate
                    xs
                    faded
                  />
                </router-link>
                <Button
                  v-if="isAdmin"
                  v-tooltip.top="$t('INBOX_MGMT.DELETE.BUTTON_TEXT')"
                  icon="i-lucide-trash-2"
                  xs
                  ruby
                  faded
                  @click="openDelete(inbox)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="$t('INBOX_MGMT.DELETE.CONFIRM.TITLE')"
      :message="confirmDeleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
      :confirm-value="selectedInbox.name"
      :confirm-place-holder-text="confirmPlaceHolderText"
      :details="confirmationDetails"
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </SettingsLayout>
</template>
