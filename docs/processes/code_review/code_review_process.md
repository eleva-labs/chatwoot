# Code Review Process Guide

**Version**: 2.0.0
**Last Updated**: 2025-10-06
**Status**: Active
**Document Type**: Process Guide
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Overview

**Purpose**: Systematic analysis of branch/feature changes to identify gaps, inconsistencies, and architectural violations in Rails + Vue.js codebase.

**When to Use**:
- ✅ Branch refactorings, feature completions, pre-merge quality gates, architectural changes, full-stack features
- ❌ Simple typo fixes, doc-only changes, emergency hotfixes, i18n-only updates

**Process**: 4 phases, 70-170 minutes total

**Outputs**: Review plan, detailed findings report, action items

## Key Principles

1. **Systematic Analysis** - Methodical commit-by-commit review, document all findings
2. **Context-Aware** - Understand intent behind changes, review in relation to each other
3. **Rails MVC + Services Compliance** - Verify Rails conventions, service object patterns, event-driven architecture
4. **Full-Stack Completeness** - Check all affected components updated (Models, Services, Controllers, Jobs, Listeners, Vue Components, Vuex Store, i18n, Tests)
5. **Pattern Consistency** - Follow established Rails and Vue.js patterns
6. **Constructive Feedback** - Actionable findings with context and examples
7. **Enterprise Compatibility** - Verify Enterprise edition compatibility

## Process Workflow

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| **1. Commit History Analysis** | 15-30 min | Commit analysis summary |
| **2. Review Planning** | 10-20 min | Review plan with checklist |
| **3. Detailed Code Review** | 30-90 min | Findings log (tracked) |
| **4. Report Generation** | 15-30 min | Final review report |

**Prerequisites**: Git access, branch/commit range, CLAUDE.md understanding, ARCHITECTURE.md familiarity

## Phase 1: Commit History Analysis

**Objective**: Understand change progression

**Steps**:
1. **Review git log** - Analyze commits, identify patterns
   ```bash
   git log --oneline --graph development..HEAD
   git log --stat development..HEAD
   ```

2. **Map affected components** - Group by component type
   ```bash
   git diff --name-only development...HEAD
   git diff --stat development...HEAD
   ```

   **Component Categories**:
   - **Backend**: Models, Services, Controllers, Jobs, Listeners, Builders, Finders, Jbuilder views
   - **Frontend**: Vue components, Vuex store, API clients, i18n files
   - **Database**: Migrations
   - **Tests**: RSpec (backend), Vitest (frontend)
   - **Enterprise**: Enterprise overrides

3. **Identify change relationships** - Find cascading changes, potential gaps
   - Model changed → Migration exists?
   - Model field added → Controller strong params updated?
   - Model field added → Jbuilder view updated?
   - API changed → Vue component updated?
   - API changed → Vuex store updated?
   - API changed → API client updated?
   - Backend changed → Frontend i18n updated?
   - Backend changed → Both en.json and es.json updated?
   - Service object created → RSpec specs created?
   - Vue component created → Vitest tests created?
   - Core change → Enterprise compatibility checked?

**Deliverable**: `/docs/ignored/code_review/<branch_name>_commit_analysis.md`
```markdown
# Commit Analysis: <Branch>
- Total commits: X
- Categories: features, refactors, fixes
- Affected components: [Models, Services, Controllers, Vue, Vuex, i18n, Tests]
- Change relationships: [map]
- Areas for deep review: [list]
- Enterprise impact: [yes/no, details if yes]
```

## Phase 2: Review Planning

**Objective**: Create structured review plan

**Steps**:
1. **Define scope** - Prioritize: High (Models, Migrations, API), Medium (Services, Vue, Vuex), Low (docs, i18n)
2. **Create checklist** - Cover all components + cross-component + tests + patterns
3. **Define strategy** - Review order: Models → Migrations → Services → Controllers → Jobs → Listeners → Jbuilder → Vue → Vuex → i18n → Cross-component → Tests → Enterprise

