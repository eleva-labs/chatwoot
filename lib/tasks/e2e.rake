# frozen_string_literal: true

namespace :e2e do
  desc 'Seed E2E test users'
  task seed: :environment do
    load Rails.root.join('scripts/e2e/seed_test_data.rb')
  end

  desc 'Clean up E2E test data'
  task cleanup: :environment do
    puts 'Cleaning up E2E test data...'

    # Find test users by email pattern
    test_emails = [
      'e2e-admin@test.chatwoot.local',
      'e2e-agent@test.chatwoot.local'
    ]

    # Find and destroy test users
    users = User.where(email: test_emails)
    user_count = users.count
    users.destroy_all

    # Find and destroy test account
    account = Account.find_by(name: 'E2E Test Account')
    if account
      account.destroy
      puts "Destroyed E2E Test Account (ID: #{account.id})"
    end

    puts "Cleaned up #{user_count} test user(s)"
    puts 'E2E test data cleanup complete!'
  end

  desc 'Reset E2E test data (cleanup + seed)'
  task reset: :environment do
    Rake::Task['e2e:cleanup'].invoke
    puts ''
    Rake::Task['e2e:seed'].invoke
  end

  desc 'Check E2E test data status'
  task status: :environment do
    puts 'E2E Test Data Status:'
    puts '-' * 50

    test_emails = [
      'e2e-admin@test.chatwoot.local',
      'e2e-agent@test.chatwoot.local'
    ]

    test_emails.each do |email|
      user = User.find_by(email: email)
      if user
        account_user = user.account_users.first
        role = account_user&.role || 'no role'
        puts "  #{email}: EXISTS (role: #{role})"
      else
        puts "  #{email}: MISSING"
      end
    end

    account = Account.find_by(name: 'E2E Test Account')
    if account
      inbox_count = account.inboxes.count
      puts "  E2E Test Account: EXISTS (ID: #{account.id}, inboxes: #{inbox_count})"
    else
      puts '  E2E Test Account: MISSING'
    end

    puts '-' * 50
  end
end
