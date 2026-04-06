# frozen_string_literal: true

class AiBackend::CreateStoreJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(account_id, user_email)
    account = Account.find(account_id)
    service = AiBackendService::StoreService.new
    store = service.create_store(account, user_email)
    persist_store_mapping(account, store)

    Rails.logger.info("Successfully created store for account_id: #{account_id} in AI Backend")
  rescue AiBackendService::StoreService::StoreError => e
    account = Account.find(account_id)
    service ||= AiBackendService::StoreService.new
    existing_store = recover_existing_store(service, account_id)
    if existing_store
      persist_store_mapping(account, existing_store)
      Rails.logger.info("Recovered existing AI Backend store mapping for account_id: #{account_id}")
      return
    end

    Rails.logger.error("Failed to create store for account_id: #{account_id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Failed to create store for account_id: #{account_id} - #{e.message}")
    raise
  end

  private

  def persist_store_mapping(account, store)
    return unless store.respond_to?(:id) && store.id.present?

    account.set_ai_backend_store_id!(store.id, external_id: store.external_id)
  rescue StandardError => e
    Rails.logger.error("Failed to persist AI Backend store mapping for account_id: #{account.id} - #{e.message}")
    raise
  end

  def recover_existing_store(service, account_id)
    service.get_store(account_id)
  rescue AiBackendService::StoreService::StoreError
    nil
  end
end