**Review Checklist** (abbreviated):
- **Models**: Validations correct, associations correct, scopes appropriate, enums used properly, no business logic
- **Migrations**: Reversible, has default values, indexes added, foreign keys correct
- **Services**: Single responsibility, initialize + perform pattern, event dispatching, error handling
- **Controllers**: Thin controllers, use service objects, strong parameters, error handling with rescue blocks
- **Jobs**: Sidekiq job structure, perform method, error handling
- **Listeners**: Event handling correct, no business logic
- **Jbuilder**: camelCase JSON, all fields included, no snake_case in API responses
- **Vue Components**: Composition API with `<script setup>`, Tailwind CSS only (no custom CSS), i18n for all labels
- **Vuex Store**: Namespaced modules, actions for async, mutations for state, getters for computed
- **API Clients**: Axios usage, error handling, matches controller endpoints
- **i18n**: BOTH en.json AND es.json updated, keys follow convention
- **Cross-Component**: Model change → Migration + Jbuilder + Vue + Vuex + i18n updated
- **Tests**: RSpec for backend (models, services, requests, jobs), Vitest for frontend (components, store)
- **Patterns**: Rails conventions, Vue.js patterns, naming conventions, code style (RuboCop + ESLint)
- **Enterprise**: No Enterprise overrides broken, Enterprise-compatible changes

**Deliverable**: `/docs/ignored/code_review/<branch_name>_review_plan.md` with checklist and progress tracking

## Phase 3: Detailed Code Review

**Objective**: Execute review, identify gaps/issues

**Key Review Areas**:

### 1. Models Layer
```bash
git diff development...HEAD -- app/models/
```

**Check**:
- Associations correct? (`belongs_to`, `has_many`, `has_one`)
- Validations present? (`validates :field, presence: true`)
- Enums used properly? (`enum status: { active: 0, inactive: 1 }`)
- Scopes appropriate? (`scope :active, -> { where(status: :active) }`)
- No business logic? (should be in services)
- Callbacks minimal? (prefer service objects for complex logic)

**Example Finding**:
```
⚠️ MAJOR: app/models/store.rb:15
Missing validation for priority field
Impact: Could allow invalid priority values
Fix: Add `validates :priority, presence: true, inclusion: { in: priorities.keys }`
```

### 2. Migrations
```bash
git diff development...HEAD -- db/migrate/
```

**Check**:
- Migration reversible? (`def change` or explicit `up`/`down`)
- Default values provided? (`default: 1, null: false`)
- Indexes added for foreign keys and frequently queried fields?
- Column types appropriate?
- No data manipulation in schema migrations? (use separate data migration if needed)

**Example Finding**:
```
🚨 CRITICAL: db/migrate/20251006120000_add_priority_to_stores.rb:5
Migration missing index on priority field
Impact: Slow queries when filtering by priority
Fix: Add `add_index :stores, :priority`
```

### 3. Services Layer
```bash
git diff development...HEAD -- app/services/
```

**Check**:
- Service object pattern? (`initialize` + `perform` methods)
- Single responsibility?
- Event dispatching present? (`Rails.configuration.dispatcher.dispatch`)
- Error handling? (raise appropriate exceptions)
- No direct controller concerns?

**Example Finding**:
```
⚠️ MAJOR: app/services/stores/update_priority_service.rb:10
Service doesn't dispatch STORE_PRIORITY_UPDATED event
Impact: Listeners won't trigger, breaking event-driven flow
Fix: Add dispatcher.dispatch call in perform method
```

### 4. Controllers
```bash
git diff development...HEAD -- app/controllers/api/
```

**Check**:
- Thin controllers? (delegate to service objects)
- Strong parameters correct? (`params.permit(:field1, :field2)`)
- Error handling with rescue blocks?
- HTTP status codes appropriate? (`:created`, `:ok`, `:unprocessable_entity`)
- Render Jbuilder views (not raw JSON)?

**Example Finding**:
```
⚠️ MAJOR: app/controllers/api/v1/accounts/stores_controller.rb:25
Controller has business logic instead of using service object
Impact: Violates thin controller pattern, harder to test
Fix: Extract logic to Stores::UpdatePriorityService
```

