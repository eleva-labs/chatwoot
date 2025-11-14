# frozen_string_literal: true

require 'httparty'
require 'openssl'

class AiBackendService::TokenCreditsService
  include HTTParty

  class TokenCreditsError < StandardError; end

  BALANCE_PATH = '/api/token-credits/balance'
  TRANSACTIONS_PATH = '/api/token-credits/transactions'
  ADD_CREDITS_PATH = '/api/token-credits/add'
  DEFAULT_TRANSACTION_LIMIT = 100

  def initialize
    self.class.base_uri(ai_backend_api_url)
  end

  def balance(store_id)
    timestamp = current_timestamp
    payload = {}

    response = self.class.get(
      BALANCE_PATH,
      query: { store_id: store_id.to_s },
      headers: headers(payload, timestamp)
    )

    handle_response(response)
  end

  def transactions(store_id, limit: DEFAULT_TRANSACTION_LIMIT)
    timestamp = current_timestamp
    payload = {}

    response = self.class.get(
      TRANSACTIONS_PATH,
      query: {
        store_id: store_id.to_s,
        limit: limit
      },
      headers: headers(payload, timestamp)
    )

    handle_response(response)
  end

  def add_credits(store_id:, tokens_to_add:, transaction_id:, payment_method: 'stripe', amount_paid_usd: nil, purchased_at: Time.current.iso8601, metadata: {})
    payload = {
      store_id: store_id.to_s,
      tokens_to_add: tokens_to_add,
      transaction_id: transaction_id,
      payment_method: payment_method,
      amount_paid_usd: amount_paid_usd,
      purchased_at: purchased_at,
      metadata: metadata
    }.compact

    timestamp = current_timestamp

    response = self.class.post(
      ADD_CREDITS_PATH,
      headers: headers(payload, timestamp),
      body: payload.to_json
    )

    handle_response(response)
  end

  private

  def headers(payload, timestamp)
    api_key = ai_backend_api_key
    raise TokenCreditsError, 'AI Backend API key is not configured' if api_key.blank?

    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}",
      'X-Chatwoot-Timestamp' => timestamp.to_s,
      'X-Chatwoot-Signature' => generate_signature(payload, timestamp)
    }
  end

  def generate_signature(payload, timestamp)
    secret = ai_backend_webhook_secret
    raise TokenCreditsError, 'AI Backend webhook secret is not configured' if secret.blank?

    message = "#{timestamp}.#{canonical_payload(payload)}"
    OpenSSL::HMAC.hexdigest('SHA256', secret, message)
  end

  def canonical_payload(payload)
    normalized_payload = normalize_payload(payload)
    JSON.generate(normalized_payload)
  end

  def normalize_payload(obj)
    case obj
    when Hash
      obj.keys.sort.each_with_object({}) do |key, acc|
        acc[key] = normalize_payload(obj[key])
      end
    when Array
      obj.map { |item| normalize_payload(item) }
    else
      obj
    end
  end

  def current_timestamp
    Time.now.to_i
  end

  def handle_response(response)
    if response&.code.to_i.between?(200, 299)
      parse_json(response.body)
    else
      Rails.logger.error(
        "AI Backend token credits request failed: status=#{response&.code}, body=#{response&.body}"
      )
      raise TokenCreditsError, 'AI Backend request failed'
    end
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse AI Backend response: #{e.message}"
    raise TokenCreditsError, 'Invalid response from AI Backend'
  end

  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.dig(:ai_backend, :api_url) ||
      'http://localhost:8000'
  end

  def ai_backend_api_key
    ENV['AI_BACKEND_API_KEY'] ||
      Rails.application.credentials.dig(:ai_backend, :api_key)
  end

  def ai_backend_webhook_secret
    ENV['AI_BACKEND_WEBHOOK_SECRET'] ||
      Rails.application.credentials.dig(:ai_backend, :webhook_secret)
  end
end

