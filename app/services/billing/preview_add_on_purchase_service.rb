# frozen_string_literal: true

class Billing::PreviewAddOnPurchaseService
  include BillingPlans

  SUPPORTED_ACTIONS = %w[add set].freeze

  def initialize(account, add_on_type, action_type, quantity = nil)
    @account = account
    @add_on_type = add_on_type&.to_sym
    @action_type = action_type
    @quantity = quantity
  end

  def preview_purchase
    return failure('Invalid add-on type') unless valid_add_on_type?
    return failure('Unsupported action') unless SUPPORTED_ACTIONS.include?(@action_type)

    subscription = fetch_subscription
    return failure('No active subscription found') unless subscription

    config = plan_config&.dig('add_ons', @add_on_type.to_s)
    return failure('Add-on configuration not found for plan') unless config

    lookup_key = config['lookup_key']
    return failure('Add-on lookup key not configured') unless lookup_key

    subscription_item = find_subscription_item(subscription, lookup_key)
    current_quantity = subscription_item&.quantity.to_i
    new_quantity = desired_quantity(current_quantity)

    return failure('Quantity unchanged') if new_quantity == current_quantity
    return failure('Quantity must be positive') if new_quantity.negative?

    preview_invoice = build_invoice_preview(
      subscription,
      subscription_item,
      lookup_key,
      new_quantity
    )

    amount_cents = preview_invoice.total.to_i
    success(
      estimated_charge_cents: amount_cents,
      estimated_charge: format_currency(amount_cents),
      details: {
        current_quantity: current_quantity,
        new_quantity: new_quantity,
        proration_lines: extract_proration_lines(preview_invoice)
      }
    )
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Stripe error previewing #{@add_on_type} purchase: #{e.message}"
    failure(e.message)
  rescue StandardError => e
    Rails.logger.error "Error previewing #{@add_on_type} purchase: #{e.message}"
    failure('Failed to calculate charge')
  end

  private

  def valid_add_on_type?
    Billing::ManageSubscriptionAddOnService::ADD_ON_TYPES.include?(@add_on_type)
  end

  def plan_name
    @plan_name ||= @account.custom_attributes&.dig('plan_name') || 'free_trial'
  end

  def plan_config
    @plan_config ||= self.class.plan_details(plan_name)
  end

  def fetch_subscription
    subscription_id = @account.custom_attributes&.dig('stripe_subscription_id')
    return retrieve_subscription(subscription_id) if subscription_id.present?

    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return nil unless customer_id.present?

    subscriptions = ::Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
    subscriptions.data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching subscription for preview: #{e.message}"
    nil
  end

  def retrieve_subscription(subscription_id)
    ::Stripe::Subscription.retrieve(subscription_id)
  rescue ::Stripe::InvalidRequestError => e
    Rails.logger.warn "Invalid subscription id stored for preview: #{e.message}"
    nil
  end

  def desired_quantity(current_quantity)
    case @action_type
    when 'add'
      current_quantity + 1
    when 'set'
      (@quantity || current_quantity).to_i
    else
      current_quantity
    end
  end

  def build_invoice_preview(subscription, subscription_item, lookup_key, new_quantity)
    proration_timestamp = Time.current.to_i

    subscription_details =
      if subscription_item
        {
          proration_behavior: proration_behavior,
          proration_date: proration_timestamp,
          items: [
            {
              id: subscription_item.id,
              quantity: new_quantity
            }
          ]
        }
      else
        price = fetch_price(lookup_key)
        raise StandardError, "Price not found in Stripe for lookup_key #{lookup_key}" unless price

        {
          proration_behavior: proration_behavior,
          proration_date: proration_timestamp,
          items: [
            {
              price: price.id,
              quantity: new_quantity
            }
          ]
        }
      end

    ::Stripe::Invoice.create_preview(
      subscription: subscription.id,
      subscription_details: subscription_details,
      expand: ['lines']
    )
  end

  def find_subscription_item(subscription, lookup_key)
    subscription.items.data.find do |item|
      item.price.lookup_key == lookup_key
    end
  end

  def fetch_price(lookup_key)
    ::Stripe::Price.list(
      lookup_keys: [lookup_key],
      limit: 1
    ).data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching price for preview: #{e.message}"
    nil
  end

  def format_currency(amount_cents)
    return '$0.00' if amount_cents.to_i.zero?

    format('$%.2f', amount_cents / 100.0)
  end

  def extract_proration_lines(preview_invoice)
    preview_invoice.lines.data
                   .select do |line|
                     line.respond_to?(:proration) ? line.proration : line['proration']
                   end
                   .map do |line|
                     {
                       id: line.id,
                       description: line.description,
                       amount_cents: line.amount,
                       amount: format_currency(line.amount)
                     }
                   end
  end

  def success(payload)
    { success: true }.merge(payload)
  end

  def failure(message)
    { success: false, error: message }
  end

  def proration_behavior
    if Billing::ManageSubscriptionAddOnService::ALWAYS_INVOICE_ADD_ONS.include?(@add_on_type)
      'always_invoice'
    else
      'create_prorations'
    end
  end

end

