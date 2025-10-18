/* global axios */
import ApiClient from './ApiClient';

class WorkflowsAPI extends ApiClient {
  constructor() {
    super('workflows', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  getDefaultWorkflow(botId) {
    const accountId = window.location.pathname.split('/')[3];
    return axios.get(
      `/api/v1/accounts/${accountId}/agent_bots/${botId}/workflows/default`
    );
  }
}

export default new WorkflowsAPI();
