class Shopify::CallbacksController < ApplicationController
  include Shopify::IntegrationHelper

  def show
    verify_account!

    @response = oauth_client.auth_code.get_token(
      params[:code],
      redirect_uri: '/shopify/callback'
    )

    handle_response
  rescue StandardError => e
    Rails.logger.error("Shopify callback error: #{e.message}")
    redirect_to "#{redirect_uri}?error=true"
  end

  private

  def verify_account!
    @account_id = verify_shopify_token(params[:state])
    raise StandardError, 'Invalid state parameter' if account.blank?
  end

  def handle_response
    begin
      # Create or update Integrations::Hook
      integration_hook = create_or_update_integration_hook
      
      # Subscribe to compliance webhooks
      webhook_subscription_result = subscribe_to_compliance_webhooks(integration_hook)
      
      # Handle subscription results
      handle_webhook_subscription_result(webhook_subscription_result, integration_hook)
      
      # Continue with existing success flow
      redirect_to shopify_integration_url
      
    rescue => e
      Rails.logger.error "Installation failed", {
        error: e.message,
        backtrace: e.backtrace.first(10),
        shop_domain: params[:shop]
      }
      
      handle_installation_failure(e)
    end
  end

  def create_or_update_integration_hook
    shop_domain = params[:shop]
    access_token = parsed_body['access_token']
    
    integration_hook = account.hooks.find_or_initialize_by(
      app_id: 'shopify',
      reference_id: shop_domain
    )
    
    integration_hook.assign_attributes(
      access_token: access_token,
      status: 'enabled',
      settings: build_integration_settings
    )
    
    integration_hook.save!
    
    Rails.logger.info "Integration hook created/updated", {
      hook_id: integration_hook.id,
      account_id: account.id,
      shop_domain: shop_domain
    }
    
    integration_hook
  end

  def build_integration_settings
    {
      'scope' => parsed_body['scope'],
      'shop_domain' => params[:shop],
      'installation_date' => Time.current.iso8601,
      'oauth_completed_at' => Time.current.iso8601,
      'api_version' => '2024-10',
      'compliance_webhooks_pending' => true
    }
  end

  def subscribe_to_compliance_webhooks(integration_hook)
    Rails.logger.info "Starting compliance webhook subscription", {
      hook_id: integration_hook.id,
      shop_domain: integration_hook.reference_id,
      account_id: integration_hook.account_id
    }
    
    # Check feature flag if implemented
    unless compliance_webhooks_enabled?
      Rails.logger.info "Compliance webhooks disabled by feature flag", {
        hook_id: integration_hook.id
      }
      return { success: true, skipped: true, reason: 'feature_flag_disabled' }
    end
    
    begin
      # Call the webhook subscription service
      service_result = Shopify::WebhookSubscriptionService.call(integration_hook)
      
      Rails.logger.info "Webhook subscription service completed", {
        hook_id: integration_hook.id,
        success: service_result[:success],
        subscribed_topics: service_result[:subscribed_topics],
        total_topics: service_result[:total_topics]
      }
      
      service_result
      
    rescue => e
      Rails.logger.error "Webhook subscription service failed", {
        hook_id: integration_hook.id,
        error: e.message,
        backtrace: e.backtrace.first(5)
      }
      
      {
        success: false,
        error: e.message,
        exception: e.class.name
      }
    end
  end

  def compliance_webhooks_enabled?
    # Check feature flag implementation if available
    return true unless defined?(Features)
    
    Features.enabled?(:shopify_compliance_webhooks, default: true)
  end

  def handle_webhook_subscription_result(result, integration_hook)
    if result[:skipped]
      Rails.logger.info "Webhook subscription skipped", {
        hook_id: integration_hook.id,
        reason: result[:reason]
      }
      return
    end
    
    if result[:success]
      handle_successful_webhook_subscription(result, integration_hook)
    else
      handle_failed_webhook_subscription(result, integration_hook)
    end
  end

  def handle_successful_webhook_subscription(result, integration_hook)
    Rails.logger.info "All compliance webhooks subscribed successfully", {
      hook_id: integration_hook.id,
      subscribed_topics: result[:subscribed_topics],
      total_topics: result[:total_topics]
    }
    
    # Update integration hook settings
    update_hook_after_successful_subscription(integration_hook, result)
    
    # Log success for monitoring
    track_webhook_subscription_success(integration_hook, result)
  end

  def handle_failed_webhook_subscription(result, integration_hook)
    Rails.logger.error "Webhook subscription failed during installation", {
      hook_id: integration_hook.id,
      error: result[:error],
      subscribed_topics: result[:subscribed_topics] || 0,
      total_topics: result[:total_topics] || 3
    }
    
    # Update integration hook to indicate partial failure
    update_hook_after_failed_subscription(integration_hook, result)
    
    # Decide whether to fail the installation or continue
    if should_fail_installation_on_webhook_error?
      raise "Critical webhook subscription failure: #{result[:error]}"
    else
      # Log for manual follow-up but don't fail installation
      queue_webhook_subscription_retry(integration_hook, result)
    end
  end

  def should_fail_installation_on_webhook_error?
    # Configuration-driven decision on whether webhook failures should block installation
    ENV.fetch('FAIL_INSTALLATION_ON_WEBHOOK_ERROR', 'false') == 'true'
  end

  def queue_webhook_subscription_retry(integration_hook, failed_result)
    Rails.logger.info "Queueing webhook subscription for retry", {
      hook_id: integration_hook.id,
      shop_domain: integration_hook.reference_id
    }
    
    # Enqueue background job for retry
    Shopify::WebhookSubscriptionRetryJob.perform_later(
      integration_hook.id,
      failed_result,
      retry_count: 1
    )
    
    # Update hook settings to indicate retry queued
    settings = integration_hook.settings || {}
    settings.merge!({
      'compliance_webhooks_pending' => true,
      'webhook_subscription_retry_queued_at' => Time.current.iso8601,
      'webhook_subscription_failure_reason' => failed_result[:error]
    })
    
    integration_hook.update!(settings: settings)
  end

  def update_hook_after_successful_subscription(integration_hook, result)
    settings = integration_hook.settings || {}
    settings.merge!({
      'compliance_webhooks_pending' => false,
      'compliance_webhooks_subscribed' => true,
      'compliance_webhooks_subscribed_at' => Time.current.iso8601,
      'subscribed_topics_count' => result[:subscribed_topics],
      'webhook_subscription_success' => true
    })
    
    # Remove any previous failure indicators
    settings.delete('webhook_subscription_failure_reason')
    settings.delete('webhook_subscription_retry_queued_at')
    
    integration_hook.update!(settings: settings)
  end

  def update_hook_after_failed_subscription(integration_hook, result)
    settings = integration_hook.settings || {}
    settings.merge!({
      'compliance_webhooks_pending' => true,
      'compliance_webhooks_subscribed' => false,
      'webhook_subscription_failed_at' => Time.current.iso8601,
      'webhook_subscription_failure_reason' => result[:error],
      'failed_topics_count' => (result[:total_topics] || 3) - (result[:subscribed_topics] || 0),
      'webhook_subscription_success' => false
    })
    
    integration_hook.update!(settings: settings)
  end

  def handle_installation_failure(error)
    Rails.logger.error "Shopify installation failed", {
      error: error.message,
      shop_domain: params[:shop],
      backtrace: error.backtrace.first(5)
    }
    
    # Render appropriate error response
    if error.message.include?('webhook subscription')
      redirect_to "#{redirect_uri}?error=webhook_setup_failed"
    else
      redirect_to "#{redirect_uri}?error=true"
    end
  end

  def track_webhook_subscription_success(integration_hook, result)
    success_metrics = {
      event: 'webhook_subscription_success',
      hook_id: integration_hook.id,
      account_id: integration_hook.account_id,
      shop_domain: integration_hook.reference_id,
      subscribed_topics: result[:subscribed_topics],
      total_topics: result[:total_topics],
      timestamp: Time.current.iso8601
    }
    
    Rails.logger.info "Webhook subscription success metrics", success_metrics
    
    # Send to monitoring system if configured
    send_to_monitoring_system('webhook_subscription_success', success_metrics)
  end

  def send_to_monitoring_system(event_type, metrics)
    # Implementation depends on your monitoring setup
    # Could be StatsD, Prometheus, custom metrics endpoint, etc.
    
    begin
      # Example: Custom metrics endpoint
      if ENV['METRICS_ENDPOINT'].present?
        HTTParty.post(ENV['METRICS_ENDPOINT'], {
          body: metrics.to_json,
          headers: { 'Content-Type' => 'application/json' }
        })
      end
      
    rescue => e
      Rails.logger.warn "Failed to send metrics", {
        error: e.message,
        event_type: event_type
      }
    end
  end

  def parsed_body
    @parsed_body ||= @response.response.parsed
  end

  def oauth_client
    OAuth2::Client.new(
      client_id,
      client_secret,
      {
        site: "https://#{params[:shop]}",
        authorize_url: '/admin/oauth/authorize',
        token_url: '/admin/oauth/access_token'
      }
    )
  end

  def account
    @account ||= Account.find(@account_id)
  end

  def account_id
    @account_id ||= params[:state].split('_').first
  end

  def shopify_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{account.id}/settings/integrations/shopify"
  end

  def redirect_uri
    return shopify_integration_url if account

    ENV.fetch('FRONTEND_URL', nil)
  end
end
