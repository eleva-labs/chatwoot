require 'rails_helper'

RSpec.describe Whatsapp::WhapiConnectionStatusService do
  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_whatsapp,
           account: account,
           provider: 'whapi',
           phone_number: 'pending:chan_1',
           provider_config: {
             'whapi_channel_id' => 'chan_1',
             'whapi_channel_token' => 'tok_1',
             'api_key' => 'tok_1',
             'connection_status' => 'pending'
           },
           sync_templates: false,
           validate_provider_config: false)
  end
  let!(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:correlation_id) { 'test-correlation-123' }

  before do
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe '#perform' do
    it 'processes events array' do
      params = { 'events' => [{ 'type' => 'connected', 'phone' => '+1234567890' }] }
      service = described_class.new(channel: channel, params: params, correlation_id: correlation_id)

      allow_any_instance_of(Whatsapp::Partner::WhapiPartnerService)
        .to receive(:update_webhook_with_phone_number).and_return('https://webhook.test')

      service.perform

      expect(channel.reload.provider_config['connection_status']).to eq('connected')
    end

    it 'processes top-level users event' do
      params = {
        'event' => { 'type' => 'users', 'event' => 'post' },
        'user' => { 'id' => '1234567890', 'name' => 'Test User' }
      }
      service = described_class.new(channel: channel, params: params, correlation_id: correlation_id)

      allow_any_instance_of(Whatsapp::Partner::WhapiPartnerService)
        .to receive(:update_webhook_with_phone_number).and_return('https://webhook.test')

      service.perform

      expect(channel.reload.provider_config['connection_status']).to eq('connected')
    end
  end

  describe '#process_health_status' do
    subject(:service) { described_class.new(channel: channel, params: {}, correlation_id: correlation_id) }

    context 'when status is AUTH' do
      it 'marks channel as connected and clears reauthorization' do
        allow_any_instance_of(Whatsapp::Providers::WhapiService).to receive(:bust_health_check_cache)

        service.process_health_status({ 'status' => { 'text' => 'AUTH' } })

        expect(channel.reload.provider_config['connection_status']).to eq('connected')
        expect(ActionCable.server).to have_received(:broadcast).at_least(:once)
      end
    end

    context 'when status is QR' do
      it 'fetches QR code and broadcasts it' do
        allow_any_instance_of(Whatsapp::Partner::WhapiPartnerService)
          .to receive(:generate_qr_code_simple)
          .and_return({ 'image_base64' => 'qrdata', 'expires_in' => 20 })

        service.process_health_status({ 'status' => { 'text' => 'QR' } })

        expect(channel.reload.provider_config['connection_status']).to eq('reconnecting')
        expect(ActionCable.server).to have_received(:broadcast).with(
          "account_#{account.id}",
          hash_including(event: 'whapi_qr_code_received')
        )
      end

      it 'handles QR fetch failure gracefully' do
        allow_any_instance_of(Whatsapp::Partner::WhapiPartnerService)
          .to receive(:generate_qr_code_simple)
          .and_return(nil)

        expect { service.process_health_status({ 'status' => { 'text' => 'QR' } }) }.not_to raise_error

        expect(channel.reload.provider_config['connection_status']).to eq('reconnecting')
      end
    end

    context 'when status is STOP' do
      it 'marks channel as disconnected and prompts reauthorization' do
        service.process_health_status({ 'status' => { 'text' => 'STOP' } })

        config = channel.reload.provider_config
        expect(config['connection_status']).to eq('stop')
        expect(config['disconnected_at']).to be_present
      end
    end

    context 'when status is ERROR' do
      it 'marks channel as disconnected' do
        service.process_health_status({ 'status' => { 'text' => 'ERROR' } })

        config = channel.reload.provider_config
        expect(config['connection_status']).to eq('error')
        expect(config['disconnected_at']).to be_present
      end
    end

    context 'when status is SYNC_ERROR' do
      it 'marks channel with sync_error status' do
        service.process_health_status({ 'status' => { 'text' => 'SYNC_ERROR' } })

        config = channel.reload.provider_config
        expect(config['connection_status']).to eq('sync_error')
        expect(config['sync_error_at']).to be_present
      end
    end

    context 'when status is transient (INIT, LAUNCH, NOT_INIT)' do
      %w[INIT LAUNCH NOT_INIT].each do |status|
        it "broadcasts #{status} status without modifying connection_status" do
          original_status = channel.provider_config['connection_status']

          service.process_health_status({ 'status' => { 'text' => status } })

          expect(channel.reload.provider_config['connection_status']).to eq(original_status)
          expect(ActionCable.server).to have_received(:broadcast).at_least(:once)
        end
      end
    end
  end

  describe 'connection events' do
    subject(:service) { described_class.new(channel: channel, params: {}, correlation_id: correlation_id) }

    describe 'connected event with phone number' do
      it 'updates channel with formatted phone and connected status' do
        allow_any_instance_of(Whatsapp::Partner::WhapiPartnerService)
          .to receive(:update_webhook_with_phone_number).and_return('https://webhook.test')

        event = { 'type' => 'connected', 'phone' => '1234567890' }
        service.send(:process_connection_event, event)

        config = channel.reload.provider_config
        expect(config['connection_status']).to eq('connected')
      end
    end

    describe 'disconnected event' do
      it 'updates channel to disconnected and prompts reauthorization' do
        event = { 'type' => 'disconnected' }
        service.send(:process_connection_event, event)

        config = channel.reload.provider_config
        expect(config['connection_status']).to eq('disconnected')
        expect(config['disconnected_at']).to be_present
      end
    end
  end

  describe 'users events' do
    subject(:service) { described_class.new(channel: channel, params: {}, correlation_id: correlation_id) }

    it 'handles users.post (connection) with phone from user id' do
      allow_any_instance_of(Whatsapp::Partner::WhapiPartnerService)
        .to receive(:update_webhook_with_phone_number).and_return('https://webhook.test')

      event_obj = { 'type' => 'users', 'event' => 'post' }
      user_obj = { 'id' => '1234567890', 'name' => 'Test' }

      service.send(:process_users_event, event_obj, user_obj)

      expect(channel.reload.provider_config['connection_status']).to eq('connected')
    end

    it 'handles users.delete (disconnection)' do
      event_obj = { 'type' => 'users', 'event' => 'delete' }
      user_obj = { 'id' => '1234567890' }

      service.send(:process_users_event, event_obj, user_obj)

      config = channel.reload.provider_config
      expect(config['connection_status']).to eq('disconnected')
      expect(config['disconnected_at']).to be_present
    end
  end

  describe 'ActionCable broadcasts' do
    subject(:service) { described_class.new(channel: channel, params: {}, correlation_id: correlation_id) }

    it 'broadcasts whapi_status with derived connection_status' do
      service.send(:broadcast_whapi_status, 'AUTH')

      expect(ActionCable.server).to have_received(:broadcast).with(
        "account_#{account.id}",
        hash_including(
          event: 'whapi_channel_status_updated',
          data: hash_including(
            whapi_status: 'AUTH',
            connection_status: 'connected'
          )
        )
      )
    end

    it 'derives disconnected status for STOP' do
      service.send(:broadcast_whapi_status, 'STOP')

      expect(ActionCable.server).to have_received(:broadcast).with(
        "account_#{account.id}",
        hash_including(
          data: hash_including(connection_status: 'disconnected')
        )
      )
    end

    it 'derives reconnecting status for QR' do
      service.send(:broadcast_whapi_status, 'QR')

      expect(ActionCable.server).to have_received(:broadcast).with(
        "account_#{account.id}",
        hash_including(
          data: hash_including(connection_status: 'reconnecting')
        )
      )
    end
  end
end
