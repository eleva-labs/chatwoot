# frozen_string_literal: true

class AiBackend::CreateStoreJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(account_id, user_email)
    account = Account.find(account_id)
    service = AiBackendService::StoreService.new
    service.create_store(account, user_email)

    Rails.logger.info("Successfully created store for account_id: #{account_id} in AI Backend")
  rescue StandardError => e
    Rails.logger.error("Failed to create store for account_id: #{account_id} - #{e.message}")
    raise
  end
end
