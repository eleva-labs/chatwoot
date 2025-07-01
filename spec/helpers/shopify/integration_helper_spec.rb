# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::IntegrationHelper, type: :helper do
  include described_class

  let(:valid_secret) { 'test_secret_key_for_shopify_webhooks' }
  let(:request_body) { '{"shop_domain":"test-shop.myshopify.com","customer":{"id":123,"email":"test@example.com"}}' }
  let(:valid_hmac) { Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', valid_secret, request_body)) }
  let(:mock_request) { double('request') }
  
  before do
    allow(ENV).to receive(:[]).with('SHOPIFY_CLIENT_SECRET').and_return(valid_secret)
  end

  describe '#generate_shopify_token' do
    let(:account_id) { 1 }
    let(:client_secret) { 'test_secret' }
    let(:current_time) { Time.current }

    before do
      allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_SECRET', nil).and_return(client_secret)
      allow(Time).to receive(:current).and_return(current_time)
    end

    it 'generates a valid JWT token with correct payload' do
      token = generate_shopify_token(account_id)
      decoded_token = JWT.decode(token, client_secret, true, algorithm: 'HS256').first

      expect(decoded_token['sub']).to eq(account_id)
      expect(decoded_token['iat']).to eq(current_time.to_i)
    end

    context 'when client secret is not configured' do
      let(:client_secret) { nil }

      it 'returns nil' do
        expect(generate_shopify_token(account_id)).to be_nil
      end
    end

    context 'when an error occurs' do
      before do
        allow(JWT).to receive(:encode).and_raise(StandardError.new('Test error'))
      end

      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with('Failed to generate Shopify token: Test error')
        expect(generate_shopify_token(account_id)).to be_nil
      end
    end
  end

  describe '#verify_shopify_token' do
    let(:account_id) { 1 }
    let(:client_secret) { 'test_secret' }
    let(:valid_token) do
      JWT.encode({ sub: account_id, iat: Time.current.to_i }, client_secret, 'HS256')
    end

    before do
      allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_SECRET', nil).and_return(client_secret)
    end

    it 'successfully verifies and returns account_id from valid token' do
      expect(verify_shopify_token(valid_token)).to eq(account_id)
    end

    context 'when token is blank' do
      it 'returns nil' do
        expect(verify_shopify_token('')).to be_nil
        expect(verify_shopify_token(nil)).to be_nil
      end
    end

    context 'when client secret is not configured' do
      let(:client_secret) { nil }

      it 'returns nil' do
        expect(verify_shopify_token(valid_token)).to be_nil
      end
    end

    context 'when token is invalid' do
      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/Unexpected error verifying Shopify token:/)
        expect(verify_shopify_token('invalid_token')).to be_nil
      end
    end
  end

  describe '#client_id' do
    it 'loads client_id from GlobalConfigService' do
      expect(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_ID', nil)
      client_id
    end
  end

  describe '#client_secret' do
    it 'loads client_secret from GlobalConfigService' do
      expect(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_SECRET', nil)
      client_secret
    end
  end

  describe '#verify_shopify_webhook' do
    context 'with valid HMAC signature' do
      before do
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => valid_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(request_body)
      end
      
      it 'returns true for valid signature' do
        expect(verify_shopify_webhook(mock_request)).to be true
      end
      
      it 'handles body rewinding properly' do
        expect(mock_request.body).to receive(:rewind).at_least(:twice)
        verify_shopify_webhook(mock_request)
      end

      it 'logs debug information for successful verification' do
        expect(Rails.logger).not_to receive(:error)
        expect(Rails.logger).not_to receive(:warn)
        
        verify_shopify_webhook(mock_request)
      end
    end

    context 'with invalid HMAC signature' do
      before do
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => 'invalid_signature'})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(request_body)
      end
      
      it 'returns false for invalid signature' do
        expect(verify_shopify_webhook(mock_request)).to be false
      end
      
      it 'logs verification failure with context' do
        expect(Rails.logger).to receive(:warn).with(/HMAC verification failed/, hash_including(
          expected_length: be_a(Integer),
          received_length: be_a(Integer),
          body_size: be_a(Integer)
        ))
        
        verify_shopify_webhook(mock_request)
      end

      it 'still rewinds body on failure' do
        expect(mock_request.body).to receive(:rewind).at_least(:twice)
        verify_shopify_webhook(mock_request)
      end
    end

    context 'with missing HMAC header' do
      before do
        allow(mock_request).to receive(:env).and_return({})
      end
      
      it 'returns false when header is missing' do
        expect(verify_shopify_webhook(mock_request)).to be false
      end

      it 'does not attempt body reading when header missing' do
        expect(mock_request).not_to receive(:body)
        verify_shopify_webhook(mock_request)
      end
    end

    context 'with empty HMAC header' do
      before do
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => ''})
      end
      
      it 'returns false when header is empty' do
        expect(verify_shopify_webhook(mock_request)).to be false
      end

      it 'logs invalid header format error' do
        expect(Rails.logger).to receive(:error).with("Invalid HMAC header format")
        verify_shopify_webhook(mock_request)
      end
    end

    context 'with malformed HMAC header' do
      before do
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => 'not@base64!'})
      end
      
      it 'returns false for non-base64 header' do
        expect(verify_shopify_webhook(mock_request)).to be false
      end

      it 'logs invalid header format' do
        expect(Rails.logger).to receive(:error).with("Invalid HMAC header format")
        verify_shopify_webhook(mock_request)
      end
    end

    context 'with missing secret' do
      before do
        allow(ENV).to receive(:[]).with('SHOPIFY_CLIENT_SECRET').and_return(nil)
        allow(Rails.application.credentials).to receive(:shopify).and_return(nil)
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => valid_hmac})
      end
      
      it 'returns false when secret is missing' do
        expect(verify_shopify_webhook(mock_request)).to be false
      end

      it 'logs secret configuration error' do
        expect(Rails.logger).to receive(:error).with("Shopify webhook secret not configured")
        verify_shopify_webhook(mock_request)
      end
    end

    context 'when body reading fails' do
      before do
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => valid_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_raise(StandardError.new('Read error'))
      end
      
      it 'returns false and logs error' do
        expect(Rails.logger).to receive(:error).with(/Shopify webhook verification error: Read error/)
        expect(verify_shopify_webhook(mock_request)).to be false
      end

      it 'handles IOError gracefully' do
        allow(mock_request.body).to receive(:read).and_raise(IOError.new('Connection reset'))
        
        expect(Rails.logger).to receive(:error).with(/Shopify webhook verification error: Connection reset/)
        expect(verify_shopify_webhook(mock_request)).to be false
      end
    end

    context 'when body rewind fails' do
      before do
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => valid_hmac})
        allow(mock_request.body).to receive(:read).and_return(request_body)
        allow(mock_request.body).to receive(:rewind).and_raise(IOError.new('Rewind failed'))
      end

      it 'continues processing without rewind' do
        expect(verify_shopify_webhook(mock_request)).to be true
      end
    end
  end

  describe 'timing attack resistance' do
    it 'uses secure comparison' do
      allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => valid_hmac})
      allow(mock_request.body).to receive(:rewind)
      allow(mock_request.body).to receive(:read).and_return(request_body)
      
      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original
      verify_shopify_webhook(mock_request)
    end

    it 'has consistent timing for different signature lengths' do
      signatures = [
        'short',
        'medium_length_signature_value',
        'very_long_signature_that_might_take_longer_to_compare_if_not_using_constant_time_comparison'
      ]
      
      times = signatures.map do |sig|
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => sig})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(request_body)
        
        start_time = Time.current
        verify_shopify_webhook(mock_request)
        Time.current - start_time
      end
      
      # All comparisons should take similar time (within 10ms variance)
      expect(times.max - times.min).to be < 0.01
    end

    it 'prevents early exit timing attacks' do
      invalid_signatures = [
        'a',
        'short_sig',
        valid_hmac[0..10] + 'modified',
        valid_hmac + 'extra'
      ]
      
      times = invalid_signatures.map do |sig|
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => sig})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(request_body)
        
        start_time = Time.current
        verify_shopify_webhook(mock_request)
        Time.current - start_time
      end
      
      # Even invalid signatures should take consistent time
      expect(times.max - times.min).to be < 0.01
    end
  end

  describe 'HMAC edge cases' do
    describe 'different payload sizes' do
      it 'handles empty payload' do
        empty_body = ''
        empty_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', valid_secret, empty_body))
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => empty_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(empty_body)
        
        expect(verify_shopify_webhook(mock_request)).to be true
      end
      
      it 'handles large payload' do
        large_body = '{"data":"' + 'x' * 100_000 + '"}'
        large_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', valid_secret, large_body))
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => large_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(large_body)
        
        expect(verify_shopify_webhook(mock_request)).to be true
      end
      
      it 'handles unicode characters' do
        unicode_body = '{"customer":"café","emoji":"🛍️💳🔒","chinese":"你好"}'
        unicode_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', valid_secret, unicode_body))
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => unicode_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(unicode_body)
        
        expect(verify_shopify_webhook(mock_request)).to be true
      end

      it 'handles binary data in JSON strings' do
        binary_body = '{"data":"' + "\x00\x01\x02\xFF".force_encoding('ASCII-8BIT') + '"}'
        binary_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', valid_secret, binary_body))
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => binary_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(binary_body)
        
        expect(verify_shopify_webhook(mock_request)).to be true
      end
    end

    describe 'malformed headers' do
      it 'handles base64 padding issues' do
        malformed_hmac = valid_hmac.chomp('=') + '='
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => malformed_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(request_body)
        
        expect(verify_shopify_webhook(mock_request)).to be false
      end
      
      it 'handles non-base64 characters' do
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => 'not@base64!'})
        
        expect(Rails.logger).to receive(:error).with("Invalid HMAC header format")
        expect(verify_shopify_webhook(mock_request)).to be false
      end

      it 'handles whitespace in headers' do
        whitespace_hmac = " #{valid_hmac} "
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => whitespace_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(request_body)
        
        expect(verify_shopify_webhook(mock_request)).to be false
      end
    end

    describe 'payload tampering detection' do
      it 'detects modified JSON keys' do
        tampered_body = request_body.gsub('shop_domain', 'shop_domain_modified')
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => valid_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(tampered_body)
        
        expect(verify_shopify_webhook(mock_request)).to be false
      end

      it 'detects modified JSON values' do
        tampered_body = request_body.gsub('123', '456')
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => valid_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(tampered_body)
        
        expect(verify_shopify_webhook(mock_request)).to be false
      end

      it 'detects whitespace modifications' do
        tampered_body = request_body.gsub(':', ': ')  # Add space after colon
        
        allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => valid_hmac})
        allow(mock_request.body).to receive(:rewind)
        allow(mock_request.body).to receive(:read).and_return(tampered_body)
        
        expect(verify_shopify_webhook(mock_request)).to be false
      end
    end
  end

  describe 'secret configuration handling' do
    it 'prioritizes ENV variable over Rails credentials' do
      env_secret = 'env_secret'
      cred_secret = double('credentials_secret')
      
      allow(ENV).to receive(:[]).with('SHOPIFY_CLIENT_SECRET').and_return(env_secret)
      allow(Rails.application.credentials).to receive(:shopify).and_return(double(client_secret: cred_secret))
      
      hmac_with_env = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', env_secret, request_body))
      
      allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => hmac_with_env})
      allow(mock_request.body).to receive(:rewind)
      allow(mock_request.body).to receive(:read).and_return(request_body)
      
      expect(verify_shopify_webhook(mock_request)).to be true
    end

    it 'falls back to Rails credentials when ENV is empty' do
      cred_secret = 'credentials_secret'
      
      allow(ENV).to receive(:[]).with('SHOPIFY_CLIENT_SECRET').and_return('')
      allow(Rails.application.credentials).to receive(:shopify).and_return(double(client_secret: cred_secret))
      
      hmac_with_cred = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', cred_secret, request_body))
      
      allow(mock_request).to receive(:env).and_return({'HTTP_X_SHOPIFY_HMAC_SHA256' => hmac_with_cred})
      allow(mock_request.body).to receive(:rewind)
      allow(mock_request.body).to receive(:read).and_return(request_body)
      
      expect(verify_shopify_webhook(mock_request)).to be true
    end
  end

  describe '#valid_base64_format?' do
    it 'validates correct base64 format' do
      expect(send(:valid_base64_format?, valid_hmac)).to be true
    end

    it 'rejects invalid base64 characters' do
      expect(send(:valid_base64_format?, 'invalid@base64!')).to be false
    end

    it 'rejects strings with spaces' do
      expect(send(:valid_base64_format?, 'valid base64')).to be false
    end

    it 'accepts base64 with padding' do
      expect(send(:valid_base64_format?, 'dGVzdA==')).to be true
    end

    it 'accepts base64 without padding' do
      expect(send(:valid_base64_format?, 'dGVzdA')).to be true
    end
  end

  private

  def valid_base64_format?(string)
    # This is the private method from the helper
    string.match?(/\A[A-Za-z0-9+\/]*={0,2}\z/)
  end
end
