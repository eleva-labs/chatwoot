import WorkflowsAPI from '../../api/workflows';

export const state = {
  workflow: null,
  uiFlags: {
    isFetching: false,
    isFetchError: false,
  },
};

export const getters = {
  getWorkflow: $state => $state.workflow,
  isLoading: $state => $state.uiFlags.isFetching,
  hasError: $state => $state.uiFlags.isFetchError,
};

export const actions = {
  fetchDefaultWorkflow: async ({ commit }, { botId }) => {
    commit('setFetching', true);
    commit('setFetchError', false);

    try {
      const response = await WorkflowsAPI.getDefaultWorkflow(botId);
      commit('setWorkflow', response.data);
    } catch (error) {
      commit('setFetchError', true);
      throw error;
    } finally {
      commit('setFetching', false);
    }
  },

  clearWorkflow: ({ commit }) => {
    commit('setWorkflow', null);
    commit('setFetchError', false);
  },
};

export const mutations = {
  setWorkflow($state, workflow) {
    $state.workflow = workflow;
  },

  setFetching($state, value) {
    $state.uiFlags.isFetching = value;
  },

  setFetchError($state, value) {
    $state.uiFlags.isFetchError = value;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
