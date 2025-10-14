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
7. [Process Checklist](#process-checklist)
8. [Related Documentation](#related-documentation)
9. [Changelog](#changelog)

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
   - **Example**: Components use Tailwind classes, i18n keys, Vuex state

3. **Principle 3: Test-Driven Quality**
   - Write RSpec specs for backend (models, services, controllers, requests)
   - Write Vitest specs for frontend (components, store modules)
   - Test happy path + edge cases + error scenarios
   - Maintain high test coverage
   - **Why it matters**: Prevents regressions, documents behavior, enables refactoring

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
- Development environment set up (see Taskfile.yml)
- Database running and migrated
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
# See Taskfile.yml for all commands

# Backend: Run RSpec tests
task test-backend-file -- spec/path/to/file_spec.rb

# Frontend: Run Vitest tests
pnpm test

# Linting: Ruby
bundle exec rubocop -a

# Linting: Vue.js/JavaScript
pnpm eslint:fix

# Database: Run migrations
rails db:migrate

# Server: Start development server (Docker)
task docker-up
# or (Non-Docker)
pnpm dev
```

**Expected Output**:
```
[Show what successful output looks like - e.g., test results, server startup logs]
```

**Verification**:
- [ ] Expected output achieved
- [ ] Tests passing
- [ ] No linting errors

**Common Issues**:
- **Issue**: [Problem] → [Solution or link to troubleshooting doc]

### Step 1.2: [Step Name]

[Repeat structure for each step]

### Phase 1 Deliverable

**Output**: [What this phase produces]

**Location**: [Where the output is stored - e.g., `app/models/`, `app/javascript/dashboard/components/`]

**Format**: [Structure/format - e.g., Ruby class, Vue component, Markdown doc]

**Quality Check**:
- [ ] Code follows Rails/Vue conventions
- [ ] Tests written and passing
- [ ] i18n updated (if applicable)
- [ ] Documentation updated

---

## Phase 2: [Phase Name]

[Repeat structure from Phase 1]

---

## Phase N: [Final Phase Name]

[Repeat structure from Phase 1]

---

## Process Checklist

### Pre-Process Setup

- [ ] Development environment ready (Taskfile.yml commands working)
- [ ] Database running and migrated
- [ ] CLAUDE.md and ARCHITECTURE.md reviewed
- [ ] Feature branch created from `develop`

### Execution

- [ ] Phase 1 complete (see Phase 1 deliverable checklist)
- [ ] Phase 2 complete (see Phase 2 deliverable checklist)
- [ ] Phase N complete (see Phase N deliverable checklist)

### Post-Process Completion

- [ ] All backend tests passing (`task test-backend-all`)
- [ ] All frontend tests passing (`pnpm test`)
- [ ] Linting clean (`bundle exec rubocop`, `pnpm eslint`)
- [ ] i18n updated (en/es for both backend and frontend)
- [ ] Documentation updated
- [ ] Code review requested
- [ ] Enterprise compatibility verified (if applicable)

---

## Related Documentation

### Process Documentation

- [Development Process](./development/development_process.md) - Full development workflow
- [Research & Design Process](./design/research_and_design_process.md) - Feature research and design
- [Code Review Process](./code_review/code_review_process.md) - Review procedures
- [API Testing Process](./tests/api_testing_process.md) - API testing guide

### Technical Documentation

- [Architecture Overview](../ARCHITECTURE.md) - Chatwoot architecture and tech stack
- [Development Guidelines](../CLAUDE.md) - Coding standards and conventions (includes commands, patterns, best practices)
- [Contributing Guide](../CONTRIBUTING.md) - Contribution guidelines

### Templates & Resources

- [Design Template](./design/DESIGN_TEMPLATE.md) - Design document template
- [Research Template](./design/RESEARCH_TEMPLATE.md) - Research report template
- [Execution Template](./development/DEVELOPMENT_EXECUTION_TEMPLATE.md) - Execution tracking
- [Test Plan Template](./tests/TEST_PLAN_TEMPLATE.md) - Test planning
- [Troubleshooting Guide](./troubleshooting.md) - Common issues and solutions

### External Resources

**Ruby on Rails**:
- [Ruby on Rails Guides](https://guides.rubyonrails.org/) - Official Rails documentation
- [RSpec Documentation](https://rspec.info/) - Testing framework

**Vue.js**:
- [Vue.js 3 Documentation](https://vuejs.org/) - Official Vue.js docs
- [Composition API Guide](https://vuejs.org/guide/extras/composition-api-faq.html) - Composition API
- [Vitest Documentation](https://vitest.dev/) - Testing framework

**Styling**:
- [Tailwind CSS Documentation](https://tailwindcss.com/) - Utility-first CSS framework

---

## Changelog

### Version X.Y.Z (YYYY-MM-DD)

**Status**: [Draft | Active | Deprecated | Archived]

**Changes**:
- Change 1
- Change 2
- Change 3

**Migration Notes**:
- [Any notes for users of previous versions]

---

### Version 1.0.0 (Previous)

**Status**: Archived

**Changes**:
- Initial version

---

## Document Metadata

**Document Owner**: Development Team

**Maintained By**: Development Team

**Review Cycle**: Quarterly or after major architectural changes

**Last Reviewed**: YYYY-MM-DD

**Next Review Due**: YYYY-MM-DD

**Contact**: Development team channel for questions and feedback

---

**End of Document**
