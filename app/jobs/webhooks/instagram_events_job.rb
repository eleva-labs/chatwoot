class Webhooks::InstagramEventsJob < MutexApplicationJob
  queue_as :default

  LOCK_RETRY_WAIT = lambda do |executions|
    base_wait_seconds = [2 * (2**(executions - 1)), 30].min
    base_wait_seconds + (base_wait_seconds * rand * 0.15)
  end

  retry_on LockAcquisitionError, wait: LOCK_RETRY_WAIT, attempts: 8

  # Message-like events require the Redis mutex; read events do not.
  MESSAGE_EVENTS = %i[message].freeze

  def perform(entries)
    @entries = entries
    process_read_events(entries)
    return unless message_work?(entries)

    key = format(::Redis::Alfred::IG_MESSAGE_MUTEX, sender_id: lock_participant_id, ig_account_id: ig_account_id)
    lock_started_at = monotonic_time
    @lock_acquired_at = nil

    with_lock(key, 30.seconds) do
      @lock_acquired_at = monotonic_time
      process_message_entries(entries)
    end
  rescue LockAcquisitionError
    log_lock_retry(lock_key: key, lock_attempt_ms: elapsed_ms(lock_started_at, monotonic_time), retry_attempt: lock_attempt)
    raise
  ensure
    log_lock_release(key, lock_started_at) if lock_started_at && @lock_acquired_at
  end

  private

  def process_read_events(entries)
    entries.each do |entry|
      entry = entry.with_indifferent_access
      next if test_event?(entry)

      messages(entry).each { |messaging| process_single_read(messaging) if read_event?(messaging) }
    end
  end

  def process_single_read(messaging)
    channel = find_channel(instagram_id(messaging))

    if channel.blank?
      log_webhook_event('read_message_missing', messaging: messaging, reason: 'channel_not_found')
      return
    end

    log_webhook_event('read_unlocked', messaging: messaging)
    ::Instagram::ReadStatusService.new(params: messaging, channel: channel).perform
  end

  def read_event?(messaging)
    messaging.key?(:read) && !message_event?(messaging)
  end

  def process_message_entries(entries)
    entries.each do |entry|
      entry = entry.with_indifferent_access
      if test_event?(entry)
        process_test_event(entry)
      else
        process_message_items(entry)
      end
    end
  end

  def process_message_items(entry)
    messages(entry).each do |messaging|
      next if read_event?(messaging)

      unless message_event?(messaging)
        log_webhook_event('unsupported_event_skipped', messaging: messaging)
        next
      end

      channel = find_channel(instagram_id(messaging))
      next if channel.blank?

      log_webhook_event('message_locked', messaging: messaging)
      dispatch_message(messaging, channel)
    end
  end

  def dispatch_message(messaging, channel)
    if channel.is_a?(Channel::Instagram)
      ::Instagram::MessageText.new(messaging, channel).perform
    else
      ::Instagram::Messenger::MessageText.new(messaging, channel).perform
    end
  end

  def message_event?(messaging)
    MESSAGE_EVENTS.any? { |key| messaging.key?(key) }
  end

  def message_work?(entries)
    entries.any? do |entry|
      entry = entry.with_indifferent_access
      next true if test_event?(entry)

      messages(entry).any? { |m| message_event?(m) }
    end
  end

  def agent_message_via_echo?(messaging)
    messaging&.dig(:message, :is_echo).present?
  end

  def test_event?(entry)
    entry[:changes].present?
  end

  def process_test_event(entry)
    messaging = entry[:changes].first&.dig(:value) if entry[:changes].present?
    Instagram::TestEventService.new(messaging).perform if messaging.present?
  end

  def instagram_id(messaging)
    agent_message_via_echo?(messaging) ? messaging[:sender][:id] : messaging[:recipient][:id]
  end

  def ig_account_id
    @entries&.first&.dig(:id)
  end

  def sender_id
    @entries&.dig(0, :messaging, 0, :sender, :id)
  end

  def lock_participant_id
    echo_recipient_id = nil
    lock_messages.each do |messaging|
      return messaging.dig(:sender, :id) unless echo_self_message?(messaging)

      echo_recipient_id ||= messaging.dig(:recipient, :id)
    end
    echo_recipient_id
  end

  def echo_self_message?(messaging)
    agent_message_via_echo?(messaging) && messaging&.dig(:sender, :id) == ig_account_id
  end

  def lock_messages
    Array(@entries).flat_map { |entry| messages(entry.with_indifferent_access).select { |m| message_event?(m) } }
  end

  def find_channel(instagram_id)
    Channel::Instagram.find_by(instagram_id: instagram_id) || Channel::FacebookPage.find_by(instagram_id: instagram_id)
  end

  def messages(entry)
    (entry[:messaging].presence || entry[:standby] || [])
  end

  def log_webhook_event(event, messaging: nil, **metadata)
    mid = messaging&.dig(:message, :mid) || messaging&.dig(:read, :mid)
    sender = messaging&.dig(:sender, :id)
    details = metadata.map { |k, v| "#{k}=#{v}" }.join(' ')
    Rails.logger.info("[#{self.class.name}] event=#{event} ig_account_id=#{ig_account_id} sender=#{sender} mid=#{mid} #{details}".strip)
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
