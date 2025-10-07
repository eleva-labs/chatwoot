# frozen_string_literal: true

class AiBackend::DeleteUserJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(user_id)
    service = AiBackendService::UserService.new
    service.delete_user(user_id)

    Rails.logger.info("Successfully deleted user for user_id: #{user_id} from AI Backend")
  rescue StandardError => e
    Rails.logger.error("Failed to delete user for user_id: #{user_id} - #{e.message}")
    raise
  end
end
