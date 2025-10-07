# frozen_string_literal: true

class AiBackend::DeleteChannelJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(inbox_id, account_id)
    service = AiBackendService::ChannelService.new
    service.delete_channel(inbox_id, account_id)

    Rails.logger.info("Successfully deleted channel for inbox_id: #{inbox_id} from AI Backend")
  rescue StandardError => e
    Rails.logger.error("Failed to delete channel for inbox_id: #{inbox_id} - #{e.message}")
    raise
  end
end
