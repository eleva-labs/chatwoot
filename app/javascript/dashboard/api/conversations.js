/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  toggleAi(conversationID, aiEnabled) {
    return axios.post(`${this.url}/${conversationID}/toggle_ai`, {
      ai_enabled: aiEnabled,
    });
  }
}

export default new ConversationApi();
