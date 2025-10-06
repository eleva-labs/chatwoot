# Code Review - Review Plan
## [Branch Name]

**Review ID**: <unique_id>
**Branch**: `<branch_name>`
**Base Branch**: `development` | `main`
**Created**: YYYY-MM-DD HH:MM:SS
**Started**: Not started | YYYY-MM-DD HH:MM:SS
**Completed**: In Progress | YYYY-MM-DD HH:MM:SS
**Reviewer**: [Name/Agent]
**Status**: Not Started | In Progress | Completed | Blocked

**Related Documents**:
- [Commit Analysis](/docs/ignored/code_review/<branch_name>_commit_analysis.md)

> **Note on Diagrams**: When including diagrams in this review plan, use simple mermaid snippets to visualize review scope, component relationships, and review flow.

---

## Review Overview

### Branch Summary
- **Total Commits**: X commits
- **Files Changed**: X files
- **Lines Changed**: +XXX / -XXX
- **Review Complexity**: Low | Medium | High
- **Estimated Review Time**: XX minutes

### Key Changes
1. [Major change 1 - e.g., Added new Store entity field]
2. [Major change 2 - e.g., Refactored config factory]
3. [Major change 3 - e.g., Updated API schemas]

---

## Review Scope

### In Scope

**Backend Changes**:
- ✅ Model modifications (validations, associations, scopes)
- ✅ Service object changes (business logic)
- ✅ Controller changes (endpoints, strong params)
- ✅ Job & listener changes (background processing, events)
- ✅ Jbuilder views (API responses, camelCase)
- ✅ Database migrations (schema changes)

**Frontend Changes**:
- ✅ Vue.js components (Composition API)
- ✅ Vuex store modules (state management)
- ✅ i18n updates (en.json + es.json)
- ✅ Tailwind CSS usage (no custom CSS)

**Cross-Cutting Concerns**:
- ✅ Architecture compliance (Rails MVC + Services)
- ✅ Code quality and patterns
- ✅ Error handling
- ✅ Backward compatibility
- ✅ Security implications
- ✅ Enterprise compatibility

**Testing**:
- ✅ RSpec test coverage (backend)
- ✅ Vitest test coverage (frontend)

**Documentation**:
- ✅ Inline code comments
- ✅ API documentation
- ✅ Design documents (if applicable)

---

### Out of Scope

**Excluded from This Review**:
- ❌ Performance optimization (unless critical issue found)
- ❌ UI/UX design decisions (focus on implementation)
- ❌ Deployment configuration (unless relevant to code)
- ❌ External integrations (unless modified)
- ❌ [Other exclusions specific to this review]

**Reason for Exclusions**: [Brief explanation]

---

### Prioritized Areas

**Priority 1 - Must Review Thoroughly** (XX min):
1. [Area 1] - Critical business logic changes (Service objects)
2. [Area 2] - Database schema modifications (Migrations)
3. [Area 3] - API contract changes (Controllers + Jbuilder)

**Priority 2 - Should Review** (XX min):
1. [Area 1] - Refactorings (Service extractions, model simplifications)
2. [Area 2] - New features (Full-stack changes)
3. [Area 3] - Event-driven changes (Listeners + Jobs)

**Priority 3 - Quick Scan** (XX min):
1. [Area 1] - Test updates (RSpec + Vitest)
2. [Area 2] - i18n changes (en.json + es.json)
3. [Area 3] - Documentation changes

---

## Review Checklist

### Backend - Models Review

**Files to Review** (X files):
- [ ] `app/models/model1.rb`
- [ ] `app/models/model2.rb`
- [ ] `app/models/concerns/concern1.rb`

**Review Points**:
- [ ] **Validations**: Presence, uniqueness, format validations correct
- [ ] **Associations**: has_many, belongs_to, has_one properly defined
- [ ] **Scopes**: Scopes are reusable and well-named
- [ ] **Enums**: Enums used for fixed value fields
- [ ] **Callbacks**: Callbacks justified and side-effect free
- [ ] **Business Logic**: Complex logic delegated to service objects
- [ ] **Dependencies**: No controller/view dependencies

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Backend - Services Review

**Files to Review** (X files):
- [ ] `app/services/domain/action_service.rb`
- [ ] `app/services/domain/update_service.rb`

**Review Points**:
- [ ] **Single Responsibility**: Each service has single, clear purpose
- [ ] **Initialize + Perform**: Standard pattern followed
- [ ] **Error Handling**: Exceptions properly raised
- [ ] **Return Values**: Services return models, not hashes
- [ ] **Business Logic**: Complex logic encapsulated
- [ ] **Side Effects**: Events dispatched for side effects

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Backend - Controllers Review

