# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Billing::Providers::Stripe do
  let(:provider) { described_class.new }
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account, email: 'test@example.com') }

  describe '#provider_name' do
    it 'returns stripe' do
      expect(provider.provider_name).to eq('stripe')
    end
  end

  describe '#create_customer' do
    let(:stripe_customer) { double('Stripe::Customer', id: 'cus_123') }

    before do
      allow(Stripe::Customer).to receive(:create).and_return(stripe_customer)
    end

    it 'creates a customer in Stripe' do
      result = provider.create_customer(account, 'starter')

      expect(Stripe::Customer).to have_received(:create).with(
        {
          email: 'test@example.com',
          name: account.name,
          metadata: {
            account_id: account.id.to_s,
            plan: 'starter'
          }
        },
        { idempotency_key: "customer_create_#{account.id}_starter" }
      )
      expect(result).to eq(stripe_customer)
    end

    it 'handles Stripe errors' do
      allow(Stripe::Customer).to receive(:create).and_raise(Stripe::StripeError.new('API error'))

      expect { provider.create_customer(account, 'starter') }
        .to raise_error(StandardError, /Failed to create customer/)
    end
  end

  describe '#create_subscription' do
    let(:stripe_subscription) { double('Stripe::Subscription', id: 'sub_123') }

    before do
      allow(Stripe::Subscription).to receive(:create).and_return(stripe_subscription)
    end

    it 'creates a subscription in Stripe' do
      result = provider.create_subscription('cus_123', 'price_123', 1)

      # Get the actual idempotency_key that was generated
      expect(Stripe::Subscription).to have_received(:create) do |params, options|
        expect(params[:customer]).to eq('cus_123')
        expect(params[:items]).to eq([{ price: 'price_123', quantity: 1 }])
        expect(params[:collection_method]).to eq('charge_automatically')
        expect(params[:payment_behavior]).to eq('default_incomplete')
        expect(params[:expand]).to eq(['latest_invoice.payment_intent'])
        expect(params[:metadata][:plan_id]).to eq('price_123')
        expect(params[:metadata][:quantity]).to eq('1')
        expect(options[:idempotency_key]).to match(/^subscription_create_cus_123_price_123_/)
      end
      expect(result).to eq(stripe_subscription)
    end

    it 'returns nil for free trial plans' do
      result = provider.create_subscription('cus_123', nil, 1)
      expect(result).to be_nil
      expect(Stripe::Subscription).not_to have_received(:create)
    end

    it 'handles Stripe errors' do
      allow(Stripe::Subscription).to receive(:create).and_raise(Stripe::StripeError.new('API error'))

      expect { provider.create_subscription('cus_123', 'price_123', 1) }
        .to raise_error(StandardError, /Failed to create subscription/)
    end
  end

  describe '#create_portal_session' do
    let(:portal_session) { double('Stripe::BillingPortal::Session', id: 'bps_123', url: 'https://billing.stripe.com/session') }

    before do
      allow(Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)
    end

    it 'creates a portal session in Stripe' do
      result = provider.create_portal_session('cus_123', 'https://example.com/return')

      expect(Stripe::BillingPortal::Session).to have_received(:create).with(
        customer: 'cus_123',
        return_url: 'https://example.com/return'
      )
      expect(result).to eq(portal_session)
    end

    it 'handles Stripe errors' do
      allow(Stripe::BillingPortal::Session).to receive(:create).and_raise(Stripe::StripeError.new('API error'))

      expect { provider.create_portal_session('cus_123', 'https://example.com/return') }
        .to raise_error(StandardError, /Failed to create portal session/)
    end
  end

  describe '#verify_webhook_signature' do
    it 'returns true for valid signatures' do
      allow(Stripe::Webhook).to receive(:construct_event).and_return(double('Event'))

      result = provider.verify_webhook_signature('payload', 'signature', 'secret')

      expect(result).to be true
      expect(Stripe::Webhook).to have_received(:construct_event).with('payload', 'signature', 'secret')
    end

    it 'returns false for invalid signatures' do
      allow(Stripe::Webhook).to receive(:construct_event).and_raise(Stripe::SignatureVerificationError.new('Invalid signature', 'signature'))

      result = provider.verify_webhook_signature('payload', 'invalid_signature', 'secret')

      expect(result).to be false
    end
  end

  describe '#get_customer' do
    let(:stripe_customer) { double('Stripe::Customer', id: 'cus_123') }

    before do
      allow(Stripe::Customer).to receive(:retrieve).and_return(stripe_customer)
    end

    it 'retrieves a customer from Stripe' do
      result = provider.get_customer('cus_123')

      expect(Stripe::Customer).to have_received(:retrieve).with('cus_123')
      expect(result).to eq(stripe_customer)
    end

    it 'handles Stripe errors' do
      allow(Stripe::Customer).to receive(:retrieve).and_raise(Stripe::StripeError.new('Not found'))

      expect { provider.get_customer('cus_123') }
        .to raise_error(StandardError, /Failed to retrieve customer/)
    end
  end

  describe '#get_subscription' do
    let(:stripe_subscription) { double('Stripe::Subscription', id: 'sub_123') }

    before do
      allow(Stripe::Subscription).to receive(:retrieve).and_return(stripe_subscription)
    end

    it 'retrieves a subscription from Stripe' do
      result = provider.get_subscription('sub_123')

      expect(Stripe::Subscription).to have_received(:retrieve).with('sub_123')
      expect(result).to eq(stripe_subscription)
    end

    it 'handles Stripe errors' do
      allow(Stripe::Subscription).to receive(:retrieve).and_raise(Stripe::StripeError.new('Not found'))

      expect { provider.get_subscription('sub_123') }
        .to raise_error(StandardError, /Failed to retrieve subscription/)
    end
  end

  describe '#cancel_subscription' do
    let(:updated_subscription) { double('Stripe::Subscription', id: 'sub_123', status: 'active', cancel_at_period_end: true) }

    before do
      allow(Stripe::Subscription).to receive(:update).and_return(updated_subscription)
    end

    it 'cancels a subscription at period end by default' do
      result = provider.cancel_subscription('sub_123')

      expect(Stripe::Subscription).to have_received(:update).with(
        'sub_123',
        { cancel_at_period_end: true }
      )
      expect(result).to eq(updated_subscription)
    end

    it 'handles Stripe errors' do
      allow(Stripe::Subscription).to receive(:update).and_raise(Stripe::StripeError.new('Cannot cancel'))

      expect { provider.cancel_subscription('sub_123') }
        .to raise_error(StandardError, /Failed to update subscription/)
    end
  end

  describe '#update_subscription' do
    let(:existing_subscription) do
      double('Stripe::Subscription',
             items: double('Items', data: [double('Item', id: 'si_123')]))
    end
    let(:updated_subscription) { double('Stripe::Subscription', id: 'sub_123') }

    before do
      allow(provider).to receive(:get_subscription).and_return(existing_subscription)
      allow(Stripe::Subscription).to receive(:update).and_return(updated_subscription)
    end

    it 'updates a subscription with new plan' do
      result = provider.update_subscription('sub_123', { plan_id: 'price_456' })

      expect(Stripe::Subscription).to have_received(:update).with('sub_123', {
                                                                    items: [{ id: 'si_123', price: 'price_456' }]
                                                                  })
      expect(result).to eq(updated_subscription)
    end

    it 'updates a subscription with new quantity' do
      result = provider.update_subscription('sub_123', { quantity: 5 })

      expect(Stripe::Subscription).to have_received(:update).with('sub_123', {
                                                                    quantity: 5
                                                                  })
      expect(result).to eq(updated_subscription)
    end

    it 'handles Stripe errors' do
      allow(Stripe::Subscription).to receive(:update).and_raise(Stripe::StripeError.new('Update failed'))

      expect { provider.update_subscription('sub_123', { quantity: 5 }) }
        .to raise_error(StandardError, /Failed to update subscription/)
    end
  end

  describe '#handle_webhook' do
    let(:webhook_account) { create(:account, custom_attributes: { 'stripe_customer_id' => 'cus_123' }) }

    before do
      webhook_account # Ensure account exists
    end

    context 'checkout session completed event' do
      let(:stripe_subscription) do
        {
          'status' => 'active',
          'customer' => 'cus_123',
          'default_payment_method' => 'pm_123',
          'current_period_end' => 1_234_567_890,
          'items' => { 'data' => [{ 'quantity' => 1 }] },
          'metadata' => { 'plan_name' => 'starter' }
        }
      end

      let(:event_data) do
        {
          'type' => 'checkout.session.completed',
          'data' => {
            'object' => {
              'customer' => 'cus_123',
              'subscription' => 'sub_123',
              'metadata' => {
                'account_id' => webhook_account.id.to_s,
                'plan_name' => 'starter'
              }
            }
          }
        }
      end

      before do
        allow(provider).to receive(:get_subscription).with('sub_123').and_return(stripe_subscription)
        allow(Stripe::Customer).to receive(:update).and_return(double('Customer', id: 'cus_123'))

        # Stub the Stripe API call that happens in sync_account_features
        stub_request(:get, 'https://api.stripe.com/v1/subscriptions')
          .with(query: { customer: 'cus_123', status: 'all' })
          .to_return(
            status: 200,
            body: {
              object: 'list',
              data: [stripe_subscription]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Stub Price and Product API calls that might be made by StripeMetadataExtractor
        stub_request(:get, %r{https://api\.stripe\.com/v1/prices/.*})
          .to_return(
            status: 200,
            body: {
              id: 'price_123',
              product: 'prod_123'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, %r{https://api\.stripe\.com/v1/products/.*})
          .to_return(
            status: 200,
            body: {
              id: 'prod_123',
              metadata: { 'plan_name' => 'starter' }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'handles checkout session completed events' do
        result = provider.handle_webhook(event_data)

        expect(result[:success]).to be true
        expect(result[:message]).to include('Checkout session completed and account updated successfully')

        webhook_account.reload
        expect(webhook_account.custom_attributes['plan_name']).to eq('starter')
        expect(webhook_account.custom_attributes['subscription_status']).to eq('active')
        expect(webhook_account.custom_attributes['stripe_customer_id']).to eq('cus_123')
      end

      it 'sets the subscription payment method as customer default' do
        result = provider.handle_webhook(event_data)

        expect(result[:success]).to be true
        
        # Verify that Stripe::Customer.update was called to set default payment method
        expect(Stripe::Customer).to have_received(:update).with(
          'cus_123',
          invoice_settings: {
            default_payment_method: 'pm_123'
          }
        )
      end

      it 'handles missing payment method gracefully' do
        # Subscription without payment method
        subscription_without_pm = stripe_subscription.except('default_payment_method')
        allow(provider).to receive(:get_subscription).with('sub_123').and_return(subscription_without_pm)

        result = provider.handle_webhook(event_data)

        # Webhook should still succeed
        expect(result[:success]).to be true
        
        # Customer.update should not be called when payment method is missing
        expect(Stripe::Customer).not_to have_received(:update)
      end

      it 'continues webhook processing even if setting default payment method fails' do
        # Simulate Stripe error when updating customer
        allow(Stripe::Customer).to receive(:update).and_raise(Stripe::StripeError.new('Customer update failed'))

        result = provider.handle_webhook(event_data)

        # Webhook should still succeed (non-blocking operation)
        expect(result[:success]).to be true
        expect(result[:message]).to include('Checkout session completed and account updated successfully')
        
        # Account should still be updated with subscription data
        webhook_account.reload
        expect(webhook_account.custom_attributes['plan_name']).to eq('starter')
      end

      it 'handles missing account' do
        event_data['data']['object']['metadata']['account_id'] = '999999'

        result = provider.handle_webhook(event_data)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Account not found from checkout session metadata')
      end
    end

    context 'subscription created event' do
      let(:event_data) do
        {
          'type' => 'customer.subscription.created',
          'data' => {
            'object' => {
              'customer' => 'cus_123',
              'status' => 'active',
              'current_period_end' => 1_234_567_890,
              'items' => { 'data' => [{ 'quantity' => 1 }] },
              'metadata' => {
                'account_id' => webhook_account.id.to_s,
                'plan_name' => 'starter'
              }
            }
          }
        }
      end

      before do
        # Stub the Stripe API call that happens in sync_account_features
        stub_request(:get, 'https://api.stripe.com/v1/subscriptions')
          .with(query: { customer: 'cus_123', status: 'all' })
          .to_return(
            status: 200,
            body: {
              object: 'list',
              data: [event_data['data']['object']]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Stub Price and Product API calls that might be made by StripeMetadataExtractor
        stub_request(:get, %r{https://api\.stripe\.com/v1/prices/.*})
          .to_return(
            status: 200,
            body: {
              id: 'price_123',
              product: 'prod_123'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, %r{https://api\.stripe\.com/v1/products/.*})
          .to_return(
            status: 200,
            body: {
              id: 'prod_123',
              metadata: { 'plan_name' => 'starter' }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'handles subscription created events' do
        result = provider.handle_webhook(event_data)

        expect(result[:success]).to be true
        expect(result[:message]).to include('created and account updated')
      end
    end

    context 'unhandled event type' do
      let(:event_data) do
        {
          'type' => 'unknown.event',
          'data' => { 'object' => {} }
        }
      end

      it 'acknowledges but does not process unknown events' do
        result = provider.handle_webhook(event_data)

        expect(result[:success]).to be true
        expect(result[:message]).to include('acknowledged but not processed')
      end
    end
  end
end