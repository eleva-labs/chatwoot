/* global axios */
import ApiClient from '../ApiClient';

class WhapiChannel extends ApiClient {
  constructor() {
    super('whapi_channels', { accountScoped: true });
  }

  create(params) {
    return super.create(params);
  }

  initiateReconnection(inboxId) {
    return axios.post(`${this.url}/${inboxId}/initiate_reconnection`);
  }
}

export default new WhapiChannel();
