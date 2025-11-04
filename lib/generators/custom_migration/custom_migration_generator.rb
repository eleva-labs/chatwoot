# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record/migration'

# Generator for creating custom fork-specific migrations
#
# Usage:
#   rails generate custom_migration MigrationName
#
# Examples:
#   rails generate custom_migration AddMetadataToKnowledgeBases
#   rails generate custom_migration CreateCustomFeature
class CustomMigrationGenerator < Rails::Generators::NamedBase
  include ActiveRecord::Generators::Migration

  source_root File.expand_path('templates', __dir__)

  def create_migration_file
    migration_template 'migration.rb.erb', File.join('db/migrate_custom', "#{file_name}.rb")
  end
end
