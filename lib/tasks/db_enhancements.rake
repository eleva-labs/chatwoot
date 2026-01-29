# We are hooking config loader to run automatically everytime migration is executed
Rake::Task['db:migrate'].enhance do
  if ActiveRecord::Base.connection.table_exists? 'installation_configs'
    puts 'Loading Installation config'
    ConfigLoader.new.process
  end
end

# Auto-run custom migrations after standard migrations
# AND dump custom schema after custom migrations complete
Rake::Task['db:migrate'].enhance do
  Rake::Task['db:migrate:custom'].invoke
  # Dump custom schema AFTER custom migrations, not during db:schema:dump
  # This ensures tables exist before we try to dump them
  Rake::Task['db:schema:dump:custom'].invoke
end

# Auto-dump custom schema after standard schema dump
# Only when called directly (not during db:migrate which handles it above)
Rake::Task['db:schema:dump'].enhance do
  # Only dump if custom tables actually exist (avoids empty schema on fresh db)
  if ActiveRecord::Base.connection.table_exists?('account_prompts')
    Rake::Task['db:schema:dump:custom'].reenable
    Rake::Task['db:schema:dump:custom'].invoke
  end
end

# Auto-load custom schema after standard schema load
Rake::Task['db:schema:load'].enhance do
  Rake::Task['db:schema:load:custom'].invoke
end

# we are creating a custom database prepare task
# the default rake db:prepare task isn't ideal for environments like heroku
# In heroku the database is already created before the first run of db:prepare
# In this case rake db:prepare tries to run db:migrate from all the way back from the beginning
# Since the assumption is migrations are only run after schema load from a point x, this could lead to things breaking.
# ref: https://github.com/rails/rails/blob/main/activerecord/lib/active_record/railties/databases.rake#L356
db_namespace = namespace :db do
  desc 'Runs setup if database does not exist, or runs migrations if it does'
  task chatwoot_prepare: :load_config do
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
      ActiveRecord::Base.establish_connection(db_config.configuration_hash)
      unless ActiveRecord::Base.connection.table_exists? 'ar_internal_metadata'
        db_namespace['load_config'].invoke if ActiveRecord.schema_format == :ruby
        ActiveRecord::Tasks::DatabaseTasks.load_schema_current(:ruby, ENV.fetch('SCHEMA', nil))

        # Load custom schema for fresh database
        Rake::Task['db:schema:load:custom'].invoke

        db_namespace['seed'].invoke
      end

      db_namespace['migrate'].invoke
      # Custom migrations run automatically via db:migrate hook
    rescue ActiveRecord::NoDatabaseError
      db_namespace['setup'].invoke
    end
  end
end

# Enhance db:setup to load custom schema
Rake::Task['db:setup'].enhance do
  Rake::Task['db:schema:load:custom'].invoke
end

# Enhance db:reset to include custom schema
Rake::Task['db:reset'].enhance do
  Rake::Task['db:schema:load:custom'].invoke
end
