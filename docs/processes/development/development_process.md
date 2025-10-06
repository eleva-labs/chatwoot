# Development Process Guide

**Version**: 2.0.0
**Last Updated**: 2025-10-06
**Status**: Active
**Document Type**: Process Guide
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Table of Contents

1. [Overview](#overview)
2. [Development Workflow](#development-workflow)
3. [Phase 1: Study & Analysis](#phase-1-study--analysis)
4. [Phase 2: Design Document](#phase-2-design-document)
5. [Phase 3: Design Review & Refinement](#phase-3-design-review--refinement)
6. [Phase 4: Execution Plan](#phase-4-execution-plan)
7. [Phase 5: Implementation & Tracking](#phase-5-implementation--tracking)
8. [Phase 6: Testing & Validation](#phase-6-testing--validation)
9. [Phase 7: Completion & Review](#phase-7-completion--review)
10. [Document Templates](#document-templates)
11. [Best Practices](#best-practices)
12. [Common Patterns](#common-patterns)
13. [File Organization](#file-organization)
14. [Resuming Paused Work](#resuming-paused-work)
15. [Quality Gates](#quality-gates)
16. [References](#references)
17. [Troubleshooting](#troubleshooting)
18. [Quick Reference](#quick-reference)
19. [Changelog](#changelog)

---

## Overview

This document defines the standardized development process for the Chatwoot project. It ensures consistent, high-quality implementations with proper documentation, testing, and review cycles across both backend (Ruby on Rails) and frontend (Vue.js) components.

### Key Principles

1. **Study First**: Deep understanding before coding
2. **Design Before Implementation**: Document the plan before execution
3. **Iterative Refinement**: Collaborate with engineers to refine designs
4. **Track Progress**: Maintain execution documents for transparency and resumability
5. **Test Thoroughly**: RSpec and Vitest tests are mandatory for all implementations
6. **Document Everything**: Clear documentation for future reference
7. **Full-Stack Thinking**: Consider both backend and frontend implications
8. **Enterprise Compatibility**: Ensure changes work with Enterprise overlay

### Process Stages

```
User Request
    ↓
Study & Analysis (Agent)
    ↓
Design Document (Agent)
    ↓
Design Review (Human ↔ Agent)
    ↓
Execution Plan (Agent)
    ↓
Implementation (Agent + Tracking)
    ↓
Testing & Validation (Agent)
    ↓
Final Review (Human)
    ↓
Completion
```

---

## Development Workflow

### Phase Summary

| Phase | Deliverable | Owner | Duration |
|-------|-------------|-------|----------|
| 1. Study & Analysis | Analysis notes | Agent | 30-60 min |
| 2. Design Document | Design MD file | Agent | 1-2 hours |
| 3. Design Review | Approved design | Human + Agent | Variable |
| 4. Execution Plan | Execution MD file | Agent | 30 min |
| 5. Implementation | Code + Updates | Agent | Variable |
| 6. Testing | Test results | Agent | Variable |
| 7. Completion | Final report | Agent + Human | 30 min |

---

## Phase 1: Study & Analysis

### Objective
Deep understanding of the current codebase, the problem to solve, and potential solutions.

### Activities

#### 1.1 Understand User Request
- Read and parse the user's request thoroughly
- Identify the core problem or feature
- Clarify ambiguities (ask questions if needed)
- Define success criteria

#### 1.2 Study Current Implementation
- Use `@ultrathink` approach for deep investigation
- Read ALL relevant files (use Glob, Grep, Read tools extensively)
- Understand the Rails MVC + Services architecture
- Identify dependencies and impacts
- Map out data flow and component interactions
- Check for Enterprise edition overrides in `enterprise/`

#### 1.3 Research Best Practices
- Review CLAUDE.md for project guidelines
- Check existing patterns in the codebase
- Consider Rails and Vue.js best practices
- Review similar implementations in the codebase
- Consult ARCHITECTURE.md for system overview

#### 1.4 Analyze Impact
- Identify all files that will be affected (backend + frontend)
- Determine breaking changes
- Assess risks and mitigation strategies
- Estimate effort and complexity
- Consider database migration requirements
- Check Enterprise compatibility

### Key Areas to Investigate

**Backend**:
- Models (`app/models/`)
- Services (`app/services/`)
- Controllers (`app/controllers/api/`)
- Jobs (`app/jobs/`)
- Listeners (`app/listeners/`)
- Builders/Finders (`app/builders/`, `app/finders/`)
- Views (`app/views/api/`) - Jbuilder
- Migrations (`db/migrate/`)

**Frontend**:
- Vue components (`app/javascript/dashboard/components/`)
- Vuex store (`app/javascript/dashboard/store/modules/`)
- API clients (`app/javascript/dashboard/api/`)
- i18n files (`app/javascript/dashboard/i18n/locale/`)
- Routes (`app/javascript/dashboard/routes/`)

**Tests**:
- Model specs (`spec/models/`)
- Service specs (`spec/services/`)
- Request specs (`spec/requests/`)
- Job specs (`spec/jobs/`)
- Component specs (`app/javascript/dashboard/components/__tests__/`)

**Enterprise**:
- Enterprise overrides (`enterprise/app/`)
- Enterprise specs (`spec/enterprise/`)

### Deliverable
Internal analysis notes (can be informal, used to create design document)

---

## Phase 2: Design Document

### Objective
Create a comprehensive design document that proposes the solution.

### Document Structure

#### File Naming Convention
```
/docs/ignored/design/<feature_name>_design.md

Format: <short_description>_design.md
Example: store_priority_feature_design.md
Naming: lowercase, snake_case

Note: All runtime documents are created in /docs/ignored/ to prevent
them from being committed to the repository. Templates remain in
/docs/processes/ for reference.
```

#### Required Sections

1. **Header Metadata**
   ```markdown
   # <Feature Name> - Design Document

   **Session ID**: <unique_session_id>
   **Created**: YYYY-MM-DD HH:MM:SS
   **Author**: Claude Code (Anthropic)
   **Status**: Draft | Under Review | Approved | Implemented
   **Related Request**: <brief description of user request>
   **Project**: Chatwoot (Rails + Vue.js)
   ```

2. **Executive Summary**
   - Brief overview (2-3 paragraphs)
   - Key benefits
   - Effort estimate
   - Risk summary

3. **Current State Analysis**
   - Description of current implementation
   - Code examples showing current behavior
   - Problems/limitations identified
   - Files affected (with file paths)
   - Enterprise considerations

4. **Proposed Solution**
   - High-level approach
   - Architecture changes
   - Code examples showing proposed changes (before/after)
   - Design patterns to use
   - Alignment with Rails MVC and Service Object patterns

5. **Technical Design**
   - Detailed implementation approach
   - Component-by-component changes:
     - **Models**: ActiveRecord models, associations, validations, scopes, enums
     - **Services**: Service objects (initialize + perform pattern)
     - **Controllers**: Rails controllers, endpoint changes
     - **Jobs**: Sidekiq background jobs
     - **Listeners**: Event listeners (event-driven architecture)
     - **Builders/Finders**: Object construction and complex queries
     - **Views**: Jbuilder JSON views (camelCase responses)
     - **Frontend Components**: Vue.js components (Composition API)
     - **Vuex Store**: State management (actions, mutations, getters)
     - **i18n**: Translation updates (en.json + es.json - BOTH required)
   - Data models and schemas
   - API contract changes (if any)
   - Database migrations

6. **Impact Analysis**
   - Files affected (categorized by type: models, services, controllers, frontend, tests)
   - Breaking changes
   - Database migrations required
   - API changes (breaking/non-breaking)
   - Test files requiring updates
   - Enterprise compatibility impact

7. **Migration Strategy**
   - Step-by-step migration plan
   - Backward compatibility approach
   - Rollback plan
   - Data migration scripts (if needed)
   - Rails migration reversibility

8. **Testing Strategy**
   - RSpec tests to create/update (model specs, service specs, request specs, job specs)
   - Vitest tests to create/update (component tests, store tests)
   - Test scenarios to cover
   - Edge cases to test
   - Coverage goals (≥80% for changed files)

9. **Risks & Mitigations**
   - Identified risks with severity
   - Mitigation strategies
   - Contingency plans

10. **Alternatives Considered**
    - Other approaches evaluated
    - Why they were rejected
    - Trade-offs of chosen approach

11. **Timeline & Effort**
    - Estimated duration
    - Task breakdown
    - Dependencies

12. **References**
    - Related documents
    - Architecture decision records
    - External resources

### Design Document Template

See: `/docs/processes/design/DESIGN_TEMPLATE.md`

### Deliverable
Complete design document in `/docs/ignored/design/` directory

---

## Phase 3: Design Review & Refinement

### Objective
Collaborate with the human engineer to refine and approve the design.

### Activities

#### 3.1 Initial Review
- Human engineer reviews the design document
- Identifies concerns, questions, or suggestions
- Requests clarifications or alternatives

#### 3.2 Iterative Refinement
- Agent updates design based on feedback
- Back-and-forth discussion to refine approach
- Alternative solutions explored if needed
- Design evolves until approval

#### 3.3 Final Approval
- Human engineer approves the design
- Design document status updated to "Approved"
- Ready to proceed to execution planning

### Deliverable
Approved design document with status: "Approved"

---

## Phase 4: Execution Plan

### Objective
Create a detailed, trackable execution plan with tasks and subtasks.

### Document Structure

#### File Naming Convention
```
/docs/ignored/development/<feature_name>_execution.md

Format: <short_description>_execution.md
Example: store_priority_feature_execution.md
Naming: lowercase, snake_case

Note: Execution documents are created in /docs/ignored/ to keep
work-in-progress tracking separate from committed documentation.
```

#### Required Sections

1. **Header Metadata**
   ```markdown
   # <Feature Name> - Execution Plan

   **Session ID**: <unique_session_id>
   **Created**: YYYY-MM-DD HH:MM:SS
   **Started**: YYYY-MM-DD HH:MM:SS
   **Completed**: YYYY-MM-DD HH:MM:SS (or "In Progress")
   **Status**: Not Started | In Progress | Completed | Blocked | Paused
   **Design Doc**: [Link to design document]
   **Related Request**: <brief description>
   **Project**: Chatwoot (Rails + Vue.js)
   ```

2. **Progress Overview**
   ```markdown
   ## Progress Overview

   ```
   Phase 1: Models & Migrations    [✅✅✅░░░] 3/5 (60%)
   Phase 2: Services & Logic       [░░░░░░░░] 0/4 (0%)
   Phase 3: Controllers & API      [░░░░░░░░] 0/3 (0%)
   Phase 4: Jobs & Background      [░░░░░░░░] 0/2 (0%)
   Phase 5: Frontend (Vue.js)      [░░░░░░░░] 0/6 (0%)
   Phase 6: Testing                [░░░░░░░░] 0/8 (0%)

   Overall Progress: ███░░░░░░░░░░░░░░░░░░░ 3/28 (11%)
   ```
   ```

3. **Quick Navigation**
   - Links to all phases
   - Link to issues section
   - Link to comments section

4. **Phase Definitions**
   - Each phase with:
     - Phase name and description
     - Status indicator
     - List of tasks

5. **Task Definitions**
   - Each task with:
     - Unique ID
     - Status checkbox
     - Description
     - Files affected
     - Subtasks (with checkboxes)
     - Expected changes (code examples)
     - Verification commands
     - Notes section

6. **Testing Section**
   - RSpec tests to create/update
   - Vitest tests to create/update
   - Test execution commands
   - Expected test results
   - Coverage requirements

7. **Issues & Blockers**
   - Open issues
   - Blockers preventing progress
   - Resolution plans

8. **Comments & Notes**
   - Implementation notes
   - Gotchas discovered
   - Decisions made during implementation
   - Items for later review

9. **Completion Checklist**
   - Definition of Done
   - Final validation steps

### Execution Plan Template

See: `/docs/processes/development/DEVELOPMENT_EXECUTION_TEMPLATE.md`

### Deliverable
Complete execution plan in `/docs/ignored/development/` directory

---

## Phase 5: Implementation & Tracking

### Objective
Implement the solution while tracking progress in the execution document.

### Activities

#### 5.1 Setup
- Create feature branch
- Initialize execution tracking document
- Set status to "In Progress"

#### 5.2 Iterative Implementation
For each task:

1. **Update Task Status**
   - Change checkbox from `[ ]` to `[x]` when starting
   - Update progress bar in overview

2. **Implement Changes**
   - Follow design document specifications
   - Write clean, well-documented code
   - Follow project coding standards (CLAUDE.md)
   - Backend: Use Rails conventions and patterns
   - Frontend: Use Vue.js Composition API with `<script setup>`
   - Styling: Use Tailwind CSS ONLY (no custom CSS)
   - i18n: Update BOTH en.json and es.json

3. **Update Execution Document**
   - Check off completed subtasks
   - Add implementation notes
   - Document any deviations from design
   - Note any issues encountered
   - Add comments for future review

4. **Verify Changes**
   - Run verification commands specified in task
   - Fix any issues before moving to next task

5. **Commit Progress**
   - Commit code changes
   - Commit updated execution document
   - Use descriptive commit messages (no Claude references)

#### 5.3 Continuous Validation
- Run tests frequently during implementation
- Run RSpec for backend: `bundle exec rspec spec/path/to/file_spec.rb`
- Run Vitest for frontend: `pnpm test`
- Run linters regularly:
  - Ruby: `bundle exec rubocop -a`
  - JS/Vue: `pnpm eslint:fix`
- Keep test coverage high

#### 5.4 Handle Issues
- Document all issues in Issues & Blockers section
- Attempt resolution
- Escalate to human if blocked
- Update execution document with resolution

#### 5.5 Rails-Specific Patterns to Follow

**Service Objects**:
```ruby
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
```

**Controllers**:
```ruby
class Api::V1::Accounts::StoresController < Api::V1::Accounts::BaseController
  def create
    @store = Stores::CreateService.new(
      account: Current.account,
      params: store_params
    ).perform

    render json: @store, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def store_params
    params.require(:store).permit(:name, :phone_number)
  end
end
```

**Vue Components (Composition API)**:
```vue
<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

const store = useStore();
const { t } = useI18n();
const isLoading = ref(false);

const stores = computed(() => store.getters['stores/getStores']);

const createStore = async (storeData) => {
  isLoading.value = true;
  try {
    await store.dispatch('stores/create', storeData);
  } catch (error) {
    console.error(error);
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Tailwind CSS only -->
    <h2 class="text-lg font-semibold">{{ t('STORES.TITLE') }}</h2>
  </div>
</template>
```

#### 5.6 Enterprise Compatibility Checks
- Search for related files in `enterprise/` before editing
- Use `rg -n "ClassName|ServiceName" app enterprise` to check for overrides
- Avoid hardcoding instance-specific behavior
- Use configuration or feature flags for Enterprise-specific logic
- Test that changes work with both OSS and Enterprise

### Progress Tracking Best Practices

1. **Update Frequently**: Update execution doc after each task completion
2. **Be Detailed**: Add notes about implementation decisions
3. **Document Issues**: Record all problems and solutions
4. **Keep It Current**: Progress bars should reflect reality
5. **Add Context**: Future you (or others) should understand what happened

### Deliverable
- Implemented code changes
- Updated execution document with progress

---

## Phase 6: Testing & Validation

### Objective
Ensure all changes work correctly with comprehensive testing.

### Activities

#### 6.1 Backend Test Development (RSpec)
- Create model specs for new models
- Create service specs for new services
- Create request specs for new API endpoints
- Create job specs for background jobs
- Follow testing patterns from CLAUDE.md:
  - Use FactoryBot factories
  - Use descriptive test names
  - Test both success and failure scenarios
  - Group tests by functionality using `describe`/`context` blocks

**Example Model Spec**:
```ruby
# spec/models/store_spec.rb
require 'rails_helper'

RSpec.describe Store, type: :model do
  describe 'associations' do
    it { should belong_to(:account) }
    it { should have_many(:conversations) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:priority) }
  end

  describe 'enums' do
    it { should define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2) }
  end
end
```

**Example Service Spec**:
```ruby
# spec/services/stores/create_service_spec.rb
require 'rails_helper'

RSpec.describe Stores::CreateService do
  let(:account) { create(:account) }
  let(:params) { { name: 'Test Store', phone_number: '1234567890' } }

  describe '#perform' do
    it 'creates a new store' do
      service = described_class.new(account: account, params: params)
      expect { service.perform }.to change(Store, :count).by(1)
    end

    it 'dispatches STORE_CREATED event' do
      service = described_class.new(account: account, params: params)
      expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
        STORE_CREATED,
        anything,
        hash_including(store: kind_of(Store))
      )
      service.perform
    end
  end
end
```

**Example Request Spec**:
```ruby
# spec/requests/api/v1/accounts/stores_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Stores', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:token) { user.create_token.token }
  let(:headers) { { 'api_access_token' => token } }

  describe 'POST /api/v1/accounts/:account_id/stores' do
    let(:valid_params) { { store: { name: 'Test Store', phone_number: '1234567890' } } }

    it 'creates a new store' do
      post "/api/v1/accounts/#{account.id}/stores",
           params: valid_params,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['name']).to eq('Test Store')
    end

    it 'returns 422 for invalid params' do
      post "/api/v1/accounts/#{account.id}/stores",
           params: { store: { name: '' } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

#### 6.2 Frontend Test Development (Vitest)
- Create component tests for new Vue components
- Create Vuex store tests for new modules
- Follow testing patterns:
  - Use `describe`/`it` blocks
  - Mock API calls with `vi.mock()`
  - Test component rendering and user interactions
  - Test Vuex actions, mutations, getters

**Example Component Spec**:
```javascript
// app/javascript/dashboard/components/__tests__/StoreDetails.spec.js
import { describe, it, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import StoreDetails from '../StoreDetails.vue';

describe('StoreDetails.vue', () => {
  it('renders store name', () => {
    const store = createStore({
      modules: {
        stores: {
          namespaced: true,
          getters: {
            getCurrentStore: () => ({ id: 1, name: 'Test Store' })
          }
        }
      }
    });

    const wrapper = mount(StoreDetails, {
      global: { plugins: [store] }
    });

    expect(wrapper.text()).toContain('Test Store');
  });
});
```

#### 6.3 Test Execution

**Backend Tests**:
```bash
# Run all specs
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/store_spec.rb

# Run specific test
bundle exec rspec spec/models/store_spec.rb:15

# Run with coverage
COVERAGE=true bundle exec rspec

# Run with test environment variables
POSTGRES_HOST=localhost POSTGRES_USERNAME=postgres POSTGRES_PASSWORD=password bundle exec rspec
```

**Frontend Tests**:
```bash
# Run all tests
pnpm test

# Run in watch mode
pnpm test:watch

# Run specific file
pnpm test StoreDetails.spec.js
```

**Linting**:
```bash
# Ruby
bundle exec rubocop -a

# JavaScript/Vue
pnpm eslint:fix
```

#### 6.4 Test Result Documentation
In execution document:
- Add test execution results
- Document coverage metrics
- Note any test failures and resolutions
- Verify all tests pass before proceeding

#### 6.5 Integration Testing
- Test end-to-end flows
- Verify API endpoints work correctly
- Test database migrations (up and down)
- Validate error handling
- Test event dispatching and listeners

#### 6.6 Code Quality Checks
```bash
# Ruby linting
bundle exec rubocop -a

# JavaScript/Vue linting
pnpm eslint:fix

# Run full test suite
bundle exec rspec
pnpm test
```

### Success Criteria
- [ ] All RSpec tests pass
- [ ] All Vitest tests pass
- [ ] Test coverage ≥ 80% for changed files
- [ ] No RuboCop violations
- [ ] No ESLint violations
- [ ] All migrations run successfully (up and down)
- [ ] All verification commands successful
- [ ] Enterprise compatibility verified (if applicable)

### Deliverable
- Complete test suite (RSpec + Vitest)
- All tests passing
- Updated execution document with test results

---

## Phase 7: Completion & Review

### Objective
Finalize implementation and prepare for merge.

### Activities

#### 7.1 Final Validation
- Run complete test suite one final time
- Verify all tasks in execution plan are complete
- Ensure all checkboxes are marked
- Review implementation notes
- Confirm no open issues or blockers

#### 7.2 Documentation Updates
- Update CLAUDE.md if patterns changed
- Update API documentation if APIs changed
- Create migration guides if breaking changes
- Update relevant README files
- Update i18n files (both en.json and es.json)

#### 7.3 Code Review Preparation
- Ensure code follows all standards
- Remove debug code and comments
- Verify commit messages are clear (no Claude references)
- Prepare summary of changes
- Check Enterprise compatibility

#### 7.4 Update Execution Document
- Set status to "Completed"
- Add completion timestamp
- Fill out completion checklist
- Add final notes and reflections

#### 7.5 Create Summary Report
In execution document, add:
- Summary of what was implemented
- Key decisions made
- Deviations from design (if any)
- Known limitations
- Recommendations for future work

### Deliverable
- Completed execution document
- Final summary report
- Code ready for review and merge

---

## Document Templates

### Design Document Template

**Location**: See `/docs/processes/design/DESIGN_TEMPLATE.md`

**Key Sections**:
- Executive Summary (benefits, effort, risk)
- Current State Analysis (code examples, problems, affected files)
- Proposed Solution (approach, architecture, patterns)
- Technical Design (component-by-component changes: Models, Services, Controllers, Jobs, Listeners, Frontend, i18n)
- Impact Analysis (files affected, breaking changes, migrations, Enterprise compatibility)
- Migration Strategy (phases, rollback plan, Rails migration reversibility)
- Testing Strategy (RSpec + Vitest, coverage goals)
- Risks & Mitigations
- Alternatives Considered
- Timeline & Effort

**Usage**: Copy template file and fill in all sections before Phase 3 review.

---

### Execution Plan Template

**Location**: See `/docs/processes/development/DEVELOPMENT_EXECUTION_TEMPLATE.md`

**Key Sections**:
- Progress Overview (with visual progress bars)
- Quick Navigation
- Phases with Tasks:
  - Phase 1: Models & Migrations
  - Phase 2: Services & Logic
  - Phase 3: Controllers & API
  - Phase 4: Jobs & Background Processing
  - Phase 5: Frontend (Vue.js)
  - Phase 6: Testing (RSpec + Vitest)
- Testing (tests to create/update, execution commands, results)
- Issues & Blockers (track open issues with severity)
- Comments & Notes (implementation decisions, learnings)
- Completion Checklist (definition of done, final validation)

**Usage**: Copy template file and update in real-time during implementation.

---

## Best Practices

### For Agents (Claude Code)

#### Study Phase
1. **Be Thorough**: Use `@ultrathink` - read ALL related files
2. **Use Tools Extensively**: Glob, Grep, Read - don't guess
3. **Understand Context**: Read CLAUDE.md and ARCHITECTURE.md
4. **Ask Questions**: If unclear, ask the human before proceeding
5. **Check Enterprise**: Always search `enterprise/` for related files

#### Design Phase
1. **Be Comprehensive**: Include all required sections
2. **Use Examples**: Show before/after code examples (Rails + Vue.js)
3. **Be Specific**: Reference exact file paths and line numbers
4. **Consider Alternatives**: Show you've thought through options
5. **Align with Patterns**: Follow Rails MVC + Services + Vue.js Composition API
6. **Full-Stack Design**: Cover both backend and frontend
7. **i18n Requirements**: Always include translation updates (en + es)

#### Execution Phase
1. **Update Frequently**: Keep execution doc current
2. **Be Detailed**: Add notes about decisions and issues
3. **Track Everything**: Document deviations from design
4. **Test Continuously**: Don't wait until the end
5. **Commit Often**: Commit code and docs together
6. **Follow Conventions**: Rails conventions, Vue.js patterns, Tailwind CSS only

#### Testing Phase
1. **Follow CLAUDE.md**: Use exact commands specified
2. **Test Thoroughly**: Cover edge cases and error scenarios
3. **Use Factories**: Always use FactoryBot factories for test data
4. **Document Results**: Add test results to execution doc
5. **Fix Before Proceeding**: Don't leave broken tests
6. **Test Both Stacks**: Run both RSpec and Vitest

### For Human Engineers

#### Design Review
1. **Review Thoroughly**: Read entire design document
2. **Question Assumptions**: Challenge approach if needed
3. **Provide Clear Feedback**: Be specific about concerns
4. **Suggest Alternatives**: If you see better approaches
5. **Approve Explicitly**: Update status to "Approved"
6. **Check Enterprise Impact**: Verify Enterprise compatibility considerations

#### During Execution
1. **Monitor Progress**: Check execution doc updates
2. **Unblock Quickly**: Respond to blockers promptly
3. **Review Code**: Provide feedback during development
4. **Validate Decisions**: Review implementation notes

#### Final Review
1. **Test Locally**: Run the implementation yourself
2. **Review Tests**: Ensure test coverage is adequate
3. **Check Documentation**: Verify docs are updated
4. **Check i18n**: Verify both en.json and es.json are updated
5. **Check Enterprise**: Test with Enterprise overlay if applicable
6. **Approve Merge**: Sign off when satisfied

---

## Common Patterns

### Pattern: Database Schema Change

**Design Doc Must Include**:
- Current schema
- Proposed schema
- Rails migration script (with reversible up/down)
- Data migration strategy (if needed)
- Rollback plan
- Index requirements
- Foreign key constraints

**Example Migration**:
```ruby
# db/migrate/20251006120000_add_priority_to_stores.rb
class AddPriorityToStores < ActiveRecord::Migration[7.1]
  def change
    add_column :stores, :priority, :integer, default: 1, null: false
    add_index :stores, :priority
  end
end
```

**Execution Must Include**:
- Migration file creation
- Migration testing: `rails db:migrate:status`
- Rollback testing: `rails db:rollback`
- Model updates (enums, validations, scopes)
- Production migration plan

**Verification Commands**:
```bash
# Create migration
rails generate migration AddPriorityToStores

# Run migration
rails db:migrate

# Test rollback
rails db:rollback

# Re-run
rails db:migrate

# Check status
rails db:migrate:status
```

---

### Pattern: API Breaking Change

**Design Doc Must Include**:
- Current API contract (Jbuilder view)
- New API contract
- Migration guide for API clients
- Deprecation timeline
- Backward compatibility strategy (if applicable)
- Frontend impact (Vue components, Vuex store, API client)

**Example API Change**:
```ruby
# Before: app/views/api/v1/accounts/stores/show.json.jbuilder
json.extract! @store, :id, :name, :created_at, :updated_at

# After: app/views/api/v1/accounts/stores/show.json.jbuilder
json.extract! @store, :id, :name, :priority, :created_at, :updated_at
json.priorityLabel @store.priority.humanize
```

**Execution Must Include**:
- Controller updates (strong parameters)
- Jbuilder view updates
- API client updates (`app/javascript/dashboard/api/`)
- Vuex store updates (actions, mutations, getters)
- Vue component updates
- Request spec updates
- API documentation updates (if exists)

---

### Pattern: Refactoring

**Design Doc Must Include**:
- Current architecture diagram/description
- Proposed architecture
- Justification for refactoring
- Impact on existing functionality
- Verification that behavior doesn't change

**Execution Must Include**:
- Tests to verify behavior preserved (regression tests)
- Incremental refactoring steps
- Continuous test execution after each step
- Performance comparison (if relevant)

**Example Service Refactoring**:
```ruby
# Before: Controller handles logic
class Api::V1::Accounts::StoresController < ApplicationController
  def create
    @store = Current.account.stores.build(store_params)
    if @store.save
      Rails.configuration.dispatcher.dispatch(STORE_CREATED, Time.zone.now, store: @store)
      render json: @store, status: :created
    else
      render json: { error: @store.errors.full_messages }, status: :unprocessable_entity
    end
  end
end

# After: Service object pattern
class Stores::CreateService
  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def perform
    store = @account.stores.build(store_params)
    store.save!
    dispatch_event(store)
    store
  end

  private

  def store_params
    @params.permit(:name, :phone_number)
  end

  def dispatch_event(store)
    Rails.configuration.dispatcher.dispatch(STORE_CREATED, Time.zone.now, store: store)
  end
end

# Controller becomes thin
class Api::V1::Accounts::StoresController < ApplicationController
  def create
    @store = Stores::CreateService.new(account: Current.account, params: store_params).perform
    render json: @store, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end
end
```

---

### Pattern: Frontend Component Change

**Design Doc Must Include**:
- Current component structure
- Proposed component structure
- Vue.js Composition API usage
- Tailwind CSS classes (no custom CSS)
- i18n key usage
- Vuex store integration
- Props and emits definition

**Example Component**:
```vue
<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  storeId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['updated']);

const store = useStore();
const { t } = useI18n();

const currentStore = computed(() =>
  store.getters['stores/getStore'](props.storeId)
);

const updatePriority = async (newPriority) => {
  await store.dispatch('stores/update', {
    id: props.storeId,
    priority: newPriority,
  });
  emit('updated');
};
</script>

<template>
  <div class="flex flex-col gap-4 p-4 bg-white rounded-lg shadow">
    <h3 class="text-lg font-semibold">{{ currentStore.name }}</h3>
    <div class="flex items-center gap-2">
      <span class="text-sm text-gray-600">{{ t('STORES.PRIORITY') }}:</span>
      <span class="px-2 py-1 text-xs font-medium rounded bg-blue-100 text-blue-800">
        {{ currentStore.priorityLabel }}
      </span>
    </div>
  </div>
</template>
```

**Execution Must Include**:
- Component file creation/update
- Vuex store updates (if needed)
- API client updates (if needed)
- i18n updates (en.json + es.json)
- Component test (Vitest)
- Integration with parent components

---

### Pattern: Event-Driven Change

**Design Doc Must Include**:
- Event name and payload structure
- Dispatcher location (usually in service object)
- Listener class to create/update
- Background job to trigger (if applicable)
- Event flow diagram

**Example Event Flow**:
```ruby
# Service dispatches event
class Stores::CreateService
  def perform
    store = @account.stores.build(store_params)
    store.save!
    dispatch_event(store)  # <-- Dispatch event
    store
  end

  private

  def dispatch_event(store)
    Rails.configuration.dispatcher.dispatch(
      STORE_CREATED,  # <-- Event name
      Time.zone.now,
      store: store    # <-- Payload
    )
  end
end

# Listener handles event
class StoreListener < BaseListener
  def store_created(event)
    store = event.data[:store]

    # Trigger background jobs
    Stores::NotifyAdminsJob.perform_later(store.id)
    Stores::SetupDefaultConfigJob.perform_later(store.id)

    # Send analytics
    Rails.logger.info("Store created: #{store.id}")
  end
end
```

**Execution Must Include**:
- Event constant definition
- Service object update (dispatch call)
- Listener class creation/update
- Background job creation (if needed)
- Listener spec (verify event handling)
- Job spec (verify job execution)

---

## File Organization

### Directory Structure

```
/docs/
├── ARCHITECTURE.md                  # System architecture documentation
├── processes/                       # Process templates (committed)
│   ├── development_process.md       # This file
│   ├── design/
│   │   ├── DESIGN_TEMPLATE.md
│   │   └── RESEARCH_TEMPLATE.md
│   ├── development/
│   │   └── DEVELOPMENT_EXECUTION_TEMPLATE.md
│   ├── tests/
│   │   ├── TEST_PLAN_TEMPLATE.md
│   │   └── TEST_RESULTS_TEMPLATE.md
│   └── review/
│       ├── REVIEW_PLAN_TEMPLATE.md
│       └── REVIEW_REPORT_TEMPLATE.md
└── ignored/                         # Runtime documents (gitignored)
    ├── design/
    │   ├── feature_a_design.md
    │   └── feature_b_design.md
    ├── development/
    │   ├── feature_a_execution.md
    │   └── feature_b_execution.md
    └── archive/                     # Completed/old documents
        ├── 2024/
        └── 2025/
```

### Naming Conventions

**Design Documents**:
- Format: `<short_description>_design.md`
- Example: `store_priority_feature_design.md`
- Lowercase, snake_case

**Execution Documents**:
- Format: `<short_description>_execution.md`
- Example: `store_priority_feature_execution.md`
- Must match corresponding design doc name

**Session IDs**:
- Format: `YYYYMMDD_HHMMSS` or UUID
- Example: `20251006_143022` or `a1b2c3d4-e5f6-...`

---

## Resuming Paused Work

If development is interrupted or paused:

1. **Open Execution Document**: Find in `/docs/ignored/development/`
2. **Review Progress**: Check progress overview and last completed task
3. **Read Comments**: Review implementation notes and decisions
4. **Check Issues**: See if any blockers need resolution
5. **Continue**: Pick up from next unchecked task
6. **Update Status**: Change from "Paused" to "In Progress"
7. **Add Note**: Document when/why work resumed

---

## Quality Gates

### Before Moving to Next Phase

#### After Study → Before Design
- [ ] All relevant files read and understood
- [ ] Rails MVC + Services architecture patterns identified
- [ ] Impact fully assessed (backend + frontend)
- [ ] Questions answered
- [ ] Enterprise compatibility checked

#### After Design → Before Review
- [ ] All required sections complete
- [ ] Code examples provided (Rails + Vue.js)
- [ ] Impact analysis thorough (models, services, controllers, frontend, tests)
- [ ] Testing strategy defined (RSpec + Vitest)
- [ ] i18n requirements documented

#### After Review → Before Execution
- [ ] Design approved by human
- [ ] All feedback incorporated
- [ ] Clarifications resolved
- [ ] Ready to implement

#### After Execution → Before Completion
- [ ] All tasks complete
- [ ] All tests passing (RSpec + Vitest)
- [ ] Documentation updated
- [ ] i18n updated (en.json + es.json)
- [ ] No open issues
- [ ] Enterprise compatibility verified

---

## References

### Related Documents
- [CLAUDE.md](/CLAUDE.md) - Project guidelines and commands
- [ARCHITECTURE.md](/docs/ARCHITECTURE.md) - System architecture overview
- [Design Template](/docs/processes/design/DESIGN_TEMPLATE.md) - Design document template
- [Execution Template](/docs/processes/development/DEVELOPMENT_EXECUTION_TEMPLATE.md) - Execution plan template
- [Test Plan Template](/docs/processes/tests/TEST_PLAN_TEMPLATE.md) - API test plan template

### External Resources
- [Rails Guides](https://guides.rubyonrails.org/) - Official Rails documentation
- [Vue.js 3 Documentation](https://vuejs.org/) - Vue.js official docs
- [Vuex Documentation](https://vuex.vuejs.org/) - State management
- [Tailwind CSS](https://tailwindcss.com/docs) - Utility-first CSS
- [RSpec Documentation](https://rspec.info/) - RSpec testing framework
- [Vitest Documentation](https://vitest.dev/) - Vitest testing framework
- [Chatwoot Enterprise Development](https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38) - Enterprise edition practices

---

## Troubleshooting

### Issue 1: Design Review Taking Too Long

**Symptoms**:
- Design document sitting unreviewed for days
- Multiple rounds of feedback with unclear direction
- Disagreement on approach

**Solutions**:
- Schedule dedicated design review session
- Set clear review timeline expectations (24-48 hours)
- Use synchronous discussion for complex topics
- Break large designs into smaller reviewable chunks

**Prevention**:
- Involve stakeholders early in research phase
- Set review expectations upfront
- Use research phase to align on approach before detailed design

---

### Issue 2: Execution Document Not Being Updated

**Symptoms**:
- Progress bars don't reflect actual progress
- Tasks marked incomplete but code is done
- Missing implementation notes

**Solutions**:
- Commit execution doc with code changes
- Set reminder to update after each task
- Use TodoWrite tool to track and auto-update progress
- Schedule regular execution doc review

**Prevention**:
- Make execution doc updates part of definition of done
- Review progress tracking in retrospectives
- Use automation where possible

---

### Issue 3: Tests Failing After Implementation

**Symptoms**:
- Implementation complete but tests fail
- Breaking existing tests
- Low test coverage

**Solutions**:
- Run tests continuously during implementation (not just at end)
- Fix tests immediately when they break
- Review test plan in design phase
- Use FactoryBot factories consistently

**Prevention**:
- Include test strategy in design document
- Run `bundle exec rspec` after each significant change
- Run `pnpm test` after frontend changes
- Review test coverage requirements before starting
- Follow testing patterns from CLAUDE.md

---

### Issue 4: Forgetting to Update All Components

**Symptoms**:
- Added model field but forgot API view
- Updated service but forgot controller
- Database migration missing
- Tests only cover backend, not frontend
- i18n missing Spanish translations

**Solutions**:
- Use design document as checklist of all files to update
- Review impact analysis section
- Test end-to-end flow, not just individual components
- Use execution plan to track all affected files
- Always check both en.json and es.json

**Prevention**:
- Create comprehensive impact analysis in design phase
- Use execution plan with explicit file lists (backend + frontend)
- Test integration, not just units
- Review all components in checklist before completing
- Set up i18n linter/checker

---

### Issue 5: Enterprise Compatibility Broken

**Symptoms**:
- Changes work in OSS but break in Enterprise
- Enterprise overrides not updated
- Hardcoded logic that Enterprise needs to customize

**Solutions**:
- Search for related files in `enterprise/` directory
- Use `rg -n "ClassName" app enterprise` to find overrides
- Add extension points instead of hardcoding
- Test with Enterprise overlay enabled

**Prevention**:
- Always check `enterprise/` during study phase
- Document Enterprise compatibility in design
- Use configuration or feature flags for Enterprise-specific logic
- Follow Enterprise development guide

---

### Issue 6: Frontend Not Working with Backend Changes

**Symptoms**:
- API returns data but frontend doesn't display it
- Vuex store not updated
- i18n keys missing
- API response format mismatch (snake_case vs camelCase)

**Solutions**:
- Verify Jbuilder view returns camelCase
- Update Vuex store actions/mutations
- Update API client to match new endpoint
- Add i18n keys for new UI elements
- Test API with browser DevTools Network tab

**Prevention**:
- Include frontend changes in design document
- Update API client alongside controller
- Test full-stack flow during implementation
- Use consistent camelCase in Jbuilder views

---

## Quick Reference

### Common Development Commands

```bash
# Backend Development
bundle install                           # Install Ruby dependencies
bundle exec rspec                        # Run all RSpec tests
bundle exec rspec spec/models/           # Run model specs
bundle exec rspec spec/models/store_spec.rb:15  # Run specific test
bundle exec rubocop -a                   # Auto-fix Ruby linting
rails db:migrate                         # Run migrations
rails db:rollback                        # Rollback last migration
rails db:migrate:status                  # Check migration status
rails console                            # Open Rails console
rails server                             # Start Rails server

# Frontend Development
pnpm install                             # Install JS dependencies
pnpm dev                                 # Start development server
pnpm test                                # Run Vitest tests
pnpm test:watch                          # Run tests in watch mode
pnpm eslint                              # Run ESLint
pnpm eslint:fix                          # Auto-fix ESLint issues

# Full Development Environment
overmind start -f Procfile.dev           # Start all services
pnpm dev                                 # Alternative: Start with pnpm

# Testing with Database
POSTGRES_HOST=localhost POSTGRES_USERNAME=postgres POSTGRES_PASSWORD=password bundle exec rspec

# Linting & Formatting
bundle exec rubocop -a                   # Ruby auto-fix
pnpm eslint:fix                          # JS/Vue auto-fix
```

### File Naming Conventions

| Document Type | Format | Example |
|---------------|--------|---------|
| Design Document | `{feature}_design.md` | `store_priority_feature_design.md` |
| Execution Plan | `{feature}_execution.md` | `store_priority_feature_execution.md` |
| Research Report | `{feature}_research.md` | `store_phone_field_research.md` |

### Session ID Format

- **Timestamp Format**: `YYYYMMDD_HHMMSS`
  - Example: `20251006_143022`
- **UUID Format**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
  - Example: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

### Document Locations

| Type | Location | Description |
|------|----------|-------------|
| **Templates** (committed) | `/docs/processes/design/` | Design document templates |
| **Templates** (committed) | `/docs/processes/development/` | Execution plan templates |
| **Templates** (committed) | `/docs/processes/tests/` | Test plan templates |
| **Runtime Docs** (ignored) | `/docs/ignored/design/` | Active design documents |
| **Runtime Docs** (ignored) | `/docs/ignored/development/` | Active execution plans |
| **Runtime Docs** (ignored) | `/docs/ignored/tests/` | Active test plans |

### Common File Paths

**Backend**:
- Models: `app/models/*.rb`
- Services: `app/services/*/*.rb`
- Controllers: `app/controllers/api/v1/accounts/*.rb`
- Jobs: `app/jobs/*/*.rb`
- Listeners: `app/listeners/*_listener.rb`
- Views: `app/views/api/v1/accounts/*/*.json.jbuilder`
- Migrations: `db/migrate/*.rb`
- Specs: `spec/models/`, `spec/services/`, `spec/requests/`, `spec/jobs/`

**Frontend**:
- Components: `app/javascript/dashboard/components/*.vue`
- Vuex Store: `app/javascript/dashboard/store/modules/*.js`
- API Clients: `app/javascript/dashboard/api/*.js`
- i18n: `app/javascript/dashboard/i18n/locale/{en,es}.json`
- Routes: `app/javascript/dashboard/routes/*.js`
- Tests: `app/javascript/dashboard/components/__tests__/*.spec.js`

**Enterprise**:
- Models: `enterprise/app/models/*.rb`
- Services: `enterprise/app/services/*/*.rb`
- Controllers: `enterprise/app/controllers/api/v1/accounts/*.rb`
- Specs: `spec/enterprise/`

---

## Changelog

### Version 2.0.0 (2025-10-06)
- **Major Update**: Adapted for Chatwoot (Rails + Vue.js) from Python/FastAPI
- Updated all references from Clean Architecture to Rails MVC + Services
- Added frontend development sections (Vue.js, Vuex, Tailwind CSS)
- Updated testing sections (RSpec + Vitest)
- Added Enterprise edition considerations throughout
- Updated all code examples to Rails and Vue.js
- Added i18n requirements (en.json + es.json)
- Restructured execution phases to match Rails/Vue.js architecture
- Added common patterns for Rails-specific scenarios
- Updated troubleshooting for full-stack issues
- Added comprehensive quick reference for Rails/Vue.js commands

### Version 1.0.0 (2025-10-04)
- Initial version (Python/FastAPI)
- Defined 7-phase development process
- Created document templates
- Established best practices
- Added troubleshooting section
- Added quick reference section

---

## Document Metadata

**Document Owner**: Development Team
**Maintained By**: Claude Code + Human Engineers
**Review Cycle**: Quarterly or as needed
**Last Reviewed**: 2025-10-06
**Next Review Due**: 2026-01-06
**Technology Stack**: Ruby on Rails 7.1+ | Vue.js 3 | PostgreSQL | Redis | Tailwind CSS
