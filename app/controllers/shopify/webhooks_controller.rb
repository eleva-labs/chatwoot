# frozen_string_literal: true

class Shopify::WebhooksController < ActionController::API
  include Shopify::IntegrationHelper

  before_action :verify_content_type
  before_action :verify_payload_size
  before_action :verify_webhook_signature
  before_action :parse_webhook_payload

  # Maximum allowed payload size (1MB)
  MAX_PAYLOAD_SIZE = 1.megabyte

  # POST /shopify/webhooks/customers_data_request
  def customers_data_request
    Rails.logger.info "Received customers_data_request webhook for shop: #{@payload['shop_domain']}"

    # Validate required payload fields
    return head :bad_request unless payload_valid_for_customers_data_request?

    # Enqueue background job for processing
    Shopify::CustomersDataRequestJob.perform_later(@payload.to_h)

    Rails.logger.info 'Enqueued customers_data_request job', {
      shop_domain: @payload['shop_domain'],
      customer_id: @payload.dig('customer', 'id'),
      data_request_id: @payload.dig('data_request', 'id'),
      request_id: request.uuid
    }

    head :ok
  rescue StandardError => e
    Rails.logger.error 'Failed to enqueue customers_data_request job', {
      shop_domain: @payload['shop_domain'],
      error: e.message,
      request_id: request.uuid
    }

    # Still return 200 OK to Shopify to prevent retries
    head :ok
  end

  # POST /shopify/webhooks/customers_redact
  def customers_redact
    Rails.logger.info "Received customers_redact webhook for shop: #{@payload['shop_domain']}"

    return head :bad_request unless payload_valid_for_customers_redact?

    Shopify::CustomersRedactJob.perform_later(@payload.to_h)

    Rails.logger.info 'Enqueued customers_redact job', {
      shop_domain: @payload['shop_domain'],
      customer_id: @payload.dig('customer', 'id'),
      request_id: request.uuid
    }

    head :ok
  rescue StandardError => e
    Rails.logger.error 'Failed to enqueue customers_redact job', {
      shop_domain: @payload['shop_domain'],
      error: e.message,
      request_id: request.uuid
    }
    head :ok
  end

  # POST /shopify/webhooks/shop_redact
  def shop_redact
    Rails.logger.info "Received shop_redact webhook for shop: #{@payload['shop_domain']}"

    return head :bad_request unless payload_valid_for_shop_redact?

    Shopify::ShopRedactJob.perform_later(@payload.to_h)

    Rails.logger.info 'Enqueued shop_redact job', {
      shop_domain: @payload['shop_domain'],
      shop_id: @payload['shop_id'],
      request_id: request.uuid
    }

    head :ok
  rescue StandardError => e
    Rails.logger.error 'Failed to enqueue shop_redact job', {
      shop_domain: @payload['shop_domain'],
      error: e.message,
      request_id: request.uuid
    }
    head :ok
  end

  private

  def verify_content_type
    unless request.content_type == 'application/json'
      Rails.logger.warn "Invalid content type from IP: #{request.remote_ip}", {
        content_type: request.content_type,
        user_agent: request.user_agent
      }
      head :bad_request
      return
    end
  end

  def verify_payload_size
    content_length = request.content_length
    if content_length && content_length > MAX_PAYLOAD_SIZE
      Rails.logger.warn "Payload too large from IP: #{request.remote_ip}", {
        content_length: content_length,
        max_allowed: MAX_PAYLOAD_SIZE
      }
      head :request_entity_too_large
      return
    end
  end

  def verify_webhook_signature
    start_time = Time.current
    
    unless verify_shopify_webhook(request)
      verification_duration = ((Time.current - start_time) * 1000).round(2)
      
      Rails.logger.warn "Invalid Shopify webhook signature from IP: #{request.remote_ip}", {
        verification_duration_ms: verification_duration,
        user_agent: request.user_agent,
        request_id: request.uuid
      }
      head :unauthorized
      return
    end

    # Log successful verification for monitoring
    verification_duration = ((Time.current - start_time) * 1000).round(2)
    Rails.logger.debug "Webhook signature verified", {
      verification_duration_ms: verification_duration,
      request_id: request.uuid
    }
  end

  def parse_webhook_payload
    @payload = JSON.parse(request.body.read)
    request.body.rewind
    
    # Basic payload structure validation
    unless @payload.is_a?(Hash)
      Rails.logger.error "Webhook payload is not a valid JSON object", {
        payload_class: @payload.class.name,
        request_id: request.uuid
      }
      head :bad_request
      return
    end
    
  rescue JSON::ParserError => e
    Rails.logger.error "Invalid JSON in webhook payload: #{e.message}", {
      request_id: request.uuid,
      content_length: request.content_length
    }
    head :bad_request
    return
  end

  def payload_valid_for_customers_data_request?
    valid = @payload['shop_domain'].present? &&
            @payload['customer'].present? &&
            (@payload['customer']['id'].present? || @payload['customer']['email'].present?)
    
    unless valid
      Rails.logger.warn "Invalid customers_data_request payload", {
        has_shop_domain: @payload['shop_domain'].present?,
        has_customer: @payload['customer'].present?,
        has_customer_id: @payload.dig('customer', 'id').present?,
        has_customer_email: @payload.dig('customer', 'email').present?,
        request_id: request.uuid
      }
    end
    
    valid
  end

  def payload_valid_for_customers_redact?
    valid = @payload['shop_domain'].present? && @payload['customer'].present?
    
    unless valid
      Rails.logger.warn "Invalid customers_redact payload", {
        has_shop_domain: @payload['shop_domain'].present?,
        has_customer: @payload['customer'].present?,
        request_id: request.uuid
      }
    end
    
    valid
  end

  def payload_valid_for_shop_redact?
    valid = @payload['shop_domain'].present? && @payload['shop_id'].present?
    
    unless valid
      Rails.logger.warn "Invalid shop_redact payload", {
        has_shop_domain: @payload['shop_domain'].present?,
        has_shop_id: @payload['shop_id'].present?,
        request_id: request.uuid
      }
    end
    
    valid
  end
end