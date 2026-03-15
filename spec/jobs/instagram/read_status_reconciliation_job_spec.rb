require 'rails_helper'

describe Instagram::ReadStatusReconciliationJob do
  include ActiveJob::TestHelper

  let!(:account) { create(:account) }
  let!(:instagram_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'chatwoot-app-user-id-1') }

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'replays the read lookup through the service with the concrete channel record and bounded retry metadata' do
    service = instance_double(Instagram::ReadStatusService, perform: true)

    allow(Instagram::ReadStatusService).to receive(:new).and_return(service)

    perform_enqueued_jobs do
      described_class.perform_later(instagram_channel, 'message-id-1', '2021-09-08T06:34:04+0000', 2)
    end

    expect(Instagram::ReadStatusService).to have_received(:new).with(
      params: {
        read: { mid: 'message-id-1' },
        timestamp: '2021-09-08T06:34:04+0000'
      },
      channel: instagram_channel,
      reconciliation_attempt: 2
    )
    expect(service).to have_received(:perform)
  end
end
