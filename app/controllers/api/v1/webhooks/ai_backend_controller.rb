# frozen_string_literal: true

module Api
  module V1
    module Webhooks
      class AiBackendController < ActionController::Base
        protect_from_forgery with: :null_session

        before_action :verify_webhook_signature!

        # POST /api/v1/webhooks/ai-backend/token-balance-status
        def token_balance_status
          account = find_account!
          
          balance_info = payload['balance_info'] || {}
          available_tokens_value = balance_info['available_tokens']
          warning_threshold_value = balance_info['warning_threshold']
          
          raise ArgumentError, "Missing required balance_info fields" if available_tokens_value.nil? || warning_threshold_value.nil?
          
          available_tokens = available_tokens_value.to_i
          warning_threshold = warning_threshold_value.to_i
          
          # Extract impacted_conversations_count from metadata
          metadata = payload['metadata'] || {}
          impacted_count = metadata['impacted_conversations_count']&.to_i || 0
          
          # Determine status based on current balance
          if available_tokens <= 0
            # Insufficient tokens - set or keep status
            if account.ai_token_balance_status != 'insufficient_tokens'
              account.set_ai_token_balance_status!('insufficient_tokens', impacted_count: impacted_count)
              Rails.logger.info "Token balance status set to insufficient_tokens: available_tokens=#{available_tokens}, impacted_conversations_count=#{impacted_count}"
            elsif impacted_count > 0
              # Update count even if status already set
              account.update_ai_token_impacted_count!(impacted_count)
              Rails.logger.debug "Updated impacted_conversations_count: #{impacted_count}"
            end
          elsif available_tokens > 0 && available_tokens <= warning_threshold
            # Low balance warning (only if not already insufficient)
            if account.ai_token_balance_status == 'insufficient_tokens'
              # Keep insufficient status (it has priority)
              Rails.logger.debug "Keeping insufficient_tokens status (has priority over low_balance)"
            elsif account.ai_token_balance_status != 'low_balance'
              account.set_ai_token_balance_status!('low_balance')
              Rails.logger.info "Token balance status set to low_balance: available_tokens=#{available_tokens}, threshold=#{warning_threshold}"
            end
          else
            # Balance is good (above threshold) - clear any status
            if account.ai_token_balance_status.present?
              account.clear_ai_token_balance_status!
              Rails.logger.info "Token balance status cleared: available_tokens=#{available_tokens} > threshold=#{warning_threshold}"
            end
          end
          
          render json: {
            status: 'received',
            store_id: payload['store_id'],
            timestamp: Time.current.iso8601
          }
        rescue ActiveRecord::RecordNotFound
          render json: { status: 'error', error: 'account_not_found', message: account_not_found_message }, status: :not_found
        rescue StandardError => e
          Rails.logger.error "Failed to process token balance status webhook: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { status: 'error', error: 'processing_failed', message: 'Failed to process token balance status' }, status: :internal_server_error
        end

        private

        def payload
          @payload ||= JSON.parse(request.raw_post.presence || '{}')
        rescue JSON::ParserError => e
          Rails.logger.error "Invalid JSON payload for AI backend webhook: #{e.message}"
          {}
        end

        def find_account!
          store_id = payload['store_id']
          raise ActiveRecord::RecordNotFound if store_id.blank?

          account = Account.where("custom_attributes ->> 'ai_backend_store_id' = ?", store_id.to_s).first
          return account if account

          # AI Backend sends the real UUID (store.id) in webhook payloads
          # Query AI Backend to get the external_id (account.id) from the UUID
          begin
            store_service = AiBackendService::StoreService.new(id_type: AiBackendService::Constants::IdType::INTERNAL)
            store_response = store_service.get_store(store_id)
            external_id = store_response.external_id

            # Find account by external_id (which matches account.id)
            account = Account.find_by(id: external_id)
            raise ActiveRecord::RecordNotFound unless account

            persist_store_mapping(account, store_response)
            account
          rescue AiBackendService::StoreService::StoreError => e
            Rails.logger.error "Failed to lookup store by UUID in AI Backend: #{e.message}"
            raise ActiveRecord::RecordNotFound
          rescue HTTParty::Error, SocketError, Net::ReadTimeout, Net::OpenTimeout, Net::TimeoutError, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
            # Handle network errors (timeout, connection refused, etc.)
            # These should be treated as account not found rather than 500 errors
            Rails.logger.error "Network error while looking up store in AI Backend: #{e.class} - #{e.message}"
            raise ActiveRecord::RecordNotFound
          rescue StandardError => e
            # Catch any other unexpected errors to prevent 500 responses
            # Log the full error for debugging but treat as account not found
            Rails.logger.error "Unexpected error while looking up store in AI Backend: #{e.class} - #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            raise ActiveRecord::RecordNotFound
          end
        end

        def account_not_found_message
          "Account with store_id #{payload['store_id']} not found"
        end

        def persist_store_mapping(account, store_response)
          return unless store_response.respond_to?(:id) && store_response.id.present?
          return if account.ai_backend_store_id == store_response.id.to_s

          account.set_ai_backend_store_id!(store_response.id, external_id: store_response.external_id)
        rescue StandardError => e
          Rails.logger.error "Failed to persist AI Backend store mapping for account #{account.id}: #{e.message}"
        end

        def verify_webhook_signature!
          signature = request.headers['X-AI-Backend-Signature']
          timestamp = request.headers['X-AI-Backend-Timestamp']

          if signature.blank? || timestamp.blank?
            Rails.logger.error(
              "[AI Backend Webhook] Missing signature headers. " \
              "Signature present: #{signature.present?}, Timestamp present: #{timestamp.present?}"
            )
            render json: { status: 'error', error: 'missing_signature', message: 'Missing signature headers' }, status: :unauthorized
            return
          end

          timestamp_value = timestamp.to_i
          time_diff = (Time.current.to_i - timestamp_value).abs
          if time_diff > 300
            Rails.logger.error(
              "[AI Backend Webhook] Invalid timestamp. " \
              "Timestamp: #{timestamp_value}, Current: #{Time.current.to_i}, Diff: #{time_diff}s"
            )
            render json: { status: 'error', error: 'invalid_timestamp', message: 'Timestamp is too old or from future' }, status: :unauthorized
            return
          end

          secret = ai_backend_webhook_secret
          unless secret
            Rails.logger.error("[AI Backend Webhook] Webhook secret not configured")
            render json: { status: 'error', error: 'webhook_not_configured', message: 'Webhook secret not configured' }, status: :internal_server_error
            return
          end

          canonical = canonical_payload(payload)
          message = "#{timestamp_value}.#{canonical}"
          expected = OpenSSL::HMAC.hexdigest('SHA256', secret, message)
          
          unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
            # Log diagnostic info without exposing sensitive cryptographic material
            # Security: Do not log signatures, payloads, or HMAC messages to prevent signature forgery
            Rails.logger.error(
              "[AI Backend Webhook] Signature verification failed. " \
              "Timestamp: #{timestamp_value}, " \
              "Payload keys: #{payload.keys.inspect}, " \
              "Payload size: #{canonical.bytesize} bytes, " \
              "Signature length: #{signature&.length || 0} chars"
            )
            render json: { status: 'error', error: 'signature_verification_failed', message: 'Invalid signature' }, status: :unauthorized
            return
          end

          Rails.logger.debug("[AI Backend Webhook] Signature verification successful")
        end

        def canonical_payload(object)
          JSON.generate(normalize_payload(object))
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
          ENV['AI_BACKEND_WEBHOOK_SECRET'] || Rails.application.credentials.dig(:ai_backend, :webhook_secret)
        end
      end
    end
  end
end

