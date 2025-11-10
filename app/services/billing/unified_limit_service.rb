# frozen_string_literal: true

# Service to enforce resource limits (agents, inboxes, channels)
# Calculates total allowed = base plan limit + purchased add-ons
class Billing::UnifiedLimitService
  include BillingPlans

  RESOURCE_TYPES = %i[agent inbox channel].freeze

  def initialize(account, resource_type)
    @account = account
    @resource_type = resource_type.to_sym
    @plan_name = account.custom_attributes&.dig('plan_name') || 'free_trial'
    @plan_config = self.class.plan_details(@plan_name)

    raise ArgumentError, "Invalid resource type: #{resource_type}. Must be one of: #{RESOURCE_TYPES.join(', ')}" unless RESOURCE_TYPES.include?(@resource_type)
  end

  # Check if resource can be created
  def can_create?
    # Unlimited plans can always create
    return true if unlimited?

    current_count < total_allowed
  end

  # Total allowed (base + purchased)
  def total_allowed
    return Float::INFINITY if unlimited?

    base_limit + purchased_extra
  end

  # Base plan limit
  def base_limit
    limit_key = case @resource_type
                when :agent
                  'agents'
                when :inbox
                  'inboxes'
                when :channel
                  'inboxes' # Channels use inbox limits
                end

    @plan_config&.dig('limits', limit_key) || 0
  end

  # Purchased extra units from Stripe subscription items
  def purchased_extra
    # Free trial and community plans don't support add-ons
    return 0 if %w[free_trial community].include?(@plan_name)

    # Enterprise has unlimited
    return 0 if unlimited?

    subscription = fetch_subscription
    return 0 unless subscription

    lookup_key = @plan_config&.dig('add_ons', @resource_type.to_s, 'lookup_key')
    return 0 unless lookup_key

    item = subscription.items.data.find { |i| i.price.lookup_key == lookup_key }
    item&.quantity || 0
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching purchased add-ons: #{e.message}"
    0 # Fail safe - allow base limit
  end

  # Calculate how many extra seats are currently being used
  # Formula: extras_used = min(E, max(0, U - I))
  # where E = purchased extras, U = current usage, I = included seats
  def extras_used
    return 0 if unlimited?
    
    current = current_count
    included = base_limit
    purchased = purchased_extra
    
    # Calculate raw extras used (usage beyond included seats)
    raw_extras_used = current - included
    
    # Cap at purchased amount and ensure non-negative
    [0, [raw_extras_used, purchased].min].max
  end

  # Calculate how many extra seats are unused (available to remove)
  # Formula: unused_extras = E - extras_used
  def unused_extras
    return 0 if unlimited?
    
    purchased_extra - extras_used
  end

  # Check if user can remove specified quantity
  # @param quantity [Integer] Number of extras to remove
  # @return [Boolean] True if removal is allowed
  def can_remove?(quantity)
    return false if quantity.negative?
    return false if quantity > purchased_extra
    
    quantity <= unused_extras
  end

  # Current usage count
  def current_count
    case @resource_type
    when :agent
      @account.users.count
    when :inbox
      @account.inboxes.count
    when :channel
      @account.inboxes.count # Channels are tracked via inboxes
    else
      0
    end
  end

  # Remaining capacity
  def remaining
    return Float::INFINITY if unlimited?

    [total_allowed - current_count, 0].max
  end

  # Usage percentage
  def usage_percentage
    return 0 if unlimited?
    return 100 if total_allowed.zero?

    ((current_count.to_f / total_allowed) * 100).round(1)
  end

  # Check if approaching limit (>= 80%)
  def approaching_limit?
    return false if unlimited?

    usage_percentage >= 80
  end

  # Upgrade options when limit reached
  def upgrade_options
    add_on_info = get_add_on_pricing

    {
      purchase_extra: add_on_info ? {
        type: @resource_type,
        unit_price: add_on_info[:unit_price_formatted],
        action: 'purchase_add_on',
        endpoint: "/api/v2/accounts/#{@account.id}/billing/add_ons"
      } : nil,
      upgrade_plan: next_tier_option
    }.compact
  end

  # Get full limit status
  def status
    {
      resource_type: @resource_type,
      current: current_count,
      base_limit: unlimited? ? 'unlimited' : base_limit,
      purchased: purchased_extra,
      total_allowed: unlimited? ? 'unlimited' : total_allowed,
      remaining: unlimited? ? 'unlimited' : remaining,
      usage_percentage: unlimited? ? 0 : usage_percentage,
      can_create: can_create?,
      approaching_limit: approaching_limit?,
      at_limit: !can_create?,
      extras_used: unlimited? ? 0 : extras_used,
      unused_extras: unlimited? ? 0 : unused_extras
    }
  end

  private

  def unlimited?
    limit_key = case @resource_type
                when :agent
                  'agents'
                when :inbox, :channel
                  'inboxes'
                end

    (@plan_config&.dig('limits', limit_key) || 0) == -1
  end

  def fetch_subscription
    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return nil unless customer_id

    subscriptions = ::Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
    subscriptions.data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching subscription: #{e.message}"
    nil
  end

  def get_add_on_pricing
    return nil if %w[free_trial community enterprise].include?(@plan_name)

    add_on_config = @plan_config&.dig('add_ons', @resource_type.to_s)
    return nil unless add_on_config

    lookup_key = add_on_config['lookup_key']
    price = fetch_price_from_stripe(lookup_key)
    return nil unless price

    {
      lookup_key: lookup_key,
      unit_price_cents: price.unit_amount,
      unit_price_formatted: "$#{format('%.2f', price.unit_amount / 100.0)}",
      currency: price.currency.upcase,
      interval: price.recurring&.interval
    }
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

  def next_tier_option
    case @plan_name
    when 'free_trial'
      { plan: 'starter', action: 'upgrade_plan', endpoint: "/api/v2/accounts/#{@account.id}/subscription" }
    when 'starter'
      { plan: 'professional', action: 'upgrade_plan', endpoint: "/api/v2/accounts/#{@account.id}/subscription" }
    when 'professional'
      { plan: 'enterprise', action: 'contact_sales', endpoint: '/contact-sales' }
    else
      nil
    end
  end
end

