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

    participant_id, fallback_used = derive_lock_participant
    @event_family = detect_event_family
    @fallback_used = fallback_used
    log_delivery_validation

    key = format(::Redis::Alfred::IG_MESSAGE_MUTEX, sender_id: participant_id, ig_account_id: ig_account_id)
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

      messages(entry).each { |messaging| process_single_read(entry, messaging) if read_event?(messaging) }
    end
  end

  def process_single_read(entry, messaging)
    channel, resolver_metadata = resolve_read_channel(entry, messaging)

    if channel.blank?
      log_webhook_event('read_message_missing', messaging: messaging, reason: 'channel_not_found', **resolver_metadata)
      return
    end

    log_webhook_event('read_unlocked', messaging: messaging, **resolver_metadata,
                                       resolved_channel_type: channel.class.name,
                                       resolved_channel_id: channel.id,
                                       resolved_channel_instagram_id: channel.instagram_id)
    ::Instagram::ReadStatusService.new(params: messaging, channel: channel).perform
  end

  def resolve_read_channel(entry, messaging)
    recipient_id = messaging.dig(:recipient, :id)
    entry_id = entry[:id]

    channel = find_channel(recipient_id)
    return [channel, read_resolver_metadata(recipient_id, entry_id, 'recipient')] if channel.present?

    channel = find_facebook_page_channel(entry_id)
    return [channel, read_resolver_metadata(recipient_id, entry_id, 'entry')] if channel.present?

    [nil, read_resolver_metadata(recipient_id, entry_id)]
  end

  def read_resolver_metadata(recipient_id, entry_id, resolved_via = nil)
    {
      recipient_id: recipient_id,
      entry_id: entry_id,
      attempted_candidates: 'recipient,entry'
    }.tap do |metadata|
      metadata[:resolved_via] = resolved_via if resolved_via.present?
    end
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

  # Returns [participant_id, fallback_used] for the lock key.
  # Narrow override: only for single-item message-like deliveries, derive based on event semantics.
  # For mixed/batched/ambiguous deliveries, fall back to the first non-echo sender (original behavior).
  def derive_lock_participant
    msgs = lock_messages
    return [sender_id, true] if msgs.empty?

    # Narrow single-item override
    if msgs.size == 1
      item = msgs.first
      if echo_self_message?(item)
        [item.dig(:recipient, :id), false]
      else
        [item.dig(:sender, :id), false]
      end
    else
      [fallback_lock_participant(msgs), true]
    end
  end

  # Original multi-item derivation: return the first non-echo-self sender, or the first echo recipient.
  def fallback_lock_participant(msgs)
    echo_recipient_id = nil
    msgs.each do |messaging|
      return messaging.dig(:sender, :id) unless echo_self_message?(messaging)

      echo_recipient_id ||= messaging.dig(:recipient, :id)
    end
    echo_recipient_id
  end

  def echo_self_message?(messaging)
    agent_message_via_echo?(messaging) && messaging&.dig(:sender, :id) == ig_account_id
  end

  def lock_messages
    @lock_messages ||= Array(@entries).flat_map { |entry| messages(entry.with_indifferent_access).select { |m| message_event?(m) } }
  end

  def detect_event_family
    msgs = lock_messages
    return 'none' if msgs.empty?

    has_echo = msgs.any? { |m| agent_message_via_echo?(m) }
    has_inbound = msgs.any? { |m| !agent_message_via_echo?(m) }
    return 'mixed' if has_echo && has_inbound
    return 'echo' if has_echo

    'inbound'
  end

  # TODO: Remove after contention analysis (Phase 1 temporary logging)
  def log_delivery_validation
    msgs = lock_messages
    entry_count = Array(@entries).size
    messaging_count = msgs.size
    has_echo = msgs.any? { |m| agent_message_via_echo?(m) }
    distinct_ids = msgs.flat_map { |m| [m.dig(:sender, :id), m.dig(:recipient, :id)] }.compact.uniq

    Rails.logger.info(
      "[#{self.class.name}] event=delivery_validation ig_account_id=#{ig_account_id} " \
      "entry_count=#{entry_count} messaging_count=#{messaging_count} " \
      "has_echo=#{has_echo} fallback_used=#{@fallback_used} " \
      "event_family=#{@event_family} distinct_participant_ids=#{distinct_ids.join(',')}"
    )
  end

  def find_channel(instagram_id)
    find_instagram_channel(instagram_id) || find_facebook_page_channel(instagram_id)
  end

  def find_instagram_channel(instagram_id)
    Channel::Instagram.find_by(instagram_id: instagram_id)
  end

  def find_facebook_page_channel(instagram_id)
    Channel::FacebookPage.find_by(instagram_id: instagram_id)
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
      "[#{self.class.name}] event=lock_#{event} lock_key=#{lock_key} sender_id=#{sender_id} " \
      "ig_account_id=#{ig_account_id} event_family=#{@event_family} fallback_used=#{@fallback_used} #{details}".strip
    )
  end

  def log_lock_retry(lock_key:, **metadata)
    details = metadata.map { |attribute, value| "#{attribute}=#{value}" }.join(' ')
    Rails.logger.warn(
      "[#{self.class.name}] event=lock_retry_scheduled lock_key=#{lock_key} sender_id=#{sender_id} " \
      "ig_account_id=#{ig_account_id} event_family=#{@event_family} fallback_used=#{@fallback_used} #{details}".strip
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
