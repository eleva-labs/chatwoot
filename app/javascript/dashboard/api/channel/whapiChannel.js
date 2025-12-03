/* global axios */
import ApiClient from '../ApiClient';

class WhapiChannel extends ApiClient {
  constructor() {
    super('whapi_channels', { accountScoped: true });
  }

  create(params) {
    return super.create(params);
  }

  getQrCode(inboxId) {
    return axios.get(`${this.url}/${inboxId}/qr_code`);
  }

  initiateReconnection(inboxId) {
    return axios.post(`${this.url}/${inboxId}/initiate_reconnection`);
  }
}

export default new WhapiChannel();
