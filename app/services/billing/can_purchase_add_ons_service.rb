# frozen_string_literal: true

module Billing
  # Service to check if account can purchase add-ons
  # Unifies checks for both trial and past_due states
  #
  # Usage:
  #   service = Billing::CanPurchaseAddOnsService.new(account)
  #   service.can_purchase?   # => true/false
  #   service.blocked?        # => true/false
  #   service.reason          # => 'trial', 'past_due', 'community', or nil
  #   service.error_message   # => User-friendly error message or nil
  class CanPurchaseAddOnsService
    def initialize(account)
      @account = account
    end

    # Check if account can purchase add-ons
    def can_purchase?
      !blocked?
    end

    # Check if account is blocked from purchasing add-ons
    def blocked?
      trialing? || past_due? || community_plan?
    end

    # Get the reason for blocking (for logging/debugging)
    # Returns: 'trial', 'past_due', 'community', or nil
    def reason
      return 'trial' if trialing?
      return 'past_due' if past_due?
      return 'community' if community_plan?

      nil
    end

    # Get user-friendly error message for the blocking reason
    def error_message
      case reason
      when 'trial'
        'Add-ons cannot be purchased during the trial period. Please wait until your trial ends.'
      when 'past_due'
        'Your subscription payment is past due. Please update your payment method before purchasing add-ons.'
      when 'community'
        'Add-ons are not available for the community plan. Please upgrade to a paid plan.'
      end
    end

    private

    def subscription_status
      @account.custom_attributes&.dig('subscription_status')
    end

    def plan_name
      @account.custom_attributes&.dig('plan_name')
    end

    def trialing?
      subscription_status == Billing::SubscriptionStatuses::TRIALING
    end

    def past_due?
      subscription_status == Billing::SubscriptionStatuses::PAST_DUE
    end

    def community_plan?
      plan_name == 'community'
    end
  end
end