**Files to Review** (X files):
- [ ] `app/controllers/api/v1/accounts/resource_controller.rb`
- [ ] `app/controllers/public/resource_controller.rb`

**Review Points**:
- [ ] **Strong Parameters**: Strong params defined and used
- [ ] **Authorization**: Authorization checks in place
- [ ] **HTTP Status Codes**: Correct status codes (200, 201, 204, 404, 422)
- [ ] **Error Handling**: Errors properly rescued and formatted
- [ ] **Service Delegation**: Logic delegated to service objects
- [ ] **Response Format**: JSON responses via Jbuilder

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Backend - Jbuilder Views Review

**Files to Review** (X files):
- [ ] `app/views/api/v1/accounts/resources/show.json.jbuilder`
- [ ] `app/views/api/v1/accounts/resources/index.json.jbuilder`

**Review Points**:
- [ ] **camelCase**: All keys in camelCase (not snake_case)
- [ ] **Completeness**: All necessary fields included
- [ ] **Consistency**: Response structure consistent across endpoints
- [ ] **Associations**: Nested resources properly rendered
- [ ] **Pagination**: Pagination metadata in `meta` key (if applicable)

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Backend - Migrations Review

**Files to Review** (X files):
- [ ] `db/migrate/YYYYMMDDHHMMSS_migration_name.rb`

**Review Points**:
- [ ] **Reversibility**: Migration can be rolled back
- [ ] **Indexes**: Indexes added for foreign keys and query columns
- [ ] **Data Safety**: Existing data handled correctly
- [ ] **Null Constraints**: null: false used appropriately
- [ ] **Defaults**: Default values set where needed

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Backend - Jobs & Listeners Review

**Files to Review** (X files):
- [ ] `app/jobs/domain/action_job.rb`
- [ ] `app/listeners/resource_listener.rb`

**Review Points**:
- [ ] **Queue Names**: Correct queue assigned
- [ ] **Retry Logic**: Retry strategy appropriate
- [ ] **Error Handling**: Errors logged and handled
- [ ] **Idempotency**: Jobs are idempotent where possible
- [ ] **Event Handling**: Listeners properly registered

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Frontend - Vue Components Review

**Files to Review** (X files):
- [ ] `app/javascript/dashboard/components/ComponentName.vue`

**Review Points**:
- [ ] **Composition API**: Uses `<script setup>` exclusively
- [ ] **Tailwind CSS**: Only Tailwind utilities (no custom CSS)
- [ ] **No Scoped CSS**: No `<style scoped>` blocks
- [ ] **i18n**: All strings use `$t()` or `t()` from useI18n
- [ ] **Props**: Props properly typed with PropTypes
- [ ] **Emits**: Events properly defined and emitted

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Frontend - Vuex Store Review

**Files to Review** (X files):
- [ ] `app/javascript/dashboard/store/modules/stores.js`

**Review Points**:
- [ ] **Namespaced**: Module is namespaced
- [ ] **State**: State structure is flat and minimal
- [ ] **Getters**: Getters for computed state
- [ ] **Actions**: Actions for async operations (API calls)
- [ ] **Mutations**: Mutations for state changes only
- [ ] **API Integration**: API calls properly handled

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Frontend - i18n Review

**Files to Review** (X files):
- [ ] `app/javascript/dashboard/i18n/locale/en.json`
- [ ] `app/javascript/dashboard/i18n/locale/es.json`

**Review Points**:
- [ ] **Both Languages**: BOTH en.json and es.json updated
- [ ] **Key Structure**: Keys follow existing structure
- [ ] **Completeness**: All new strings translated
- [ ] **No Bare Strings**: No hardcoded strings in components

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Cross-Component Completeness

**Full-Stack Change Verification**:

**Change 1: [Model field added/modified]**
- [ ] ✅ Model updated (`model.rb`)
- [ ] ✅ Migration created (`db/migrate/*.rb`)
- [ ] ✅ Controller strong params updated (`controller.rb`)
- [ ] ✅ Jbuilder view updated (`show.json.jbuilder`)
- [ ] ✅ Vue component updated (`ComponentName.vue`)
- [ ] ✅ Vuex store updated (if stateful) (`stores.js`)
- [ ] ✅ i18n updated (en + es) (`en.json`, `es.json`)
- [ ] ✅ Tests added (RSpec + Vitest)
- [ ] ✅ Enterprise checked (`enterprise/app/models/`)

