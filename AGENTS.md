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

See `docs/ignored/ARCHITECTURE.md` for full details.

## Commands

**See Taskfile.yml first** - Most commands are there

Essential quick reference:
- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Test Backend**: `task test-backend-file -- spec/path/to/file_spec.rb` (use `SETUP_DB=true` first time)
- **Test Frontend**: `pnpm test` or `pnpm test:watch`
- **Lint**: `pnpm eslint:fix` (JS/Vue) | `bundle exec rubocop -a` (Ruby)

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
