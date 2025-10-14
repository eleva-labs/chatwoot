# Unit Testing Process

**Version**: 2.0.0
**Last Updated**: 2025-10-09
**Status**: Active
**Document Type**: Process Guide
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Overview](#overview)
3. [Simple Decision Guide](#simple-decision-guide)
4. [Backend Testing (RSpec)](#backend-testing-rspec)
5. [Frontend Testing (Vitest)](#frontend-testing-vitest)
6. [Process Checklist](#process-checklist)
7. [Related Documentation](#related-documentation)

---

## Quick Start

### I need to run tests. What do I do?

**Backend tests (Ruby/RSpec):**
```bash
# First time or after schema changes
SETUP_DB=true task test-backend-all

# Normal runs (faster - DB stays running)
task test-backend-all

# When done testing
CLEANUP=true task test-backend-all
```

**Frontend tests (Vue/Vitest):**
```bash
task test-frontend-all
```

**That's it!** The commands handle all complexity for you.

---

## Overview

This guide helps run unit tests in Chatwoot autonomously.

### What Tests Can I Run?

**Backend (Ruby/RSpec)** - Requires PostgreSQL + Redis:
- Model tests: `spec/models/`
- Service tests: `spec/services/`
- API tests: `spec/requests/`
- Job tests: `spec/jobs/`
- Library tests: `spec/lib/`

**Frontend (Vue/Vitest)** - No dependencies needed:
- Component tests
- Composable tests
- Helper/utility tests
- Store tests

---

## Simple Decision Guide

### Step 1: What type of tests?

→ **Backend (Ruby)?** Go to Step 2
→ **Frontend (Vue/JavaScript)?** Skip to [Frontend Testing](#frontend-testing-vitest)

### Step 2: What scope do I need?

→ **All backend tests?**
```bash
task test-backend-all  # Add SETUP_DB=true for first run
```

→ **Specific folder (e.g., models)?**
```bash
task test-backend-module -- spec/models
```

→ **Single file?**
```bash
task test-backend-file -- spec/models/user_spec.rb
```

→ **Specific test line?**
```bash
task test-backend-file -- spec/models/user_spec.rb:45
```

### Step 3: Did tests pass?

→ **YES** ✅ - Done! Cleanup happens automatically.

→ **NO** ❌ - Check error output and see CLAUDE.md or Taskfile.yml for troubleshooting

---

## Backend Testing (RSpec)

### What You Need

- Docker installed and running
- Rails gems installed (`bundle install`)

### Task Commands Reference

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `task test-backend-all` | Run ALL backend tests | Full validation, CI/CD |
| `task test-backend-module -- spec/models` | Run specific folder | Testing one area |
| `task test-backend-file -- spec/models/user_spec.rb` | Run one file | Debugging, TDD |

**Optional Flags:**
- `SETUP_DB=true` - Setup database before running (first time, schema changes)
- `CLEANUP=true` - Stop containers after running (when done testing)

**Examples:**
```bash
# First run or after schema changes
SETUP_DB=true task test-backend-file -- spec/models/user_spec.rb

# Fast iteration (DB stays running)
task test-backend-file -- spec/models/user_spec.rb

# Done for the day
CLEANUP=true task test-backend-all
```

### Understanding Test Output

**When tests PASS:**
```
User
  validations
    ✓ should validate presence of name
    ✓ should validate uniqueness of email

Finished in 1.23 seconds
4 examples, 0 failures
```
✅ All good! Cleanup happens automatically.

**When tests FAIL:**
```
User
  validations
    ✗ should validate presence of name (FAILED - 1)

Failures:

  1) User validations should validate presence of name
     Failure/Error: expect(user).to validate_presence_of(:name)
     # ./spec/models/user_spec.rb:12
```
❌ The error shows:
- Which test failed
- What the error was
- File path and line number (`spec/models/user_spec.rb:12`)

### What Happens Behind the Scenes

**With `SETUP_DB=true`:**
1. Stops any conflicting databases
2. Starts Docker postgres + redis
3. Sets up test database schema
4. Runs tests

**Normal run (no flags):**
1. Runs tests (assumes DB already running)

**With `CLEANUP=true`:**
1. Runs tests
2. Stops Docker containers

---

## Frontend Testing (Vitest)

### What You Need

- Node.js 23.x installed
- pnpm installed
- Dependencies installed (`pnpm install`)

### Task Commands Reference

| Command | What It Does |
|---------|-------------|
| `task test-frontend-all` | Run ALL frontend tests |
| `task test-frontend-watch` | Interactive watch mode |
| `task test-frontend-coverage` | Run with coverage |

### Basic Usage

**Run all frontend tests:**
```bash
task test-frontend-all
```

**Run tests with auto-reload (for active development):**
```bash
task test-frontend-watch
```

**Run tests with coverage report:**
```bash
task test-frontend-coverage
```

### Understanding Test Output

**When tests PASS:**
```
 ✓ app/javascript/dashboard/components/Button.spec.js (4)
   ✓ renders correctly
   ✓ emits click event
   ✓ applies correct classes
   ✓ handles disabled state

 Test Files  1 passed (1)
      Tests  4 passed (4)
```
✅ All good!

**When tests FAIL:**
```
 ✗ app/javascript/dashboard/components/Button.spec.js (1 failed)
   ✗ emits click event

 FAIL  emits click event
 AssertionError: expected "click" to have been emitted 1 times, but got 0 times
```
❌ The error shows:
- Which test failed
- What assertion failed
- Expected vs actual behavior

### No Setup Required

Frontend tests run directly - no database or Docker needed!

---

## Process Checklist

### For Backend Tests

**Running tests:**
- [ ] Run: `task test-backend-all` (or module/file variant)
- [ ] Capture exit code and output
- [ ] Check if tests passed (exit code 0)

**If tests fail:**
- [ ] Read error messages
- [ ] Note file paths and line numbers
- [ ] Report failures with context

**Cleanup:**
- [ ] Verify cleanup happened (check `docker ps`)
- [ ] If needed, manually run: `task test-cleanup`

### For Frontend Tests

**Running tests:**
- [ ] Run: `task test-frontend-all` (or watch/coverage)
- [ ] Capture exit code and output
- [ ] Check if tests passed (exit code 0)

**If tests fail:**
- [ ] Read error messages
- [ ] Note file paths
- [ ] Report failures with context

---

## Related Documentation

### Process Documentation
- [API Testing Process](./api_testing_process.md) - API endpoint testing
- [Development Process](../development/development_process.md) - Full development workflow
- [Code Review Process](../code_review/code_review_process.md) - Code review procedures

### Technical Documentation
- [CLAUDE.md](/CLAUDE.md) - Commands, guidelines, and troubleshooting
- [Taskfile.yml](/Taskfile.yml) - All available task commands

### Testing Frameworks
- [RSpec Documentation](https://rspec.info/) - Backend testing framework
- [Vitest Documentation](https://vitest.dev/) - Frontend testing framework
- [FactoryBot](https://github.com/thoughtbot/factory_bot) - Test data factories

---

## Changelog

### Version 2.0.0 (2025-10-09)

**Status**: Active

**Changes:**
- Removed "Common Issues & Solutions" section (now in separate troubleshooting guide)
- Removed "Detailed Workflow" section (commands handle this automatically)
- Removed "Manual Setup/Cleanup" commands (rarely needed, available in Taskfile.yml)
- Streamlined Process Checklist
- 30% reduction in document size while maintaining all essential testing guidance

### Version 1.1.0 (2025-10-06)

**Status**: Superseded

**Changes:**
- Simplified structure for better readability
- Added "Quick Start" section at the top
- Replaced complex decision tree with "Simple Decision Guide"
- Condensed command reference into tables
- Simplified test output examples

---

**End of Document**
