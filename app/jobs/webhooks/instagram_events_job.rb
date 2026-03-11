class Webhooks::InstagramEventsJob < MutexApplicationJob
  queue_as :default

  LOCK_RETRY_WAIT = lambda do |executions|
    base_wait_seconds = [2 * (2**(executions - 1)), 30].min
    base_wait_seconds + (base_wait_seconds * rand * 0.15)
  end

  retry_on LockAcquisitionError, wait: LOCK_RETRY_WAIT, attempts: 8

  # @return [Array] We will support further events like reaction or seen in future
  SUPPORTED_EVENTS = [:message, :read].freeze

  def perform(entries)
    @entries = entries

    key = format(::Redis::Alfred::IG_MESSAGE_MUTEX, sender_id: sender_id, ig_account_id: ig_account_id)
    lock_started_at = monotonic_time
    @lock_acquired_at = nil

    with_lock(key, 30.seconds) do
      @lock_acquired_at = monotonic_time
      process_entries(entries)
    end
  rescue LockAcquisitionError
    log_lock_retry(
      lock_key: key,
      lock_attempt_ms: elapsed_ms(lock_started_at, monotonic_time),
      retry_attempt: lock_attempt
    )
    raise
  ensure
    log_lock_release(key, lock_started_at) if lock_started_at && @lock_acquired_at
  end

  # https://developers.facebook.com/docs/messenger-platform/instagram/features/webhook
  def process_entries(entries)
    entries.each do |entry|
      process_single_entry(entry.with_indifferent_access)
    end
  end

  private

  def process_single_entry(entry)
    if test_event?(entry)
      process_test_event(entry)
      return
    end

    process_messages(entry)
  end

  def process_messages(entry)
    messages(entry).each do |messaging|
      instagram_id = instagram_id(messaging)
      channel = find_channel(instagram_id)

      next if channel.blank?

      if (event_name = event_name(messaging))
        send(event_name, messaging, channel)
      end
    end
  end

  def agent_message_via_echo?(messaging)
    messaging[:message].present? && messaging[:message][:is_echo].present?
  end

  def test_event?(entry)
    entry[:changes].present?
  end

  def process_test_event(entry)
    messaging = extract_messaging_from_test_event(entry)

    Instagram::TestEventService.new(messaging).perform if messaging.present?
  end

  def extract_messaging_from_test_event(entry)
    entry[:changes].first&.dig(:value) if entry[:changes].present?
  end

  def instagram_id(messaging)
    if agent_message_via_echo?(messaging)
      messaging[:sender][:id]
    else
      messaging[:recipient][:id]
    end
  end

  def ig_account_id
    @entries&.first&.dig(:id)
  end

  def sender_id
    @entries&.dig(0, :messaging, 0, :sender, :id)
  end

  def find_channel(instagram_id)
    # There will be chances for the instagram account to be connected to a facebook page,
    # so we need to check for both instagram and facebook page channels
    # priority is for instagram channel which created via instagram login
    channel = Channel::Instagram.find_by(instagram_id: instagram_id)
    # If not found, fallback to the facebook page channel
    channel ||= Channel::FacebookPage.find_by(instagram_id: instagram_id)

    channel
  end

  def event_name(messaging)
    SUPPORTED_EVENTS.find { |key| messaging.key?(key) }
  end

  def message(messaging, channel)
    if channel.is_a?(Channel::Instagram)
      ::Instagram::MessageText.new(messaging, channel).perform
    else
      ::Instagram::Messenger::MessageText.new(messaging, channel).perform
    end
  end

  def read(messaging, channel)
    # Use a single service to handle read status for both channel types since the params are same
    ::Instagram::ReadStatusService.new(params: messaging, channel: channel).perform
  end

  def messages(entry)
    (entry[:messaging].presence || entry[:standby] || [])
  end

  def log_lock_release(lock_key, lock_started_at)
    lock_released_at = monotonic_time
    log_lock_event(
      'released',
      lock_key: lock_key,
      lock_attempt_ms: elapsed_ms(lock_started_at, @lock_acquired_at),
      lock_hold_ms: elapsed_ms(@lock_acquired_at, lock_released_at),
      total_elapsed_ms: elapsed_ms(lock_started_at, lock_released_at)
    )
  end

  def log_lock_event(event, lock_key:, **metadata)
    details = metadata.map { |attribute, value| "#{attribute}=#{value}" }.join(' ')
    Rails.logger.info(
      "[#{self.class.name}] event=lock_#{event} lock_key=#{lock_key} sender_id=#{sender_id} ig_account_id=#{ig_account_id} #{details}".strip
    )
  end

  def log_lock_retry(lock_key:, **metadata)
    details = metadata.map { |attribute, value| "#{attribute}=#{value}" }.join(' ')
    Rails.logger.warn(
      "[#{self.class.name}] event=lock_retry_scheduled lock_key=#{lock_key} sender_id=#{sender_id} ig_account_id=#{ig_account_id} #{details}".strip
    )
  end

  def lock_attempt
    [executions.to_i, 1].max
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def elapsed_ms(started_at, ended_at)
    ((ended_at - started_at) * 1000).round
  end

  def log_attempt(_lock_key, _executions)
    nil
  end

  def handle_failed_lock_acquisition(lock_key)
    raise LockAcquisitionError, "Failed to acquire lock for key: #{lock_key}"
  end
end

# Actual response from Instagram webhook (both via Facebook page and Instagram direct)
# [
#   {
#     "time": <timestamp>,
#     "id": <INSTAGRAM_USER_ID>,
#     "messaging": [
#       {
#         "sender": {
#           "id": <INSTAGRAM_USER_ID>
#         },
#         "recipient": {
#           "id": <INSTAGRAM_USER_ID>
#         },
#         "timestamp": <timestamp>,
#         "message": {
#           "mid": <MESSAGE_ID>,
#           "text": <MESSAGE_TEXT>
#         }
#       }
#     ]
#   }
# ]

# Instagram's webhook via Instagram direct testing quirk: Test payloads vs Actual payloads
# When testing in Facebook's developer dashboard, you'll get a Page-style
# payload with a "changes" object. But don't be fooled! Real Instagram DMs
# arrive in the familiar Messenger format with a "messaging" array.
# This apparent inconsistency is actually by design - Instagram's webhooks
# use different formats for testing vs production to maintain compatibility
# with both Instagram Direct and Facebook Page integrations.
# See: https://developers.facebook.com/docs/instagram-platform/webhooks#event-notifications

# Test response from via Instagram direct
# [
#   {
#     "id": "0",
#     "time": <timestamp>,
#     "changes": [
#       {
#         "field": "messages",
#         "value": {
#           "sender": {
#             "id": "12334"
#           },
#           "recipient": {
#             "id": "23245"
#           },
#           "timestamp": "1527459824",
#           "message": {
#             "mid": "random_mid",
#             "text": "random_text"
#           }
#         }
#       }
#     ]
#   }
# ]

# Test response via Facebook page
# [
#   {
#     "time": <timestamp>,,
#     "id": "0",
#     "messaging": [
#       {
#         "sender": {
#           "id": "12334"
#         },
#         "recipient": {
#           "id": "23245"
#         },
#         "timestamp": <timestamp>,
#         "message": {
#             "mid": "random_mid",
#             "text": "random_text"
#         }
#       }
#     ]
#   }
# ]