### 5. Jobs Layer
```bash
git diff development...HEAD -- app/jobs/
```

**Check**:
- Sidekiq job structure? (`< ApplicationJob`)
- `perform` method signature correct?
- Error handling for external services?
- Idempotent operations?

### 6. Listeners Layer
```bash
git diff development...HEAD -- app/listeners/
```

**Check**:
- Listener inherits from `BaseListener`?
- Event handler methods match event names?
- No complex business logic? (trigger jobs instead)

### 7. Jbuilder Views
```bash
git diff development...HEAD -- app/views/api/
```

**Check**:
- camelCase field names? (`json.priorityLabel` not `json.priority_label`)
- All new model fields included?
- No sensitive data exposed?
- Consistent structure with other views?

**Example Finding**:
```
🚨 CRITICAL: app/views/api/v1/accounts/stores/show.json.jbuilder:5
Using snake_case (priority_label) instead of camelCase
Impact: Frontend expects camelCase, will break API contract
Fix: Change to `json.priorityLabel @store.priority.humanize`
```

### 8. Vue Components
```bash
git diff development...HEAD -- app/javascript/dashboard/components/
```

**Check**:
- Composition API with `<script setup>`? (not Options API)
- Tailwind CSS only? (no custom CSS, no scoped styles, no inline styles)
- i18n for all user-facing text? (`{{ t('KEY') }}`)
- Props validated with PropTypes?
- Emits declared?
- No business logic? (in Vuex actions instead)

**Example Finding**:
```
⚠️ MAJOR: app/javascript/dashboard/components/StorePriorityBadge.vue:15
Using inline styles instead of Tailwind CSS
Impact: Violates project styling standards
Fix: Replace `style="color: red"` with Tailwind class `text-red-600`
```

### 9. Vuex Store
```bash
git diff development...HEAD -- app/javascript/dashboard/store/modules/
```

**Check**:
- Namespaced module? (`namespaced: true`)
- Actions for async operations (API calls)?
- Mutations for state changes only?
- Getters for computed state?
- No direct state mutations in actions?

**Example Finding**:
```
⚠️ MAJOR: app/javascript/dashboard/store/modules/stores.js:45
Action mutating state directly instead of using mutation
Impact: Breaks Vuex pattern, harder to debug state changes
Fix: Use `commit('SET_STORE_PRIORITY', payload)` instead of direct mutation
```

### 10. API Clients
```bash
git diff development...HEAD -- app/javascript/dashboard/api/
```

**Check**:
- Methods match controller endpoints?
- Axios usage correct?
- Error handling present?
- Returns promises?

### 11. i18n Files
```bash
git diff development...HEAD -- app/javascript/dashboard/i18n/locale/
git diff development...HEAD -- config/locales/
```

**Check**:
- **BOTH** en.json AND es.json updated? (frontend)
- **BOTH** en.yml AND es.yml updated? (backend)
- Keys follow convention? (`RESOURCE.SECTION.KEY`)
- Translations accurate?
- No hardcoded strings in components?

**Example Finding**:
```
🚨 CRITICAL: i18n translations incomplete
Found updates to en.json but es.json not updated
Impact: Spanish users will see English text
Fix: Add Spanish translations for STORES.PRIORITY.* keys
```

### 12. Cross-Component Completeness

For each model field change, verify complete propagation:

**Checklist for Field Addition**:
- [ ] Model updated (with validation, enum if applicable)
- [ ] Migration created (with index if needed)
- [ ] Controller strong params updated
- [ ] Jbuilder view updated (camelCase)
- [ ] Vue component updated (display field)
- [ ] Vuex store updated (if stateful)
- [ ] API client updated (if new endpoint)
- [ ] i18n updated (en + es, both JSON and YML)
- [ ] Tests updated (RSpec + Vitest)
- [ ] Enterprise checked (no conflicts)

**Example Finding**:
```
🚨 CRITICAL: Incomplete cross-component update
Added `priority` field to Store model but:
- ❌ Jbuilder view not updated (API won't return field)
- ❌ Vue component not updated (UI won't display field)
- ❌ i18n not updated (labels missing)
- ✅ Migration present
- ✅ Model validation present
Fix: Update Jbuilder, Vue component, and i18n files
```

