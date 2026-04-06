#!/usr/bin/env ruby
# Simulate API request to AddOnsController

require_relative '../config/environment'

# Find test account
account = Account.joins(:users).where(users: { email: 'admin@test.com' }).first
account ||= Account.first

puts "=" * 60
puts "TESTING API CONTROLLER RESPONSE"
puts "=" * 60
puts "Account: #{account.name} (ID: #{account.id})"

begin
  # Call index action logic (simplified)
  result = {
    capacity_add_ons: {},
    training_services: {}
  }
  
  # Get all add-ons (both capacity and training)
  Billing::ManageSubscriptionAddOnService::ADD_ON_TYPES.each do |type|
    begin
      service = Billing::ManageSubscriptionAddOnService.new(account, type)
      
      info = service.add_on_info
      next unless info
      
      # Categorize by category field
      if info[:category] == 'training'
        result[:training_services][type] = info
      else
        result[:capacity_add_ons][type] = info
      end
    rescue StandardError => e
      puts "\n⚠️  Skipping #{type}: #{e.message}"
      next
    end
  end
  
  puts "\n📦 Controller Response Structure:"
  puts JSON.pretty_generate(JSON.parse(result.to_json))
  
  # Validate structure
  puts "\n✅ Validation:"
  puts "  capacity_add_ons present: #{result[:capacity_add_ons].present?}"
  puts "  Number of capacity add-ons: #{result[:capacity_add_ons].keys.length}"
  puts "  training_services present: #{result[:training_services].present?}"
  puts "  Number of training services: #{result[:training_services].keys.length}"
  
  result[:training_services].each do |type, info|
    puts "\n  Training: #{type}"
    puts "    ✅ display_name: #{info[:display_name].present? ? '✓' : '✗'}"
    puts "    ✅ description: #{info[:description].present? ? '✓' : '✗'}"
    puts "    ✅ feature_bullets: #{info[:feature_bullets]&.any? ? '✓' : '✗'}"
    puts "    ✅ unit_price_formatted: #{info[:unit_price_formatted].present? ? '✓' : '✗'}"
    puts "    ✅ is_owned: #{info[:is_owned].nil? ? '✗' : '✓'}"
    puts "    ✅ category: #{info[:category] == 'training' ? '✓' : '✗'}"
  end
  
rescue => e
  puts "\n❌ ERROR: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 60
puts "Controller test complete!"
puts "=" * 60

