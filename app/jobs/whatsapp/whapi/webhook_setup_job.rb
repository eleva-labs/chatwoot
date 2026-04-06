class Whatsapp::Whapi::WebhookSetupJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(channel_id)
    channel = Channel::Whatsapp.find_by(id: channel_id)
    return unless channel&.provider == 'whapi'

    config_object = channel.provider_config_object
    channel_token = config_object.whapi_channel_token
    return if channel_token.blank?

    webhook_service = Whatsapp::WebhookUrlService.new
    webhook_url = webhook_service.generate_webhook_url
    
    service = Whatsapp::Partner::WhapiPartnerService.new
    service.update_channel_webhook(channel_token: channel_token, webhook_url: webhook_url)
    
    # Mark webhook as configured successfully
    config_object.set_webhook_configured(webhook_url)
    
    # Broadcast success event to frontend
    broadcast_webhook_configured(channel)
    
    Rails.logger.info "[WhapiWebhookSetup] Webhook configured successfully for channel #{channel_id}"
  rescue Timeout::Error => e
    # Catch all timeout exceptions (Net::ReadTimeout, Net::OpenTimeout, Net::WriteTimeout, etc.)
    # Timeout::Error is the superclass for all timeout-related exceptions in Ruby
    Rails.logger.warn "[WhapiWebhookSetup] Webhook setup timeout for channel #{channel_id}: #{e.message}"
    config_object&.set_webhook_failed("Timeout: #{e.message}")
    raise
  rescue HTTParty::Error, Net::HTTPError => e
    Rails.logger.error "[WhapiWebhookSetup] Webhook setup HTTP error for channel #{channel_id}: #{e.message}"
    config_object&.set_webhook_failed("HTTP Error: #{e.message}")
    raise
  rescue JSON::ParserError => e
    Rails.logger.error "[WhapiWebhookSetup] Webhook setup JSON parse error for channel #{channel_id}: #{e.message}"
    config_object&.set_webhook_failed("JSON Parse Error: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error "[WhapiWebhookSetup] Unexpected webhook setup error for channel #{channel_id}: #{e.class} - #{e.message}"
    config_object&.set_webhook_failed("Unknown Error: #{e.message}")
    raise
  end

  private

  def broadcast_webhook_configured(channel)
    Rails.logger.info "[WhapiWebhookSetup] Broadcasting whapi_webhook_configured event for inbox #{channel.inbox.id}, account #{channel.account_id}"
    ActionCable.server.broadcast(
      "account_#{channel.account_id}",
      {
        event: 'whapi_webhook_configured',
        data: {
          inbox_id: channel.inbox.id,
          account_id: channel.account_id
        }
      }
    )
    Rails.logger.info "[WhapiWebhookSetup] Broadcast sent successfully for inbox #{channel.inbox.id}"
  end
end