### 13. Test Coverage
```bash
git diff development...HEAD -- spec/
git diff development...HEAD -- app/javascript/dashboard/**/__tests__/
```

**Backend (RSpec)**:
- [ ] Model specs for validations, associations, scopes
- [ ] Service specs for business logic, event dispatching
- [ ] Request specs for API endpoints
- [ ] Job specs for background jobs
- [ ] Listener specs for event handling

**Frontend (Vitest)**:
- [ ] Component specs for rendering, user interactions
- [ ] Store specs for Vuex actions, mutations, getters

**Check**:
- New/modified tests present?
- Edge cases covered?
- Error scenarios tested?
- Mocking appropriate? (factories, stubs)
- Test coverage adequate (≥80% for changed files)?

**Example Finding**:
```
⚠️ MAJOR: Missing tests for new service
app/services/stores/update_priority_service.rb created without spec
Impact: No test coverage for business logic
Fix: Create spec/services/stores/update_priority_service_spec.rb
```

### 14. Patterns & Code Style

**Rails Patterns**:
- [ ] Service objects follow initialize + perform pattern
- [ ] Controllers are thin
- [ ] Models have minimal callbacks
- [ ] Event dispatching used for cross-cutting concerns
- [ ] Error handling consistent

**Vue.js Patterns**:
- [ ] Composition API everywhere
- [ ] Tailwind CSS only (no custom CSS)
- [ ] i18n for all text
- [ ] Props/emits declared

**Code Style**:
- [ ] RuboCop passes (backend)
- [ ] ESLint passes (frontend)
- [ ] No console.log statements
- [ ] No commented-out code

**Example Finding**:
```
💡 MINOR: app/services/stores/create_service.rb:25
Using instance variable instead of local variable
Impact: Minor style inconsistency
Fix: Change `@store` to local `store` where not needed as instance var
```

### 15. Enterprise Compatibility

```bash
git diff development...HEAD -- enterprise/
rg -n "ClassName" app enterprise
```

**Check**:
- [ ] No Enterprise overrides broken?
- [ ] Changes compatible with Enterprise edition?
- [ ] No hardcoded logic that Enterprise needs to customize?
- [ ] Enterprise-specific tests updated if needed?

**Example Finding**:
```
🚨 CRITICAL: Breaking Enterprise override
app/models/store.rb changes conflict with enterprise/app/models/store.rb
Impact: Enterprise edition will break
Fix: Update Enterprise override or use prepend_mod_with pattern
```

**Document Findings** (by severity):
- 🚨 **Critical**: Must fix before merge (breaking changes, data loss, API contract violations)
- ⚠️ **Major**: Should fix before merge (pattern violations, missing tests, incomplete features)
- 💡 **Minor**: Can defer (style issues, minor optimizations, documentation)

**Deliverable**: Update `/docs/ignored/code_review/<branch_name>_review_plan.md` with findings

## Phase 4: Report Generation

**Objective**: Compile actionable final report

**Steps**:
1. **Categorize findings** - Group by severity (critical, major, minor) and type (gaps, violations, inconsistencies)
2. **Create executive summary** - Overall assessment, strengths, critical issues, go/no-go recommendation
3. **Document detailed findings** - Each issue with: severity, location (file:line), description, impact, evidence, fix
4. **Generate action items** - Prioritized tasks: Must Do (critical), Should Do (major), Can Defer (minor) with effort estimates
5. **Add metadata** - Files reviewed, metrics, sign-off section

