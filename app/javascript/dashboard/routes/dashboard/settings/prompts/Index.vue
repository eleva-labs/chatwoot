<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AddKnowledgeSource from './components/AddKnowledgeSource.vue';
import Modal from 'dashboard/components/Modal.vue';
import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';
import { useAlert } from 'dashboard/composables';
import Auth from 'dashboard/api/auth';

const { t } = useI18n();
const store = useStore();

const showAddKnowledgeSourceModal = ref(false);
const knowledgeSources = ref([]);
const loadingKnowledgeSources = ref(false);
const showDeleteConfirm = ref(false);
const sourceToDelete = ref(null);
const showGalleryViewer = ref(false);
const activeAttachment = ref({});

const currentAccountId = computed(() => store.getters.getCurrentAccountId);

const getAuthHeaders = () => {
  const authData = Auth.getAuthData();
  const headers = { 'Content-Type': 'application/json' };
  if (authData) {
    headers['access-token'] = authData['access-token'];
    headers['token-type'] = authData['token-type'];
    headers.client = authData.client;
    headers.expiry = authData.expiry;
    headers.uid = authData.uid;
  }
  return headers;
};

const fetchKnowledgeSources = async () => {
  loadingKnowledgeSources.value = true;
  try {
    const response = await fetch(
      `/api/v1/accounts/${currentAccountId.value}/knowledge_bases`,
      { method: 'GET', headers: getAuthHeaders() }
    );
    if (response.ok) {
      knowledgeSources.value = await response.json();
    } else {
      throw new Error('Failed to fetch knowledge sources');
    }
  } catch {
    useAlert(t('KNOWLEDGE_SOURCE.FETCH_ERROR'));
  } finally {
    loadingKnowledgeSources.value = false;
  }
};

const openAddKnowledgeSourceModal = () => {
  showAddKnowledgeSourceModal.value = true;
};

const hideAddKnowledgeSourceModal = () => {
  showAddKnowledgeSourceModal.value = false;
};

const viewKnowledgeSource = source => {
  if (source.source_type === 'image') {
    openGallery(source);
  } else if (
    source.source_type === 'file' ||
    source.source_type === 'webpage'
  ) {
    window.open(source.url, '_blank', 'noopener noreferrer');
  }
};

const openGallery = source => {
  activeAttachment.value = {
    id: source.id,
    message_id: source.id,
    file_type: 'image',
    data_url: source.url,
    created_at: source.created_at,
    sender: {
      name: 'Knowledge Base',
      id: 'system',
      avatar_url: '',
    },
  };
  showGalleryViewer.value = true;
};

const onCloseGallery = () => {
  showGalleryViewer.value = false;
  activeAttachment.value = {};
};

const confirmDeleteKnowledgeSource = (knowledgeSource, event) => {
  event.stopPropagation();
  sourceToDelete.value = knowledgeSource;
  showDeleteConfirm.value = true;
};

const deleteKnowledgeSource = async () => {
  if (!sourceToDelete.value) return;
  try {
    const response = await fetch(
      `/api/v1/accounts/${currentAccountId.value}/knowledge_bases/${sourceToDelete.value.id}`,
      { method: 'DELETE', headers: getAuthHeaders() }
    );
    if (response.ok) {
      useAlert(t('KNOWLEDGE_SOURCE.DELETE_SUCCESS'));
      fetchKnowledgeSources();
    } else {
      throw new Error('Failed to delete knowledge source');
    }
  } catch {
    useAlert(t('KNOWLEDGE_SOURCE.DELETE_ERROR'));
  } finally {
    showDeleteConfirm.value = false;
    sourceToDelete.value = null;
  }
};

const cancelDelete = () => {
  showDeleteConfirm.value = false;
  sourceToDelete.value = null;
};

const getSourceIcon = sourceType => {
  switch (sourceType) {
    case 'webpage':
      return 'i-lucide-globe';
    case 'file':
      return 'i-lucide-file-text';
    case 'image':
      return 'i-lucide-image';
    default:
      return 'i-lucide-file';
  }
};

const getSourceTypeDisplay = sourceType => {
  switch (sourceType) {
    case 'webpage':
      return t('KNOWLEDGE_SOURCE.TYPE.URL');
    case 'file':
      return t('KNOWLEDGE_SOURCE.TYPE.FILE');
    case 'image':
      return t('KNOWLEDGE_SOURCE.TYPE.IMAGE');
    default:
      return t('KNOWLEDGE_SOURCE.TYPE.UNKNOWN');
  }
};

