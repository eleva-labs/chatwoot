# frozen_string_literal: true

class Billing::PreviewAddOnRemovalService
  def initialize(account, add_on_type, action_type, quantity = nil)
    @account = account
    @add_on_type = add_on_type&.to_sym
    @action_type = action_type
    @quantity = quantity
  end

  def preview_removal
    subscription = fetch_subscription
    return failure('No active subscription found') unless subscription

    add_on_service = build_add_on_service
    return failure('Invalid add-on type') unless add_on_service

    config = add_on_service.send(:add_on_config)
    return failure('Add-on configuration not found for plan') unless config

    subscription_item = find_subscription_item(subscription, config['lookup_key'])
    return failure('Add-on not found in subscription') unless subscription_item

    current_quantity = subscription_item.quantity
    new_quantity = calculate_new_quantity(current_quantity)

    credit_cents = preview_invoice_with_removal(
      subscription_id: subscription.id,
      subscription_item_id: subscription_item.id,
      lookup_key: config['lookup_key'],
      new_quantity: new_quantity
    )

    success(
      estimated_credit: format_currency(credit_cents),
      details: {
        current_quantity: current_quantity,
        new_quantity: new_quantity,
        credit_amount_cents: credit_cents
      }
    )
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Stripe error previewing add-on removal: #{e.message}"
    failure(e.message)
  rescue StandardError => e
    Rails.logger.error "Error previewing add-on removal: #{e.message}"
    failure('Failed to calculate credit')
  end

  private

  def fetch_subscription
    subscription_id = @account.custom_attributes&.dig('stripe_subscription_id')
    if subscription_id.present?
      begin
        return ::Stripe::Subscription.retrieve(subscription_id)
      rescue ::Stripe::StripeError => e
        Rails.logger.warn(
          "Unable to retrieve stored Stripe subscription id #{subscription_id} for account #{@account.id}: #{e.message}"
        )
        # Fall through to fetch by customer id
      end
    end

    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return nil unless customer_id.present?

    subscriptions = ::Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
    subscriptions.data.first
  rescue ::Stripe::StripeError => e
    Rails.logger.error "Error fetching subscription for preview removal: #{e.message}"
    nil
  end

  def build_add_on_service
    Billing::ManageSubscriptionAddOnService.new(@account, @add_on_type)
  rescue StandardError => e
    Rails.logger.warn "Failed to build add-on service for #{@add_on_type}: #{e.message}"
    nil
  end

  def find_subscription_item(subscription, lookup_key)
    subscription.items.data.find do |item|
      item.price.lookup_key == lookup_key
    end
  end

  def calculate_new_quantity(current_quantity)
    case @action_type
    when 'remove'
      [current_quantity - 1, 0].max
    when 'set'
      (@quantity || 0).to_i
    else
      current_quantity
    end
  end

  def preview_invoice_with_removal(subscription_id:, subscription_item_id:, lookup_key:, new_quantity:)
    subscription_details = build_subscription_details(
      subscription_item_id: subscription_item_id,
      new_quantity: new_quantity
    )

    preview_invoice = ::Stripe::Invoice.create_preview(
      subscription: subscription_id,
      subscription_details: subscription_details,
      expand: ['lines']
    )

    negative_lines = preview_invoice.lines.data.select do |line|
      line_amount = line['amount'] || line.amount
      line_amount&.negative?
    end

    positive_lines_total = preview_invoice.lines.data
                          .select { |line| (line['amount'] || line.amount)&.positive? }
                          .sum { |line| line['amount'] || line.amount }

    negative_lines_total = negative_lines.sum { |line| (-(line['amount'] || line.amount)) }

    net_credit_cents = [negative_lines_total - positive_lines_total, 0].max

    return net_credit_cents if net_credit_cents.positive?

    negative_lines_total
  rescue StandardError => e
    Rails.logger.error "Error calculating credit from preview invoice: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  def build_subscription_details(subscription_item_id:, new_quantity:)
    behavior = proration_behavior
    details = if new_quantity.zero?
                {
                  proration_behavior: behavior,
          items: [
            {
              id: subscription_item_id,
              deleted: true
            }
          ]
        }
      else
        {
                  proration_behavior: behavior,
          items: [
            {
              id: subscription_item_id,
              quantity: new_quantity
            }
          ]
        }
      end

    # Always set proration_date for preview calculations, regardless of behavior
    details[:proration_date] = Time.current.to_i

    details
  end

  def proration_behavior
    if Billing::ManageSubscriptionAddOnService::ALWAYS_INVOICE_ADD_ONS.include?(@add_on_type)
      'always_invoice'
    else
      'create_prorations'
    end
  end

  def format_currency(amount_cents)
    return '$0.00' if amount_cents.to_i.zero?

    format('$%.2f', amount_cents / 100.0)
  end

  def success(payload)
    { success: true }.merge(payload)
  end

  def failure(message)
    { success: false, error: message }
  end
end


