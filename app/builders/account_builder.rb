# frozen_string_literal: true

class AccountBuilder
  include CustomExceptions::Account
  include BillingPlans
  pattr_initialize [:account_name, :email!, :confirmed, :user, :user_full_name, :user_password, :super_admin, :locale]

  def perform
    if @user.nil?
      validate_email
      validate_user
    end
    ActiveRecord::Base.transaction do
      @account = create_account
      @user = create_and_link_user
      create_stripe_trial_subscription
    end

    [@user, @account]
  rescue StandardError => e
    Rails.logger.debug e.inspect
    raise e
  end

  private

  def user_full_name
    # the empty string ensures that not-null constraint is not violated
    @user_full_name || ''
  end

  def account_name
    # the empty string ensures that not-null constraint is not violated
    @account_name || ''
  end

  def validate_email
    Account::SignUpEmailValidationService.new(@email).perform
  end

  def validate_user
    if User.exists?(email: @email)
      raise UserExists.new(email: @email)
    else
      true
    end
  end

  def create_account
    @account = Account.new(name: account_name, locale: I18n.locale)
    set_initial_plan_attributes
    @account.save!

    Current.account = @account
    @account
  end

  def create_and_link_user
    if @user.present? || create_user
      link_user_to_account(@user, @account)
      @user.reload # Reload to pick up the new account association
      @user
    else
      raise UserErrors.new(errors: @user.errors)
    end
  end

  def link_user_to_account(user, account)
    AccountUser.create!(
      account_id: account.id,
      user_id: user.id,
      role: AccountUser.roles['administrator'],
      inviter_id: nil # Explicitly mark as account creator (not invited)
    )

    # Sync owner token to AI backend after account creator is linked
    # NOTE: Only account creators (inviter_id: nil) trigger this, not invited admins
    dispatch_owner_token_event(user, account) if user.access_token.present?
  end

  def create_user
    @user = User.new(email: @email,
                     password: user_password,
                     password_confirmation: user_password,
                     name: user_full_name)
    @user.type = 'SuperAdmin' if @super_admin
    @user.confirm if @confirmed
    @user.save!
  end

  def set_initial_plan_attributes
    # Set initial attributes with 'starter' plan
    # Actual subscription status will be updated by CreateCustomerService
    plan_name = 'starter'
    plan_details = self.class.plan_details(plan_name)

    # Use starter plan limits as defaults for trial
    plan_limits = if plan_details
                    {
                      'agents' => plan_details.dig('limits', 'agents') || 5,
                      'inboxes' => plan_details.dig('limits', 'inboxes') || 2,
                      'conversations_monthly' => plan_details.dig('limits', 'conversations_monthly') || 4000
                    }
                  else
                    # Fallback defaults if plan config not found
                    { 'agents' => 5, 'inboxes' => 2, 'conversations_monthly' => 4000 }
                  end

    @account.custom_attributes ||= {}
    @account.custom_attributes.merge!({
                                        'plan_name' => plan_name,
                                        'subscription_status' => Billing::SubscriptionStatuses::TRIALING,
                                        'billing_status' => 'provisioning_pending'
                                      })

    # Set plan limits
    @account.limits = plan_limits
  end

  def dispatch_owner_token_event(user, account)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::OWNER_TOKEN_UPDATED,
      Time.zone.now,
      account: account,
      user: user,
      token: user.access_token.token
    )
    Rails.logger.info "Dispatched owner_token_updated event for user #{user.id}, account #{account.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to dispatch owner_token_updated event: #{e.message}"
    # Don't raise - account creation should succeed even if token sync fails
  end

  def create_stripe_trial_subscription
    Rails.logger.info "Creating Stripe trial subscription for account #{@account.id}"

    # Get trial period from starter plan config
    plan_details = self.class.plan_details('starter')
    trial_days = plan_details&.dig('trial_expires_in_days') || 7

    # Create customer and subscription in Stripe
    result = Billing::CreateCustomerService.new(@account, 'starter', trial_period_days: trial_days).perform

    if result[:success]
      Rails.logger.info "Stripe trial subscription created successfully for account #{@account.id}"
    else
      # If Stripe API fails, raise error to fail signup
      # User can retry signup later
      error_message = result[:error] || 'Failed to create billing subscription'
      Rails.logger.error "Failed to create Stripe subscription for account #{@account.id}: #{error_message}"
      raise StandardError, "Billing setup failed: #{error_message}"
    end
  rescue StandardError => e
    Rails.logger.error "Error creating Stripe trial subscription: #{e.message}"
    # Re-raise to fail signup - user needs to retry
    raise e
  end
end