**Change 2: [New endpoint added]**
- [ ] ✅ Controller action implemented (`controller.rb`)
- [ ] ✅ Service object created (`service.rb`)
- [ ] ✅ Jbuilder view created (`show.json.jbuilder`)
- [ ] ✅ Routes updated (`routes.rb`)
- [ ] ✅ Vue component created (if needed) (`ComponentName.vue`)
- [ ] ✅ Vuex action created (if needed) (`stores.js`)
- [ ] ✅ API client method added (`api.js`)
- [ ] ✅ Tests: RSpec request specs (`requests/api/v1/*_spec.rb`)
- [ ] ✅ Tests: Vitest component tests (`__tests__/*.spec.js`)

**Change 3: [Event-driven change]**
- [ ] ✅ Event dispatched (`service.rb`)
- [ ] ✅ Listener created/updated (`listener.rb`)
- [ ] ✅ Job created/updated (`job.rb`)
- [ ] ✅ Tests: Listener specs (`spec/listeners/*_spec.rb`)
- [ ] ✅ Tests: Job specs (`spec/jobs/*_spec.rb`)

**Change 4: [Other significant change]**
- [ ] [Checklist items specific to this change]

---

### Test Coverage Review

**Backend Tests (RSpec)** (X files):
- [ ] `spec/models/model_spec.rb`
- [ ] `spec/services/service_spec.rb`
- [ ] `spec/requests/api/v1/accounts/resources_spec.rb`
- [ ] `spec/jobs/job_spec.rb`
- [ ] `spec/listeners/listener_spec.rb`

**Frontend Tests (Vitest)** (X files):
- [ ] `app/javascript/dashboard/components/__tests__/ComponentName.spec.js`
- [ ] `app/javascript/dashboard/store/__tests__/stores.spec.js`

**Review Points**:
- [ ] **New Tests**: Tests exist for new functionality
- [ ] **Modified Tests**: Existing tests updated for changes
- [ ] **Test Quality**: Tests are clear and maintainable
- [ ] **Edge Cases**: Edge cases and error scenarios tested
- [ ] **Coverage**: Adequate coverage for critical paths (≥80%)
- [ ] **Test Patterns**: Tests follow project conventions
- [ ] **Factories**: Proper use of FactoryBot (backend)
- [ ] **Mocks**: Appropriate use of mocks/stubs

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

### Code Quality & Patterns

**Review Points**:
- [ ] **Naming Conventions**: Variables, methods, classes follow Ruby/JS conventions
- [ ] **Ruby Style**: RuboCop compliant (150 char max line length)
- [ ] **JavaScript Style**: ESLint compliant (Airbnb + Vue 3)
- [ ] **Code Duplication**: No unnecessary duplication
- [ ] **SOLID Principles**: Code follows SOLID principles
- [ ] **Error Messages**: Clear, actionable error messages
- [ ] **Comments**: Inline comments where logic is complex
- [ ] **Service Objects**: Follow initialize + perform pattern
- [ ] **Vue API**: Composition API with `<script setup>` only
- [ ] **Tailwind Only**: No custom CSS, no scoped styles

**Notes/Findings**:
```
[Document any issues or observations here]
```

---

## Review Strategy

### Review Approach

**Phase 1: Backend Foundation** (XX min)
1. Review model changes (validations, associations, scopes)
2. Verify migrations exist and are reversible
3. Check service object implementations
4. Verify event dispatching (if applicable)

**Phase 2: API & Views** (XX min)
1. Review controller actions and strong params
2. Verify Jbuilder views (camelCase!)
3. Check HTTP status codes
4. Verify error handling

**Phase 3: Frontend** (XX min)
1. Review Vue components (Composition API + Tailwind)
2. Check Vuex store changes
3. Verify i18n (en + es)
4. Check API client integration

**Phase 4: Tests & Cross-Component** (XX min)
1. Verify RSpec coverage (backend)
2. Verify Vitest coverage (frontend)
3. Check cross-component completeness
4. Validate Enterprise compatibility

---

### Session Planning

**Session 1** (45 min):
- [ ] Models review
- [ ] Migrations review
- [ ] Services review

**Session 2** (40 min):
- [ ] Controllers review
- [ ] Jbuilder views review
- [ ] Jobs & listeners review

**Session 3** (35 min):
- [ ] Vue components review
- [ ] Vuex store review
- [ ] i18n review

**Session 4** (25 min):
- [ ] RSpec tests review
- [ ] Vitest tests review
- [ ] Cross-component validation
- [ ] Enterprise compatibility

---

## Findings Log

### Session 1 - [Date/Time]

**Duration**: XX minutes
**Areas Reviewed**: [List]

**Findings**:

