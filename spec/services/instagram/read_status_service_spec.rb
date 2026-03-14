require 'rails_helper'

describe Instagram::ReadStatusService do
  before do
    create(:message, message_type: :incoming, inbox: instagram_inbox, account: account, conversation: conversation,
                     source_id: 'chatwoot-app-user-id-1')
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  let!(:account) { create(:account) }
  let!(:instagram_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'chatwoot-app-user-id-1') }
  let!(:instagram_inbox) { create(:inbox, channel: instagram_channel, account: account, greeting_enabled: false) }
  let!(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: instagram_inbox) }
  let(:conversation) { create(:conversation, contact: contact, inbox: instagram_inbox, contact_inbox: contact_inbox) }

  describe '#perform' do
    context 'when messaging_seen callback is fired' do
      let(:message) { conversation.messages.last }

      before do
        allow(Conversations::UpdateMessageStatusJob).to receive(:perform_later)
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
        expect(Instagram::ReadStatusReconciliationJob).to have_been_enqueued.with(
          instagram_channel,
          'random-message-id',
          '2021-09-08T06:34:04+0000',
          1
        ).on_queue('default')
      end

      it 'schedules the next bounded retry when a reconciliation attempt still misses' do
        params = {
          read: {
            mid: 'random-message-id'
          },
          timestamp: '2021-09-08T06:34:04+0000'
        }

        described_class.new(params: params, channel: instagram_channel, reconciliation_attempt: 2).perform

        expect(Instagram::ReadStatusReconciliationJob).to have_been_enqueued.with(
          instagram_channel,
          'random-message-id',
          '2021-09-08T06:34:04+0000',
          3
        ).on_queue('default')
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
        expect(Instagram::ReadStatusReconciliationJob).not_to have_been_enqueued
        expect(Rails.logger).to have_received(:warn).with(
          '[Instagram::ReadStatusService] event=read_status_terminal_miss ' \
          "channel_id=#{instagram_channel.id} inbox_id=#{instagram_channel.inbox.id} " \
          "mid=random-message-id attempt=#{Instagram::ReadStatusService::RECONCILIATION_DELAYS.length} " \
          'webhook_timestamp=2021-09-08T06:34:04+0000'
        )
      end
    end
  end
end
