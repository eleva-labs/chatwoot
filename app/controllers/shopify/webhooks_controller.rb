# frozen_string_literal: true

class Shopify::WebhooksController < ActionController::API
  include Shopify::IntegrationHelper

  before_action :verify_content_type
  before_action :verify_payload_size
  # before_action :verify_webhook_signature  # TEMPORARILY DISABLED FOR POSTMAN TESTING
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

    Rails.logger.info "Enqueued customers_data_request job: #{job_context_for_request.to_json}"

    head :ok
  rescue StandardError => e
    Rails.logger.error "Failed to enqueue customers_data_request job: #{error_context_for_request(e).to_json}"

    # Still return 200 OK to Shopify to prevent retries
    head :ok
  end

  # POST /shopify/webhooks/customers_redact
  def customers_redact
    Rails.logger.info "Received customers_redact webhook for shop: #{@payload['shop_domain']}"

    return head :bad_request unless payload_valid_for_customers_redact?

    Shopify::CustomersRedactJob.perform_later(@payload.to_h)

    Rails.logger.info "Enqueued customers_redact job: #{job_context_for_redact.to_json}"

    head :ok
  rescue StandardError => e
    Rails.logger.error "Failed to enqueue customers_redact job: #{error_context_for_redact(e).to_json}"
    head :ok
  end

  # POST /shopify/webhooks/shop_redact
  def shop_redact
    Rails.logger.info "Received shop_redact webhook for shop: #{@payload['shop_domain']}"

    return head :bad_request unless payload_valid_for_shop_redact?

    Shopify::ShopRedactJob.perform_later(@payload.to_h)

    Rails.logger.info "Enqueued shop_redact job: #{job_context_for_shop_redact.to_json}"

    head :ok
  rescue StandardError => e
    Rails.logger.error "Failed to enqueue shop_redact job: #{error_context_for_shop_redact(e).to_json}"
    head :ok
  end

  private

  def verify_content_type
    unless request.content_type == 'application/json'
      Rails.logger.warn "Invalid content type from IP: #{request.remote_ip}, content_type: #{request.content_type}, user_agent: #{request.user_agent}"
      head :bad_request
      return
    end
  end

  def verify_payload_size
    content_length = request.content_length
    if content_length && content_length > MAX_PAYLOAD_SIZE
      Rails.logger.warn "Payload too large from IP: #{request.remote_ip}, content_length: #{content_length}, max_allowed: #{MAX_PAYLOAD_SIZE}"
      head :request_entity_too_large
      return
    end
  end

  def parse_webhook_payload
    @payload = JSON.parse(request.raw_post)
    
    # Basic payload structure validation
    unless @payload.is_a?(Hash)
      Rails.logger.error "Webhook payload is not a valid JSON object: payload_class: #{@payload.class.name}, request_id: #{request.request_id}"
      head :bad_request
      return
    end
    
  rescue JSON::ParserError => e
    Rails.logger.error "Invalid JSON in webhook payload: #{e.message}, request_id: #{request.request_id}, content_length: #{request.content_length}"
    head :bad_request
    return
  end

  def job_context_for_request
    {
      shop_domain: @payload['shop_domain'],
      customer_id: @payload.dig('customer', 'id'),
      data_request_id: @payload.dig('data_request', 'id'),
      request_id: request.request_id
    }
  end

  def error_context_for_request(error)
    {
      shop_domain: @payload ? @payload['shop_domain'] : 'unknown',
      error: error.message,
      request_id: request.request_id
    }
  end

  def job_context_for_redact
    {
      shop_domain: @payload['shop_domain'],
      customer_id: @payload.dig('customer', 'id'),
      request_id: request.request_id
    }
  end

  def error_context_for_redact(error)
    {
      shop_domain: @payload ? @payload['shop_domain'] : 'unknown',
      error: error.message,
      request_id: request.request_id
    }
  end

  def job_context_for_shop_redact
    {
      shop_domain: @payload['shop_domain'],
      shop_id: @payload['shop_id'],
      request_id: request.request_id
    }
  end

  def error_context_for_shop_redact(error)
    {
      shop_domain: @payload ? @payload['shop_domain'] : 'unknown',
      error: error.message,
      request_id: request.request_id
    }
  end

  def payload_valid_for_customers_data_request?
    valid = @payload['shop_domain'].present? &&
            @payload['customer'].present? &&
            (@payload['customer']['id'].present? || @payload['customer']['email'].present?)
    
    unless valid
      Rails.logger.warn "Invalid customers_data_request payload: #{invalid_payload_context.to_json}"
    end
    
    valid
  end

  def payload_valid_for_customers_redact?
    valid = @payload['shop_domain'].present? && @payload['customer'].present?
    
    unless valid
      Rails.logger.warn "Invalid customers_redact payload: #{invalid_payload_context.to_json}"
    end
    
    valid
  end

  def payload_valid_for_shop_redact?
    valid = @payload['shop_domain'].present? && @payload['shop_id'].present?
    
    unless valid
      Rails.logger.warn "Invalid shop_redact payload: #{invalid_payload_context.to_json}"
    end
    
    valid
  end

  def invalid_payload_context
    {
      has_shop_domain: @payload['shop_domain'].present?,
      has_customer: @payload.dig('customer').present?,
      has_customer_id: @payload.dig('customer', 'id').present?,
      has_customer_email: @payload.dig('customer', 'email').present?,
      has_shop_id: @payload.dig('shop_id').present?,
      request_id: request.request_id
    }
  end
end