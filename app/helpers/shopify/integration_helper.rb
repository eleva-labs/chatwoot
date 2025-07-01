module Shopify::IntegrationHelper
  REQUIRED_SCOPES = %w[read_customers read_orders read_fulfillments].freeze

  # Generates a signed JWT token for Shopify integration
  #
  # @param account_id [Integer] The account ID to encode in the token
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_shopify_token(account_id)
    return if client_secret.blank?

    JWT.encode(token_payload(account_id), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate Shopify token: #{e.message}")
    nil
  end

  def token_payload(account_id)
    {
      sub: account_id,
      iat: Time.current.to_i
    }
  end

  # Verifies and decodes a Shopify JWT token
  #
  # @param token [String] The JWT token to verify
  # @return [Integer, nil] The account ID from the token or nil if invalid
  def verify_shopify_token(token)
    return if token.blank? || client_secret.blank?

    decode_token(token, client_secret)
  end

  # Verifies that a webhook request originated from Shopify
  #
  # @param request [ActionDispatch::Request] The incoming HTTP request
  # @return [Boolean] true if the webhook is valid, false otherwise
  def verify_shopify_webhook(request)
    shopify_hmac_header = request.env['HTTP_X_SHOPIFY_HMAC_SHA256']
    return false if shopify_hmac_header.blank?

    # Validate HMAC header format
    unless valid_base64_format?(shopify_hmac_header)
      Rails.logger.error "Invalid HMAC header format"
      return false
    end

    # Get raw request body for HMAC calculation
    request.body.rewind if request.body.respond_to?(:rewind)
    body = request.body.read
    request.body.rewind if request.body.respond_to?(:rewind)

    # Validate webhook secret is available
    webhook_secret = shopify_client_secret
    if webhook_secret.blank?
      Rails.logger.error "Shopify webhook secret not configured"
      return false
    end

    # Calculate expected HMAC
    calculated_hmac = Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha256', webhook_secret, body)
    )

    # Secure comparison to prevent timing attacks
    is_valid = ActiveSupport::SecurityUtils.secure_compare(
      calculated_hmac,
      shopify_hmac_header
    )

    unless is_valid
      Rails.logger.warn "HMAC verification failed", {
        expected_length: calculated_hmac.length,
        received_length: shopify_hmac_header.length,
        body_size: body.bytesize
      }
    end

    is_valid
  rescue StandardError => e
    Rails.logger.error "Shopify webhook verification error: #{e.message}"
    false
  end

  private

  def client_id
    @client_id ||= GlobalConfigService.load('SHOPIFY_CLIENT_ID', nil)
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('SHOPIFY_CLIENT_SECRET', nil)
  end

  def shopify_client_secret
    ENV['SHOPIFY_CLIENT_SECRET'] || Rails.application.credentials.shopify&.client_secret
  end

  def decode_token(token, secret)
    JWT.decode(
      token,
      secret,
      true,
      {
        algorithm: 'HS256',
        verify_expiration: true
      }
    ).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying Shopify token: #{e.message}")
    nil
  end

  def valid_base64_format?(string)
    # Check if string matches Base64 format
    string.match?(/\A[A-Za-z0-9+\/]*={0,2}\z/) && (string.length % 4).zero?
  rescue StandardError
    false
  end
end