**Report Template Structure**:
```markdown
# Code Review Report: <Branch>

## Executive Summary
- Overall: ✅ PASS / ⚠️ CONDITIONAL PASS / ❌ FAIL
- Strengths: [list]
- Critical issues: [list]
- Recommendation: [go/no-go with rationale]

## Findings Summary
- Total: X (Y critical, Z major, W minor)
- By type: gaps, violations, inconsistencies
- By component: models, services, controllers, vue, vuex, tests, i18n

## Detailed Findings
### 🚨 Critical (must fix before merge)
[Each with: location, description, impact, evidence code, fix]

### ⚠️ Major (should fix)
[Same structure]

### 💡 Minor (can defer)
[Same structure]

## Action Items
- Must Do (X hours): [tasks with owners, files, steps]
- Should Do (Y hours): [tasks]
- Can Defer (Z hours): [tasks]

## Metadata
- Files reviewed: X backend, Y frontend, Z tests
- Lines: +A/-B
- Metrics: test coverage %, RuboCop compliance, ESLint compliance
- Sign-off: Reviewer, approvals needed
```

**Deliverable**: `/docs/ignored/code_review/<branch_name>_review_report.md`

## Best Practices

**For Reviewers**:
- ✅ Be systematic, provide context/evidence, be constructive, think full-stack
- ✅ Use git diff, Grep/Glob effectively, document everything
- ✅ Check both backend and frontend, verify i18n completeness (en + es)
- ✅ Run RuboCop and ESLint to catch style issues
- ✅ Verify Enterprise compatibility
- ❌ Don't be vague, skip cross-component checks, ignore patterns, rush conclusions
- ❌ Don't forget frontend implications of backend changes
- ❌ Don't skip i18n verification

**For Authors**:
- ✅ Write clear commits (no Claude references), keep atomic, update tests, be receptive to feedback
- ✅ Update BOTH en and es for i18n changes
- ✅ Run RuboCop and ESLint before submitting
- ✅ Check Enterprise compatibility if applicable
- ❌ Don't take feedback personally, ignore findings, merge with critical issues

**General**:
- Schedule focused time (70-170 min), take breaks for long reviews
- Encourage dialogue, use findings as discussion points
- Track common issues, refine templates over time
- Use pair review for complex full-stack changes

## Quick Checklist

**Setup**: Branch identified, tools ready, time allocated (70-170 min)

**Phase 1**: ✅ Git log → commits categorized → components mapped (backend + frontend) → relationships identified → Enterprise impact assessed → summary created

**Phase 2**: ✅ Scope defined → checklist created (models, services, controllers, jobs, listeners, jbuilder, vue, vuex, i18n, tests, enterprise) → strategy documented → tracking setup

**Phase 3**: ✅ Review all components (models, migrations, services, controllers, jobs, listeners, jbuilder, vue, vuex, api clients, i18n) → cross-component completeness → tests (RSpec + Vitest) → patterns (Rails + Vue.js) → code style (RuboCop + ESLint) → enterprise compatibility → document findings

**Phase 4**: ✅ Categorize findings → executive summary → detailed report → action items → metadata → deliver

**Completion**: Report delivered, critical issues flagged, re-review if needed

## Templates

### Template Locations

**Process Templates** (committed to repo):
- **Commit Analysis Template**: `/docs/processes/code_review/COMMIT_ANALYSIS_TEMPLATE.md`
- **Review Plan Template**: `/docs/processes/code_review/REVIEW_PLAN_TEMPLATE.md`
- **Review Report Template**: `/docs/processes/code_review/REVIEW_REPORT_TEMPLATE.md`

**Runtime Documents** (created in `/docs/ignored/code_review/`):
- Commit Analysis: `<branch>_commit_analysis.md`
- Review Plan: `<branch>_review_plan.md`
- Final Report: `<branch>_review_report.md`

---

### 1. Commit Analysis Template

**Template**: `/docs/processes/code_review/COMMIT_ANALYSIS_TEMPLATE.md`
**Runtime Location**: `/docs/ignored/code_review/<branch>_commit_analysis.md`

**Key Sections**:
- Commits: total, categories (features/refactors/fixes)
- Affected components: models, services, controllers, jobs, vue, vuex, i18n, tests
- Change relationships
- Areas for review
- Potential issues identified
- Enterprise impact
- Review strategy

---

### 2. Review Plan Template

**Template**: `/docs/processes/code_review/REVIEW_PLAN_TEMPLATE.md`
**Runtime Location**: `/docs/ignored/code_review/<branch>_review_plan.md`

