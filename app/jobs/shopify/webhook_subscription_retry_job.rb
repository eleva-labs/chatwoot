module Shopify
  class WebhookSubscriptionRetryJob < ApplicationJob
    queue_as :default
    
    # Configure retry behavior for webhook processing
    retry_on StandardError, wait: :exponentially_longer, attempts: 5
    discard_on ActiveRecord::RecordNotFound
    
    def perform(integration_hook_id, previous_failure_result, retry_count: 1, max_retries: 3)
      integration_hook = Integrations::Hook.find(integration_hook_id)
      
      Rails.logger.info "Retrying webhook subscription", {
        hook_id: integration_hook.id,
        retry_count: retry_count,
        max_retries: max_retries,
        previous_error: previous_failure_result[:error]
      }
      
      # Attempt subscription again
      service_result = Shopify::WebhookSubscriptionService.call(integration_hook)
      
      if service_result[:success]
        handle_retry_success(integration_hook, service_result, retry_count)
      elsif retry_count < max_retries
        schedule_next_retry(integration_hook_id, service_result, retry_count + 1, max_retries)
      else
        handle_final_retry_failure(integration_hook, service_result, retry_count)
      end
    end
    
    private
    
    def handle_retry_success(integration_hook, result, retry_count)
      Rails.logger.info "Webhook subscription retry succeeded", {
        hook_id: integration_hook.id,
        retry_count: retry_count,
        subscribed_topics: result[:subscribed_topics]
      }
      
      # Update integration hook settings
      settings = integration_hook.settings || {}
      settings.merge!({
        'compliance_webhooks_pending' => false,
        'compliance_webhooks_subscribed' => true,
        'compliance_webhooks_subscribed_at' => Time.current.iso8601,
        'webhook_subscription_retry_succeeded_at' => Time.current.iso8601,
        'webhook_subscription_retry_count' => retry_count,
        'subscribed_topics_count' => result[:subscribed_topics]
      })
      
      # Remove failure indicators
      settings.delete('webhook_subscription_failure_reason')
      settings.delete('webhook_subscription_retry_queued_at')
      
      integration_hook.update!(settings: settings)
    end
    
    def schedule_next_retry(integration_hook_id, failure_result, next_retry_count, max_retries)
      # Calculate exponential backoff delay
      delay = calculate_retry_delay(next_retry_count)
      
      Rails.logger.info "Scheduling next webhook subscription retry", {
        hook_id: integration_hook_id,
        next_retry_count: next_retry_count,
        delay_minutes: delay,
        error: failure_result[:error]
      }
      
      # Schedule next retry
      Shopify::WebhookSubscriptionRetryJob.set(wait: delay.minutes).perform_later(
        integration_hook_id,
        failure_result,
        retry_count: next_retry_count,
        max_retries: max_retries
      )
    end
    
    def handle_final_retry_failure(integration_hook, result, final_retry_count)
      Rails.logger.error "Webhook subscription failed after all retries", {
        hook_id: integration_hook.id,
        final_retry_count: final_retry_count,
        final_error: result[:error],
        requires_manual_intervention: true
      }
      
      # Mark as permanently failed
      settings = integration_hook.settings || {}
      settings.merge!({
        'compliance_webhooks_pending' => false,
        'compliance_webhooks_subscribed' => false,
        'webhook_subscription_permanently_failed_at' => Time.current.iso8601,
        'webhook_subscription_final_retry_count' => final_retry_count,
        'webhook_subscription_final_error' => result[:error],
        'requires_manual_intervention' => true
      })
      
      integration_hook.update!(settings: settings)
      
      # Send alert for manual intervention
      send_manual_intervention_alert(integration_hook, result)
    end
    
    def calculate_retry_delay(retry_count)
      # Exponential backoff: 5, 15, 45 minutes
      base_delay = 5
      base_delay * (3 ** (retry_count - 1))
    end
    
    def send_manual_intervention_alert(integration_hook, result)
      Rails.logger.error "ALERT: Manual intervention required for webhook subscription", {
        hook_id: integration_hook.id,
        shop_domain: integration_hook.reference_id,
        account_id: integration_hook.account_id,
        error: result[:error],
        action_required: 'manual_webhook_subscription_setup'
      }
      
      # Implementation depends on your alerting system
      # Could send to Slack, email, PagerDuty, etc.
    end

    # Add monitoring dashboard query methods
    def self.webhook_subscription_health_report
      total_hooks = Integrations::Hook.where(app_id: 'shopify').count
      
      successful_subscriptions = Integrations::Hook.where(app_id: 'shopify')
                                                   .where("settings->>'compliance_webhooks_subscribed' = 'true'")
                                                   .count
      
      pending_subscriptions = Integrations::Hook.where(app_id: 'shopify')
                                                .where("settings->>'compliance_webhooks_pending' = 'true'")
                                                .count
      
      failed_subscriptions = Integrations::Hook.where(app_id: 'shopify')
                                               .where("settings->>'requires_manual_intervention' = 'true'")
                                               .count
      
      {
        total_hooks: total_hooks,
        successful_subscriptions: successful_subscriptions,
        pending_subscriptions: pending_subscriptions,
        failed_subscriptions: failed_subscriptions,
        success_rate: total_hooks > 0 ? (successful_subscriptions.to_f / total_hooks * 100).round(2) : 0
      }
    end
  end
end 