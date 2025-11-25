# frozen_string_literal: true

# CustomMigrationRunner handles execution of custom fork-specific migrations
# that are separate from upstream Chatwoot migrations.
#
# Custom migrations are stored in db/migrate_custom/ with timestamp versioning
# (e.g., 20251104123456_migration_name.rb) and tracked in a separate
# custom_schema_migrations table.
#
# This system eliminates merge conflicts during upstream syncs by keeping
# custom migrations completely separate from upstream migrations.
class CustomMigrationRunner
  MIGRATIONS_DIR = Rails.root.join('db/migrate_custom')
  TRACKING_TABLE = 'custom_schema_migrations'

  def initialize(connection = ActiveRecord::Base.connection)
    @connection = connection
    ensure_tracking_table_exists
  end

  # Run all pending custom migrations
  # Ensures upstream migrations are complete before running custom ones
  def migrate
    ensure_upstream_migrations_complete!

    migrations = pending_migrations

    if migrations.empty?
      puts "\n✅ No pending custom migrations"
      return
    end

    puts "\n🔄 Running #{migrations.count} custom migration(s)..."

    migrations.each do |migration_file|
      version = extract_version(migration_file)
      name = extract_name(migration_file)

      puts "== Running custom migration #{version}: #{name} =="

      run_migration(migration_file, :up)
      record_version(version)

      puts "== Custom migration #{version} complete =="
    end

    puts "\n✅ All custom migrations complete"
  end

  # Rollback last N custom migrations
  # @param steps [Integer] number of migrations to rollback (default: 1)
  def rollback(steps = 1)
    versions_to_rollback = executed_versions.last(steps).reverse

    if versions_to_rollback.empty?
      puts "\n⚠️  No custom migrations to rollback"
      return
    end

    puts "\n🔄 Rolling back #{versions_to_rollback.count} custom migration(s)..."

    versions_to_rollback.each do |version|
      migration_file = find_migration_file(version)
      name = extract_name(migration_file)

      puts "== Rolling back custom migration #{version}: #{name} =="

      run_migration(migration_file, :down)
      remove_version(version)

      puts "== Custom migration #{version} rolled back =="
    end

    puts "\n✅ Rolled back #{versions_to_rollback.count} custom migration(s)"
  end

  # Show migration status for all custom migrations
  # @return [Array<Hash>] array of migration status hashes
  def status
    all_migration_files.map do |file|
      version = extract_version(file)
      status = executed_versions.include?(version) ? 'up' : 'down'
      name = extract_name(file)
      { status: status, version: version, name: name }
    end
  end

  # Dump custom schema to db/schema_custom.rb
  # Creates a clean schema file with only custom tables
  def dump_schema
    schema_file = Rails.root.join('db/schema_custom.rb')
    custom_tables = get_custom_tables

    File.open(schema_file, 'w') do |file|
      write_schema_header(file)

      latest_version = executed_versions.last || '0'

      file.puts "ActiveRecord::Schema[7.1].define(version: #{latest_version}) do"
      file.puts '  enable_extension "pgcrypto"'
      file.puts ''

      # Dump each custom table
      custom_tables.each do |table_name|
        dump_table_schema(table_name, file)
      end

      # Dump foreign keys
      dump_foreign_keys(custom_tables, file)

      file.puts 'end'
    end

    puts '✅ Custom schema dumped to db/schema_custom.rb'
  end

  # Load custom schema from db/schema_custom.rb
  # Idempotent - safe to run multiple times
  def load_schema
    schema_file = Rails.root.join('db/schema_custom.rb')

    unless File.exist?(schema_file)
      puts "⚠️  Custom schema file not found: #{schema_file}"
      return
    end

    load(schema_file)
    puts '✅ Custom schema loaded from db/schema_custom.rb'
  end

  # Get list of pending custom migrations
  # @return [Array<String>] array of migration file paths
  def pending_migrations
    all_migration_files.reject do |file|
      version = extract_version(file)
      executed_versions.include?(version)
    end
  end

  private

  # Ensure tracking table exists, create if not
  def ensure_tracking_table_exists
    return if @connection.table_exists?(TRACKING_TABLE)

    @connection.create_table(TRACKING_TABLE, id: false) do |t|
      t.string :version, null: false
    end

    @connection.execute("ALTER TABLE #{TRACKING_TABLE} ADD PRIMARY KEY (version)")

    puts "✅ Created #{TRACKING_TABLE} table"
  end

  # Ensure all upstream migrations are complete before running custom migrations
  # Raises error if upstream migrations are pending
  def ensure_upstream_migrations_complete!
    migrator = ActiveRecord::MigrationContext.new(
      ActiveRecord::Migrator.migrations_paths,
      ActiveRecord::SchemaMigration
    )

    pending = migrator.migrations.reject { |m| migrator.get_all_versions.include?(m.version) }

    return if pending.empty?

    raise StandardError, "Cannot run custom migrations: #{pending.count} upstream migration(s) pending. " \
                         "Run 'rails db:migrate' first."
  end

  # Get all migration files in custom directory
  # @return [Array<String>] sorted array of migration file paths
  def all_migration_files
    return [] unless File.directory?(MIGRATIONS_DIR)

    Dir.glob(MIGRATIONS_DIR.join('*.rb')).sort
  end

  # Get list of executed migration versions from tracking table
  # @return [Array<String>] array of version strings
  def executed_versions
    @connection.select_values("SELECT version FROM #{TRACKING_TABLE} ORDER BY version")
  end

  # Extract version number from migration filename
  # @param filename [String] migration filename
  # @return [String] version number (e.g., "20251104123456")
  def extract_version(filename)
    File.basename(filename).match(/^(\d+)_/)[1]
  end

  # Extract human-readable name from migration filename
  # @param filename [String] migration filename
  # @return [String] titleized name (e.g., "Create Account Prompts")
  def extract_name(filename)
    File.basename(filename, '.rb').gsub(/^\d+_/, '').tr('_', ' ').split.map(&:capitalize).join(' ')
  end

  # Find migration file by version number
  # @param version [String] version to find
  # @return [String, nil] migration file path or nil
  def find_migration_file(version)
    all_migration_files.find { |f| extract_version(f) == version }
  end

  # Run a migration file in the specified direction
  # @param file [String] migration file path
  # @param direction [Symbol] :up or :down
  def run_migration(file, direction)
    require file

    # Extract migration class name from file
    class_name = File.basename(file, '.rb').camelize.sub(/^\d+/, '')
    migration_class = class_name.constantize

    # Run migration within transaction
    ActiveRecord::Base.transaction do
      migration_class.new.migrate(direction)
    end
  rescue StandardError => e
    puts "\n❌ Error running custom migration: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    raise
  end

  # Record migration version in tracking table
  # @param version [String] version to record
  def record_version(version)
    @connection.execute(
      "INSERT INTO #{TRACKING_TABLE} (version) VALUES (#{@connection.quote(version)})"
    )
  end

  # Remove migration version from tracking table
  # @param version [String] version to remove
  def remove_version(version)
    @connection.execute(
      "DELETE FROM #{TRACKING_TABLE} WHERE version = #{@connection.quote(version)}"
    )
  end

  # Get list of custom tables (tables created by custom migrations)
  # @return [Array<String>] array of table names
  def get_custom_tables
    # Known custom tables - could be made dynamic by parsing migration files
    %w[account_prompts knowledge_bases]
  end

  # Write schema file header with comments
  # @param file [File] file handle to write to
  def write_schema_header(file)
    file.puts '# Custom schema file for fork-specific migrations'
    file.puts '# Generated automatically by db:schema:dump:custom'
    file.puts '# DO NOT EDIT THIS FILE DIRECTLY'
    file.puts '#'
    file.puts '# This file documents the schema for custom business-specific tables'
    file.puts '# that are separate from upstream Chatwoot tables.'
    file.puts '#'
    file.puts "# Current custom migration version: #{executed_versions.last || 'none'}"
    file.puts ''
  end

  # Dump table schema to file
  # @param table_name [String] name of table to dump
  # @param file [File] file handle to write to
  def dump_table_schema(table_name, file)
    return unless @connection.table_exists?(table_name)

    columns = @connection.columns(table_name)
    indexes = @connection.indexes(table_name)

    # Determine if table uses UUID
    id_column = columns.find { |c| c.name == 'id' }
    uses_uuid = id_column&.sql_type&.include?('uuid')

    # Start create_table block
    if uses_uuid
      file.puts "  create_table :#{table_name}, id: :uuid, default: -> { \"gen_random_uuid()\" }, force: :cascade do |t|"
    else
      file.puts "  create_table :#{table_name}, force: :cascade do |t|"
    end

    # Dump columns (skip id column)
    columns.each do |column|
      next if column.name == 'id'

      dump_column(column, file)
    end

    file.puts '  end'
    file.puts ''

    # Dump indexes
    indexes.each do |index|
      dump_index(table_name, index, file)
    end

    file.puts '' unless indexes.empty?
  end

  # Dump a single column definition
  # @param column [ActiveRecord::ConnectionAdapters::Column] column object
  # @param file [File] file handle to write to
  def dump_column(column, file)
    type = column.type
    options = []

    options << 'null: false' unless column.null
    options << "default: #{column.default.inspect}" if column.default && column.default.to_s != ''

    options_str = options.empty? ? '' : ", #{options.join(', ')}"
    file.puts "    t.#{type} :#{column.name}#{options_str}"
  end

  # Dump an index definition
  # @param table_name [String] name of table
  # @param index [ActiveRecord::ConnectionAdapters::IndexDefinition] index object
  # @param file [File] file handle to write to
  def dump_index(table_name, index, file)
    columns_str = if index.columns.is_a?(Array)
                    "[#{index.columns.map { |c| ":#{c}" }.join(', ')}]"
                  else
                    ":#{index.columns}"
                  end

    options = []
    options << "name: \"#{index.name}\""
    options << 'unique: true' if index.unique

    file.puts "  add_index :#{table_name}, #{columns_str}, #{options.join(', ')}"
  end

  # Dump foreign keys for custom tables
  # @param custom_tables [Array<String>] list of custom table names
  # @param file [File] file handle to write to
  def dump_foreign_keys(custom_tables, file)
    return if custom_tables.empty?

    file.puts ''

    custom_tables.each do |table_name|
      next unless @connection.table_exists?(table_name)

      foreign_keys = @connection.foreign_keys(table_name)

      foreign_keys.each do |fk|
        file.puts "  add_foreign_key \"#{fk.from_table}\", \"#{fk.to_table}\""
      end
    end
  end
end