#### 🔴 Critical Issues
1. **[Issue Title]** - `file.py:line`
   - **Description**: [What's wrong]
   - **Impact**: [Why it's critical]
   - **Recommendation**: [How to fix]

#### 🟡 Major Issues
1. **[Issue Title]** - `file.py:line`
   - **Description**: [What's wrong]
   - **Impact**: [Why it's important]
   - **Recommendation**: [How to fix]

#### 💡 Minor Issues / Suggestions
1. **[Suggestion Title]** - `file.py:line`
   - **Description**: [What could be better]
   - **Recommendation**: [How to improve]

---

### Session 2 - [Date/Time]

**Duration**: XX minutes
**Areas Reviewed**: [List]

**Findings**:
[Same structure as Session 1]

---

### Session 3 - [Date/Time]

**Duration**: XX minutes
**Areas Reviewed**: [List]

**Findings**:
[Same structure as Session 1]

---

## Progress Tracking

### Completion Status

| Area | Status | Findings | Notes |
|------|--------|----------|-------|
| Models | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Migrations | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Services | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Controllers | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Jbuilder | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Jobs & Listeners | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Vue Components | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Vuex Store | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| i18n | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| RSpec Tests | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Vitest Tests | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Cross-Component | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |
| Code Quality | ⬜ Not Started / 🟡 In Progress / ✅ Complete | X issues | [Notes] |

**Overall Progress**: [✅✅✅░░░░░░░░░░] 3/13 (23%)

---

### Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| 🔴 Critical | X | X open, X resolved |
| 🟡 Major | X | X open, X resolved |
| 💡 Minor | X | X open, X resolved |
| **Total** | **X** | **X open, X resolved** |

---

## Blockers & Questions

### Blockers

**Blocker 1: [Title]**
- **Description**: [What's blocking the review]
- **Impact**: [Why this blocks review completion]
- **Status**: Open | Resolved
- **Resolution**: [How it was resolved]

---

### Questions for Author

**Question 1: [Question]**
- **Context**: [Where/why this question arose]
- **Location**: `file.py:line`
- **Asked**: YYYY-MM-DD
- **Response**: [Author's response]
- **Status**: Open | Answered

**Question 2: [Question]**
- [Same structure]

---

## Review Summary

### Overall Assessment

**Code Quality**: Excellent | Good | Fair | Needs Improvement
**Architecture Compliance**: ✅ Full | ⚠️ Partial | ❌ Violations Found
**Test Coverage**: ✅ Adequate | ⚠️ Gaps | ❌ Insufficient
**Documentation**: ✅ Good | ⚠️ Needs Work | ❌ Missing

**Comments**:
```
[Overall impressions, key strengths, main concerns]
```

---

### Recommendation

- [ ] ✅ **Approve**: Ready to merge
- [ ] ⚠️ **Approve with Comments**: Can merge, address comments in follow-up
- [ ] 🔴 **Request Changes**: Must address issues before merge
- [ ] ⏸️ **Needs Discussion**: Requires team discussion

**Rationale**:
```
[Explain recommendation]
```

---

## Next Steps

1. ✅ Review plan created
2. 🟡 Execute review (in progress)
3. ⏭️ Generate final report: `/docs/ignored/code_review/<branch_name>_review_report.md`
4. ⏭️ Share findings with author
5. ⏭️ Re-review after fixes (if needed)

---

## Appendix

### Files Reviewed

**Total Files**: X files

**By Component**:
- Models: X files
- Services: X files
- Controllers: X files
- Jobs: X files
- Listeners: X files
- Jbuilder: X files
- Migrations: X files
- Vue Components: X files
- Vuex Store: X files
- i18n: X files
- Tests (RSpec): X files
- Tests (Vitest): X files
- Other: X files

**Detailed List**:
```
[Full list of files reviewed with checkboxes]
- [x] app/models/model1.rb
- [x] app/services/domain/service1.rb
- [ ] app/controllers/api/v1/accounts/resource_controller.rb
- [ ] app/javascript/dashboard/components/ComponentName.vue
...
```

---

### Review Tools Used

**Git Commands**:
```bash
git diff development...HEAD -- app/models/
git diff development...HEAD -- app/services/
git diff development...HEAD -- app/controllers/
git diff development...HEAD -- app/javascript/dashboard/
```

**Search Patterns**:
```bash
Glob: "app/models/**/*.rb"
Grep: "class.*ApplicationRecord"
Grep: "def perform"
Glob: "app/javascript/dashboard/components/**/*.vue"
Grep: "<script setup>"
```

---

**Last Updated**: YYYY-MM-DD HH:MM:SS
**Updated By**: [Reviewer Name/Agent]
