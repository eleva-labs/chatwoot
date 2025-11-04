# Chatwoot Development Guidelines

## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Run Project**: `overmind start -f Procfile.dev`

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:  
  - Do not write custom CSS  
  - Do not use scoped CSS  
  - Do not use inline styles  
  - Always use Tailwind utility classes  
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- MVP focus: Least code change, happy-path only
- No unnecessary defensive programming
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- Remove dead/unreachable/unused code
- Don’t write multiple versions or backups for the same logic — pick the best approach and implement it
- Don't reference Claude in commit messages

## Project-Specific

- **Translations**:
  - Only update `en.yml` and `en.json`
  - Other languages are handled by the community
  - Backend i18n → `en.yml`, Frontend i18n → `en.json`
- **Frontend**:
  - Use `components-next/` for message bubbles (the rest is being deprecated)

## Custom Migrations

This fork uses a **dual migration system** to avoid conflicts during upstream Chatwoot syncs.

### Overview

- **Upstream migrations**: `db/migrate/` - **Never modify these**
- **Custom migrations**: `db/migrate_custom/` - Our business-specific changes
- Both run automatically when you use `rails db:migrate`

### Directory Structure

```
db/
├── migrate/              # Upstream Chatwoot (pristine, never touch)
├── migrate_custom/       # Our custom migrations (timestamps: 20251104120000_*)
├── schema.rb            # Upstream tables only
└── schema_custom.rb     # Custom tables only (both committed to git)
```

### Creating Custom Migrations

**Step 1:** Generate migration using custom generator
```bash
rails generate custom_migration AddMetadataToKnowledgeBases
# Creates: db/migrate_custom/20251104120000_add_metadata_to_knowledge_bases.rb
```

**Step 2:** Edit the generated migration file
```ruby
class AddMetadataToKnowledgeBases < ActiveRecord::Migration[7.1]
  def change
    add_column :knowledge_bases, :metadata, :jsonb, default: {}, if_not_exists: true
  end
end
```

**Step 3:** Run migration
```bash
rails db:migrate
# This automatically runs both upstream and custom migrations
```

### Common Commands

```bash
# Generate a new custom migration
rails generate custom_migration MigrationName

# Run all migrations (upstream + custom)
rails db:migrate

# Check migration status
rails db:migrate:status          # Upstream migrations
rails db:migrate:custom:status   # Custom migrations

# Rollback custom migrations only
rails db:rollback:custom STEP=1

# Dump schemas (both are auto-dumped)
rails db:schema:dump

# Fresh database setup
rails db:setup                   # Loads both schemas automatically
```

### Important Rules

1. **Never edit files in `db/migrate/`** - These are upstream Chatwoot migrations
2. **Use `rails generate custom_migration`** to create new custom migrations
3. **Always run `rails db:migrate`** (not `db:migrate:custom`) for normal workflow
4. **Both schema files are tracked in git** (`schema.rb` and `schema_custom.rb`)
5. **Custom migrations run AFTER upstream** - Dependencies are guaranteed
6. **Use `if_not_exists: true`** option to make migrations idempotent

### Troubleshooting

**Problem:** "Cannot run custom migrations: X upstream migrations pending"
- **Solution:** Run `rails db:migrate` first (this runs both upstream then custom)

**Problem:** Custom tables missing after `db:setup`
- **Solution:** Ensure `db/schema_custom.rb` exists and is committed to git

**Problem:** Merge conflict in `db/migrate/` or `db/schema.rb`
- **Solution:** This shouldn't happen! Custom migrations are separate. If it does, custom files may have been added to wrong directory.

### Full Documentation

For complete documentation including architecture, troubleshooting, and best practices, see:
**[docs/db/CUSTOM_MIGRATIONS.md](docs/db/CUSTOM_MIGRATIONS.md)**

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

Practical checklist for any change impacting core logic or public APIs
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
