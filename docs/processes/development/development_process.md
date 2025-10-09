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
11. [File Organization](#file-organization)
12. [Quality Gates](#quality-gates)
13. [References](#references)
14. [Changelog](#changelog)

---

## Overview

This document defines the standardized development process for the Chatwoot project. It ensures consistent, high-quality implementations with proper documentation, testing, and review cycles across both backend (Ruby on Rails) and frontend (Vue.js) components.

### Document Location

**IMPORTANT**: All design and execution documents MUST be created in `/docs/ignored/`

- **Design documents**: `/docs/ignored/design/<feature_name>_design.md`
- **Execution plans**: `/docs/ignored/development/<feature_name>_execution.md`
- These documents are NOT committed to the repository
- Templates remain in `/docs/processes/` for reference

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

1. **Header Metadata** - Session ID, timestamps, status, author
2. **Executive Summary** - Brief overview, key benefits, effort estimate, risk summary
3. **Current State Analysis** - Current implementation, code examples, problems, files affected, Enterprise considerations
4. **Proposed Solution** - High-level approach, architecture changes, code examples (before/after), design patterns, alignment with Rails MVC
5. **Technical Design** - Detailed implementation by component:
   - Models, Services, Controllers, Jobs, Listeners, Builders/Finders
   - Views (Jbuilder), Frontend Components, Vuex Store
   - i18n (en.json + es.json - BOTH required)
   - Database migrations
6. **Impact Analysis** - Files affected, breaking changes, migrations, API changes, tests, Enterprise compatibility
7. **Migration Strategy** - Step-by-step plan, backward compatibility, rollback plan, Rails migration reversibility
8. **Testing Strategy** - RSpec tests, Vitest tests, scenarios, edge cases, coverage goals (≥80%)
9. **Risks & Mitigations** - Identified risks with severity, mitigation strategies, contingency plans
10. **Alternatives Considered** - Other approaches evaluated, why rejected, trade-offs
11. **Timeline & Effort** - Estimated duration, task breakdown, dependencies
12. **References** - Related documents, external resources

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
```

#### Required Sections

1. **Header Metadata** - Session ID, timestamps, status, design doc link
2. **Progress Overview** - Visual progress bars for each phase and overall
3. **Quick Navigation** - Links to all phases, issues, comments
4. **Phase Definitions** - Each phase with status, tasks list
5. **Task Definitions** - Each task with:
   - Unique ID
   - Status checkbox
   - Description
   - Files affected
   - Subtasks (with checkboxes)
   - Expected changes (code examples)
   - Verification commands
   - Notes section
6. **Testing Section** - RSpec tests, Vitest tests, execution commands, results, coverage
7. **Issues & Blockers** - Open issues, blockers, resolution plans
8. **Comments & Notes** - Implementation notes, gotchas, decisions
9. **Completion Checklist** - Definition of Done, final validation steps

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

1. **Update Task Status** - Change checkbox from `[ ]` to `[x]` when starting, update progress bar
2. **Implement Changes** - Follow design specs, write clean code, follow CLAUDE.md standards
   - Backend: Use Rails conventions and patterns
   - Frontend: Use Vue.js Composition API with `<script setup>`
   - Styling: Use Tailwind CSS ONLY (no custom CSS)
   - i18n: Update BOTH en.json and es.json
3. **Update Execution Document** - Check off subtasks, add notes, document deviations, note issues
4. **Verify Changes** - Run verification commands, fix issues before next task
5. **Commit Progress** - Commit code + execution doc, use descriptive messages (no Claude references)

#### 5.3 Continuous Validation
- Run tests frequently: `bundle exec rspec`, `pnpm test`
- Run linters regularly: `bundle exec rubocop -a`, `pnpm eslint:fix`
- Keep test coverage high

#### 5.4 Handle Issues
- Document all issues in Issues & Blockers section
- Attempt resolution
- Escalate to human if blocked
- Update execution document with resolution

#### 5.5 Enterprise Compatibility Checks
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

#### 6.2 Frontend Test Development (Vitest)
- Create component tests for new Vue components
- Create Vuex store tests for new modules
- Follow testing patterns:
  - Use `describe`/`it` blocks
  - Mock API calls with `vi.mock()`
  - Test component rendering and user interactions
  - Test Vuex actions, mutations, getters

#### 6.3 Test Execution

**Backend Tests**:
```bash
# Run all specs
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/store_spec.rb

# Run specific test
bundle exec rspec spec/models/store_spec.rb:15
```

**Frontend Tests**:
```bash
# Run all tests
pnpm test

# Run in watch mode
pnpm test:watch
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

**Location**: `/docs/processes/design/DESIGN_TEMPLATE.md`

**Usage**: Copy template file and fill in all sections before Phase 3 review.

---

### Execution Plan Template

**Location**: `/docs/processes/development/DEVELOPMENT_EXECUTION_TEMPLATE.md`

**Usage**: Copy template file and update in real-time during implementation.

---

## File Organization

### Directory Structure

```
/docs/
├── ARCHITECTURE.md                  # System architecture documentation
├── processes/                       # Process templates (committed)
│   ├── process_template.md
│   ├── design/
│   │   ├── DESIGN_TEMPLATE.md
│   │   └── RESEARCH_TEMPLATE.md
│   ├── development/
│   │   └── DEVELOPMENT_EXECUTION_TEMPLATE.md
│   ├── tests/
│   │   ├── TEST_PLAN_TEMPLATE.md
│   │   └── TEST_RESULTS_TEMPLATE.md
│   └── code_review/
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

### Resuming Paused Work

If development is interrupted:
1. Open execution document in `/docs/ignored/development/`
2. Review progress overview and last completed task
3. Read comments section for context
4. Check issues section for any blockers
5. Continue from next unchecked task
6. Update status from "Paused" to "In Progress"
7. Add note documenting when/why work resumed

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
- [CLAUDE.md](/CLAUDE.md) - Project guidelines, commands, patterns, best practices
- [ARCHITECTURE.md](/docs/ARCHITECTURE.md) - System architecture overview
- [Design Template](/docs/processes/design/DESIGN_TEMPLATE.md) - Design document template
- [Execution Template](/docs/processes/development/DEVELOPMENT_EXECUTION_TEMPLATE.md) - Execution plan template
- [Research Process](/docs/processes/design/research_and_design_process.md) - Pre-design research phase
- [Troubleshooting Guide](/docs/processes/troubleshooting.md) - Common issues and solutions

### External Resources
- [Rails Guides](https://guides.rubyonrails.org/) - Official Rails documentation
- [Vue.js 3 Documentation](https://vuejs.org/) - Vue.js official docs
- [Vuex Documentation](https://vuex.vuejs.org/) - State management
- [Tailwind CSS](https://tailwindcss.com/docs) - Utility-first CSS
- [RSpec Documentation](https://rspec.info/) - RSpec testing framework
- [Vitest Documentation](https://vitest.dev/) - Vitest testing framework
- [Chatwoot Enterprise Development](https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38) - Enterprise edition practices

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
- Removed redundant best practices (now in CLAUDE.md)
- Removed detailed common patterns (examples in templates)
- Removed troubleshooting section (separate doc)
- Removed quick reference commands (now in CLAUDE.md and Taskfile.yml)
- Simplified to focus on process flow

### Version 1.0.0 (2025-10-04)
- Initial version (Python/FastAPI)
- Defined 7-phase development process
- Created document templates
- Established best practices

---

## Document Metadata

**Document Owner**: Development Team
**Maintained By**: Claude Code + Human Engineers
**Review Cycle**: Quarterly or as needed
**Last Reviewed**: 2025-10-06
**Next Review Due**: 2026-01-06
**Technology Stack**: Ruby on Rails 7.1+ | Vue.js 3 | PostgreSQL | Redis | Tailwind CSS
