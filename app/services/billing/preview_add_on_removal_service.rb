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
    return nil unless subscription_id.present?

    ::Stripe::Subscription.retrieve(subscription_id)
  rescue ::Stripe::InvalidRequestError
    # If the stored subscription id is invalid, fall back to listing active subscriptions
    customer_id = @account.custom_attributes&.dig('stripe_customer_id')
    return nil unless customer_id.present?

    subscriptions = ::Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
    subscriptions.data.first
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

  def preview_invoice_with_removal(subscription_id:, subscription_item_id:, new_quantity:)
    subscription_details =
      if new_quantity.zero?
        {
          proration_behavior: 'create_prorations',
          proration_date: Time.current.to_i,
          items: [
            {
              id: subscription_item_id,
              deleted: true
            }
          ]
        }
      else
        {
          proration_behavior: 'create_prorations',
          proration_date: Time.current.to_i,
          items: [
            {
              id: subscription_item_id,
              quantity: new_quantity
            }
          ]
        }
      end

    preview_invoice = ::Stripe::Invoice.create_preview(
      subscription: subscription_id,
      subscription_details: subscription_details,
      expand: ['lines']
    )

    credit_lines = preview_invoice.lines.data.select do |line|
      proration_flag = line.respond_to?(:proration) ? line.proration : line['proration']
      proration_flag && line.amount.negative?
    end

    credit_lines.sum { |line| line.amount.abs }
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


