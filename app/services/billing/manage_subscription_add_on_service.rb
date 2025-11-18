# frozen_string_literal: true

# Service to manage subscription add-ons (extra agents, inboxes, channels)
# Handles adding, removing, and updating quantities of add-on subscription items
class Billing::ManageSubscriptionAddOnService
  include BillingPlans

  ADD_ON_TYPES = %i[agent inbox channel live_training live_1_1_training].freeze
  ALWAYS_INVOICE_ADD_ONS = %i[agent inbox live_training live_1_1_training].freeze

  def initialize(account, add_on_type)
    @account = account
    @add_on_type = add_on_type.to_sym
    @plan_name = account.custom_attributes&.dig('plan_name') || 'free_trial'
    @plan_config = self.class.plan_details(@plan_name)

    raise ArgumentError, "Invalid add-on type: #{add_on_type}. Must be one of: #{ADD_ON_TYPES.join(', ')}" unless ADD_ON_TYPES.include?(@add_on_type)
    raise StandardError, "Add-ons not available for plan: #{@plan_name}" unless add_ons_available?
  end

  # Add one unit of the add-on
  def add_unit
    update_quantity(current_quantity + 1)
  end

  # Remove one unit of the add-on
  # @param skip_validation [Boolean] If true, skips validation check (used when removing before deleting the resource)
  def remove_unit(skip_validation: false)
    return failure_response('Cannot remove below 0') if current_quantity.zero?
    
    # Validate against unused extras for capacity add-ons (unless validation is skipped)
    unless skip_validation || can_remove_quantity?(1)
      limit_service = Billing::UnifiedLimitService.new(@account, map_to_resource_type)
      unused = limit_service.unused_extras
      extras_used = limit_service.extras_used
      
      return failure_response(
        "Cannot remove - only #{unused} extra #{@add_on_type}(s) are unused (#{extras_used} in use). " \
        "Remove #{@add_on_type}s from #{settings_section_name} first to free up seats."
      )
    end

    update_quantity(current_quantity - 1)
  end

  # Set specific quantity
  def set_quantity(quantity)
    raise ArgumentError, 'Quantity must be non-negative' if quantity.negative?
    
    # If reducing quantity, validate against unused extras for capacity add-ons
    if quantity < current_quantity
      removal_count = current_quantity - quantity
      
      unless can_remove_quantity?(removal_count)
        limit_service = Billing::UnifiedLimitService.new(@account, map_to_resource_type)
        unused = limit_service.unused_extras
        extras_used = limit_service.extras_used
        
        return failure_response(
          "Cannot remove #{removal_count} - only #{unused} extra #{@add_on_type}(s) are unused (#{extras_used} in use). " \
          "Remove #{@add_on_type}s from #{settings_section_name} first to free up seats."
        )
      end
    end

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
    
    # Return nil if price not found in Stripe (indicates failure)
    return nil unless price

    info = {
      type: @add_on_type,
      lookup_key: lookup_key,
      current_quantity: current_quantity,
      unit_price_cents: price.unit_amount,
      unit_price_formatted: format_price(price.unit_amount),
      currency: price.currency&.upcase,
      interval: price.recurring&.interval
    }

    # Add product metadata if available (name, description, custom fields)
    if price&.product.present?
      product = price.product
      info.merge!({
        display_name: product.name,
        description: product.description,
        product_metadata: product.metadata.to_h  # Include all custom metadata fields
      })
    end

    # Enhanced fields for training add-ons
    if training_add_on?
      product = price&.product # Requires expand in fetch_price_from_stripe

      info.merge!({
        display_name: product&.name || I18n.t("billing.training.#{@add_on_type}.name"),
        description: product&.description,
        feature_bullets: extract_feature_bullets(product),
        max_quantity: add_on_config['max_quantity'] || 1,
        is_owned: current_quantity >= 1,
        category: add_on_config['category'] || 'training' # Default to 'training' for training add-ons
      })
    end

    info
  end

  private

  # Check if the current add-on is a training service
  def training_add_on?
    %i[live_training live_1_1_training].include?(@add_on_type)
  end

  # Extract feature bullets from Stripe product metadata
  # Iterates through metadata keys bullet_1, bullet_2, etc.
  # Falls back to i18n if no Stripe metadata found
  def extract_feature_bullets(product)
    return [] unless product

    bullets = []
    # Iterate through all possible bullet keys (1-10) without breaking on gaps
    # This handles non-sequential metadata keys (e.g., bullet_1, bullet_3 without bullet_2)
    (1..10).each do |i|
      bullet_text = product.metadata["bullet_#{i}"]
      bullets << bullet_text if bullet_text.present?
    end

    # Fallback to i18n if no Stripe metadata
    if bullets.empty?
      bullets = I18n.t("billing.training.#{@add_on_type}.bullets", default: [])
    end

    bullets
  end

  def add_on_config
    @plan_config&.dig('add_ons', @add_on_type.to_s)
  end

  def update_quantity(new_quantity)
    subscription = fetch_subscription
    return failure_response('No active subscription found') unless subscription

    # Enforce max_quantity for training add-ons
    if training_add_on?
      add_on_config = @plan_config.dig('add_ons', @add_on_type.to_s)
      max_qty = add_on_config['max_quantity'] || 1
      return failure_response('Cannot add more of this add-on') if new_quantity > max_qty
    end

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
        proration_behavior: stripe_proration_behavior
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
        proration_behavior: stripe_proration_behavior
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
      proration_behavior: stripe_proration_behavior
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

    # Search for price by lookup_key and expand product to get metadata
    prices = ::Stripe::Price.list(
      lookup_keys: [lookup_key],
      limit: 1,
      expand: ['data.product']  # Expand product to fetch metadata (name, description, custom fields)
    )
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

  # Check if quantity can be removed (validates against unused extras)
  # @param quantity [Integer] Number of units to remove
  # @return [Boolean] True if removal is allowed
  def can_remove_quantity?(quantity)
    # Training add-ons don't have usage constraints
    return true if training_add_on?
    
    # Capacity add-ons (agent, inbox) need usage validation
    limit_service = Billing::UnifiedLimitService.new(@account, map_to_resource_type)
    limit_service.can_remove?(quantity)
  rescue StandardError => e
    Rails.logger.error "Error checking removal quantity: #{e.message}"
    # Fail open - allow removal if check fails
    true
  end

  # Map add-on type to resource type for UnifiedLimitService
  # @return [Symbol] Resource type (:agent or :inbox)
  def map_to_resource_type
    case @add_on_type
    when :agent then :agent
    when :inbox, :channel then :inbox
    else
      raise ArgumentError, "Cannot map add-on type #{@add_on_type} to resource type"
    end
  end

  # Get human-readable settings section name for error messages
  # @return [String] Settings section name
  def settings_section_name
    case @add_on_type
    when :agent then 'Settings > Members'
    when :inbox, :channel then 'Settings > Channels'
    else
      'Settings'
    end
  end

  def stripe_proration_behavior
    ALWAYS_INVOICE_ADD_ONS.include?(@add_on_type) ? 'always_invoice' : 'create_prorations'
  end
end

