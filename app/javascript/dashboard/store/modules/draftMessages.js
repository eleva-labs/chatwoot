import types from '../mutation-types';

import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

function getAccountId() {
  const isInsideAccountScopedURLs =
    window.location.pathname.includes('/app/accounts');
  if (isInsideAccountScopedURLs) {
    return window.location.pathname.split('/')[3];
  }
  return '';
}

function getScopedStorageKey() {
  const accountId = getAccountId();
  return accountId
    ? `${LOCAL_STORAGE_KEYS.DRAFT_MESSAGES}::${accountId}`
    : LOCAL_STORAGE_KEYS.DRAFT_MESSAGES;
}

function migrateUnscopedDrafts() {
  const accountId = getAccountId();
  if (!accountId) return;

  const scopedKey = getScopedStorageKey();
  const unscopedKey = LOCAL_STORAGE_KEYS.DRAFT_MESSAGES;

  // Only migrate if scoped key doesn't exist yet and unscoped key has data
  if (
    !window.localStorage.getItem(scopedKey) &&
    window.localStorage.getItem(unscopedKey)
  ) {
    const unscopedData = LocalStorage.get(unscopedKey);
    if (unscopedData && typeof unscopedData === 'object') {
      LocalStorage.set(scopedKey, unscopedData);
      // Don't delete unscoped key — other accounts may still need to migrate from it
    }
  }
}

// Run migration on module load
migrateUnscopedDrafts();

const state = {
  records: LocalStorage.get(getScopedStorageKey()) || {},
  replyEditorMode: REPLY_EDITOR_MODES.REPLY,
};

export const getters = {
  get: _state => key => {
    return _state.records[key] || '';
  },
  getReplyEditorMode: _state => _state.replyEditorMode,
};

export const actions = {
  set: async ({ commit }, { key, message }) => {
    commit(types.SET_DRAFT_MESSAGES, { key, message });
  },
  delete: ({ commit }, { key }) => {
    commit(types.SET_DRAFT_MESSAGES, { key });
  },
  setReplyEditorMode: ({ commit }, { mode }) => {
    commit(types.SET_REPLY_EDITOR_MODE, { mode });
  },
};

export const mutations = {
  [types.SET_DRAFT_MESSAGES]($state, { key, message }) {
    $state.records = {
      ...$state.records,
      [key]: message,
    };
    LocalStorage.set(getScopedStorageKey(), $state.records);
  },
  [types.REMOVE_DRAFT_MESSAGES]($state, { key }) {
    const { [key]: draftToBeRemoved, ...updatedRecords } = $state.records;
    $state.records = updatedRecords;
    LocalStorage.set(getScopedStorageKey(), $state.records);
  },
  [types.SET_REPLY_EDITOR_MODE]($state, { mode }) {
    $state.replyEditorMode = mode;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
