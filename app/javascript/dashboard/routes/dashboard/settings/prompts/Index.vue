<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AddKnowledgeSource from './components/AddKnowledgeSource.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();

const showAddKnowledgeSourceModal = ref(false);

const knowledgeSources = ref([
  {
    id: 1,
    name: 'https://docs.chatwoot.com/product/features/reports',
    type: 'URL',
    icon: 'i-lucide-globe',
    uploadedDate: 'May 20, 2024',
  },
  {
    id: 2,
    name: 'pricing-details.pdf',
    type: 'File',
    icon: 'i-lucide-file-text',
    uploadedDate: 'May 18, 2024',
  },
  {
    id: 3,
    name: 'logo-dark.png',
    type: 'Image',
    icon: 'i-lucide-image',
    uploadedDate: 'May 17, 2024',
  },
]);
</script>

<template>
  <div class="flex flex-col w-full">
    <BaseSettingsHeader
      :title="t('PROMPTS_PAGE.TITLE')"
      :description="t('PROMPTS_PAGE.DESCRIPTION')"
    >
      <template #actions>
        <NextButton
          icon="i-lucide-plus"
          @click="showAddKnowledgeSourceModal = true"
        >
          {{ t('ADD_KNOWLEDGE_SOURCE_BUTTON') }}
        </NextButton>
      </template>
    </BaseSettingsHeader>

    <!-- Knowledge Sources Section -->
    <div class="mt-6">
      <div
        class="bg-white dark:bg-slate-800 rounded-lg border border-slate-50 dark:border-slate-700/50"
      >
        <ul>
          <li
            v-for="(source, index) in knowledgeSources"
            :key="source.id"
            class="flex items-center justify-between p-4"
            :class="{
              'border-b border-slate-50 dark:border-slate-700/50':
                index < knowledgeSources.length - 1,
            }"
          >
            <div class="flex items-center gap-4">
              <Icon
                :icon="source.icon"
                class="w-6 h-6 text-slate-600 dark:text-slate-300"
              />
              <div class="flex flex-col">
                <p class="font-semibold text-slate-900 dark:text-slate-100">
                  {{ source.name }}
                </p>
                <p class="text-sm text-slate-600 dark:text-slate-300">
                  {{ source.type }}
                  <span>·</span>
                  {{
                    t('KNOWLEDGE_SOURCES.UPLOADED_ON', {
                      date: source.uploadedDate,
                    })
                  }}
                </p>
              </div>
            </div>
            <NextButton
              v-tooltip.top="t('PROMPTS_PAGE.DELETE')"
              icon="i-lucide-trash-2"
              variant="smooth"
              color-scheme="secondary"
            />
          </li>
        </ul>
      </div>
    </div>

    <!-- Add Knowledge Source Modal -->
    <AddKnowledgeSource
      v-if="showAddKnowledgeSourceModal"
      @close="showAddKnowledgeSourceModal = false"
    />
  </div>
</template>
