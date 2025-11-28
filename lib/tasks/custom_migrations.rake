# frozen_string_literal: true

# Custom migration rake tasks for managing fork-specific migrations
# These migrations are separate from upstream Chatwoot migrations to avoid
# merge conflicts during upstream syncs.

# rubocop:disable Metrics/BlockLength
namespace :db do
  namespace :migrate do
    desc 'Run custom migrations (db/migrate_custom/)'
    task custom: :environment do
      runner = CustomMigrationRunner.new
      runner.migrate
    rescue StandardError => e
      puts "\n❌ Custom migration failed: #{e.message}"
      puts e.backtrace.first(10).join("\n") if ENV['VERBOSE']
      exit 1
    end

    namespace :custom do
      desc 'Display status of custom migrations'
      # rubocop:disable Metrics/BlockLength
      task status: :environment do
        runner = CustomMigrationRunner.new
        statuses = runner.status

        if statuses.empty?
          puts "\n⚠️  No custom migrations found in db/migrate_custom/"
          puts 'Create custom migrations in db/migrate_custom/ with sequential numbering (001_, 002_, etc.)'
        else
          puts "\nCustom Migration Status:"
          puts "#{'-' * 70}"
          puts 'Status   Version   Migration Name'
          puts "#{'-' * 70}"

          statuses.each do |s|
            status_symbol = s[:status] == 'up' ? '  ✓  ' : '  ✗  '
            puts "#{status_symbol}    #{s[:version].ljust(8)}  #{s[:name]}"
          end

          puts "#{'-' * 70}"

          up_count = statuses.count { |s| s[:status] == 'up' }
          down_count = statuses.count { |s| s[:status] == 'down' }

          puts "\nExecuted: #{up_count} | Pending: #{down_count} | Total: #{statuses.count.to_s}"
          puts ''
        end
      rescue StandardError => e
        puts "\n❌ Error checking migration status: #{e.message}"
        exit 1
      end
      # rubocop:enable Metrics/BlockLength
    end
  end

  namespace :rollback do
    desc 'Rollback custom migrations (STEP=n to rollback n migrations, default: 1)'
    task custom: :environment do
      steps = ENV['STEP'] ? ENV['STEP'].to_i : 1

      if steps < 1
        puts "\n❌ STEP must be a positive integer"
        exit 1
      end

      runner = CustomMigrationRunner.new
      runner.rollback(steps)
    rescue StandardError => e
      puts "\n❌ Custom rollback failed: #{e.message}"
      puts e.backtrace.first(10).join("\n") if ENV['VERBOSE']
      exit 1
    end
  end

  namespace :schema do
    namespace :dump do
      desc 'Dump custom schema to db/schema_custom.rb'
      task custom: :environment do
        runner = CustomMigrationRunner.new
        runner.dump_schema
      rescue StandardError => e
        puts "\n❌ Custom schema dump failed: #{e.message}"
        puts e.backtrace.first(10).join("\n") if ENV['VERBOSE']
        exit 1
      end
    end

    namespace :load do
      desc 'Load custom schema from db/schema_custom.rb'
      task custom: :environment do
        runner = CustomMigrationRunner.new
        runner.load_schema
      rescue StandardError => e
        puts "\n❌ Custom schema load failed: #{e.message}"
        puts e.backtrace.first(10).join("\n") if ENV['VERBOSE']
        exit 1
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
