#!/usr/bin/env ruby
# Test fetching training products and prices from Stripe

require_relative '../config/environment'

puts "=" * 60
puts "STRIPE TRAINING PRODUCTS FETCH TEST"
puts "=" * 60

lookup_keys = {
  'Live Training' => 'live_training_pricing',
  'Live 1:1 Training' => 'live_1_1_training_pricing'
}

lookup_keys.each do |name, lookup_key|
  puts "\n🔍 Fetching: #{name}"
  puts "   Lookup Key: #{lookup_key}"
  
  begin
    # Fetch price by lookup_key
    prices = Stripe::Price.list(lookup_keys: [lookup_key], expand: ['data.product'])
    
    if prices.data.empty?
      puts "   ❌ ERROR: No price found for lookup_key '#{lookup_key}'"
      next
    end
    
    price = prices.data.first
    product = price.product
    
    puts "   ✅ Price found!"
    puts "   💰 Amount: $#{price.unit_amount / 100.0} #{price.currency.upcase}"
    puts "   📦 Product ID: #{product.id}"
    puts "   📛 Product Name: #{product.name}"
    puts "   📝 Description: #{product.description&.truncate(60)}"
    
    # Check metadata bullets
    bullet_count = 0
    (1..10).each do |i|
      if product.metadata["bullet_#{i}"].present?
        bullet_count += 1
        puts "   • bullet_#{i}: #{product.metadata["bullet_#{i}"].truncate(50)}"
      end
    end
    
    if bullet_count > 0
      puts "   ✅ Found #{bullet_count} feature bullets"
    else
      puts "   ⚠️  WARNING: No feature bullets in metadata"
    end
    
  rescue Stripe::InvalidRequestError => e
    puts "   ❌ Stripe Error: #{e.message}"
  rescue => e
    puts "   ❌ Unexpected Error: #{e.class} - #{e.message}"
  end
end

puts "\n" + "=" * 60
puts "Stripe fetch test complete!"
puts "=" * 60

