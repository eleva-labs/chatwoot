# frozen_string_literal: true

class AiBackend::CreateChannelJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(inbox_id, account_id)
    inbox = Inbox.find(inbox_id)
    service = AiBackendService::ChannelService.new
    service.create_channel(inbox, account_id)

    Rails.logger.info("Successfully created channel for inbox_id: #{inbox_id} in AI Backend")
  rescue StandardError => e
    Rails.logger.error("Failed to create channel for inbox_id: #{inbox_id} - #{e.message}")
    raise
  end
end
