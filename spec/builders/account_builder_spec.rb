# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountBuilder do
  let(:email) { 'user@example.com' }
  let(:user_password) { 'Password123!' }
  let(:account_name) { 'Test Account' }
  let(:user_full_name) { 'Test User' }
  let(:validation_service) { instance_double(Account::SignUpEmailValidationService, perform: true) }
  let(:account_builder) do
    described_class.new(
      account_name: account_name,
      email: email,
      user_full_name: user_full_name,
      user_password: user_password,
      confirmed: true
    )
  end

  # Mock the email validation service and Stripe subscription creation
  before do
    allow(Account::SignUpEmailValidationService).to receive(:new).with(email).and_return(validation_service)
    # Mock Stripe subscription creation to avoid actual API calls in tests
    allow_any_instance_of(Billing::CreateCustomerService).to receive(:perform).and_return({ success: true })
  end

  describe '#perform' do
    context 'when valid params are passed' do
      it 'creates a new account with correct name' do
        _user, account = account_builder.perform
        expect(account).to be_an(Account)
        expect(account.name).to eq(account_name)
      end

      it 'creates a new confirmed user with correct details' do
        user, _account = account_builder.perform
        expect(user).to be_a(User)
        expect(user.email).to eq(email)
        expect(user.name).to eq(user_full_name)
        expect(user.confirmed?).to be(true)
      end

      it 'links user to account as administrator' do
        user, account = account_builder.perform
        expect(user.account_users.first.role).to eq('administrator')
        expect(user.accounts.first).to eq(account)
      end

      it 'increments the counts of models' do
        expect do
          account_builder.perform
        end.to change(Account, :count).by(1)
           .and change(User, :count).by(1)
           .and change(AccountUser, :count).by(1)
      end
    end

    context 'when an account is created' do
      it 'does not add store_id to custom_attributes (removed - using account.id with id_type=external instead)' do
        _user, account = account_builder.perform

        # store_id is no longer stored in custom_attributes
        # All AI Backend services now use account.id with id_type=external
        expect(account.custom_attributes).not_to have_key('store_id')
      end

      it 'sets initial starter plan with trialing status and billing status provisioning_pending' do
        _user, account = account_builder.perform

        expect(account.custom_attributes['plan_name']).to eq('starter')
        expect(account.custom_attributes['subscription_status']).to eq('trialing')
        expect(account.custom_attributes['billing_status']).to eq('provisioning_pending')
      end

      it 'sets starter plan limits correctly' do
        _user, account = account_builder.perform

        expect(account.limits).to include(
          'agents' => 5,
          'inboxes' => 2,
          'conversations_monthly' => 4000
        )
      end

      it 'calls CreateCustomerService to create Stripe subscription' do
        expect_any_instance_of(Billing::CreateCustomerService).to receive(:perform).and_return({ success: true })
        account_builder.perform
      end

      it 'dispatches owner_token_updated event after user is linked to account' do
        # Allow the account.created event (triggered by Account's after_create_commit callback)
        allow(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::ACCOUNT_CREATED,
          an_instance_of(ActiveSupport::TimeWithZone),
          hash_including(account: an_instance_of(Account))
        )

        # Allow the agent.added event (triggered by AccountUser's after_create_commit callback)
        allow(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::AGENT_ADDED,
          an_instance_of(ActiveSupport::TimeWithZone),
          hash_including(account: an_instance_of(Account), account_user: an_instance_of(AccountUser))
        )

        # Expect the owner_token_updated event to be dispatched when user is linked to account
        expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
          Events::Types::OWNER_TOKEN_UPDATED,
          an_instance_of(ActiveSupport::TimeWithZone),
          hash_including(
            account: an_instance_of(Account),
            user: an_instance_of(User),
            token: an_instance_of(String)
          )
        )

        user, account = account_builder.perform

        # Verify user has access token
        expect(user.access_token).to be_present
        expect(user.accounts).to include(account)
      end

      it 'creates access token for user during account creation' do
        user, _account = account_builder.perform

        # User should have access token created via after_create callback
        expect(user.access_token).to be_present
        expect(user.access_token.token).to be_present
      end
    end
  end
end
