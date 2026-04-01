<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { checkFileSizeLimit } from 'shared/helpers/FileHelper';
import { MAXIMUM_FILE_UPLOAD_SIZE } from 'shared/constants/messages';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import Auth from 'dashboard/api/auth';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineProps({
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'refresh']);

const IMAGE_CONTENT_TYPES = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/bmp',
  'image/webp',
];

const { t } = useI18n();
const store = useStore();
const accountId = ref(store.getters.getCurrentAccountId);

const fileUploadInput = ref(null);
const isLoading = ref(false);

const openFileBrowser = () => {
  fileUploadInput.value.click();
};

const closeModal = () => {
  isLoading.value = false;
  emit('close');
};

// Auto-detect source type from file content type
const detectSourceType = file => {
  return IMAGE_CONTENT_TYPES.includes(file.type) ? 'image' : 'file';
};

// Create knowledge base record via API
const createKnowledgeBase = async (name, sourceType, blobId, url) => {
  const authData = Auth.getAuthData();
  const headers = { 'Content-Type': 'application/json' };

  if (authData) {
    headers['access-token'] = authData['access-token'];
    headers['token-type'] = authData['token-type'];
    headers.client = authData.client;
    headers.expiry = authData.expiry;
    headers.uid = authData.uid;
  }

  const response = await fetch(
    `/api/v1/accounts/${accountId.value}/knowledge_bases`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify({
        knowledge_base: { name, source_type: sourceType, url },
        file_blob_id: blobId,
      }),
    }
  );

  if (!response.ok) {
    throw new Error('Failed to create knowledge source');
  }
};

// Handle file selection and upload
const onFileChange = async event => {
  const file = event.target.files[0];
  if (!file) return;

  if (checkFileSizeLimit(file, MAXIMUM_FILE_UPLOAD_SIZE)) {
    isLoading.value = true;
    try {
      const sourceType = detectSourceType(file);
      const { blobId, fileUrl } = await uploadFile(file, accountId.value);
      await createKnowledgeBase(file.name, sourceType, blobId, fileUrl);
      useAlert(t('KNOWLEDGE_SOURCE.SUCCESS_MESSAGE'));
      closeModal();
      emit('refresh');
    } catch {
      useAlert(t('KNOWLEDGE_SOURCE.FILE.UPLOAD_ERROR'));
    } finally {
      isLoading.value = false;
    }
  } else {
    useAlert(t('KNOWLEDGE_SOURCE.FILE.SIZE_LIMIT_ERROR'));
  }

  // Reset the input so the same file can be selected again
  if (fileUploadInput.value) {
    fileUploadInput.value.value = '';
  }
};
</script>

<template>
  <Modal :show="show" :on-close="closeModal" size="medium">
    <div class="flex flex-col">
      <!-- Hidden file input (accepts both documents and images) -->
      <input
        ref="fileUploadInput"
        type="file"
        class="hidden"
        accept=".pdf,.doc,.docx,.txt,.csv,.xls,.xlsx,.jpg,.jpeg,.png,.gif,.bmp,.webp"
        @change="onFileChange"
      />

      <!-- Modal Header -->
      <woot-modal-header :header-title="t('ADD_KNOWLEDGE_SOURCE_BUTTON')" />

      <!-- Modal Body -->
      <div class="p-6">
        <div class="space-y-4">
          <div
            class="text-center py-8 border-2 border-dashed border-slate-300 dark:border-slate-600 rounded-lg"
          >
            <i class="i-lucide-upload text-4xl text-slate-400 mb-4" />
            <h4
              class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2"
            >
              {{ t('KNOWLEDGE_SOURCE.FILE.UPLOAD_TITLE') }}
            </h4>
            <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
              {{ t('KNOWLEDGE_SOURCE.FILE.UPLOAD_DESCRIPTION') }}
            </p>
            <NextButton :loading="isLoading" @click="openFileBrowser">
              {{ t('KNOWLEDGE_SOURCE.FILE.BROWSE') }}
            </NextButton>
          </div>
          <p class="text-xs text-slate-500 dark:text-slate-400 text-center">
            {{ t('KNOWLEDGE_SOURCE.UPLOAD.SUPPORTED_TYPES') }}
          </p>
        </div>
      </div>

      <!-- Modal Footer -->
      <div
        class="flex items-center justify-end gap-3 p-6 border-t border-slate-200 dark:border-slate-700"
      >
        <NextButton slate outline @click="closeModal">
          {{ t('KNOWLEDGE_SOURCE.CANCEL') }}
        </NextButton>
      </div>
    </div>
  </Modal>
</template>