**Key Sections**:
- Scope: in/out, prioritized
- Checklist: models, migrations, services, controllers, jobs, listeners, jbuilder, vue, vuex, api clients, i18n, cross-component, tests, patterns, enterprise
- Strategy: review order, approach
- Progress tracking with findings log
- Blockers and questions

---

### 3. Review Report Template

**Template**: `/docs/processes/code_review/REVIEW_REPORT_TEMPLATE.md`
**Runtime Location**: `/docs/ignored/code_review/<branch>_review_report.md`

**Key Sections**:
- Executive summary: overall assessment, go/no-go
- Findings: critical/major/minor with location, evidence, fix
- Action items: must do/should do/can defer
- Metadata: files reviewed (backend + frontend), metrics, sign-off

---

### Example Workflow

```
5 commits: 2 features, 2 refactors, 1 fix
→ Affected: Models (Store), Services (UpdatePriorityService), Controllers (StoresController), Vue (StorePriorityBadge), Vuex (stores.js), i18n (en + es)
→ GAPS FOUND:
  - Missing Jbuilder camelCase field (critical)
  - Missing Vitest component test (major)
  - Spanish i18n missing (critical)
```

## Troubleshooting

**Too Many Commits**: Group by theme (`git log --grep`), focus on key commits touching critical files, or request squashing/rebasing

**Unclear Commit Messages**: Read diffs to infer intent (`git show <sha>`), ask author for clarification

**Missing Cross-Component Changes**: Use systematic checklist (model → migration → controller → jbuilder → vue → vuex → i18n → tests), search for field references with Grep

**Frontend Not Updated**: Always check `git diff` for Vue, Vuex, and i18n changes when backend changes, ask "Does this need UI?"

**i18n Incomplete**: Check both en.json and es.json (and en.yml/es.yml), verify all new UI text has translations

**Enterprise Conflicts**: Search `enterprise/` directory with `rg -n "ClassName" app enterprise`, ask author about Enterprise compatibility

**Intentional vs Accidental Gaps**: Mark as question not issue, review related docs/comments, ask author

**Review Fatigue**: Take breaks (45-min chunks), split review across sessions, get second reviewer for complex full-stack reviews

## Quick Reference

**Git Commands**:
```bash
# Commit analysis
git log --oneline --graph development..HEAD
git log --stat development..HEAD

# File changes
git diff --name-only development...HEAD
git diff --stat development...HEAD

# Diffs
git diff development...HEAD -- app/models/
git diff development...HEAD -- app/javascript/dashboard/components/
git show <commit-sha>

# Search
git log -p -S "search_term" development..HEAD
git log --grep="pattern" development..HEAD
```

**Search Patterns**:
```bash
# Models
Glob: "app/models/**/*.rb"
Grep: "class.*ApplicationRecord"

# Services
Glob: "app/services/**/*.rb"
Grep: "def perform"

# Controllers
Glob: "app/controllers/api/**/*.rb"
Grep: "class.*Controller"

# Vue Components
Glob: "app/javascript/dashboard/components/**/*.vue"
Grep: "<script setup>"

# Vuex Store
Glob: "app/javascript/dashboard/store/modules/**/*.js"
Grep: "namespaced: true"

# i18n
Glob: "app/javascript/dashboard/i18n/locale/{en,es}.json"
Glob: "config/locales/{en,es}.yml"

# Tests - Backend
Glob: "spec/**/*_spec.rb"
Grep: "RSpec.describe"

# Tests - Frontend
Glob: "app/javascript/dashboard/**/__tests__/**/*.spec.js"
Grep: "describe.*Component"

# Migrations
Glob: "db/migrate/**/*.rb"
Grep: "def change"

# Enterprise
Glob: "enterprise/app/**/*.rb"
Grep: "prepend_mod_with"
```

**Code Quality Commands**:
```bash
# Backend linting
bundle exec rubocop -a

# Frontend linting
pnpm eslint:fix

# Backend tests
bundle exec rspec

# Frontend tests
pnpm test
```

