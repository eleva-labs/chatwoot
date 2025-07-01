module Shopify
  class WebhookSubscriptionService
    include HTTParty
    
    attr_reader :integration_hook, :shop_domain, :access_token, :subscription_results
    
    # Shopify GraphQL Admin API endpoint
    GRAPHQL_ENDPOINT = 'admin/api/2024-10/graphql.json'
    
    # Mandatory compliance webhook topics
    MANDATORY_TOPICS = [
      'customers/data_request',
      'customers/redact',
      'shop/redact'
    ].freeze
    
    def self.call(integration_hook)
      service = new(integration_hook)
      service.subscribe_to_compliance_webhooks
    end

    def initialize(integration_hook)
      @integration_hook = integration_hook
      @shop_domain = extract_shop_domain(integration_hook.reference_id)
      @access_token = integration_hook.access_token
      @subscription_results = {}
      
      validate_initialization!
      log_service_initialization
    end
    
    def subscribe_to_compliance_webhooks
      Rails.logger.info "Starting compliance webhook subscription", service_context
      
      begin
        results = {}
        
        MANDATORY_TOPICS.each do |topic|
          Rails.logger.info "Subscribing to webhook topic", 
                           service_context.merge(topic: topic)
          
          result = subscribe_with_retry(topic)
          results[topic] = result
          
          unless result[:success]
            Rails.logger.error "Failed to subscribe to topic", 
                             service_context.merge(topic: topic, error: result[:error])
            # Continue with other topics even if one fails
            next
          end
        end
        
        @subscription_results = results
        
        # Verify all mandatory topics were subscribed
        success_count = results.count { |_, result| result[:success] }
        all_successful = success_count == MANDATORY_TOPICS.count
        
        Rails.logger.info "Compliance webhook subscription completed", 
                         service_context.merge(
                           successful_topics: success_count,
                           total_topics: MANDATORY_TOPICS.count,
                           all_successful: all_successful
                         )
        
        {
          success: all_successful,
          results: results,
          subscribed_topics: success_count,
          total_topics: MANDATORY_TOPICS.count
        }
        
      rescue => e
        Rails.logger.error "Webhook subscription service failed", 
                         service_context.merge(error: e.message, backtrace: e.backtrace.first(5))
        
        {
          success: false,
          error: e.message,
          results: @subscription_results
        }
      end
    end
    
    private
    
    def service_context
      {
        service: 'WebhookSubscriptionService',
        shop_domain: @shop_domain,
        integration_hook_id: @integration_hook.id,
        account_id: @integration_hook.account_id
      }
    end
    
    def extract_shop_domain(reference_id)
      # Handle both formats: "shop-name" and "shop-name.myshopify.com"
      return reference_id if reference_id.include?('.myshopify.com')
      "#{reference_id}.myshopify.com"
    end

    def log_service_initialization
      Rails.logger.info "Webhook subscription service initialized", {
        shop_domain: @shop_domain,
        account_id: @integration_hook.account_id,
        hook_id: @integration_hook.id,
        has_access_token: @access_token.present?
      }
    end

    def validate_initialization!
      validations = {
        integration_hook_present: @integration_hook.present?,
        access_token_present: @access_token.present?,
        shop_domain_present: @shop_domain.present?,
        correct_app_type: @integration_hook.app_id == 'shopify',
        hook_active: @integration_hook.status == 'enabled'
      }
      
      failed_validations = validations.reject { |_, valid| valid }.keys
      
      if failed_validations.any?
        error_msg = "Service initialization failed: #{failed_validations.join(', ')}"
        Rails.logger.error error_msg, service_context
        raise ArgumentError, error_msg
      end
    end
    
    def subscribe_with_retry(topic, max_attempts = 3)
      attempt = 1
      
      while attempt <= max_attempts
        Rails.logger.info "Webhook subscription attempt", {
          topic: topic,
          attempt: attempt,
          max_attempts: max_attempts
        }
        
        result = subscribe_to_topic(topic)
        
        if result[:success]
          return result
        elsif should_retry_error?(result[:error]) && attempt < max_attempts
          wait_time = calculate_retry_delay(attempt)
          Rails.logger.info "Retrying webhook subscription", {
            topic: topic,
            attempt: attempt,
            wait_time: wait_time,
            error: result[:error]
          }
          
          sleep(wait_time)
          attempt += 1
        else
          Rails.logger.error "Webhook subscription failed after all attempts", {
            topic: topic,
            final_attempt: attempt,
            error: result[:error]
          }
          return result
        end
      end
    end

    def should_retry_error?(error_message)
      retryable_patterns = [
        /timeout/i,
        /rate limit/i,
        /temporarily unavailable/i,
        /internal server error/i,
        /service unavailable/i
      ]
      
      retryable_patterns.any? { |pattern| error_message.match?(pattern) }
    end

    def calculate_retry_delay(attempt)
      # Exponential backoff with jitter
      base_delay = 2 ** attempt
      jitter = rand(0.5..1.5)
      (base_delay * jitter).round(2)
    end

    def subscribe_to_topic(topic)
      webhook_url = build_webhook_url(topic)
      
      Rails.logger.info "Creating webhook subscription", {
        topic: topic,
        webhook_url: webhook_url,
        shop_domain: @shop_domain
      }
      
      mutation_result = create_webhook_subscription(topic, webhook_url)
      
      if mutation_result[:success]
        subscription_data = mutation_result[:data]['webhookSubscriptionCreate']
        
        if subscription_data['userErrors']&.any?
          handle_subscription_errors(topic, subscription_data['userErrors'])
        else
          handle_successful_subscription(topic, subscription_data['webhookSubscription'])
        end
      else
        {
          success: false,
          topic: topic,
          error: mutation_result[:error]
        }
      end
    end

    def build_webhook_url(topic)
      protocol = determine_protocol
      host = determine_host
      path = build_webhook_path(topic)
      
      url = "#{protocol}://#{host}#{path}"
      
      # Validate URL format
      unless valid_webhook_url?(url)
        Rails.logger.error "Invalid webhook URL generated", {
          url: url,
          topic: topic,
          protocol: protocol,
          host: host,
          path: path
        }
        raise "Invalid webhook URL generated: #{url}"
      end
      
      Rails.logger.debug "Generated webhook URL", {
        topic: topic,
        url: url,
        environment: Rails.env
      }
      
      url
    end

    def determine_protocol
      if Rails.env.production? || ENV['FORCE_SSL'] == 'true'
        'https'
      else
        ENV.fetch('WEBHOOK_PROTOCOL', 'https')
      end
    end

    def determine_host
      # Priority: ENV variable > Rails config > default
      ENV['WEBHOOK_HOST'] || 
      Rails.application.config.hosts&.first || 
      ENV['APP_DOMAIN'] ||
      raise("Webhook host not configured. Set WEBHOOK_HOST environment variable.")
    end

    def build_webhook_path(topic)
      path_mapping = {
        'customers/data_request' => '/shopify/webhooks/customers_data_request',
        'customers/redact' => '/shopify/webhooks/customers_redact',
        'shop/redact' => '/shopify/webhooks/shop_redact'
      }
      
      path_mapping[topic] || raise("Unknown topic: #{topic}")
    end

    def valid_webhook_url?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && uri.host.present? && uri.path.present?
    rescue URI::InvalidURIError
      false
    end

    def create_webhook_subscription(topic, callback_url)
      mutation = build_webhook_subscription_mutation
      variables = build_mutation_variables(topic, callback_url)
      
      Rails.logger.debug "Executing webhook subscription mutation", {
        topic: topic,
        callback_url: callback_url,
        shop_domain: @shop_domain
      }
      
      result = execute_graphql_request(mutation, variables)
      
      if result[:success]
        Rails.logger.info "Webhook subscription mutation executed", {
          topic: topic,
          has_data: result[:data].present?,
          shop_domain: @shop_domain
        }
      else
        Rails.logger.error "Webhook subscription mutation failed", {
          topic: topic,
          error: result[:error],
          shop_domain: @shop_domain
        }
      end
      
      result
    end

    def build_webhook_subscription_mutation
      <<~GRAPHQL
        mutation webhookSubscriptionCreate($topic: WebhookSubscriptionTopic!, $webhookSubscription: WebhookSubscriptionInput!) {
          webhookSubscriptionCreate(topic: $topic, webhookSubscription: $webhookSubscription) {
            webhookSubscription {
              id
              callbackUrl
              createdAt
              updatedAt
              format
              includeFields
              metafieldNamespaces
              privateMetafieldNamespaces
              apiVersion
            }
            userErrors {
              field
              message
            }
          }
        }
      GRAPHQL
    end

    def build_mutation_variables(topic, callback_url)
      {
        topic: normalize_topic_for_graphql(topic),
        webhookSubscription: {
          callbackUrl: callback_url,
          format: 'JSON',
          includeFields: [],
          metafieldNamespaces: [],
          privateMetafieldNamespaces: []
        }
      }
    end

    # Map topic names to Shopify GraphQL enum values
    def normalize_topic_for_graphql(topic)
      topic_mapping = {
        'customers/data_request' => 'CUSTOMERS_DATA_REQUEST',
        'customers/redact' => 'CUSTOMERS_REDACT',
        'shop/redact' => 'SHOP_REDACT'
      }
      
      normalized = topic_mapping[topic]
      
      unless normalized
        Rails.logger.error "Unknown webhook topic", {
          topic: topic,
          available_topics: topic_mapping.keys
        }
        raise ArgumentError, "Unknown webhook topic: #{topic}"
      end
      
      normalized
    end

    def execute_graphql_request(query, variables = {})
      request_payload = {
        query: query,
        variables: variables
      }
      
      Rails.logger.debug "Executing GraphQL request", {
        shop_domain: @shop_domain,
        query_type: extract_query_type(query),
        has_variables: variables.any?
      }
      
      response = HTTParty.post(
        "https://#{@shop_domain}/#{GRAPHQL_ENDPOINT}",
        {
          headers: {
            'Content-Type' => 'application/json',
            'X-Shopify-Access-Token' => @access_token,
            'User-Agent' => 'Chatwoot-Shopify-Integration/1.0'
          },
          body: request_payload.to_json,
          timeout: 30
        }
      )
      
      handle_graphql_response(response)
      
    rescue Net::TimeoutError => e
      Rails.logger.error "GraphQL request timeout", service_context.merge(error: e.message)
      { success: false, error: 'Request timeout', response: nil }
    rescue => e
      Rails.logger.error "GraphQL request failed", service_context.merge(error: e.message)
      { success: false, error: e.message, response: nil }
    end

    def handle_graphql_response(response)
      unless response.success?
        Rails.logger.error "GraphQL HTTP error", {
          status_code: response.code,
          response_body: response.body,
          shop_domain: @shop_domain
        }
        return { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
      
      parsed_response = JSON.parse(response.body)
      
      if parsed_response['errors']
        Rails.logger.error "GraphQL errors in response", {
          errors: parsed_response['errors'],
          shop_domain: @shop_domain
        }
        return { 
          success: false, 
          error: parsed_response['errors'].map { |e| e['message'] }.join(', '),
          response: parsed_response 
        }
      end
      
      { success: true, data: parsed_response['data'], response: parsed_response }
    end

    def extract_query_type(query)
      # Extract operation type from GraphQL query for logging
      if query.include?('webhookSubscriptionCreate')
        'webhookSubscriptionCreate'
      elsif query.include?('webhookSubscriptions')
        'webhookSubscriptions'
      else
        'unknown'
      end
    end

    def handle_successful_subscription(topic, subscription_data)
      Rails.logger.info "Webhook subscription created successfully", {
        topic: topic,
        subscription_id: subscription_data['id'],
        callback_url: subscription_data['callbackUrl'],
        shop_domain: @shop_domain
      }
      
      # Store subscription metadata in integration hook
      update_hook_with_subscription_data(topic, subscription_data)
      
      {
        success: true,
        topic: topic,
        subscription_id: subscription_data['id'],
        callback_url: subscription_data['callbackUrl']
      }
    end

    def handle_subscription_errors(topic, user_errors)
      error_messages = user_errors.map { |error| error['message'] }
      
      Rails.logger.error "Webhook subscription failed with user errors", {
        topic: topic,
        errors: error_messages,
        shop_domain: @shop_domain
      }
      
      {
        success: false,
        topic: topic,
        error: "Subscription errors: #{error_messages.join(', ')}",
        user_errors: user_errors
      }
    end

    def update_hook_with_subscription_data(topic, subscription_data)
      current_settings = @integration_hook.settings || {}
      webhook_subscriptions = current_settings['webhook_subscriptions'] || {}
      
      webhook_subscriptions[topic] = {
        subscription_id: subscription_data['id'],
        callback_url: subscription_data['callbackUrl'],
        created_at: Time.current.iso8601,
        api_version: subscription_data['apiVersion']
      }
      
      updated_settings = current_settings.merge(
        'webhook_subscriptions' => webhook_subscriptions,
        'compliance_webhooks_subscribed_at' => Time.current.iso8601
      )
      
      @integration_hook.update!(settings: updated_settings)
      
      Rails.logger.info "Updated integration hook with subscription data", {
        topic: topic,
        hook_id: @integration_hook.id,
        subscription_id: subscription_data['id']
      }
    end
  end
end 