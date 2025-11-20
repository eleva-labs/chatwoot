# frozen_string_literal: true

class Billing::FetchPricingTableService
  PLAN_ORDER = %w[starter custom].freeze

  def fetch
    products = fetch_stripe_products
    plans = products.map { |product| build_plan_data(product) }
    plans.sort_by { |plan| PLAN_ORDER.index(plan[:plan_name]) || Float::INFINITY }
  end

  private

  def fetch_stripe_products
    # List products with expand for better performance
    products = ::Stripe::Product.list(
      active: true,
      expand: ['data.marketing_features'],
      limit: 100
    )

    # Filter by plan_name metadata
    products.data.select do |product|
      metadata = product.metadata || {}
      PLAN_ORDER.include?(metadata['plan_name'])
    end
  end

  def build_plan_data(product)
    {
      id: product.id,
      plan_name: product.metadata['plan_name'],
      name: product.name,
      description: product.description,
      image_url: extract_image_url(product),
      prices: fetch_prices(product.id),
      features: extract_features(product)
    }
  end

  def fetch_prices(product_id)
    prices = ::Stripe::Price.list(
      product: product_id,
      active: true,
      limit: 10
    )

    {
      monthly: find_price_by_interval(prices.data, 'month'),
      yearly: find_price_by_interval(prices.data, 'year')
    }
  end

  def find_price_by_interval(prices, interval)
    price = prices.find { |p| p.recurring&.interval == interval }
    return nil unless price

    {
      id: price.id,
      amount: price.unit_amount,
      currency: price.currency,
      formatted: format_price(price.unit_amount, price.currency)
    }
  end

  def extract_image_url(product)
    # Try images array first
    return product.images.first if product.images&.any?

    # Fallback to metadata
    product.metadata&.dig('image_url')
  end

  def extract_features(product)
    # Try marketing_features first (Stripe's native feature)
    if product.marketing_features&.any?
      return product.marketing_features.map(&:name)
    end

    # Fallback to metadata (bullet_1, bullet_2, etc.)
    features = []
    index = 1
    while (bullet = product.metadata&.dig("bullet_#{index}"))
      features << bullet
      index += 1
    end
    features
  end

  def format_price(amount_cents, currency)
    return '$0' if amount_cents.nil? || amount_cents.zero?

    amount_dollars = amount_cents / 100
    # Standard approach: match each digit followed by groups of 3 digits until end
    formatted = amount_dollars.to_s.gsub(/(\d)(?=(\d{3})+$)/, '\1,')
    "$#{formatted}"
  end
end

