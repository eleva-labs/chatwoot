# frozen_string_literal: true

module Billing
  # Service to create billing portal sessions for customer self-service
  # Generates secure, one-time URLs for subscription management
  class CreatePortalSessionService
    def initialize(account, return_url = nil)
      @account = account
      @return_url = return_url || default_return_url
      @provider = ProviderFactory.get_provider
    end

    def perform
      Rails.logger.info '---[CREATE PORTAL SESSION SERVICE]---'
      Rails.logger.info "Account ID: #{@account.id}"
      Rails.logger.info "Account custom_attributes: #{@account.custom_attributes.inspect}"
      Rails.logger.info "Customer ID: #{customer_id.inspect}"

      return failure_response('No customer ID found') unless customer_id

      begin
        Rails.logger.info "Creating portal session for customer: #{customer_id}"
        session = @provider.create_portal_session(customer_id, @return_url)
        Rails.logger.info "Portal session created successfully: #{session.id}"
        success_response(session)
      rescue StandardError => e
        Rails.logger.error "Error in CreatePortalSessionService: #{e.message}"
        Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join("\n")}"
        failure_response("Portal session creation failed: #{e.message}")
      end
    end

    private

    def customer_id
      @customer_id ||= @account.custom_attributes&.dig('stripe_customer_id')
    end

    def default_return_url
      # Use FRONTEND_URL environment variable (same pattern as checkout session)
      # Return to billing settings page
      # Ensure the URL is properly formatted with trailing slash removed and valid format
      base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3000').to_s.chomp('/')
      "#{base_url}/app/accounts/#{@account.id}/settings/billing"
    end

    def success_response(session)
      {
        success: true,
        data: {
          session_id: session.id,
          session_url: session.url,
          expires_at: Time.at(session.created + 86_400).iso8601 # Sessions expire after 24 hours
        },
        message: 'Portal session created successfully'
      }
    end

    def failure_response(message)
      {
        success: false,
        error: message,
        data: {}
      }
    end
  end
end