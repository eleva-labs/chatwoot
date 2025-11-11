# Chatwoot Development Guidelines

## Architecture Overview

**Stack**: Ruby on Rails 7.1+ (backend) + Vue 3 (frontend) + PostgreSQL + Redis + Sidekiq
**Style**: Monolithic Rails app with service-oriented architecture
**Real-time**: ActionCable (WebSockets)
**Multi-tenancy**: Account-based isolation (no schema separation)

### Key Patterns

- **Services** (`app/services/`) - Business logic layer (e.g., `Whatsapp::IncomingMessageService`)
- **Finders** (`app/finders/`) - Complex database queries (e.g., `ConversationsFinder`)
- **Builders** (`app/builders/`) - Object construction (e.g., `Messages::MessageBuilder`)
- **Listeners** (`app/listeners/`) - Event-driven reactions (subscribe to domain events)
- **Event Dispatcher** - Pub/sub pattern (`Rails.configuration.dispatcher.dispatch(...)`)
- **Jobs** (`app/jobs/`) - Background processing via Sidekiq

### Directory Structure

```
app/
├── controllers/api/    # REST API endpoints (JSON)
├── services/           # Business logic
├── finders/            # Query objects
├── builders/           # Object builders
├── listeners/          # Event handlers
├── jobs/               # Background jobs
└── models/             # ActiveRecord models

app/javascript/dashboard/
├── components/         # Vue components
├── components-next/    # New architecture (preferred for message bubbles)
├── store/              # Vuex state management
├── api/                # API client wrappers
└── i18n/               # Translations (en.json, es.json)
```

See `docs/ARCHITECTURE.md` for full details.

## Commands

**See Taskfile.yml first** - Most commands are there

### Docker Development Setup

**From Scratch (First Time)**
```bash
# 1. Build Docker images
task docker-build

# 2. Start containers
docker compose up -d

# 3. Prepare development database
task docker-setup-dev

# 4. Access app at http://localhost:3000
```

**After Code Changes (Quick Reload)**
```bash
# For Ruby/service changes - restart containers
docker compose restart

# For env variable changes - reload without rebuild
task docker-reload-env
```

**After DB Schema Changes or docker-down**
```bash
# Re-prepare database (required after docker compose down)
task docker-setup-dev
```

**Full Rebuild (When Needed)**
```bash
# Complete rebuild and setup
task docker-chatwoot-build
```

### Unit Testing

**IMPORTANT: Always use Taskfile commands for tests - they handle RAILS_ENV=test automatically**

**Backend Tests (RSpec)**
```bash
# First time setup - starts test DB and runs tests
SETUP_DB=true task test-backend-file -- spec/path/to/file_spec.rb

# Subsequent runs - no DB setup needed
task test-backend-file -- spec/path/to/file_spec.rb

# Run specific test module
task test-backend-module -- spec/models

# Run all backend tests
task test-backend-all

# Cleanup after tests
task test-cleanup
```

**⚠️ NEVER run `bundle exec rspec` directly - always use task commands!**
- Task commands automatically set `RAILS_ENV=test`
- Running rspec directly defaults to development environment and tests will fail

**Frontend Tests (Vitest)**
```bash
# Run all tests
pnpm test

# Watch mode
pnpm test:watch

# Coverage report
pnpm test:coverage
```

### Quick Reference
- **Lint**: `pnpm eslint:fix` (JS/Vue) | `bundle exec rubocop -a` (Ruby)
- **Run Dev (Non-Docker)**: `pnpm dev` or `overmind start -f ./Procfile.dev`

## Critical Code Style Rules

### Styling
- **Tailwind Only**: Do not write custom CSS, scoped CSS, or inline styles - use Tailwind utility classes only
- **Colors**: Refer to `tailwind.config.js` for color definitions

### Vue/Frontend
- **Composition API**: Always use `<script setup>` at the top (never Options API)
- **Components**: PascalCase for names, camelCase for events
- **I18n**: No bare strings in templates - use i18n
- **State**: Use Vuex store modules via `useStore()`

### Ruby/Backend
- **Service Objects**: Extract complex business logic to `app/services/`
- **Finders**: Use for complex queries instead of scopes/model methods
- **Error Handling**: Use custom exceptions from `lib/custom_exceptions/`
- **Module/Class**: Use compact definitions (avoid nested styles)
- **Line Length**: 150 character max (RuboCop enforced)

## General Guidelines

- MVP focus: Least code change, happy-path only
- No unnecessary defensive programming
- Break down complex tasks into small, testable units
- Avoid writing specs unless explicitly asked
- Remove dead/unreachable/unused code
- Don't write multiple versions or backups - pick the best approach and implement it
- Don't reference Claude in commit messages

## Project-Specific Conventions

### Translations
- Update both `en/es.yml` and `en/es.json`
- Backend i18n → `en/es.yml`, Frontend i18n → `en/es.json`
- Other languages handled by community

### Frontend
- Use `components-next/` for message bubbles (rest is being deprecated)

### Domain Concepts
- **INBOXES**: Referred to as "Channels" in locales/UI labels
- **AGENTS**: Referred to as "Members" in locales/UI labels

### Git Branches
- **Base branch**: `development` (NOT `develop`)
- **Production branch**: `main` (NOT `master`)

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
