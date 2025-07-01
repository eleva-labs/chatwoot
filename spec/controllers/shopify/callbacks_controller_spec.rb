require 'rails_helper'

RSpec.describe Shopify::CallbacksController, type: :request do
  let(:account) { create(:account) }
  let(:code) { SecureRandom.hex(10) }
  let(:state) { SecureRandom.hex(10) }
  let(:shop) { 'my-store.myshopify.com' }
  let(:frontend_url) { 'http://www.example.com' }
  let(:shopify_redirect_uri) { "#{frontend_url}/app/accounts/#{account.id}/settings/integrations/shopify" }
  let(:oauth_client) { instance_double(OAuth2::Client) }
  let(:auth_code_strategy) { instance_double(OAuth2::Strategy::AuthCode) }

  before do
    stub_const('ENV', ENV.to_hash.merge('FRONTEND_URL' => frontend_url))
    allow(ENV).to receive(:[]).with('WEBHOOK_HOST').and_return('test.chatwoot.com')
  end

  describe 'GET /shopify/callback' do
    let(:access_token) { SecureRandom.hex(10) }
    let(:response_body) do
      {
        'access_token' => access_token,
        'scope' => 'read_products,write_products'
      }
    end

    context 'when successful with webhook subscription' do
      before do
        controller = described_class.new
        allow(controller).to receive(:verify_shopify_token).with(state).and_return(account.id)
        allow(described_class).to receive(:new).and_return(controller)

        stub_request(:post, "https://#{shop}/admin/oauth/access_token")
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Mock successful webhook subscription
        allow(Shopify::WebhookSubscriptionService).to receive(:call).and_return({
          success: true,
          subscribed_topics: 3,
          total_topics: 3,
          results: {
            'customers/data_request' => { success: true },
            'customers/redact' => { success: true },
            'shop/redact' => { success: true }
          }
        })
      end

      it 'creates a new integration hook with compliance webhook settings' do
        expect do
          get shopify_callback_path, params: { code: code, state: state, shop: shop }
        end.to change(Integrations::Hook, :count).by(1)

        hook = Integrations::Hook.last
        expect(hook.access_token).to eq(access_token)
        expect(hook.app_id).to eq('shopify')
        expect(hook.status).to eq('enabled')
        expect(hook.reference_id).to eq(shop)
        
        # Check compliance webhook settings
        expect(hook.settings['compliance_webhooks_pending']).to be false
        expect(hook.settings['compliance_webhooks_subscribed']).to be true
        expect(hook.settings['compliance_webhooks_subscribed_at']).to be_present
        expect(hook.settings['subscribed_topics_count']).to eq(3)
        
        expect(response).to redirect_to(shopify_redirect_uri)
      end

      it 'calls the webhook subscription service' do
        get shopify_callback_path, params: { code: code, state: state, shop: shop }

        expect(Shopify::WebhookSubscriptionService).to have_received(:call).once
      end

      it 'logs successful webhook subscription' do
        expect(Rails.logger).to receive(:info).with(/All compliance webhooks subscribed successfully/)
        
        get shopify_callback_path, params: { code: code, state: state, shop: shop }
      end
    end

    context 'when webhook subscription fails' do
      before do
        controller = described_class.new
        allow(controller).to receive(:verify_shopify_token).with(state).and_return(account.id)
        allow(described_class).to receive(:new).and_return(controller)

        stub_request(:post, "https://#{shop}/admin/oauth/access_token")
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Mock failed webhook subscription
        allow(Shopify::WebhookSubscriptionService).to receive(:call).and_return({
          success: false,
          error: 'API rate limit exceeded',
          subscribed_topics: 1,
          total_topics: 3
        })

        # Mock retry job enqueueing
        allow(Shopify::WebhookSubscriptionRetryJob).to receive(:perform_later)
      end

      it 'still creates integration hook but marks webhooks as pending' do
        expect do
          get shopify_callback_path, params: { code: code, state: state, shop: shop }
        end.to change(Integrations::Hook, :count).by(1)

        hook = Integrations::Hook.last
        expect(hook.access_token).to eq(access_token)
        expect(hook.app_id).to eq('shopify')
        expect(hook.status).to eq('enabled')
        
        # Check webhook failure handling
        expect(hook.settings['compliance_webhooks_pending']).to be true
        expect(hook.settings['compliance_webhooks_subscribed']).to be false
        expect(hook.settings['webhook_subscription_failure_reason']).to eq('API rate limit exceeded')
        expect(hook.settings['webhook_subscription_retry_queued_at']).to be_present
        
        expect(response).to redirect_to(shopify_redirect_uri)
      end

      it 'enqueues retry job for failed subscriptions' do
        get shopify_callback_path, params: { code: code, state: state, shop: shop }

        expect(Shopify::WebhookSubscriptionRetryJob).to have_received(:perform_later)
      end

      it 'logs webhook subscription failure' do
        expect(Rails.logger).to receive(:error).with(/Webhook subscription failed during installation/)
        
        get shopify_callback_path, params: { code: code, state: state, shop: shop }
      end

      context 'when configured to fail installation on webhook error' do
        before do
          allow(ENV).to receive(:[]).with('FAIL_INSTALLATION_ON_WEBHOOK_ERROR').and_return('true')
        end

        it 'fails the installation and redirects with error' do
          get shopify_callback_path, params: { code: code, state: state, shop: shop }

          expect(response).to redirect_to(/error=webhook_setup_failed/)
        end
      end
    end

    context 'when webhook subscription service raises exception' do
      before do
        controller = described_class.new
        allow(controller).to receive(:verify_shopify_token).with(state).and_return(account.id)
        allow(described_class).to receive(:new).and_return(controller)

        stub_request(:post, "https://#{shop}/admin/oauth/access_token")
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Mock service exception
        allow(Shopify::WebhookSubscriptionService).to receive(:call).and_raise(StandardError.new('Connection timeout'))
        allow(Shopify::WebhookSubscriptionRetryJob).to receive(:perform_later)
      end

      it 'handles exception gracefully and enqueues retry' do
        expect do
          get shopify_callback_path, params: { code: code, state: state, shop: shop }
        end.to change(Integrations::Hook, :count).by(1)

        hook = Integrations::Hook.last
        expect(hook.settings['webhook_subscription_failure_reason']).to eq('Connection timeout')
        
        expect(Shopify::WebhookSubscriptionRetryJob).to have_received(:perform_later)
        expect(response).to redirect_to(shopify_redirect_uri)
      end
    end

    context 'when compliance webhooks are disabled by feature flag' do
      before do
        controller = described_class.new
        allow(controller).to receive(:verify_shopify_token).with(state).and_return(account.id)
        allow(controller).to receive(:compliance_webhooks_enabled?).and_return(false)
        allow(described_class).to receive(:new).and_return(controller)

        stub_request(:post, "https://#{shop}/admin/oauth/access_token")
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'skips webhook subscription and proceeds normally' do
        expect do
          get shopify_callback_path, params: { code: code, state: state, shop: shop }
        end.to change(Integrations::Hook, :count).by(1)

        expect(Shopify::WebhookSubscriptionService).not_to receive(:call)
        expect(response).to redirect_to(shopify_redirect_uri)
      end

      it 'logs that webhook subscription was skipped' do
        expect(Rails.logger).to receive(:info).with(/Webhook subscription skipped/)
        
        get shopify_callback_path, params: { code: code, state: state, shop: shop }
      end
    end

    context 'when installation fails' do
      before do
        controller = described_class.new
        allow(controller).to receive(:verify_shopify_token).with(state).and_return(account.id)
        allow(described_class).to receive(:new).and_return(controller)

        stub_request(:post, "https://#{shop}/admin/oauth/access_token")
          .to_return(
            status: 400,
            body: { error: 'invalid_grant' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'redirects with error parameter' do
        get shopify_callback_path, params: { code: code, state: state, shop: shop }

        expect(response).to redirect_to(/error=true/)
      end

      it 'logs installation failure' do
        expect(Rails.logger).to receive(:error).with(/Installation failed/)
        
        get shopify_callback_path, params: { code: code, state: state, shop: shop }
      end
    end
  end

  describe 'webhook subscription integration methods' do
    let(:controller) { described_class.new }
    let(:integration_hook) { create(:integrations_hook, app_id: 'shopify', account: account) }

    describe '#compliance_webhooks_enabled?' do
      it 'returns true when Features is not defined' do
        hide_const('Features')
        expect(controller.send(:compliance_webhooks_enabled?)).to be true
      end

      it 'checks feature flag when Features is defined' do
        features_class = double('Features')
        stub_const('Features', features_class)
        allow(features_class).to receive(:enabled?).with(:shopify_compliance_webhooks, default: true).and_return(false)

        expect(controller.send(:compliance_webhooks_enabled?)).to be false
      end
    end

    describe '#should_fail_installation_on_webhook_error?' do
      it 'returns false by default' do
        allow(ENV).to receive(:fetch).with('FAIL_INSTALLATION_ON_WEBHOOK_ERROR', 'false').and_return('false')
        expect(controller.send(:should_fail_installation_on_webhook_error?)).to be false
      end

      it 'returns true when environment variable is set to true' do
        allow(ENV).to receive(:fetch).with('FAIL_INSTALLATION_ON_WEBHOOK_ERROR', 'false').and_return('true')
        expect(controller.send(:should_fail_installation_on_webhook_error?)).to be true
      end
    end
  end
end
