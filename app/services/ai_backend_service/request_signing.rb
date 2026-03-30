# frozen_string_literal: true

require 'json'
require 'openssl'

module AiBackendService::RequestSigning
  private

  def current_timestamp
    Time.now.to_i
  end

  def signed_headers(payload:, timestamp:, bearer_token: nil, require_bearer: false)
    raise StandardError, 'AI Backend webhook secret is not configured' if ai_backend_webhook_secret.blank?
    raise StandardError, 'AI Backend API key is not configured' if require_bearer && bearer_token.blank?

    headers = {
      'Content-Type' => 'application/json',
      'X-Chatwoot-Timestamp' => timestamp.to_s,
      'X-Chatwoot-Signature' => generate_signature(payload, timestamp)
    }
    headers['Authorization'] = "Bearer #{bearer_token}" if bearer_token.present?
    headers
  end

  def generate_signature(payload, timestamp)
    message = "#{timestamp}.#{canonical_payload(payload || {})}"
    OpenSSL::HMAC.hexdigest('SHA256', ai_backend_webhook_secret, message)
  end

  def canonical_payload(payload)
    normalized_payload = normalize_payload(payload || {})
    # Match Python canonical JSON format: json.dumps(..., separators=(',', ':'))
    JSON.generate(normalized_payload, space: nil, space_before: nil)
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

  def ai_backend_webhook_secret
    ENV['AI_BACKEND_WEBHOOK_SECRET'] ||
      Rails.application.credentials.dig(:ai_backend, :webhook_secret)
  end
end
