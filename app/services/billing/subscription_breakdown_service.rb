# frozen_string_literal: true

# Service to calculate subscription cost breakdown (base plan + add-ons)
class Billing::SubscriptionBreakdownService
  include BillingPlans

  def initialize(account)
    @account = account
    @plan_name = account.custom_attributes&.dig('plan_name') || 'free_trial'
    @plan_config = self.class.plan_details(@plan_name)
  end

  def breakdown
    # Try to fetch subscription from Stripe first
    subscription = fetch_subscription
    
    if subscription
      # Active paid subscription - use Stripe data
      {
        plan_name: @plan_name.titleize,
        base_plan: base_plan_details(subscription),
        add_ons: add_on_details(subscription),
        total: calculate_total(subscription),
        next_billing_date: subscription.current_period_end,
        currency: subscription.currency&.upcase || 'USD'
      }
    else
      # No Stripe subscription (free trial, community, etc.) - use plan config
      build_breakdown_from_plan_config
    end
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching subscription breakdown: #{e.message}"
    build_breakdown_from_plan_config
  end

  private

  def base_plan_details(subscription)
    # Find the base plan subscription item (not an add-on)
    plan_price_id = self.class.plan_price_id(@plan_name)
    
    base_item = if plan_price_id.present?
                  subscription.items.data.find do |item|
                    item.price.id == plan_price_id
                  end
                else
                  # If no price_id configured, take the first non-add-on item
                  # (item that doesn't have a lookup_key matching add-on patterns)
                  subscription.items.data.find do |item|
                    lookup_key = item.price.lookup_key
                    lookup_key.nil? || !lookup_key.match?(/extra_|conversation_pack/)
                  end
                end

    # If we found a base item, use it; otherwise create a basic structure
    if base_item
      price = base_item.price
      unit_amount = price.unit_amount || 0

      {
        name: "#{@plan_name.titleize} Plan",
        price_cents: unit_amount,
        price_formatted: format_price(unit_amount),
        interval: price.recurring&.interval,
        inclusions: plan_inclusions
      }
    else
      # Fallback for subscriptions without a clear base item (e.g., trial-only)
      {
        name: "#{@plan_name.titleize} Plan",
        price_cents: 0,
        price_formatted: '$0.00',
        interval: 'month',
        inclusions: plan_inclusions
      }
    end
  end

  def plan_inclusions
    limits = @plan_config&.dig('limits') || {}

    inclusions = []
    inclusions << "#{limits['agents']} agents included" if limits['agents']&.positive?
    inclusions << "#{limits['inboxes']} inboxes included" if limits['inboxes']&.positive?

    if limits['conversations_monthly']&.positive?
      inclusions << "#{number_with_delimiter(limits['conversations_monthly'])} conversations/month"
    end

    inclusions
  end

  def add_on_details(subscription)
    add_ons = []

    # Get all subscription items that are add-ons (not the base plan)
    subscription.items.data.each do |item|
      next if item.price.id == self.class.plan_price_id(@plan_name)

      # Determine add-on type from lookup_key
      add_on_type = determine_add_on_type(item.price.lookup_key)
      next unless add_on_type

      quantity = item.quantity || 0
      next if quantity.zero? # Only show active add-ons

      unit_price = item.price.unit_amount || 0
      total_price = unit_price * quantity

      add_ons << {
        type: add_on_type,
        name: add_on_name(add_on_type),
        quantity: quantity,
        unit_price_cents: unit_price,
        unit_price_formatted: format_price(unit_price),
        total_price_cents: total_price,
        total_price_formatted: format_price(total_price),
        interval: item.price.recurring&.interval
      }
    end

    add_ons
  end

  def determine_add_on_type(lookup_key)
    return nil unless lookup_key

    case lookup_key
    when /agent/
      'agent'
    when /inbox/
      'inbox'
    when /channel/
      'channel'
    else
      nil
    end
  end

  def add_on_name(type)
    case type
    when 'agent'
      'Extra Agents'
    when 'inbox'
      'Extra Inboxes'
    when 'channel'
      'Extra Channels'
    else
      type.titleize
    end
  end

  def calculate_total(subscription)
    total_cents = 0

    subscription.items.data.each do |item|
      unit_price = item.price.unit_amount || 0
      quantity = item.quantity || 0
      total_cents += (unit_price * quantity)
    end

    {
      amount_cents: total_cents,
      amount_formatted: format_price(total_cents)
    }
  end

  def fetch_subscription
    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return nil unless customer_id

    subscriptions = ::Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
    subscriptions.data.first
  end

  def format_price(cents)
    return '$0.00' unless cents

    "$#{format('%.2f', cents / 100.0)}"
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def build_breakdown_from_plan_config
    # Build breakdown from plan configuration (for free trials, community plans, etc.)
    inclusions = plan_inclusions
    
    # If there are no inclusions, return free_plan_breakdown (truly empty plan)
    return free_plan_breakdown if inclusions.empty?
    
    {
      plan_name: @plan_name.titleize,
      base_plan: {
        name: "#{@plan_name.titleize} Plan",
        price_cents: 0,
        price_formatted: '$0.00',
        interval: 'month',
        inclusions: inclusions
      },
      add_ons: [],
      total: { amount_cents: 0, amount_formatted: '$0.00' },
      next_billing_date: trial_end_date,
      currency: 'USD'
    }
  end

  def trial_end_date
    # Get trial end date from account custom attributes
    subscription_ends_on = @account.custom_attributes&.dig('subscription_ends_on')
    return nil unless subscription_ends_on

    # Parse the date string and convert to Unix timestamp
    Time.parse(subscription_ends_on).to_i
  rescue ArgumentError
    nil
  end

  def free_plan_breakdown
    {
      plan_name: @plan_name.titleize,
      base_plan: nil,
      add_ons: [],
      total: { amount_cents: 0, amount_formatted: '$0.00' },
      next_billing_date: nil,
      currency: 'USD'
    }
  end
end

