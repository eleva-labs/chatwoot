# Unit Testing Process - AI Agent Guide

**Version**: 1.1.0
**Last Updated**: 2025-10-06
**Status**: Active
**Document Type**: Process Guide
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Overview](#overview)
3. [Simple Decision Guide](#simple-decision-guide)
4. [Task Commands Reference](#task-commands-reference)
5. [Backend Testing (RSpec)](#backend-testing-rspec)
6. [Frontend Testing (Vitest)](#frontend-testing-vitest)
7. [Common Issues & Solutions](#common-issues--solutions)
8. [Detailed Workflow](#detailed-workflow)
9. [Process Checklist](#process-checklist)

---

## Quick Start

### I need to run tests. What do I do?

**Backend tests (Ruby/RSpec):**
```bash
task test-backend-all
```
This command does everything: stops conflicting databases, sets up test database, runs all tests, and cleans up.

**Frontend tests (Vue/Vitest):**
```bash
task test-frontend-all
```
This just runs the tests. No setup needed.

**That's it!** The commands handle all complexity for you.

---

## Overview

This guide helps AI agents run unit tests in Chatwoot autonomously.

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
task test-backend-all
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

→ **NO** ❌ - Check the error output and see [Common Issues](#common-issues--solutions)

---

## Task Commands Reference

### Backend Commands (Auto Setup + Cleanup)

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `task test-backend-all` | Run ALL backend tests | Full validation, CI/CD |
| `task test-backend-module -- spec/models` | Run specific folder | Testing one area |
| `task test-backend-file -- spec/models/user_spec.rb` | Run one file | Debugging, TDD |
| `task test-backend-local -- spec/models` | Run using local DB | Faster iteration |

### Frontend Commands (No Setup Needed)

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `task test-frontend-all` | Run ALL frontend tests | Full validation |
| `task test-frontend-watch` | Interactive watch mode | Active development |
| `task test-frontend-coverage` | Run with coverage report | Check test coverage |

### Cleanup Commands (Usually Not Needed)

| Command | What It Does |
|---------|-------------|
| `task test-cleanup` | Stop database containers |
| `task test-full-cleanup` | Stop containers + delete volumes |

### Pre-flight Commands (Usually Not Needed)

| Command | What It Does |
|---------|-------------|
| `task test-check-db` | Check if database is running |
| `task test-stop-db` | Stop any databases on port 5432 |
| `task test-setup-db` | Setup test database manually |


## Backend Testing (RSpec)

### What You Need

- Docker installed and running
- Rails gems installed (`bundle install`)

### Basic Usage

**Run all backend tests:**
```bash
task test-backend-all
```

**Run tests in a specific folder:**
```bash
task test-backend-module -- spec/models
task test-backend-module -- spec/services
```

**Run a single test file:**
```bash
task test-backend-file -- spec/models/user_spec.rb
```

**Run a specific test (by line number):**
```bash
task test-backend-file -- spec/models/user_spec.rb:45
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

When you run `task test-backend-all`:
1. ✓ Stops any conflicting databases
2. ✓ Starts Docker postgres + redis
3. ✓ Sets up test database schema
4. ✓ Runs tests
5. ✓ Cleans up containers

You don't need to do any of this manually!

---

## Frontend Testing (Vitest)

### What You Need

- Node.js 23.x installed
- pnpm installed
- Dependencies installed (`pnpm install`)

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

## Common Issues & Solutions

### 1. "Port is already allocated"

**Problem:** Database already running on port 5432

**Fix:**
```bash
task test-stop-db
task test-backend-all
```

### 2. "relation does not exist" / Database schema errors

**Problem:** Test database schema is outdated

**Fix:**
```bash
task test-full-cleanup
task test-backend-all
```

### 3. "Cannot find module" (Frontend)

**Problem:** Missing dependencies or stale cache

**Fix:**
```bash
pnpm install
rm -rf node_modules/.vite
task test-frontend-all
```

### 4. "LoadError: cannot load such file"

**Problem:** Missing Ruby gems

**Fix:**
```bash
bundle install
task test-backend-all
```

### 5. Tests timeout

**Problem:** Database not responding or slow queries

**Fix:**
```bash
# Check database is running
docker ps | grep postgres

# Restart if needed
task test-setup-db
```

### 6. Docker permission denied

**Problem:** Docker daemon not running or permission issue

**Fix:**
- Start Docker Desktop
- Or check Docker daemon is running: `docker ps`

---

## Detailed Workflow

This section explains what happens step-by-step when you run tests.

### Backend Test Workflow (Automated)

When you run `task test-backend-all`, here's what happens:

**Step 1: Pre-flight Check**
- Checks if a database is running on port 5432
- Stops it if found (Docker or local PostgreSQL)

**Step 2: Setup**
- Starts Docker postgres container
- Starts Docker redis container
- Waits 3 seconds for services to start
- Runs database migrations for test environment
- Creates test database schema

**Step 3: Execute Tests**
- Runs RSpec tests
- Uses transactional fixtures (auto-rollback after each test)
- Outputs results to terminal

**Step 4: Cleanup**
- Stops postgres container
- Stops redis container

**Step 5: Report**
- Returns exit code 0 if all pass
- Returns non-zero exit code if any fail

### Frontend Test Workflow (Simple)

When you run `task test-frontend-all`:

**Step 1: Execute**
- Vitest finds all `.spec.js` files
- Runs tests in isolated environments
- No database needed

**Step 2: Report**
- Shows pass/fail results
- Returns exit code

### Key Points for AI Agents

1. **Always use task commands** - They handle all complexity
2. **Capture the exit code** - 0 = success, non-zero = failure
3. **Parse test output** - Extract file paths and line numbers from failures
4. **Report failures clearly** - Include error messages and file locations
5. **Don't skip cleanup** - Backend tests auto-cleanup, but you can manually cleanup if needed

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
- [ ] Check [Common Issues](#common-issues--solutions) section
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
- [ ] Check [Common Issues](#common-issues--solutions) section
- [ ] Report failures with context

---

## Related Documentation

**Process Documentation:**
- [API Testing Process](/docs/processes/tests/api_testing_process.md) - API endpoint testing
- [Development Process](/docs/processes/development/development_process.md) - Full development workflow

**Technical Documentation:**
- [CLAUDE.md](/CLAUDE.md) - Project guidelines and commands
- [Taskfile.yml](/Taskfile.yml) - Task automation commands

**Testing Frameworks:**
- [RSpec Documentation](https://rspec.info/) - Backend testing framework
- [Vitest Documentation](https://vitest.dev/) - Frontend testing framework
- [FactoryBot](https://github.com/thoughtbot/factory_bot) - Test data factories

---

## Revision History

### Version 1.1.0 (2025-10-06)

**Status**: Active

**Changes:**
- Simplified structure for better readability
- Added "Quick Start" section at the top
- Replaced complex decision tree with "Simple Decision Guide"
- Condensed command reference into tables
- Simplified test output examples
- Streamlined troubleshooting section
- Removed redundant "Key Principles" section
- Made workflow explanation more concise
- Simplified checklists

### Version 1.0.0 (2025-10-06)

**Status**: Superseded

**Changes:**
- Initial version with comprehensive testing process
- Task automation commands
- Pre-flight checks for database conflicts
- Auto-cleanup after tests
- Detailed troubleshooting guide

---

## Document Metadata

**Document Owner**: Development Team

**Maintained By**: Claude Code + Human Engineers

**Review Cycle**: Quarterly or after significant changes

**Last Reviewed**: 2025-10-06

**Next Review Due**: 2026-01-06

**Technology Stack**: Ruby on Rails 7.1+ | PostgreSQL | Redis | RSpec | Vitest | Docker

**Contact**: Development team channel for questions and feedback

---

**End of Document**
