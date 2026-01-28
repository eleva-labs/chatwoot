# frozen_string_literal: true

# E2E Test Data Seeding Script
# Usage: rails runner "load 'scripts/e2e/seed_test_data.rb'"
#
# This script creates test users for E2E testing. It is idempotent and can be
# run multiple times safely - existing users will not be modified.

puts 'Seeding E2E test data...'

# Find or create test account
account = Account.find_or_create_by!(name: 'E2E Test Account') do |a|
  a.domain = 'test.chatwoot.local'
end
puts "Account: #{account.name} (ID: #{account.id})"

# Seed admin user
admin_email = 'e2e-admin@test.chatwoot.local'
admin = User.find_by(email: admin_email)

if admin
  puts "Admin user already exists: #{admin_email}"
else
  admin = User.new(
    email: admin_email,
    password: 'Password1!',
    password_confirmation: 'Password1!',
    name: 'E2E Admin User',
    display_name: 'E2E Admin'
  )
  admin.skip_confirmation!
  admin.save!

  AccountUser.create!(
    account: account,
    user: admin,
    role: :administrator
  )
  puts "Created admin user: #{admin_email}"
end

# Seed agent user
agent_email = 'e2e-agent@test.chatwoot.local'
agent = User.find_by(email: agent_email)

if agent
  puts "Agent user already exists: #{agent_email}"
else
  agent = User.new(
    email: agent_email,
    password: 'Password1!',
    password_confirmation: 'Password1!',
    name: 'E2E Agent User',
    display_name: 'E2E Agent'
  )
  agent.skip_confirmation!
  agent.save!

  AccountUser.create!(
    account: account,
    user: agent,
    role: :agent
  )
  puts "Created agent user: #{agent_email}"
end

# Create a test inbox for the account (optional but useful for testing)
inbox = Inbox.find_or_create_by!(account: account, name: 'E2E Test Inbox') do |i|
  i.channel = Channel::WebWidget.create!(
    account: account,
    website_url: 'https://test.chatwoot.local'
  )
end
puts "Inbox: #{inbox.name} (ID: #{inbox.id})"

# Assign agent to inbox
InboxMember.find_or_create_by!(inbox: inbox, user: agent)
InboxMember.find_or_create_by!(inbox: inbox, user: admin)

puts ''
puts 'E2E test data seeding complete!'
puts ''
puts 'Test Users:'
puts "  Admin: #{admin_email} / Password1!"
puts "  Agent: #{agent_email} / Password1!"
puts "  Account ID: #{account.id}"
puts "  Inbox ID: #{inbox.id}"
