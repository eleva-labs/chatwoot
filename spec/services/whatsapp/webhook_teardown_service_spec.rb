require 'rails_helper'

RSpec.describe Whatsapp::WebhookTeardownService do
  describe '#perform' do
    let(:account) { create(:account) }
    let(:api_client) { double }
    let(:channel) do
      create(:channel_whatsapp,
             account: account,
             provider: 'whatsapp_cloud',
             provider_config: {
               'source' => 'embedded_signup'
             },
             sync_templates: false)
    end
    let(:service) { described_class.new(channel) }

    before do
      # Stub WhatsApp Cloud provider config validation (called during channel creation)
      stub_request(:get, %r{https://graph\.facebook\.com/v\d+\.\d+/\d+/message_templates})
        .to_return(status: 200, body: '{"data": []}', headers: { 'Content-Type' => 'application/json' })

      allow(Whatsapp::FacebookApiClient).to receive(:new).and_return(api_client)
      # Stub webhook setup to prevent HTTP calls during channel update
      allow(channel).to receive(:setup_webhooks).and_return(true)
    end

    context 'when channel is whatsapp_cloud with embedded_signup' do
      it 'calls unsubscribe_waba_webhook on Facebook API client' do
        allow(api_client).to receive(:unsubscribe_waba_webhook).with('123456789')

        service.perform

        expect(api_client).to have_received(:unsubscribe_waba_webhook).with('123456789')
      end

      it 'handles errors gracefully without raising' do
        allow(api_client).to receive(:unsubscribe_waba_webhook).with('123456789').and_raise(StandardError, 'API error')
        expect { service.perform }.not_to raise_error
      end
    end

    it 'does not attempt to unsubscribe webhook when channel is not whatsapp_cloud' do
      other_channel = create(:channel_api, account: account)
      expect(api_client).not_to receive(:unsubscribe_waba_webhook)
      described_class.new(other_channel).perform
    end

    it 'does not attempt to unsubscribe webhook when channel is whatsapp_cloud but not embedded_signup' do
      channel = create(:channel_whatsapp,
                       account: account,
                       provider: 'whatsapp_cloud',
                       provider_config: {
                         'source' => 'manual',
                         'api_key' => 'test_access_token'
                       },
                       sync_templates: false)
      expect(api_client).not_to receive(:unsubscribe_waba_webhook)
      described_class.new(channel).perform
    end

    it 'does not attempt to unsubscribe webhook when required config is missing' do
      channel_with_missing_config = create(:channel_whatsapp,
                                           account: account,
                                           provider: 'whatsapp_cloud',
                                           provider_config: {
                                             'source' => 'embedded_signup',
                                             'business_account_id' => 'test_waba_id'
                                             # api_key is missing
                                           },
                                           sync_templates: false)
      # Manually override the provider_config to remove api_key (factory adds it automatically)
      channel_with_missing_config.provider_config = {
        'source' => 'embedded_signup',
        'business_account_id' => 'test_waba_id'
      }
      channel_with_missing_config.save(validate: false)

      expect(api_client).not_to receive(:unsubscribe_waba_webhook)
      described_class.new(channel_with_missing_config).perform
    end
  end
end