**Review Checklist** (30 min minimum):
- Models (5 min): Associations, validations, enums, scopes, no business logic
- Migrations (5 min): Reversible, defaults, indexes
- Services (5 min): SRP, perform method, event dispatching
- Controllers (5 min): Thin, strong params, error handling
- Jbuilder (3 min): camelCase, complete fields
- Vue Components (5 min): Composition API, Tailwind only, i18n
- Vuex Store (3 min): Actions/mutations/getters pattern
- i18n (5 min): en + es updated (JSON + YML)
- Cross-Component (5 min): Model → Migration + Jbuilder + Vue + Vuex + i18n
- Tests (7 min): RSpec + Vitest coverage adequate
- Enterprise (2 min): No conflicts, compatibility verified

## Related Documentation

### Internal Documentation

**Process Documentation**:
- [Research Process](/docs/processes/design/research_and_design_process.md) - For initial feature research
- [Development Process](/docs/processes/development/development_process.md) - Full development workflow
- [API Testing Process](/docs/processes/tests/api_testing_process.md) - API testing procedures

**Technical Documentation**:
- [CLAUDE.md](/CLAUDE.md) - Project guidelines and commands
- [ARCHITECTURE.md](/docs/ARCHITECTURE.md) - System architecture overview
- [README.md](/README.md) - Project overview and setup

**Templates**:
- [Process Template](/docs/processes/process_template.md) - Template for creating new processes
- [Research Template](/docs/processes/design/RESEARCH_TEMPLATE.md) - Research report template
- [Design Template](/docs/processes/design/DESIGN_TEMPLATE.md) - Design document template

### External Resources

- [Git Diff Documentation](https://git-scm.com/docs/git-diff) - Official git diff reference
- [Rails Guides](https://guides.rubyonrails.org/) - Official Rails documentation
- [Vue.js 3 Documentation](https://vuejs.org/) - Vue.js official docs
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message standards
- [Code Review Best Practices](https://google.github.io/eng-practices/review/) - Google's engineering practices
- [Chatwoot Enterprise Development](https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38) - Enterprise edition practices

---

## Changelog

### Version 2.0.0 (2025-10-06)

**Status**: Active

**Changes**:
- **Major Update**: Adapted for Chatwoot (Rails + Vue.js) from Python/FastAPI
- Updated all references from Clean Architecture layers to Rails MVC + Services + Vue.js components
- Added full-stack review requirements (backend + frontend)
- Updated component categories: Models, Services, Controllers, Jobs, Listeners, Jbuilder, Vue, Vuex, i18n, Tests
- Added Enterprise compatibility checks
- Updated code examples to Ruby and Vue.js
- Added i18n verification (en.json + es.json, en.yml + es.yml)
- Updated testing sections (RSpec + Vitest)
- Added cross-component completeness checklist for full-stack features
- Updated search patterns for Rails and Vue.js files
- Added code quality commands (RuboCop + ESLint)
- Updated troubleshooting for full-stack issues

### Version 1.0.0 (2025-10-04)

**Status**: Superseded

**Changes**:
- Initial version (Python/FastAPI)
- Defined 4-phase review workflow
- Created comprehensive checklists for all layers
- Added templates for commit analysis, review plan, and final report
- Included examples for simple and complex reviews
- Added troubleshooting section for common review challenges
- Created quick reference for git commands and search patterns
- Defined best practices for reviewers and code authors
- Integrated with existing development process workflow

**Migration Notes**:
- Previous version focused on Clean Architecture layers (Domain/Application/Infrastructure)
- New version focuses on Rails MVC + Services + Vue.js components
- Update existing review templates to use new component categories
- Add frontend review steps to existing review processes

---

## Document Metadata

**Document Owner**: Development Team

**Maintained By**: Claude Code + Human Engineers

**Review Cycle**: Quarterly or after significant process changes

**Last Reviewed**: 2025-10-06

**Next Review Due**: 2026-01-06

**Technology Stack**: Ruby on Rails 7.1+ | Vue.js 3 | PostgreSQL | Redis | Tailwind CSS

**Contact**: Development team channel for questions and feedback

---

**End of Document**
