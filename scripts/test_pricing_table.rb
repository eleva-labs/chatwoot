#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple test script for pricing table implementation
# Run: rails runner scripts/test_pricing_table.rb

puts '=' * 80
puts 'Testing Pricing Table Implementation'
puts '=' * 80
puts

# Test 1: Service exists and can be instantiated
puts '✓ Test 1: Service instantiation'
begin
  service = Billing::FetchPricingTableService.new
  puts "  Service created: #{service.class.name}"
rescue StandardError => e
  puts "  ✗ FAILED: #{e.message}"
  exit 1
end
puts

# Test 2: Service can fetch pricing data
puts '✓ Test 2: Fetch pricing data from Stripe'
begin
  pricing_data = service.fetch
  puts "  Found #{pricing_data.length} plan(s)"
  
  if pricing_data.empty?
    puts '  ⚠ WARNING: No plans found. Check Stripe product metadata.'
  else
    pricing_data.each do |plan|
      puts "  - #{plan[:name]} (#{plan[:plan_name]})"
      puts "    Monthly: #{plan[:prices][:monthly]&.dig(:formatted) || 'N/A'}"
      puts "    Yearly: #{plan[:prices][:yearly]&.dig(:formatted) || 'N/A'}"
      puts "    Features: #{plan[:features]&.count || 0}"
    end
  end
rescue StandardError => e
  puts "  ✗ FAILED: #{e.message}"
  puts "  Check your Stripe configuration and API keys"
  exit 1
end
puts

# Test 3: Controller exists
puts '✓ Test 3: Controller exists'
begin
  controller_class = Api::V2::Accounts::PricingController
  puts "  Controller: #{controller_class.name}"
rescue NameError => e
  puts "  ✗ FAILED: #{e.message}"
  exit 1
end
puts

# Test 4: Route exists
puts '✓ Test 4: Route verification'
begin
  routes = Rails.application.routes.routes.map do |route|
    { path: route.path.spec.to_s, verb: route.verb, controller: route.defaults[:controller] }
  end
  
  pricing_route = routes.find do |r|
    r[:controller] == 'api/v2/accounts/pricing' && r[:verb] == 'GET'
  end
  
  if pricing_route
    puts "  Route found: GET #{pricing_route[:path]}"
  else
    puts '  ✗ FAILED: Route not found'
    exit 1
  end
rescue StandardError => e
  puts "  ✗ FAILED: #{e.message}"
  exit 1
end
puts

# Test 5: Plan hierarchy validation
puts '✓ Test 5: Plan hierarchy order'
expected_order = %w[starter professional enterprise]
actual_order = pricing_data.map { |p| p[:plan_name] }
if actual_order == actual_order.sort_by { |name| expected_order.index(name) || Float::INFINITY }
  puts "  Plans are correctly ordered: #{actual_order.join(' → ')}"
else
  puts "  ⚠ WARNING: Plans not in expected order"
  puts "    Expected: #{expected_order.join(' → ')}"
  puts "    Actual: #{actual_order.join(' → ')}"
end
puts

# Summary
puts '=' * 80
puts 'All core tests passed! ✓'
puts '=' * 80
puts
puts 'Next steps:'
puts '1. Start your Rails server: task docker-reload-env'
puts '2. Navigate to Settings > Billing in the UI'
puts '3. Verify pricing table renders correctly'
puts '4. Test monthly/yearly toggle'
puts '5. Test button states with different subscription scenarios'
puts

