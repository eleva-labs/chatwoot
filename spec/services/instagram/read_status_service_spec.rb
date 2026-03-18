require 'rails_helper'

describe Instagram::ReadStatusService do
  before do
    create(:message, message_type: :incoming, inbox: instagram_inbox, account: account, conversation: conversation,
                     source_id: 'chatwoot-app-user-id-1')
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    allow(ActiveSupport::Notifications).to receive(:instrument) do |_event_name, payload|
      observability_events << payload
    end
  end

  let!(:account) { create(:account) }
  let!(:instagram_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'chatwoot-app-user-id-1') }
  let!(:instagram_inbox) { create(:inbox, channel: instagram_channel, account: account, greeting_enabled: false) }
  let!(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: instagram_inbox) }
  let(:conversation) { create(:conversation, contact: contact, inbox: instagram_inbox, contact_inbox: contact_inbox) }
  let(:observability_events) { [] }
  let(:reconciliation_job) { double('reconciliation_job', perform_later: true) }

  describe '#perform' do
    context 'when messaging_seen callback is fired' do
      let(:message) { conversation.messages.last }

      before do
        allow(Conversations::UpdateMessageStatusJob).to receive(:perform_later)
        allow(Instagram::ReadStatusReconciliationJob).to receive(:set).and_return(reconciliation_job)
        allow(Rails.logger).to receive(:info)
      end

      it 'enqueues the UpdateMessageStatusJob with correct parameters if the message is found' do
        params = {
          recipient: {
            id: 'chatwoot-app-user-id-1'
          },
          read: {
            mid: message.source_id
          }
        }
        described_class.new(params: params, channel: instagram_channel).perform
        expect(Conversations::UpdateMessageStatusJob).to have_received(:perform_later).with(conversation.id, message.created_at)
        expect(observability_events).to be_empty
        expect(Rails.logger).not_to have_received(:info)
      end

      it 'does not enqueue the UpdateMessageStatusJob if the message is not found' do
        params = {
          recipient: {
            id: 'chatwoot-app-user-id-1'
          },
          read: {
            mid: 'random-message-id'
          },
          timestamp: '2021-09-08T06:34:04+0000'
        }

        described_class.new(params: params, channel: instagram_channel).perform

        expect(Conversations::UpdateMessageStatusJob).not_to have_received(:perform_later)
        expect(Instagram::ReadStatusReconciliationJob).to have_received(:set).with(wait: 2.seconds)
        expect(reconciliation_job).to have_received(:perform_later).with(
          instagram_channel,
          'random-message-id',
          '2021-09-08T06:34:04+0000',
          1
        )
        expect(observability_events).to include(
          hash_including(event: 'read_status_initial_miss', mid: 'random-message-id', attempt: 0, webhook_timestamp: '2021-09-08T06:34:04+0000'),
          hash_including(
            event: 'read_status_retry_scheduled',
            mid: 'random-message-id',
            attempt: 0,
            next_attempt: 1,
            scheduled_delay_seconds: 2
          )
        )
        expect(observability_events).to all(satisfy { |payload| !payload.key?(:recovery_lag_seconds) })
        expect(Rails.logger).not_to have_received(:info)
      end

      it 'schedules the next bounded retry when a reconciliation attempt still misses' do
        params = {
          read: {
            mid: 'random-message-id'
          },
          timestamp: '2021-09-08T06:34:04+0000'
        }

        described_class.new(params: params, channel: instagram_channel, reconciliation_attempt: 2).perform

        expect(Instagram::ReadStatusReconciliationJob).to have_received(:set).with(wait: 15.seconds)
        expect(reconciliation_job).to have_received(:perform_later).with(
          instagram_channel,
          'random-message-id',
          '2021-09-08T06:34:04+0000',
          3
        )
        expect(observability_events).to include(
          hash_including(
            event: 'read_status_retry_scheduled',
            mid: 'random-message-id',
            attempt: 2,
            next_attempt: 3,
            scheduled_delay_seconds: 15
          )
        )
        expect(Rails.logger).not_to have_received(:info)
      end

      it 'logs a recovered retry with recovery lag when a later reconciliation attempt finds the message' do
        params = {
          read: {
            mid: message.source_id
          },
          timestamp: '2021-09-08T06:34:04+0000'
        }

        travel_to Time.zone.parse('2021-09-08T06:34:10+0000') do
          described_class.new(params: params, channel: instagram_channel, reconciliation_attempt: 2).perform
        end

        expect(Conversations::UpdateMessageStatusJob).to have_received(:perform_later).with(conversation.id, message.created_at)
        expect(observability_events).to include(
          hash_including(
            event: 'read_status_recovered_on_retry',
            mid: message.source_id,
            attempt: 2,
            recovery_lag_seconds: 6.0
          )
        )
        expect(Rails.logger).to have_received(:info).with(
          hash_including(event: 'read_status_recovered_on_retry', recovery_lag_seconds: 6.0)
        )
      end

      it 'logs a single terminal miss after the bounded retries are exhausted' do
        params = {
          read: {
            mid: 'random-message-id'
          },
          timestamp: '2021-09-08T06:34:04+0000'
        }

        allow(Rails.logger).to receive(:warn)

        described_class.new(
          params: params,
          channel: instagram_channel,
          reconciliation_attempt: Instagram::ReadStatusService::RECONCILIATION_DELAYS.length
        ).perform

        expect(Conversations::UpdateMessageStatusJob).not_to have_received(:perform_later)
        expect(reconciliation_job).not_to have_received(:perform_later)
        expect(observability_events).to include(
          hash_including(
            event: 'read_status_terminal_miss',
            channel_id: instagram_channel.id,
            inbox_id: instagram_channel.inbox.id,
            instagram_account_id: instagram_channel.instagram_id,
            mid: 'random-message-id',
            attempt: Instagram::ReadStatusService::RECONCILIATION_DELAYS.length,
            webhook_timestamp: '2021-09-08T06:34:04+0000'
          )
        )
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            event: 'read_status_terminal_miss',
            mid: 'random-message-id',
            attempt: Instagram::ReadStatusService::RECONCILIATION_DELAYS.length
          )
        )
      end
    end
  end
end
