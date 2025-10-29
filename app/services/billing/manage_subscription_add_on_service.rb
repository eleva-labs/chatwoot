# frozen_string_literal: true

# Service to manage subscription add-ons (extra agents, inboxes, channels)
# Handles adding, removing, and updating quantities of add-on subscription items
class Billing::ManageSubscriptionAddOnService
  include BillingPlans

  ADD_ON_TYPES = %i[agent inbox channel].freeze

  def initialize(account, add_on_type)
    @account = account
    @add_on_type = add_on_type.to_sym
    @plan_name = account.custom_attributes&.dig('plan_name') || 'free_trial'
    @plan_config = plan_details(@plan_name)

    raise ArgumentError, "Invalid add-on type: #{add_on_type}. Must be one of: #{ADD_ON_TYPES.join(', ')}" unless ADD_ON_TYPES.include?(@add_on_type)
    raise StandardError, "Add-ons not available for plan: #{@plan_name}" unless add_ons_available?
  end

  # Add one unit of the add-on
  def add_unit
    update_quantity(current_quantity + 1)
  end

  # Remove one unit of the add-on
  def remove_unit
    return failure_response('Cannot remove below 0') if current_quantity.zero?

    update_quantity(current_quantity - 1)
  end

  # Set specific quantity
  def set_quantity(quantity)
    raise ArgumentError, 'Quantity must be non-negative' if quantity.negative?

    update_quantity(quantity)
  end

  # Get current quantity of purchased add-ons
  def current_quantity
    subscription = fetch_subscription
    return 0 unless subscription

    item = find_subscription_item(subscription)
    item&.quantity || 0
  end

  # Get add-on configuration and pricing from Stripe
  def add_on_info
    add_on_config = @plan_config.dig('add_ons', @add_on_type.to_s)
    return nil unless add_on_config

    lookup_key = add_on_config['lookup_key']
    price = fetch_price_from_stripe(lookup_key)

    {
      type: @add_on_type,
      lookup_key: lookup_key,
      current_quantity: current_quantity,
      unit_price_cents: price&.unit_amount,
      unit_price_formatted: format_price(price&.unit_amount),
      currency: price&.currency&.upcase,
      interval: price&.recurring&.interval
    }
  end

  private

  def update_quantity(new_quantity)
    subscription = fetch_subscription
    return failure_response('No active subscription found') unless subscription

    item = find_subscription_item(subscription)

    if new_quantity.zero?
      # Remove the item if quantity is 0
      remove_subscription_item(item) if item
      success_response("#{@add_on_type} add-on removed", quantity: 0)
    elsif item
      # Update existing item
      updated_item = ::Stripe::SubscriptionItem.update(
        item.id,
        quantity: new_quantity,
        proration_behavior: 'create_prorations'
      )
      success_response("#{@add_on_type} quantity updated to #{new_quantity}", quantity: new_quantity, item: updated_item)
    else
      # Create new item
      add_on_config = @plan_config.dig('add_ons', @add_on_type.to_s)
      lookup_key = add_on_config['lookup_key']
      price = fetch_price_from_stripe(lookup_key)

      return failure_response("Price not found in Stripe for lookup_key: #{lookup_key}") unless price

      new_item = ::Stripe::SubscriptionItem.create(
        subscription: subscription.id,
        price: price.id,
        quantity: new_quantity,
        proration_behavior: 'create_prorations'
      )
      success_response("#{@add_on_type} add-on added with quantity #{new_quantity}", quantity: new_quantity, item: new_item)
    end
  rescue ::Stripe::RateLimitError => e
    Rails.logger.warn "Stripe rate limit hit: #{e.message}"
    failure_response("Rate limited - please try again: #{e.message}")
  rescue ::Stripe::InvalidRequestError => e
    Rails.logger.error "Stripe invalid request: #{e.message}"
    failure_response("Invalid request: #{e.message}")
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Failed to update #{@add_on_type} add-on: #{e.message}"
    failure_response(e.message)
  end

  def find_subscription_item(subscription)
    add_on_config = @plan_config.dig('add_ons', @add_on_type.to_s)
    return nil unless add_on_config

    lookup_key = add_on_config['lookup_key']

    subscription.items.data.find do |item|
      item.price.lookup_key == lookup_key
    end
  end

  def remove_subscription_item(item)
    ::Stripe::SubscriptionItem.delete(
      item.id,
      proration_behavior: 'create_prorations'
    )
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

  def fetch_price_from_stripe(lookup_key)
    return nil unless lookup_key

    # Search for price by lookup_key
    prices = ::Stripe::Price.list(lookup_keys: [lookup_key], limit: 1)
    prices.data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching price from Stripe: #{e.message}"
    nil
  end

  def add_ons_available?
    # Free trial and community plans don't support add-ons
    return false if %w[free_trial community].include?(@plan_name)

    # Enterprise has unlimited, no need for add-ons
    return false if @plan_name == 'enterprise'

    # Check if plan has add-on configuration
    @plan_config&.dig('add_ons', @add_on_type.to_s).present?
  end

  def format_price(cents)
    return nil unless cents

    "$#{format('%.2f', cents / 100.0)}"
  end

  def success_response(message, data = {})
    {
      success: true,
      message: message,
      add_on_type: @add_on_type
    }.merge(data)
  end

  def failure_response(error)
    {
      success: false,
      error: error,
      add_on_type: @add_on_type
    }
  end
end

