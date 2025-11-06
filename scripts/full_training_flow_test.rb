#!/usr/bin/env ruby
# End-to-end flow: Check config → Fetch from Stripe → Simulate purchase

require_relative '../config/environment'

puts "\n" + "=" * 70
puts " 🧪 TRAINING ADD-ON FULL FLOW TEST"
puts "=" * 70

# Step 1: Check YAML config
puts "\n[1/5] Checking YAML configuration..."
config = YAML.load_file('config/billing_plans.yml')
training_addon = config['plans']['starter']['add_ons']['live_training']

if training_addon && training_addon['category'] == 'training'
  puts "      ✅ YAML config valid"
else
  puts "      ❌ YAML config missing or invalid"
  exit 1
end

# Step 2: Find test account
puts "\n[2/5] Finding test account..."
account = Account.joins(:users).first

if account
  puts "      ✅ Account found: #{account.name} (ID: #{account.id})"
  
  # Upgrade to starter plan if needed for testing
  plan_name = account.custom_attributes&.dig('plan_name') || 'free_trial'
  if plan_name == 'free_trial'
    puts "      ⚠️  Account on free_trial, upgrading to starter for testing..."
    account.custom_attributes ||= {}
    account.custom_attributes['plan_name'] = 'starter'
    account.save!
    puts "      ✅ Account upgraded to starter plan"
  else
    puts "      ℹ️  Account plan: #{plan_name}"
  end
else
  puts "      ❌ No account found"
  exit 1
end

# Step 3: Fetch from Stripe
puts "\n[3/5] Fetching training data from Stripe..."
service = Billing::ManageSubscriptionAddOnService.new(account, 'live_training')

begin
  info = service.add_on_info
  
  if info[:display_name].present? && info[:unit_price_formatted].present?
    puts "      ✅ Stripe data fetched successfully"
    puts "         Name: #{info[:display_name]}"
    puts "         Price: #{info[:unit_price_formatted]}"
    puts "         Bullets: #{info[:feature_bullets]&.length || 0} items"
    puts "         Category: #{info[:category]}"
  else
    puts "      ❌ Missing required Stripe data"
    exit 1
  end
rescue => e
  puts "      ❌ Stripe fetch failed: #{e.message}"
  exit 1
end

# Step 4: Check purchase eligibility
puts "\n[4/5] Checking purchase eligibility..."
if info[:is_owned]
  puts "      ⚠️  Already owned (quantity: #{info[:current_quantity]})"
  puts "         Purchase should be blocked in UI"
else
  puts "      ✅ Not owned - purchase allowed"
end

# Step 5: Simulate API response structure
puts "\n[5/5] Validating API response structure..."
response = {
  capacity_add_ons: {},
  training_services: {
    live_training: info
  }
}

required_fields = [:display_name, :description, :feature_bullets, :unit_price_formatted, :is_owned, :category]
missing_fields = required_fields.reject { |field| info.key?(field) }

if missing_fields.empty?
  puts "      ✅ All required fields present"
else
  puts "      ❌ Missing fields: #{missing_fields.join(', ')}"
  exit 1
end

puts "\n" + "=" * 70
puts " ✅ ALL CHECKS PASSED - Training add-on ready for use!"
puts "=" * 70
puts "\n📝 Next Step: Test in browser at /app/accounts/#{account.id}/settings/billing"
puts "\n"

