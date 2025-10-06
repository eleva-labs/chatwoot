# [Process Name] Process Guide

**Version**: X.Y.Z
**Last Updated**: YYYY-MM-DD
**Status**: Draft | Active | Deprecated | Archived
**Document Type**: Process Guide
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Table of Contents

1. [Overview](#overview)
2. [Key Principles](#key-principles)
3. [Process Workflow](#process-workflow)
4. [Phase 1: [Phase Name]](#phase-1-phase-name)
5. [Phase 2: [Phase Name]](#phase-2-phase-name)
6. [Phase N: [Phase Name]](#phase-n-phase-name)
7. [Best Practices](#best-practices)
8. [Process Checklist](#process-checklist)
9. [Templates & Examples](#templates--examples)
10. [Troubleshooting](#troubleshooting)
11. [Quick Reference](#quick-reference)
12. [Related Documentation](#related-documentation)
13. [Changelog](#changelog)

---

## Overview

### Purpose

[Describe what this process achieves. Answer: Why does this process exist?]

**Example**: This process ensures systematic and repeatable [activity] for Chatwoot development, resulting in [outcome].

### Scope

**What is Covered**:
- Backend development (Ruby on Rails 7.1+)
- Frontend development (Vue.js 3 with Composition API)
- Database changes (PostgreSQL with Rails migrations)
- Testing (RSpec for backend, Vitest for frontend)
- Documentation updates

**What is NOT Covered**:
- Infrastructure/DevOps changes
- Third-party integrations (unless directly related)
- Performance optimization (separate process)

### When to Use This Process

**ALWAYS Use This Process For**:
- New feature development
- Complex refactoring tasks
- Breaking changes to API or data models
- Multi-component changes (backend + frontend)
- Scenario 3

**SKIP This Process For**:
- Trivial bug fixes (typos, obvious fixes)
- Documentation-only changes
- Emergency hotfixes (use expedited process)

### Process Summary

[2-3 paragraph overview describing:
- What the process does
- Who is involved (Development Team, Code Reviewers, QA)
- What the main outputs are (Code, Tests, Documentation)
- How long it typically takes]

---

## Key Principles

### Core Principles

1. **Principle 1: Rails MVC + Services Architecture**
   - Follow Rails conventions (Models, Controllers, Views)
   - Extract business logic into Service objects
   - Keep controllers thin, models focused on data
   - Use Finders for complex queries, Builders for object construction
   - **Why it matters**: Maintainable, testable, follows established patterns
   - **Example**: `Stores::CreateService` handles creation logic, not the controller

2. **Principle 2: Frontend Component-Based Development**
   - Use Vue 3 Composition API exclusively (`<script setup>`)
   - Use Tailwind CSS only (no custom CSS, scoped styles, or inline styles)
   - Always update i18n for both `en.json` and `es.json`
   - Manage state with Vuex store modules
   - **Why it matters**: Consistent UI, accessible, translatable
   - **Example**: StoreDetails component uses Tailwind classes, i18n keys, Vuex state

3. **Principle 3: Test-Driven Quality**
   - Write RSpec specs for backend (models, services, controllers, requests)
   - Write Vitest specs for frontend (components, store modules)
   - Test happy path + edge cases + error scenarios
   - Maintain high test coverage
   - **Why it matters**: Prevents regressions, documents behavior, enables refactoring
   - **Example**: Request specs validate API contracts, component specs test user interactions

### Success Criteria

The process is successful when:
- [ ] All code follows CLAUDE.md guidelines
- [ ] All tests pass (RSpec + Vitest)
- [ ] Code review approved
- [ ] i18n updated for all UI changes (en/es)
- [ ] Documentation updated
- [ ] Enterprise compatibility verified (if applicable)

---

## Process Workflow

### Process Flow Diagram

```
[Stage 1: Requirements Analysis]
    ↓
[Stage 2: Design & Planning]
    ↓
[Stage 3: Implementation] → [Decision: Frontend Changes?]
    ↓ Yes                        ↓ No
[Stage 4a: Backend + Frontend]   [Stage 4b: Backend Only]
    ↓                             ↓
[Stage 5: Testing & Review]
    ↓
[Stage 6: Documentation & Deployment]
```

### Phase Summary Table

| Phase | Objective | Deliverable | Owner | Duration |
|-------|-----------|-------------|-------|----------|
| 1. [Name] | [What it achieves] | [Output] | Developer | [Time] |
| 2. [Name] | [What it achieves] | [Output] | Developer | [Time] |
| 3. [Name] | [What it achieves] | [Output] | Developer + Reviewer | [Time] |
| **Total** | | | | **[Total Time]** |

### Dependencies & Prerequisites

**Prerequisites**:
- Development environment set up (`bundle install`, `pnpm install`)
- Database running and migrated (`rails db:migrate`)
- Review CLAUDE.md and ARCHITECTURE.md
- Understanding of Chatwoot's Rails + Vue.js stack

**Dependencies**:
- Rails 7.1+ installed
- PostgreSQL and Redis running
- Node.js 23.x and pnpm 10.x installed
- Access to codebase and documentation

---

## Phase 1: [Phase Name]

**Objective**: [Clear statement of what this phase achieves]

**Duration**: [Estimated time range]

**Owner**: [Who is responsible for this phase]

**Prerequisites**:
- Item 1
- Item 2

### Step 1.1: [Step Name]

**Description**: [What this step does]

**Actions**:
1. Action 1 - [Description]
2. Action 2 - [Description]
3. Action 3 - [Description]

**Tools/Commands**:
```bash
# Backend: Run RSpec tests
bundle exec rspec spec/models/store_spec.rb

# Frontend: Run Vitest tests
pnpm test

# Linting: Ruby
bundle exec rubocop -a

# Linting: Vue.js/JavaScript
pnpm eslint:fix

# Database: Run migrations
rails db:migrate

# Server: Start development server
pnpm dev
# or
overmind start -f Procfile.dev
```

**Expected Output**:
```
[Show what successful output looks like - e.g., test results, server startup logs]
```

**Verification**:
```bash
# Verify backend tests pass
bundle exec rspec

# Verify frontend tests pass
pnpm test

# Verify no linting errors
bundle exec rubocop
pnpm eslint
```

**Common Issues**:
- **Issue 1**: Database migration fails → Check PostgreSQL is running, check migration syntax
- **Issue 2**: Frontend tests fail → Check Node version (23.x), clear node_modules and reinstall

### Step 1.2: [Step Name]

[Repeat structure for each step]

### Phase 1 Deliverable

**Output**: [What this phase produces]

**Location**: [Where the output is stored - e.g., `app/models/`, `app/javascript/dashboard/components/`]

**Format**: [Structure/format - e.g., Ruby class, Vue component, Markdown doc]

**Quality Check**:
- [ ] Code follows Rails conventions
- [ ] Vue components use Composition API
- [ ] All Tailwind CSS (no custom CSS)
- [ ] i18n updated (en/es)
- [ ] Tests written and passing

---

## Phase 2: [Phase Name]

[Repeat structure from Phase 1]

---

## Phase N: [Final Phase Name]

[Repeat structure from Phase 1]

---

## Best Practices

### For Backend Developers (Ruby/Rails)

#### Do's ✅
1. **Follow Rails MVC Pattern**: Models for data, Controllers for HTTP, Services for business logic
2. **Use Service Objects**: Extract complex logic into `app/services/` (e.g., `Stores::CreateService`)
3. **Validate in Models**: Use ActiveRecord validations (`validates :name, presence: true`)
4. **Use Finders for Queries**: Complex queries go in `app/finders/` (e.g., `ConversationsFinder`)
5. **Dispatch Events**: Use event dispatcher for decoupled actions (`Rails.configuration.dispatcher.dispatch(...)`)
6. **Write RSpec Specs**: Test models, services, controllers, and request specs
7. **Follow CLAUDE.md**: 150 char line length, compact module/class definitions

#### Don'ts ❌
1. **Don't Put Business Logic in Controllers**: Controllers should be thin, delegate to services
2. **Don't Skip Migrations**: Always create migrations for schema changes (`rails g migration ...`)
3. **Don't Ignore Enterprise**: Check for enterprise overlays in `enterprise/app/` before making changes
4. **Don't Skip i18n**: Update both `config/locales/en.yml` and `config/locales/es.yml`
5. **Don't Use Nested Module Definitions**: Use compact style (`class Api::V1::StoresController` not nested)

### For Frontend Developers (Vue.js)

#### Do's ✅
1. **Always Use Composition API**: `<script setup>` at the top of every component
2. **Only Use Tailwind CSS**: Utility classes only, no scoped CSS, no custom CSS, no inline styles
3. **Update i18n**: Both `app/javascript/dashboard/i18n/locale/en.json` AND `es.json`
4. **Use Vuex for State**: State management in `app/javascript/dashboard/store/modules/`
5. **PascalCase Components**: Component names in PascalCase, events in camelCase
6. **Write Vitest Specs**: Test components, store modules, helper functions
7. **Use components-next**: For message bubbles, prefer `components-next/` over deprecated components

#### Don'ts ❌
1. **Don't Use Options API**: No `export default { data(), methods: {} }` - use Composition API
2. **Don't Write Custom CSS**: No `<style>` blocks, no scoped CSS, no inline styles - Tailwind only
3. **Don't Skip i18n**: No bare strings in templates, always use `$t('KEY')`
4. **Don't Put Logic in Components**: Complex logic belongs in Vuex actions or composables
5. **Don't Mix Old Patterns**: Use new architecture (`components-next/`) when working with messages

### General Guidelines

1. **Guideline 1: Multi-Layer Updates**
   - Backend change → Update Model, Service, Controller, Jbuilder view, Migration
   - Frontend change → Update Component, Vuex store, i18n (en/es), Tests
   - Full-stack change → All of the above

2. **Guideline 2: Test Coverage**
   - Backend: RSpec specs for models, services, controllers, request specs for APIs
   - Frontend: Vitest specs for components, store modules
   - Target: >80% coverage for changed files

### Common Patterns

#### Pattern 1: Add Field to Existing Model

**When to Use**: Adding a new field to a database model

**How to Apply**:
1. Create Rails migration
2. Update model validations
3. Update service objects (create/update)
4. Update controller (permit new param)
5. Update Jbuilder view (expose new field)
6. Update Vue component (display/edit field)
7. Update Vuex store (state management)
8. Update i18n (en.json, es.json, en.yml, es.yml)
9. Write tests (model spec, request spec, component spec)

**Example**:
```bash
# Step 1: Generate migration
rails g migration AddPhoneNumberToStores phone_number:string

# Step 2: Run migration
rails db:migrate

# Step 3: Update model
# app/models/store.rb
class Store < ApplicationRecord
  validates :phone_number, phone: { allow_blank: true }
end

# Step 4: Update service
# app/services/stores/create_service.rb - permit :phone_number

# Step 5: Update controller
# app/controllers/api/v1/accounts/stores_controller.rb
def store_params
  params.permit(:name, :phone_number, :email)
end

# Step 6: Update Jbuilder view
# app/views/api/v1/accounts/stores/show.json.jbuilder
json.phoneNumber store.phone_number

# Step 7: Update Vue component
# app/javascript/dashboard/components/StoreDetails.vue

# Step 8: Update i18n
# Both en.json and es.json

# Step 9: Write tests
bundle exec rspec spec/models/store_spec.rb
bundle exec rspec spec/requests/api/v1/accounts/stores_spec.rb
pnpm test -- StoreDetails.spec.js
```

#### Pattern 2: Create New Service Object

**When to Use**: Extracting business logic from controller

**Example**:
```ruby
# app/services/stores/create_service.rb
class Stores::CreateService
  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def perform
    store = @account.stores.build(store_params)

    if store.save
      dispatch_event(store)
      store
    else
      raise ActiveRecord::RecordInvalid, store
    end
  end

  private

  def store_params
    @params.permit(:name, :phone_number, :email)
  end

  def dispatch_event(store)
    Rails.configuration.dispatcher.dispatch(
      STORE_CREATED,
      Time.zone.now,
      store: store
    )
  end
end

# Usage in controller:
# app/controllers/api/v1/accounts/stores_controller.rb
def create
  @store = Stores::CreateService.new(
    account: Current.account,
    params: params
  ).perform

  render json: @store, status: :created
rescue ActiveRecord::RecordInvalid => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

---

## Process Checklist

### Pre-Process Setup

- [ ] Development environment ready
- [ ] Database running and migrated
- [ ] CLAUDE.md and ARCHITECTURE.md reviewed
- [ ] Tools available (Ruby, Rails, Node.js, pnpm)
- [ ] Feature branch created from `develop`

### Phase 1: [Phase Name]

- [ ] Step 1.1 complete
- [ ] Step 1.2 complete
- [ ] Step 1.N complete
- [ ] Phase 1 deliverable created
- [ ] Quality check passed (linting, tests)

### Phase 2: [Phase Name]

[Repeat for each phase]

### Post-Process Completion

- [ ] All phases complete
- [ ] Backend tests passing (`bundle exec rspec`)
- [ ] Frontend tests passing (`pnpm test`)
- [ ] Linting clean (`bundle exec rubocop`, `pnpm eslint`)
- [ ] i18n updated (en/es for both backend and frontend)
- [ ] Documentation updated
- [ ] Code review requested
- [ ] Enterprise compatibility verified (if applicable)

### Quality Gates

#### After Backend Development → Before Frontend Development
- [ ] Models and migrations complete
- [ ] Service objects tested
- [ ] API endpoints functional (test with cURL or request specs)
- [ ] Jbuilder views return correct JSON structure

#### After Frontend Development → Before Review
- [ ] Components use Composition API
- [ ] Only Tailwind CSS used (no custom/scoped/inline styles)
- [ ] i18n complete (en.json + es.json)
- [ ] Vuex store updated
- [ ] Component tests passing

[Continue for all phase transitions]

---

## Templates & Examples

### Template 1: Service Object Template

**Purpose**: Creating a new service object for business logic

**Location**: `app/services/<domain>/<action>_service.rb`

**Usage Instructions**:
1. Create file in appropriate domain folder (`stores/`, `conversations/`, etc.)
2. Name it `<action>_service.rb` (e.g., `create_service.rb`, `update_service.rb`)
3. Follow the structure below

**Template Structure**:

```ruby
# app/services/<domain>/<action>_service.rb

class <Domain>::<Action>Service
  def initialize(<dependencies>)
    @dependency1 = dependency1
    @dependency2 = dependency2
  end

  def perform
    # Main service logic here

    if <success_condition>
      dispatch_event if applicable
      result
    else
      raise <CustomException>
    end
  end

  private

  def helper_method
    # Private helper logic
  end

  def dispatch_event
    Rails.configuration.dispatcher.dispatch(
      EVENT_CONSTANT,
      Time.zone.now,
      data: { ... }
    )
  end
end

# Spec: spec/services/<domain>/<action>_service_spec.rb
RSpec.describe <Domain>::<Action>Service do
  let(:service) { described_class.new(...) }

  describe '#perform' do
    it 'succeeds when conditions met' do
      result = service.perform
      expect(result).to be_valid
    end

    it 'raises error when conditions not met' do
      expect { service.perform }.to raise_error(CustomException)
    end
  end
end
```

### Template 2: Vue Component Template

**Purpose**: Creating a new Vue.js component

**Location**: `app/javascript/dashboard/components/<ComponentName>.vue`

**Template Structure**:

```vue
<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

// Composables
const store = useStore();
const { t } = useI18n();

// Props
const props = defineProps({
  itemId: {
    type: String,
    required: true,
  },
});

// Emits
const emit = defineEmits(['update', 'close']);

// State
const isLoading = ref(false);

// Computed
const item = computed(() => store.getters['items/getItem'](props.itemId));

// Methods
const handleUpdate = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('items/update', { id: props.itemId, data: {...} });
    emit('update');
  } catch (error) {
    console.error('Update failed:', error);
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-4 p-4">
    <h2 class="text-lg font-semibold">
      {{ t('COMPONENT.TITLE') }}
    </h2>

    <button
      @click="handleUpdate"
      :disabled="isLoading"
      class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 disabled:opacity-50"
    >
      {{ t('COMPONENT.ACTION') }}
    </button>
  </div>
</template>

<!-- Spec: app/javascript/dashboard/components/__tests__/ComponentName.spec.js -->
```

### Example 1: Full-Stack Feature Implementation

**Scenario**: Add "priority" field to Store model (High/Medium/Low)

**Context**: Business wants to prioritize stores for support team

**Walkthrough**:

```markdown
**Step 1: Backend - Migration**
```bash
rails g migration AddPriorityToStores priority:integer
# Edit migration to add default value
rails db:migrate
```

**Step 2: Backend - Model**
```ruby
# app/models/store.rb
class Store < ApplicationRecord
  enum priority: { low: 0, medium: 1, high: 2 }

  validates :priority, presence: true, inclusion: { in: priorities.keys }
end
```

**Step 3: Backend - Service**
```ruby
# app/services/stores/create_service.rb
def store_params
  @params.permit(:name, :phone_number, :priority) # Added :priority
end
```

**Step 4: Backend - Jbuilder**
```ruby
# app/views/api/v1/accounts/stores/show.json.jbuilder
json.priority store.priority
```

**Step 5: Frontend - i18n**
```json
// en.json
"STORE": {
  "PRIORITY": "Priority",
  "PRIORITY_HIGH": "High",
  "PRIORITY_MEDIUM": "Medium",
  "PRIORITY_LOW": "Low"
}

// es.json (Spanish translation)
"STORE": {
  "PRIORITY": "Prioridad",
  "PRIORITY_HIGH": "Alta",
  "PRIORITY_MEDIUM": "Media",
  "PRIORITY_LOW": "Baja"
}
```

**Step 6: Frontend - Component**
```vue
<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium">
      {{ t('STORE.PRIORITY') }}
    </label>
    <select
      v-model="selectedPriority"
      class="border rounded px-3 py-2"
    >
      <option value="low">{{ t('STORE.PRIORITY_LOW') }}</option>
      <option value="medium">{{ t('STORE.PRIORITY_MEDIUM') }}</option>
      <option value="high">{{ t('STORE.PRIORITY_HIGH') }}</option>
    </select>
  </div>
</template>
```

**Step 7: Tests**
```bash
# Backend
bundle exec rspec spec/models/store_spec.rb
bundle exec rspec spec/requests/api/v1/accounts/stores_spec.rb

# Frontend
pnpm test -- StorePriority.spec.js
```
```

**Key Takeaways**:
1. Full-stack changes require updates across 6+ files
2. Always update both en.json and es.json for i18n
3. Test at each layer (model, API, component)

---

## Troubleshooting

### Issue 1: Rails Server Won't Start

**Symptoms**:
- `rails server` fails to start
- Port 3000 already in use error
- Database connection errors

**Possible Causes**:
1. PostgreSQL not running
2. Redis not running
3. Port 3000 already in use
4. Missing environment variables

**Diagnosis**:
```bash
# Check if PostgreSQL is running
pg_isready

# Check if Redis is running
redis-cli ping

# Check what's using port 3000
lsof -ti:3000

# Check environment variables
cat .env
```

**Solutions**:

**Solution 1** (Recommended - Use Overmind):
```bash
# Start all services with Overmind
pnpm dev
# or
overmind start -f Procfile.dev
```

**Solution 2** (Manual):
```bash
# Start PostgreSQL
brew services start postgresql
# or
docker-compose up -d postgres

# Start Redis
brew services start redis
# or
docker-compose up -d redis

# Kill process on port 3000
kill $(lsof -ti:3000)

# Start Rails server
rails server
```

**Prevention**:
- Use Overmind to manage all processes
- Check services before starting development
- Use `pnpm dev` instead of manual `rails server`

---

### Issue 2: Frontend Tests Failing

**Symptoms**:
- Vitest tests fail unexpectedly
- Import errors in test files
- "Cannot find module" errors

**Possible Causes**:
1. Wrong Node.js version (needs 23.x)
2. Stale node_modules
3. Missing test setup files
4. Incorrect import paths

**Diagnosis**:
```bash
# Check Node.js version
node --version  # Should be 23.x

# Check pnpm version
pnpm --version  # Should be 10.x

# Check test configuration
cat vitest.config.js
```

**Solutions**:

**Solution 1** (Recommended):
```bash
# Clear node_modules and reinstall
rm -rf node_modules
pnpm install

# Run tests
pnpm test
```

**Solution 2** (Alternative):
```bash
# Check Node.js version manager
nvm use 23  # or appropriate version

# Clear Vitest cache
pnpm vitest --clearCache

# Run specific test file
pnpm test -- path/to/test.spec.js
```

**Prevention**:
- Use correct Node.js version (check `.nvmrc` or package.json engines)
- Commit `pnpm-lock.yaml` to ensure consistent dependencies
- Run tests before pushing changes

---

### Issue 3: i18n Keys Missing

**Symptoms**:
- Translation keys showing in UI instead of text
- Console warnings about missing i18n keys
- Different languages have different keys

**Possible Causes**:
1. Added key to `en.json` but not `es.json` (or vice versa)
2. Added key to backend i18n but not frontend (or vice versa)
3. Typo in translation key

**Diagnosis**:
```bash
# Check for key in en.json
grep -r "YOUR_KEY" app/javascript/dashboard/i18n/locale/en.json

# Check for key in es.json
grep -r "YOUR_KEY" app/javascript/dashboard/i18n/locale/es.json

# Compare en.json and es.json structure
diff <(jq -S . app/javascript/dashboard/i18n/locale/en.json) \
     <(jq -S . app/javascript/dashboard/i18n/locale/es.json)
```

**Solutions**:

**Solution 1** (Recommended):
```bash
# Add key to BOTH en.json and es.json
# en.json
{
  "STORE": {
    "NEW_FIELD": "New Field Label"
  }
}

# es.json
{
  "STORE": {
    "NEW_FIELD": "Etiqueta de Nuevo Campo"
  }
}

# Backend i18n (if needed)
# config/locales/en.yml and config/locales/es.yml
```

**Prevention**:
- Always update BOTH `en.json` and `es.json` together
- Run i18n validation script if available
- Check for missing keys during code review

---

## Quick Reference

### Common Commands

```bash
# === Backend (Rails) ===

# Run all backend tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/store_spec.rb

# Run specific test (by line number)
bundle exec rspec spec/models/store_spec.rb:25

# Lint Ruby code
bundle exec rubocop

# Auto-fix Ruby linting issues
bundle exec rubocop -a

# Create migration
rails g migration AddFieldToTable field:type

# Run migrations
rails db:migrate

# Rollback last migration
rails db:rollback

# Start Rails server
rails server

# === Frontend (Vue.js) ===

# Run all frontend tests
pnpm test

# Run tests in watch mode
pnpm test:watch

# Run tests with coverage
pnpm test:coverage

# Lint JavaScript/Vue
pnpm eslint

# Auto-fix ESLint issues
pnpm eslint:fix

# === Full Stack ===

# Start all services (Overmind)
pnpm dev

# Alternative: Foreman
foreman start -f Procfile.dev

# === Database ===

# Start PostgreSQL (Homebrew)
brew services start postgresql

# Start Redis (Homebrew)
brew services start redis

# Start with Docker Compose
docker-compose up -d postgres redis

# === Git ===

# View Rails routes
rails routes | grep stores

# Check git status
git status

# Create feature branch
git checkout -b feature/your-feature-name
```

### File Locations

| Type | Location | Description |
|------|----------|-------------|
| **Backend - Models** | `app/models/` | ActiveRecord models |
| **Backend - Services** | `app/services/` | Business logic service objects |
| **Backend - Controllers** | `app/controllers/api/v1/` | API controllers |
| **Backend - Jobs** | `app/jobs/` | Background jobs (Sidekiq) |
| **Backend - Views** | `app/views/api/v1/` | Jbuilder JSON views |
| **Backend - Specs** | `spec/` | RSpec tests |
| **Backend - Migrations** | `db/migrate/` | Database migrations |
| **Backend - i18n** | `config/locales/` | Backend translations (en.yml, es.yml) |
| **Frontend - Components** | `app/javascript/dashboard/components/` | Vue components |
| **Frontend - Store** | `app/javascript/dashboard/store/` | Vuex state management |
| **Frontend - i18n** | `app/javascript/dashboard/i18n/locale/` | Frontend translations (en.json, es.json) |
| **Frontend - Tests** | `app/javascript/**/*.spec.js` | Vitest component tests |
| **Enterprise** | `enterprise/app/` | Enterprise edition overlay |
| **Docs - Processes** | `docs/processes/` | Process documentation |
| **Docs - Architecture** | `docs/ARCHITECTURE.md` | Architecture overview |
| **Guidelines** | `CLAUDE.md` | Development guidelines |

### Key Terminology

- **Account**: Multi-tenant workspace (top-level isolation)
- **Inbox**: Communication channel (referred to as "Channels" in UI/locales)
- **Agent**: System user (referred to as "Members" in UI/locales)
- **Conversation**: Chat or email thread
- **Service Object**: Business logic class (e.g., `Stores::CreateService`)
- **Finder**: Query object for complex database queries
- **Builder**: Object construction pattern
- **Listener**: Event subscriber for decoupled actions
- **Dispatcher**: Event publisher
- **Jbuilder**: JSON view template library
- **Composition API**: Vue 3 API style using `<script setup>`

---

## Related Documentation

### Internal Documentation

**Process Documentation**:
- [Development Process](./development/development_process.md) - Full development workflow
- [Research & Design Process](./design/research_and_design_process.md) - Feature research and design
- [Code Review Process](./code_review/code_review_process.md) - Review procedures
- [API Testing Process](./tests/api_testing_process.md) - API testing guide

**Technical Documentation**:
- [Architecture Overview](../ARCHITECTURE.md) - Chatwoot architecture and tech stack
- [Development Guidelines](../CLAUDE.md) - Coding standards and conventions
- [Contributing Guide](../CONTRIBUTING.md) - Contribution guidelines

**Templates**:
- [Design Template](./design/DESIGN_TEMPLATE.md) - Design document template
- [Research Template](./design/RESEARCH_TEMPLATE.md) - Research report template
- [Execution Template](./development/DEVELOPMENT_EXECUTION_TEMPLATE.md) - Execution tracking
- [Test Plan Template](./tests/TEST_PLAN_TEMPLATE.md) - Test planning
- [Review Report Template](./code_review/REVIEW_REPORT_TEMPLATE.md) - Code review reporting

### External Resources

**Ruby on Rails**:
- [Ruby on Rails Guides](https://guides.rubyonrails.org/) - Official Rails documentation
- [RSpec Documentation](https://rspec.info/) - Testing framework
- [ActiveRecord Guides](https://guides.rubyonrails.org/active_record_basics.html) - ORM documentation
- [Rails API Documentation](https://api.rubyonrails.org/) - API reference

**Vue.js**:
- [Vue.js 3 Documentation](https://vuejs.org/) - Official Vue.js docs
- [Composition API Guide](https://vuejs.org/guide/extras/composition-api-faq.html) - Composition API
- [Vuex Documentation](https://vuex.vuejs.org/) - State management
- [Vue Router Documentation](https://router.vuejs.org/) - Routing
- [Vitest Documentation](https://vitest.dev/) - Testing framework

**Styling**:
- [Tailwind CSS Documentation](https://tailwindcss.com/) - Utility-first CSS framework

**Best Practices**:
- [Rails Service Objects](https://www.toptal.com/ruby-on-rails/rails-service-objects-tutorial) - Service pattern
- [Vue.js Best Practices](https://vuejs.org/style-guide/) - Vue style guide

---

## Integration with Other Processes

### How This Process Fits in the Workflow

```
┌─────────────────────────────────────┐
│  Research & Design Process          │
│  (Understand requirements, design)  │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│  THIS PROCESS                       │
│  Phase 1 → Phase 2 → Phase N        │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│  Code Review Process                │
│  (Review, approve, merge)           │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│  API Testing Process                │
│  (Validate endpoints, regression)   │
└─────────────────────────────────────┘
```

### Handoffs

**From Research & Design Process**:
- Approved design document
- Architecture plan
- Identified files to change

**To Code Review Process**:
- Implemented code changes
- Updated tests (passing)
- Documentation updates

---

## Metrics & Success Indicators

### Process Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Duration | [X hours/days] | Time from branch creation to PR ready |
| Test Coverage | >80% | RSpec coverage report + Vitest coverage |
| Code Quality | No RuboCop/ESLint errors | Linting reports |
| Review Cycles | ≤2 rounds | Number of review iterations |

### Success Indicators

**Process Successful When**:
- [ ] All tests pass (RSpec + Vitest)
- [ ] No linting errors (RuboCop + ESLint)
- [ ] i18n complete (en/es for backend and frontend)
- [ ] Code review approved
- [ ] Documentation updated
- [ ] Feature works as designed

**Process Failed When**:
- Critical bugs discovered in production
- Tests failing on CI/CD pipeline
- Breaking changes not documented
- i18n incomplete (missing translations)

---

## Changelog

### Version 2.0.0 (2025-10-06)

**Status**: Active

**Changes**:
- **MAJOR UPDATE**: Adapted for Chatwoot (Rails + Vue.js) from AI Backend (Python/FastAPI)
- Replaced Python/FastAPI examples with Ruby/Rails + Vue.js examples
- Updated commands (pytest → bundle exec rspec, pnpm test)
- Updated file paths (Python structure → Rails structure)
- Added frontend development sections (Vue.js, Tailwind CSS, i18n)
- Added Enterprise edition considerations
- Updated architecture references (Clean Architecture → Rails MVC + Services)
- Added service object, finder, builder, listener patterns
- Referenced ARCHITECTURE.md and CLAUDE.md
- Updated all code examples to Ruby and Vue.js
- Added full-stack feature implementation examples

**Migration Notes**:
- All Python/Clean Architecture references removed
- Use this template for all new Chatwoot process documents
- See PROCESS_ADAPTATION_PLAN.md for complete migration strategy

---

### Version 1.0.0 (Previous)

**Status**: Archived

**Changes**:
- Initial template for AI Backend (Python/FastAPI)
- Defined generic process structure
- Created reusable sections

---

## Document Metadata

**Document Owner**: Development Team

**Maintained By**: Development Team

**Review Cycle**: Quarterly or after major architectural changes

**Last Reviewed**: 2025-10-06

**Next Review Due**: 2026-01-06

**Contact**: Development team channel for questions and feedback

---

## Appendix

### Appendix A: Glossary

| Term | Definition |
|------|------------|
| **ActiveRecord** | Rails ORM for database interactions |
| **Composition API** | Vue 3 API style using `<script setup>` |
| **Jbuilder** | Ruby library for building JSON views |
| **RSpec** | Ruby testing framework (BDD style) |
| **Vitest** | Vue.js testing framework (Vite-powered) |
| **Vuex** | State management library for Vue.js |
| **Sidekiq** | Background job processing library |
| **ActionCable** | Rails WebSocket framework |
| **Tailwind CSS** | Utility-first CSS framework |
| **i18n** | Internationalization (translations) |
| **MVC** | Model-View-Controller pattern |
| **Service Object** | Business logic extraction pattern |

### Appendix B: Decision Records

#### Decision 1: Use Composition API for All Vue Components

**Date**: 2025-10-06
**Context**: Transitioning from Options API to Composition API
**Decision**: All new Vue components must use Composition API (`<script setup>`)
**Rationale**: Better TypeScript support, better code organization, Vue 3 standard
**Consequences**: Existing Options API components will be gradually migrated

#### Decision 2: Tailwind CSS Only (No Custom CSS)

**Date**: 2025-10-06
**Context**: Need consistent styling across application
**Decision**: Only Tailwind utility classes allowed; no custom CSS, scoped styles, or inline styles
**Rationale**: Consistency, maintainability, no CSS conflicts
**Consequences**: All styling must use Tailwind utilities; custom designs require Tailwind configuration updates

### Appendix C: Additional Resources

**Chatwoot-Specific**:
- [Chatwoot Architecture Patterns](../ARCHITECTURE.md#development-patterns)
- [Chatwoot Enterprise Development](https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38)

---

**End of Document**
