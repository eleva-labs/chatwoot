# frozen_string_literal: true

class AiBackend::CreateUserJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(user_id, store_id)
    user = User.find(user_id)
    service = AiBackendService::UserService.new
    service.create_user(user, store_id)

    Rails.logger.info("Successfully created user for user_id: #{user_id} in AI Backend")
  rescue StandardError => e
    Rails.logger.error("Failed to create user for user_id: #{user_id} - #{e.message}")
    raise
  end
end
