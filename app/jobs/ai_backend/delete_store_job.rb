# frozen_string_literal: true

class AiBackend::DeleteStoreJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(account_id, ai_backend_store_id = nil)
    if ai_backend_store_id.present?
      service = AiBackendService::StoreService.new(id_type: AiBackendService::Constants::IdType::INTERNAL)
      service.delete_store(ai_backend_store_id)
    else
      service = AiBackendService::StoreService.new
      service.delete_store(account_id)
    end

    Rails.logger.info("Successfully deleted store for account_id: #{account_id} from AI Backend")
  rescue StandardError => e
    Rails.logger.error("Failed to delete store for account_id: #{account_id} - #{e.message}")
    raise
  end
end