const formatDate = dateString => {
  const date = new Date(dateString);
  const now = new Date();
  const diffTime = Math.abs(now - date);
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

  if (diffDays === 1) return t('KNOWLEDGE_SOURCE.DATE.TODAY');
  if (diffDays === 2) return t('KNOWLEDGE_SOURCE.DATE.YESTERDAY');
  if (diffDays <= 7) {
    return t('KNOWLEDGE_SOURCE.DATE.DAYS_AGO', { count: diffDays - 1 });
  }
  if (diffDays <= 14) return t('KNOWLEDGE_SOURCE.DATE.WEEK_AGO');
  if (diffDays <= 30) {
    return t('KNOWLEDGE_SOURCE.DATE.WEEKS_AGO', {
      count: Math.ceil(diffDays / 7),
    });
  }
  return t('KNOWLEDGE_SOURCE.DATE.MONTHS_AGO', {
    count: Math.ceil(diffDays / 30),
  });
};

const onKnowledgeSourceAdded = () => {
  fetchKnowledgeSources();
};

onMounted(() => {
  fetchKnowledgeSources();
});
</script>

<template>
  <div class="flex flex-col w-full">
    <BaseSettingsHeader
      :title="t('PROMPTS_PAGE.TITLE')"
      :description="t('PROMPTS_PAGE.DESCRIPTION')"
    >
      <template #actions>
        <NextButton @click="openAddKnowledgeSourceModal">
          {{ t('ADD_KNOWLEDGE_SOURCE_BUTTON') }}
        </NextButton>
      </template>
    </BaseSettingsHeader>

    <!-- Knowledge Sources Section -->
    <div class="mt-12">
      <h2
        class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-6"
      >
        {{ t('KNOWLEDGE_SOURCE.TITLE') }}
      </h2>

      <div v-if="loadingKnowledgeSources" class="flex justify-center py-8">
        <div class="text-slate-600 dark:text-slate-400">
          {{ t('KNOWLEDGE_SOURCE.LOADING') }}
        </div>
      </div>

      <div
        v-else-if="knowledgeSources.length === 0"
        class="text-center py-8"
      >
        <p class="text-slate-600 dark:text-slate-400">
          {{ t('KNOWLEDGE_SOURCE.EMPTY_STATE') }}
        </p>
      </div>

      <div v-else class="space-y-3">
        <div
          v-for="source in knowledgeSources"
          :key="source.id"
          class="flex items-center justify-between p-4 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 cursor-pointer transition-colors hover:border-slate-300 dark:hover:border-slate-600"
          @click="viewKnowledgeSource(source)"
        >
          <div class="flex items-center gap-3">
            <i
              :class="getSourceIcon(source.source_type)"
              class="text-slate-600 dark:text-slate-400 text-lg"
            />
            <div>
              <p class="font-medium text-slate-900 dark:text-slate-100">
                {{ source.name }}
              </p>
              <p class="text-sm text-slate-600 dark:text-slate-400">
                {{ getSourceTypeDisplay(source.source_type) }} &bull;
                {{ formatDate(source.created_at) }}
              </p>
            </div>
          </div>
          <NextButton
            icon="i-lucide-trash-2"
            slate
            xs
            faded
            @click="confirmDeleteKnowledgeSource(source, $event)"
          />
        </div>
      </div>
    </div>

    <!-- Add Knowledge Source Modal -->
    <AddKnowledgeSource
      :show="showAddKnowledgeSourceModal"
      @close="hideAddKnowledgeSourceModal"
      @refresh="onKnowledgeSourceAdded"
    />

    <!-- Gallery View for Images -->
    <GalleryView
      v-if="showGalleryViewer"
      v-model:show="showGalleryViewer"
      :attachment="activeAttachment"
      :all-attachments="[activeAttachment]"
      @close="onCloseGallery"
    />

    <!-- Delete Confirmation Modal -->
    <Modal v-if="showDeleteConfirm" :show="showDeleteConfirm" size="small">
      <div class="flex flex-col">
        <woot-modal-header
          :header-title="t('KNOWLEDGE_SOURCE.DELETE_CONFIRM.TITLE')"
        />
        <div class="p-6">
          <p class="text-slate-600 dark:text-slate-400">
            {{
              t('KNOWLEDGE_SOURCE.DELETE_CONFIRM.MESSAGE', {
                name: sourceToDelete?.name,
              })
            }}
          </p>
        </div>
        <div
          class="flex items-center justify-end gap-3 p-6 border-t border-slate-200 dark:border-slate-700"
        >
          <NextButton slate outline @click="cancelDelete">
            {{ t('KNOWLEDGE_SOURCE.DELETE_CONFIRM.CANCEL') }}
          </NextButton>
          <NextButton variant="danger" @click="deleteKnowledgeSource">
            {{ t('KNOWLEDGE_SOURCE.DELETE_CONFIRM.DELETE') }}
          </NextButton>
        </div>
      </div>
    </Modal>
  </div>
</template>
