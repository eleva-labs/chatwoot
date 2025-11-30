# frozen_string_literal: true

# Service to enforce conversation limits
# Tracks monthly conversation usage and manages conversation pack purchases
class Billing::ConversationLimitService
  include BillingPlans

  def initialize(account)
    @account = account
    @plan_name = account.custom_attributes&.dig('plan_name') || 'starter'
    @plan_config = self.class.plan_details(@plan_name)
  end

  # Check if a new conversation can be created
  def can_create_conversation?
    # Unlimited plans can always create
    return true if unlimited?

    current_month_conversations < total_allowed_conversations
  end

  # Total allowed conversations this month
  def total_allowed_conversations
    return Float::INFINITY if unlimited?

    plan_limit + purchased_extra_conversations
  end

  # Plan's base conversation limit
  def plan_limit
    # Use plan_limits() to get limits from Stripe metadata first, then YAML fallback
    plan_limits = self.class.plan_limits(@plan_name)
    plan_limits['conversations_monthly'] || 0
  end

  # Extra conversations purchased via one-time packs
  def purchased_extra_conversations
    # Track purchased packs in custom_attributes
    purchased_this_period = @account.custom_attributes&.dig('extra_conversations_purchased')&.to_i || 0
    
    # Reset if new billing period
    if new_billing_period?
      reset_purchased_conversations
      return 0
    end
    
    purchased_this_period
  end

  # Current month's conversation count
  def current_month_conversations
    period_start = billing_period_start
    @account.conversations.where('created_at >= ?', period_start).count
  end

  # Conversations remaining this month
  def conversations_remaining
    return Float::INFINITY if unlimited?

    [total_allowed_conversations - current_month_conversations, 0].max
  end

  # Usage percentage
  def usage_percentage
    return 0 if unlimited?
    return 100 if total_allowed_conversations.zero?

    ((current_month_conversations.to_f / total_allowed_conversations) * 100).round(1)
  end

  # Check if approaching limit (>= 80%)
  def approaching_limit?
    return false if unlimited?

    usage_percentage >= 80
  end

  # Upgrade options when limit reached
  def upgrade_options
    pack_info = conversation_pack_info

    {
      conversation_pack: pack_info ? {
        description: "#{format_number(pack_info[:conversations])} extra conversations",
        price: pack_info[:unit_price_formatted],
        conversations: pack_info[:conversations],
        action: 'purchase_pack',
        endpoint: "/api/v2/accounts/#{@account.id}/billing/conversation_packs/purchase"
      } : nil,
      next_tier: next_tier_option
    }.compact
  end

  # Get full status
  def status
    {
      current: current_month_conversations,
      plan_limit: unlimited? ? 'unlimited' : plan_limit,
      purchased: purchased_extra_conversations,
      total_allowed: unlimited? ? 'unlimited' : total_allowed_conversations,
      remaining: unlimited? ? 'unlimited' : conversations_remaining,
      usage_percentage: unlimited? ? 0 : usage_percentage,
      can_create: can_create_conversation?,
      approaching_limit: approaching_limit?,
      at_limit: !can_create_conversation?,
      billing_period_start: billing_period_start.iso8601,
      billing_period_end: billing_period_end.iso8601
    }
  end

  # Get conversation pack pricing info
  def conversation_pack_info
    # Use unified service to check if add-ons can be purchased
    purchase_check = Billing::CanPurchaseAddOnsService.new(@account)
    return nil if purchase_check.blocked?
    return nil if @plan_name == 'enterprise'

    pack_config = @plan_config&.dig('conversation_packs')
    return nil unless pack_config

    lookup_key = pack_config['lookup_key']
    price = fetch_price_from_stripe(lookup_key)
    return nil unless price

    {
      lookup_key: lookup_key,
      conversations: pack_config['conversations'],
      unit_price_cents: price.unit_amount,
      unit_price_formatted: "$#{format('%.2f', price.unit_amount / 100.0)}",
      currency: price.currency.upcase
    }
  end

  private

  def unlimited?
    # Use plan_limits() to get limits from Stripe metadata first, then YAML fallback
    plan_limits = self.class.plan_limits(@plan_name)
    (plan_limits['conversations_monthly'] || 0) == -1
  end

  def billing_period_start
    # Use subscription's current_period_start if available
    period_start_timestamp = @account.custom_attributes&.dig('current_period_start')
    
    if period_start_timestamp.present?
      Time.zone.at(period_start_timestamp.to_i)
    else
      # Fallback to start of current month
      Time.current.beginning_of_month
    end
  end

  def billing_period_end
    # Use subscription's current_period_end if available
    period_end_timestamp = @account.custom_attributes&.dig('current_period_end')
    
    if period_end_timestamp.present?
      Time.zone.at(period_end_timestamp.to_i)
    else
      # Fallback to end of current month
      Time.current.end_of_month
    end
  end

  def new_billing_period?
    last_reset = @account.custom_attributes&.dig('conversations_last_reset')
    return true unless last_reset

    last_reset_time = Time.zone.at(last_reset.to_i)
    last_reset_time < billing_period_start
  end

  def reset_purchased_conversations
    attrs = @account.custom_attributes || {}
    attrs['extra_conversations_purchased'] = 0
    attrs['conversations_last_reset'] = Time.current.to_i
    @account.custom_attributes = attrs
    @account.save!
  end

  def fetch_price_from_stripe(lookup_key)
    return nil unless lookup_key

    # Expand product to fetch metadata (name, description, custom fields)
    prices = ::Stripe::Price.list(
      lookup_keys: [lookup_key],
      limit: 1,
      expand: ['data.product']
    )
    prices.data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching price from Stripe: #{e.message}"
    nil
  end

  def format_number(num)
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def next_tier_option
    case @plan_name
    when 'community'
      {
        plan: 'starter',
        limit: format_number(self.class.plan_limits('starter')['conversations_monthly'] || 0),
        action: 'upgrade'
      }
    when 'starter'
      {
        plan: 'professional',
        limit: format_number(self.class.plan_limits('professional')['conversations_monthly'] || 0),
        action: 'upgrade'
      }
    when 'professional'
      {
        plan: 'enterprise',
        limit: 'unlimited',
        action: 'contact_sales'
      }
    else
      nil
    end
  end
end

