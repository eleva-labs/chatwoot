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
    base_item = base_subscription_item(subscription)
    
    if subscription
      # Active paid subscription - use Stripe data
      # Try to fetch upcoming invoice to get accurate totals with credits
      upcoming_invoice = fetch_upcoming_invoice(subscription)
      
      breakdown_data = {
        plan_name: @plan_name.titleize,
        base_plan: base_plan_details(subscription, base_item),
        add_ons: add_on_details(subscription),
        total: calculate_total(subscription, upcoming_invoice),
        next_billing_date: next_billing_date(subscription, base_item, upcoming_invoice),
        currency: subscription_currency(subscription, base_item)
      }
      
      # Add credit information if available from upcoming invoice
      if upcoming_invoice
        breakdown_data[:total_before_credits] = calculate_total_before_credits(upcoming_invoice)
        breakdown_data[:credits_applied] = calculate_credits_applied(upcoming_invoice)
      end
      
      breakdown_data
    else
      # No Stripe subscription (free trial, community, etc.) - use plan config
      build_breakdown_from_plan_config
    end
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching subscription breakdown: #{e.message}"
    build_breakdown_from_plan_config
  end

  private

  def base_plan_details(subscription, base_item)
    base_item ||= base_subscription_item(subscription)

    if base_item
      price = base_item.price
      unit_amount = price&.unit_amount || 0

      {
        name: "#{@plan_name.titleize} Plan",
        price_cents: unit_amount,
        price_formatted: format_price(unit_amount),
        interval: price&.recurring&.interval,
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
    # Use plan_limits() to get limits from Stripe metadata first, then YAML fallback
    limits = self.class.plan_limits(@plan_name)

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
    when /live_1_1_training/
      'live_1_1_training'
    when /live_training/
      'live_training'
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
    when 'live_training'
      'Live Training'
    when 'live_1_1_training'
      'Live 1:1 Training with an Expert'
    else
      type.titleize
    end
  end

  def calculate_total(subscription, upcoming_invoice = nil)
    # If we have upcoming invoice data, use amount_due (net amount after credits)
    if upcoming_invoice
      amount_due = upcoming_invoice.amount_due || 0
      return {
        amount_cents: amount_due,
        amount_formatted: format_price(amount_due)
      }
    end

    # Fallback: calculate from subscription items (before credits)
    total_cents = 0

    subscription.items.data.each do |item|
      unit_price = item.price&.unit_amount || 0
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

  def fetch_upcoming_invoice(subscription)
    return nil unless subscription

    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return nil unless customer_id

    invoice_klass = ::Stripe::Invoice

    # Prefer retrieve_upcoming if available (Stripe Ruby 16+)
    if invoice_klass.respond_to?(:retrieve_upcoming)
      return invoice_klass.retrieve_upcoming(customer: customer_id, subscription: subscription.id)
    end

    # Fallback to legacy upcoming if still available
    if invoice_klass.respond_to?(:upcoming)
      return invoice_klass.upcoming(customer: customer_id, subscription: subscription.id)
    end

    # Finally, attempt to use create_preview if provided by the gem
    if invoice_klass.respond_to?(:create_preview)
      return invoice_klass.create_preview(customer: customer_id, subscription: subscription.id)
    end

    nil
  rescue ::Stripe::InvalidRequestError => e
    # Upcoming invoice may not exist (e.g., subscription just started, no next billing cycle)
    # Log but don't fail - we'll fall back to subscription-based calculation
    Rails.logger.debug "No upcoming invoice available: #{e.message}"
    nil
  rescue ::Stripe::StripeError => e
    Rails.logger.warn "Error fetching upcoming invoice: #{e.message}"
    nil
  end

  def calculate_total_before_credits(upcoming_invoice)
    # Use subtotal to match Stripe's "Subtotal" display
    # This represents the total of all line items before credits are applied
    total_cents = upcoming_invoice.subtotal || 0

    {
      amount_cents: total_cents,
      amount_formatted: format_price(total_cents)
    }
  end

  def calculate_credits_applied(upcoming_invoice)
    # Credits applied = subtotal - amount_due
    # This matches what Stripe shows in the dashboard as "Applied balance"
    # The difference between subtotal and amount_due represents credits/discounts applied
    subtotal = upcoming_invoice.subtotal || 0
    amount_due = upcoming_invoice.amount_due || 0
    credits_cents = [subtotal - amount_due, 0].max

    {
      amount_cents: credits_cents,
      amount_formatted: format_price(credits_cents)
    }
  end

  def base_subscription_item(subscription)
    return nil unless subscription&.items&.respond_to?(:data)

    items = subscription.items.data
    return nil if items.empty?

    plan_price_id = self.class.plan_price_id(@plan_name)

    if plan_price_id.present?
      item = items.find { |subscription_item| subscription_item.price&.id == plan_price_id }
      return item if item
    end

    # Prefer a non add-on item if available
    primary_item = items.find do |subscription_item|
      lookup_key = subscription_item.price&.lookup_key
      lookup_key.nil? || !lookup_key.match?(/extra_|conversation_pack/)
    end

    primary_item
  end

  def next_billing_date(subscription, base_item, upcoming_invoice = nil)
    # If we have upcoming invoice, use its period_end or due_date (most accurate)
    if upcoming_invoice
      # Prefer period_end (when invoice will be generated)
      # Fallback to due_date (when payment is due)
      period_end = if upcoming_invoice.respond_to?(:period_end)
                     upcoming_invoice.period_end
                   elsif upcoming_invoice.is_a?(Hash)
                     upcoming_invoice['period_end']
                   end

      return period_end if period_end

      due_date = if upcoming_invoice.respond_to?(:due_date)
                   upcoming_invoice.due_date
                 elsif upcoming_invoice.is_a?(Hash)
                   upcoming_invoice['due_date']
                 end

      return due_date if due_date
    end

    # Fallback to subscription item period end
    item = base_item || base_subscription_item(subscription)
    item_end = subscription_item_current_period_end(item)
    return item_end if item_end

    subscription_current_period_end(subscription)
  end

  def subscription_currency(subscription, base_item)
    item = base_item || base_subscription_item(subscription)
    currency = item&.price&.currency || subscription&.currency
    currency&.upcase || 'USD'
  end

  def format_price(cents)
    return '$0.00' unless cents

    "$#{format('%.2f', cents / 100.0)}"
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def subscription_item_current_period_end(item)
    return nil unless item

    if item.respond_to?(:current_period_end)
      item.current_period_end
    elsif item.is_a?(Hash)
      item['current_period_end']
    end
  end

  def subscription_current_period_end(subscription)
    return nil unless subscription

    if subscription.respond_to?(:current_period_end)
      subscription.current_period_end
    elsif subscription.is_a?(Hash)
      subscription['current_period_end']
    end
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

