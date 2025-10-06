class AiBackendService::SetupService
  class SetupError < StandardError; end

  def self.setup_store(account, user_email)
    new.setup_store(account, user_email)
  end

  def setup_store(account, user_email)
    store_service.create_store(account, user_email)

    # NOTE: Configuration creation removed - AI backend manages all configs with defaults
    # The AI backend will automatically create:
    # - general_store_config
    # - messaging_config
    # - conversation_config
    # - notifications_config
    # - ecommerce_config
    # - calendly_config

  rescue AiBackendService::StoreService::StoreError => e
    Rails.logger.error "AI Backend setup failed: #{e.message}"
    raise SetupError, "AI Backend setup failed: #{e.message}"
  end

  private

  def store_service
    @store_service ||= AiBackendService::StoreService.new
  end
end
