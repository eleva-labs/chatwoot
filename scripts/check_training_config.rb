#!/usr/bin/env ruby
# Simple script to verify training add-ons are in billing_plans.yml

require 'yaml'

config_path = 'config/billing_plans.yml'
config = YAML.load_file(config_path)

puts "=" * 60
puts "TRAINING ADD-ON CONFIGURATION CHECK"
puts "=" * 60

training_types = ['live_training', 'live_1_1_training']

training_types.each do |type|
  puts "\n📋 Checking #{type}..."
  
  if config['plans']['starter']['add_ons'] && config['plans']['starter']['add_ons'][type]
    addon_config = config['plans']['starter']['add_ons'][type]
    
    puts "  ✅ Found in YAML (starter plan)"
    puts "  📦 Category: #{addon_config['category']}"
    puts "  🔑 Lookup Key: #{addon_config['lookup_key']}"
    puts "  📊 Max Quantity: #{addon_config['max_quantity']}"
    
    # Verify it's marked as training
    if addon_config['category'] == 'training'
      puts "  ✅ Correctly categorized as 'training'"
    else
      puts "  ❌ ERROR: Category should be 'training', got '#{addon_config['category']}'"
    end
  else
    puts "  ❌ MISSING from config/billing_plans.yml (starter plan)"
  end
  
  # Check professional plan too
  if config['plans']['professional']['add_ons'] && config['plans']['professional']['add_ons'][type]
    puts "  ✅ Found in professional plan"
  else
    puts "  ⚠️  WARNING: Missing from professional plan"
  end
end

puts "\n" + "=" * 60
puts "Check complete!"
puts "=" * 60

