# Fork Sync Process Guide

**Version**: 1.1.0
**Last Updated**: 2025-10-31
**Status**: Active
**Document Type**: Process Guide
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Table of Contents

1. [Overview](#overview)
2. [Key Principles](#key-principles)
3. [Process Workflow](#process-workflow)
4. [Phase 1: Pre-Sync Preparation](#phase-1-pre-sync-preparation)
5. [Phase 2: Sync Branch Creation](#phase-2-sync-branch-creation)
6. [Phase 3: Merge Execution](#phase-3-merge-execution)
7. [Phase 4: Conflict Resolution](#phase-4-conflict-resolution)
8. [Phase 5: Validation & Testing](#phase-5-validation--testing)
9. [Phase 6: PR Creation & Merge](#phase-6-pr-creation--merge)
10. [Process Checklist](#process-checklist)
11. [Related Documentation](#related-documentation)
12. [Changelog](#changelog)

---

## Overview

### Purpose

This process ensures systematic and safe synchronization of upstream Chatwoot changes into our forked development branch, minimizing conflicts and preventing regressions while maintaining our custom features.

**Problem Statement**: We maintain a fork of Chatwoot with custom features. Periodically, we need to pull upstream changes from the original Chatwoot repository (`develop` branch) into our active development branch (`development`), but doing this directly risks breaking our custom code and losing track of conflicts.

**Solution**: Use a dedicated sync branch to merge, resolve conflicts carefully, test thoroughly, and then merge into our main development branch via PR.

### Scope

**What is Covered**:
- Creating dedicated sync branches for upstream merges
- Merging upstream changes (from `develop` to sync branch)
- Systematic conflict resolution (backend + frontend)
- Testing merged changes (RSpec + Vitest + manual validation)
- PR creation and code review
- Documentation of merge decisions and learnings

**What is NOT Covered**:
- Emergency hotfixes (use expedited process)
- Feature development during sync (freeze development on affected areas)
- Infrastructure/deployment changes (separate process)
- Database migration conflicts (requires DBA review)

### When to Use This Process

**ALWAYS Use This Process For**:
- Syncing upstream Chatwoot releases (e.g., 4.4.0, 4.5.0)
- Pulling upstream security patches
- Periodic sync to stay up-to-date with Chatwoot development
- Any merge from `develop` (upstream) to `development` (our fork)

**SKIP This Process For**:
- Regular feature branch merges into `development`
- Hotfixes that don't involve upstream sync
- Documentation-only changes

### Process Summary

This process involves creating a dedicated sync branch (e.g., `chore/sync-fork-4.4.0`) from our `development` branch, merging upstream `develop` into it, carefully resolving all conflicts by understanding both sides of changes, validating with comprehensive testing, and finally creating a PR to merge into `development`.

**Key Participants**:
- **Developer**: Executes merge, resolves conflicts, writes tests
- **Code Reviewer**: Reviews conflict resolutions and validates decisions
- **QA/Team**: Tests merged changes in staging environment

**Main Outputs**:
- Merged sync branch with all conflicts resolved
- Test suite passing (RSpec + Vitest)
- PR with detailed description of merge decisions
- Updated documentation of sync learnings

**Typical Duration**: 2-5 days depending on conflict complexity

---

## Key Principles

### Core Principles

1. **Principle 1: Systematic Conflict Analysis**
   - Never auto-resolve conflicts blindly
   - Always understand BOTH sides: what upstream changed, what we changed
   - Document reasoning for each conflict resolution decision
   - Prefer upstream implementation unless we have custom business logic
   - **Why it matters**: Prevents accidentally losing custom features or breaking upstream improvements
   - **Example**: If upstream refactors a service and we added custom fields, preserve both changes

2. **Principle 2: Isolated Sync Branch**
   - Always create a dedicated branch for sync (never merge directly to `development`)
   - Branch naming: `chore/sync-fork-[version]` (e.g., `chore/sync-fork-4.4.0`)
   - This branch is temporary and deleted after successful merge
   - **Why it matters**: Allows safe experimentation, easy rollback, and peer review before affecting main branch
   - **Example**: `chore/sync-fork-4.4.0` branched from `development`, merges `develop`, then PR to `development`

3. **Principle 3: Test-Driven Validation**
   - Run full test suite after merge (backend + frontend)
   - Fix all test failures before creating PR
   - Add new tests for custom code affected by upstream changes
   - Manual smoke testing of critical features (auth, messaging, integrations)
   - **Why it matters**: Ensures merged code works correctly and doesn't break existing functionality
   - **Example**: After merging upstream changes to messaging service, run all message-related specs

4. **Principle 4: Documentation of Decisions**
   - Document complex conflict resolutions in commit messages
   - Update this process guide with learnings from each sync
   - Maintain a sync log with date, version, major conflicts, and resolutions
   - **Why it matters**: Builds institutional knowledge, helps future syncs, aids debugging
   - **Example**: "Resolved conflict in IncomingMessageService by preserving our custom rate limiting while adopting upstream error handling improvements"

### Success Criteria

The process is successful when:
- [ ] All upstream changes merged without data loss
- [ ] All custom features preserved and functional
- [ ] All tests passing (RSpec + Vitest + Rubocop + ESLint)
- [ ] No regressions in existing functionality
- [ ] Code review approved by at least one senior developer
- [ ] Sync learnings documented in this guide
- [ ] PR merged successfully into `development`

---

## Process Workflow

### Process Flow Diagram

```
[Stage 1: Pre-Sync Preparation]
    ↓
[Stage 2: Sync Branch Creation]
    ↓
[Stage 3: Merge Execution] → [Decision: Conflicts?]
    ↓ Yes                        ↓ No
[Stage 4: Conflict Resolution]   [Skip to Stage 5]
    ↓                             ↓
[Stage 5: Validation & Testing]
    ↓
[Stage 6: PR Creation & Merge]
```

### Phase Summary Table

| Phase | Objective | Deliverable | Owner | Duration |
|-------|-----------|-------------|-------|----------|
| 1. Pre-Sync Preparation | Ensure environment ready, understand upstream changes, **analyze fork changes** | Changelog review, clean working tree, **fork analysis document** | Developer | **2-3 hours** |
| 2. Sync Branch Creation | Create isolated branch for merge | Sync branch created and pushed | Developer | 10 min |
| 3. Merge Execution | Merge upstream into sync branch | Merge commit (with or without conflicts) | Developer | 10-30 min |
| 4. Conflict Resolution | Resolve all conflicts systematically | Conflict-free codebase | Developer | 2-8 hours |
| 5. Validation & Testing | Run tests, fix failures, manual testing | All tests passing, no regressions | Developer + QA | 2-4 hours |
| 6. PR Creation & Merge | Document changes, get review, merge | PR merged to `development` | Developer + Reviewer | 1-2 days |
| **Total** | | | | **2-5 days** |

### Dependencies & Prerequisites

**Prerequisites**:
- Development environment set up (see Taskfile.yml)
- Clean working tree (no uncommitted changes in `development`)
- All local tests passing on `development` before sync
- Access to upstream repository (fetch permissions)
- Understanding of custom features in our fork
- **Sync artifacts directory created**: `docs/ignored/fork_sync_[version]_[date]/`
- **Execution document created** from [FORK_SYNC_EXECUTION_TEMPLATE.md](./FORK_SYNC_EXECUTION_TEMPLATE.md) at `docs/ignored/fork_sync_[version]_[date]/execution.md`

**Dependencies**:
- Git configured with upstream remote
- Docker environment running (for testing)
- Staging environment available (for validation)
- Code reviewer available for PR review

---

## Phase 1: Pre-Sync Preparation

**Objective**: Ensure the development environment is ready and understand what upstream changes are being merged

**Duration**: 30-60 minutes

**Owner**: Developer

**Prerequisites**:
- Git repository access
- Development environment running

### Step 1.1: Review Upstream Changes

**Description**: Understand what has changed in the upstream repository since our last sync

**Actions**:
1. Fetch latest upstream changes:
   ```bash
   git fetch origin develop
   ```

2. Review upstream changelog/release notes for the target version (e.g., Chatwoot 4.4.0 release notes)

3. Identify high-risk areas:
   - Database schema changes (new migrations)
   - Breaking API changes
   - Major refactorings in areas we've customized
   - Dependency updates (Gemfile, package.json)

4. List custom features in our fork that might conflict:
   - Custom services (e.g., Whatsapp integrations, custom tools)
   - Custom models or fields
   - Custom UI components
   - Custom API endpoints

**Expected Output**:
- List of major upstream changes
- List of potential conflict areas
- Understanding of merge complexity

**Verification**:
- [ ] Upstream changelog reviewed
- [ ] High-risk areas identified
- [ ] Custom features documented

**Common Issues**:
- **Issue**: Can't fetch upstream changes → Ensure upstream remote is configured: `git remote -v`

### Step 1.2: Create Fork Analysis Document

**Description**: Analyze all fork-exclusive changes since last sync and create a comprehensive reference document

**Rationale**: This analysis serves as a critical reference during conflict resolution, ensuring no fork-specific features are accidentally removed when merging upstream changes. It documents all business-critical customizations, helping you make informed decisions during merge conflicts.

**Actions**:
1. Find the last common commit between `development` and `develop`:
   ```bash
   git merge-base development develop
   # Save this commit hash (e.g., b8814a8bd...)
   ```

2. Analyze commits made exclusively in `development` since last sync:
   ```bash
   # Count total commits
   git log --oneline --no-merges [merge-base-hash]..development | wc -l

   # Get detailed commit history
   git log [merge-base-hash]..development --oneline --no-merges

   # Get file change statistics
   git diff --stat [merge-base-hash]..development
   git diff --shortstat [merge-base-hash]..development
   ```

3. Create a dedicated folder for this sync's artifacts:
   ```bash
   # Pattern: docs/ignored/fork_sync_[version]_[date]/
   mkdir -p docs/ignored/fork_sync_4.4.0_2025-10-31
   ```

4. Create analysis document at `docs/ignored/fork_sync_[version]_[date]/fork_analysis.md`:
   - Document all major fork-specific features (with file locations)
   - List critical files by conflict risk (Critical/Medium/Low)
   - Document environment variables added by fork
   - Create conflict resolution strategy guide
   - List features that MUST be preserved during merge

   **Template sections to include**:
   - Executive Summary (commit count, files changed, risk level)
   - Critical Fork-Specific Features (detailed breakdown)
   - Files to Watch During Merge (prioritized by risk)
   - Merge Conflict Resolution Strategy
   - Environment Variables (fork-specific)
   - Quick Reference (top modified files)

   **⚠️ Important**: All sync-specific artifacts (analysis, notes, execution log) should be stored in `docs/ignored/fork_sync_[version]_[date]/` directory. This directory is gitignored and won't be committed, keeping the repository clean while preserving artifacts locally for reference.

5. Review the analysis document and validate completeness:
   - Verify all major custom features are documented
   - Ensure file paths are accurate
   - Check that risk assessments are realistic
   - Confirm merge strategies are actionable

**Expected Output**:
```markdown
docs/ignored/fork_sync_4.4.0_2025-10-31/ directory created
docs/ignored/fork_sync_4.4.0_2025-10-31/fork_analysis.md created

Contents include:
- 213 commits analyzed
- 2,405 files changed
- Critical features documented (AI Backend, WHAPI, Stripe, etc.)
- Risk assessment by feature area
- Conflict resolution strategies
- Top 20 most modified files
```

**Verification**:
- [ ] Merge-base commit identified
- [ ] Fork-exclusive commits analyzed (count and content)
- [ ] Sync artifacts directory created: `docs/ignored/fork_sync_[version]_[date]/`
- [ ] Analysis document created at: `docs/ignored/fork_sync_[version]_[date]/fork_analysis.md`
- [ ] All critical fork features documented with file paths
- [ ] Files categorized by conflict risk level
- [ ] Merge resolution strategies documented
- [ ] Environment variables documented

**Common Issues**:
- **Issue**: Can't find merge-base → Ensure `develop` branch is fetched: `git fetch origin develop`
- **Issue**: Too many changes to analyze → Focus on high-impact areas first (services, models, controllers, major components)
- **Issue**: Unclear which features are fork-specific → Review git log messages and identify commits not from upstream

**Time Required**: 1-2 hours (depending on number of fork-specific commits)

**⚠️ Important**: This step is **critical** for complex syncs with many fork-specific features. Do not skip it! The analysis document will be your reference throughout the entire conflict resolution process.

### Step 1.3: Clean Working Tree

**Description**: Ensure local `development` branch is clean and up-to-date

**Actions**:
1. Switch to `development` branch:
   ```bash
   git checkout development
   ```

2. Ensure no uncommitted changes:
   ```bash
   git status
   # Should show: "nothing to commit, working tree clean"
   ```

3. Pull latest changes from our `development`:
   ```bash
   git pull origin development
   ```

4. Run tests to ensure baseline is healthy:
   ```bash
   task test-backend-all
   pnpm test
   ```

**Expected Output**:
```
On branch development
Your branch is up to date with 'origin/development'.

nothing to commit, working tree clean

Tests: ✓ All passing
```

**Verification**:
- [ ] Working tree is clean
- [ ] `development` is up-to-date with remote
- [ ] All tests passing on `development`

**Common Issues**:
- **Issue**: Uncommitted changes → Stash them: `git stash` (or commit to feature branch)
- **Issue**: Tests failing on `development` → Fix tests before proceeding with sync

### Phase 1 Deliverable

**Output**: Clean environment ready for merge + Fork analysis document created

**Quality Check**:
- [ ] Upstream changes understood
- [ ] Fork sync artifacts directory created: `docs/ignored/fork_sync_[version]_[date]/`
- [ ] Fork analysis document created: `docs/ignored/fork_sync_[version]_[date]/fork_analysis.md`
- [ ] All critical fork features documented
- [ ] Conflict risk assessment completed
- [ ] `development` branch is clean and tested
- [ ] Conflict areas identified
- [ ] Team notified of upcoming sync (optional)

---

## Phase 2: Sync Branch Creation

**Objective**: Create an isolated branch for the merge operation

**Duration**: 10 minutes

**Owner**: Developer

**Prerequisites**:
- Phase 1 complete
- On `development` branch with clean working tree

### Step 2.1: Create Sync Branch

**Description**: Create a new branch for the upstream merge

**Actions**:
1. Create branch following naming convention:
   ```bash
   # Pattern: chore/sync-fork-[version-or-date]
   git checkout -b chore/sync-fork-4.4.0
   ```

2. Push branch to remote immediately:
   ```bash
   git push -u origin chore/sync-fork-4.4.0
   ```

3. Verify branch creation:
   ```bash
   git branch
   git status
   ```

**Expected Output**:
```
Switched to a new branch 'chore/sync-fork-4.4.0'
Branch 'chore/sync-fork-4.4.0' set up to track remote branch 'chore/sync-fork-4.4.0' from 'origin'.
```

**Verification**:
- [ ] New branch created from `development`
- [ ] Branch pushed to remote
- [ ] Branch name follows convention

**Common Issues**:
- **Issue**: Branch already exists → Delete old branch: `git branch -D chore/sync-fork-4.4.0` and try again

### Phase 2 Deliverable

**Output**: Sync branch ready for merge

**Location**: Local and remote repository

**Format**: Git branch named `chore/sync-fork-[version]`

**Quality Check**:
- [ ] Branch created from latest `development`
- [ ] Branch pushed to remote
- [ ] Ready to merge upstream changes

---

## Phase 3: Merge Execution

**Objective**: Execute the merge from upstream `develop` into our sync branch

**Duration**: 10-30 minutes

**Owner**: Developer

**Prerequisites**:
- Phase 2 complete
- On sync branch (`chore/sync-fork-4.4.0`)

### Step 3.1: Execute Merge Command

**Description**: Merge upstream `develop` branch into current sync branch

**Actions**:
1. Ensure you're on the sync branch:
   ```bash
   git branch --show-current
   # Should show: chore/sync-fork-4.4.0
   ```

2. Execute merge:
   ```bash
   git merge develop --no-ff
   ```

3. Git will either:
   - **Auto-merge successfully**: Proceed to Phase 5 (Validation)
   - **Report conflicts**: Proceed to Phase 4 (Conflict Resolution)

**Expected Output (No Conflicts)**:
```
Merge made by the 'recursive' strategy.
 [list of changed files]
```

**Expected Output (With Conflicts)**:
```
Auto-merging [file]
CONFLICT (content): Merge conflict in [file]
Automatic merge failed; fix conflicts and then commit the result.
```

**Verification**:
- [ ] Merge command executed
- [ ] Conflict status identified
- [ ] If no conflicts: merge commit created
- [ ] If conflicts: conflict files identified

**Common Issues**:
- **Issue**: "fatal: refusing to merge unrelated histories" → Check that branches share common history

### Step 3.2: Assess Merge Status

**Description**: Understand the scope of conflicts (if any)

**Actions**:
1. Check merge status:
   ```bash
   git status
   ```

2. List all conflicted files:
   ```bash
   git diff --name-only --diff-filter=U
   ```

3. Categorize conflicts:
   - Backend conflicts (Ruby files in `app/`, `lib/`, `spec/`)
   - Frontend conflicts (Vue/JS files in `app/javascript/`)
   - Configuration conflicts (Gemfile, package.json, docker-compose, etc.)
   - Migration conflicts (`db/migrate/`)
   - Documentation conflicts (`docs/`, `README.md`)

**Expected Output**:
```
Unmerged paths:
  (use "git add <file>..." to mark resolution)
        both modified:   app/services/whatsapp/incoming_message_service.rb
        both modified:   app/javascript/dashboard/components/MessageBubble.vue
        both modified:   Gemfile.lock
```

**Verification**:
- [ ] All conflicted files identified
- [ ] Conflicts categorized by type
- [ ] Merge complexity assessed

### Phase 3 Deliverable

**Output**: Merge initiated with clear understanding of conflicts

**Quality Check**:
- [ ] Merge executed from `develop`
- [ ] Conflict list documented
- [ ] Ready to resolve conflicts (or skip to validation if auto-merged)

---

## Phase 4: Conflict Resolution

**Objective**: Systematically resolve all merge conflicts while preserving both upstream improvements and our custom features

**Duration**: 2-8 hours (depends on conflict count and complexity)

**Owner**: Developer

**Prerequisites**:
- Phase 3 complete with conflicts identified
- Understanding of both upstream and custom changes
- **Fork analysis document** from Phase 1 (Step 1.2) available for reference

**⚠️ Critical Reference**: Throughout this phase, **constantly refer to the fork analysis document** (`docs/ignored/fork_sync_[version]_[date]/fork_analysis.md`) created in Phase 1. This document lists:
- Critical fork-specific features that MUST be preserved
- Files categorized by conflict risk level
- Detailed context for why each change was made
- Merge resolution strategies for each feature area
- Environment variables and configuration changes

**Before resolving each conflict**, check the analysis document to understand:
1. Is this file part of a critical fork feature?
2. What fork-specific logic exists in this file?
3. What merge strategy is recommended?

### Step 4.1: Resolve Backend Conflicts (Ruby)

**Description**: Resolve conflicts in Ruby files (models, services, controllers, specs)

**Actions**:
1. Open first conflicted Ruby file (use editor with merge conflict support):
   ```bash
   # Example conflict in a service file
   code app/services/whatsapp/incoming_message_service.rb
   ```

2. Analyze conflict markers:
   ```ruby
   <<<<<<< HEAD (our changes in sync branch)
   # Our custom code
   =======
   # Upstream code
   >>>>>>> develop (upstream changes)
   ```

3. For each conflict, determine resolution strategy:
   - **Strategy A: Take Upstream** - Upstream refactored/improved, we had minor changes → Use upstream version
   - **Strategy B: Take Ours** - We have critical custom logic → Keep our version
   - **Strategy C: Merge Both** - Both changes are necessary → Integrate both (most common)
   - **Strategy D: Rewrite** - Both sides changed fundamentally → Rewrite to combine intent

4. Resolve conflict by editing file and removing conflict markers

5. Mark file as resolved:
   ```bash
   git add app/services/whatsapp/incoming_message_service.rb
   ```

6. Repeat for all Ruby conflicts

**Example Resolution (Strategy C: Merge Both)**:
```ruby
# Conflict:
<<<<<<< HEAD
def process_message(message)
  # Our custom validation
  return unless valid_custom_format?(message)

  create_message(message)
end
=======
def process_message(message)
  # Upstream added error handling
  create_message(message)
rescue StandardError => e
  log_error(e)
  raise
end
>>>>>>> develop

# Resolution (merge both):
def process_message(message)
  # Our custom validation (preserved)
  return unless valid_custom_format?(message)

  # Upstream error handling (adopted)
  create_message(message)
rescue StandardError => e
  log_error(e)
  raise
end
```

**Verification**:
- [ ] All Ruby conflicts resolved
- [ ] Code follows Rails conventions
- [ ] No syntax errors (check with `bundle exec rubocop [file]`)
- [ ] Resolution reasoning documented in notes

**Common Issues**:
- **Issue**: Unsure which version to keep → **First**, check the fork analysis document for this file's context and recommended strategy. **Then**, check git history: `git log -p [file]` to understand intent
- **Issue**: Both sides refactored completely → **First**, check if the file is listed as critical in the analysis document. If yes, prioritize preserving fork logic. **Then**, consult team/reviewer before resolving

### Step 4.2: Resolve Frontend Conflicts (Vue/JS)

**Description**: Resolve conflicts in Vue components and JavaScript files

**Actions**:
1. Open conflicted Vue/JS file:
   ```bash
   code app/javascript/dashboard/components/MessageBubble.vue
   ```

2. Analyze conflict (same process as backend):
   - Understand upstream changes (new features, refactors)
   - Understand our custom changes (custom fields, custom logic)
   - Decide resolution strategy

3. Resolve conflict and remove markers

4. Mark as resolved:
   ```bash
   git add app/javascript/dashboard/components/MessageBubble.vue
   ```

5. Lint the file:
   ```bash
   pnpm eslint:fix app/javascript/dashboard/components/MessageBubble.vue
   ```

**Example Resolution (Template Conflict)**:
```vue
<!-- Conflict in template -->
<<<<<<< HEAD
<div class="message-bubble bg-blue-500">
  <span>{{ ourCustomField }}</span>
  <span>{{ message.content }}</span>
</div>
=======
<div class="message-bubble bg-primary-500">
  <MessageContent :message="message" />
</div>
>>>>>>> develop

<!-- Resolution: adopt upstream component structure, add our custom field -->
<div class="message-bubble bg-primary-500">
  <span v-if="ourCustomField" class="custom-field">{{ ourCustomField }}</span>
  <MessageContent :message="message" />
</div>
```

**Verification**:
- [ ] All Vue/JS conflicts resolved
- [ ] Code follows Composition API patterns (if `<script setup>`)
- [ ] Tailwind classes used (no custom CSS)
- [ ] No linting errors
- [ ] i18n keys preserved (no hardcoded strings)

### Step 4.3: Resolve Configuration Conflicts

**Description**: Resolve conflicts in package.json, Gemfile, docker-compose.yml, etc.

**Actions**:
1. Identify configuration conflicts:
   ```bash
   git status | grep -E "(package.json|Gemfile|docker-compose)"
   ```

2. For **dependency conflicts** (Gemfile, package.json):
   - Generally prefer upstream versions (they've tested compatibility)
   - Keep our custom dependencies
   - Check for version conflicts

3. For **Gemfile.lock / package-lock.json / pnpm-lock.yaml**:
   - Delete the file and regenerate:
   ```bash
   rm Gemfile.lock
   bundle install

   rm pnpm-lock.yaml
   pnpm install
   ```

4. For **docker-compose.yml**:
   - Merge both sets of services/volumes
   - Prefer upstream base configuration
   - Preserve our custom environment variables

5. Mark as resolved:
   ```bash
   git add Gemfile Gemfile.lock package.json pnpm-lock.yaml docker-compose.yml
   ```

**Verification**:
- [ ] All dependency conflicts resolved
- [ ] Lock files regenerated
- [ ] Bundle install succeeds
- [ ] Pnpm install succeeds
- [ ] Docker compose validates: `docker compose config`

**Common Issues**:
- **Issue**: Dependency version conflicts → Check compatibility, may need to upgrade/downgrade
- **Issue**: Docker compose errors → Validate syntax with `docker compose config`

### Step 4.4: Resolve Migration Conflicts

**Description**: Handle database migration conflicts (rare but critical)

**Actions**:
1. Check for migration conflicts:
   ```bash
   git status | grep db/migrate
   ```

2. If migrations conflict:
   - **DO NOT merge migration files** - migrations must remain immutable
   - Keep both migration files
   - Rename ours if timestamps conflict: `rails db:migrate:rename[old_version,new_version]`
   - Ensure migration order is correct

3. If schema.rb conflicts:
   - Delete schema.rb and regenerate:
   ```bash
   rm db/schema.rb
   rails db:migrate
   git add db/schema.rb
   ```

**Verification**:
- [ ] All migrations preserved
- [ ] No duplicate timestamps
- [ ] Schema.rb regenerated
- [ ] `rails db:migrate:status` shows all migrations

**Common Issues**:
- **Issue**: Migration timestamp conflict → Rename our migration to later timestamp
- **Issue**: Schema.rb conflicts → Always regenerate, never manually merge

### Step 4.5: Commit Merge Resolution

**Description**: Finalize merge after all conflicts resolved

**Actions**:
1. Verify all conflicts resolved:
   ```bash
   git status
   # Should show: "All conflicts fixed but you are still merging."
   ```

2. Run linters:
   ```bash
   bundle exec rubocop -a
   pnpm eslint:fix
   ```

3. Commit the merge:
   ```bash
   git commit -m "$(cat <<'EOF'
   chore: merge upstream develop (v4.4.0) into sync branch

   Merged upstream Chatwoot v4.4.0 changes into sync branch.

   Key conflict resolutions:
   - IncomingMessageService: merged upstream error handling with our custom validation
   - MessageBubble.vue: adopted upstream component structure, preserved custom fields
   - Gemfile: upgraded to upstream dependency versions, kept custom gems
   - db/schema.rb: regenerated after resolving migration order

   All tests passing. Ready for validation phase.

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

4. Push merge commit:
   ```bash
   git push origin chore/sync-fork-4.4.0
   ```

**Expected Output**:
```
[chore/sync-fork-4.4.0 abc1234] chore: merge upstream develop (v4.4.0) into sync branch
 X files changed, Y insertions(+), Z deletions(-)
```

**Verification**:
- [ ] All conflicts resolved
- [ ] Merge commit created
- [ ] Changes pushed to remote

### Phase 4 Deliverable

**Output**: Fully merged codebase with all conflicts resolved

**Quality Check**:
- [ ] No remaining conflict markers in code
- [ ] All files added to git
- [ ] Linters passing
- [ ] Merge commit created with descriptive message
- [ ] Conflict resolutions documented

---

## Phase 5: Validation & Testing

**Objective**: Ensure merged code works correctly and doesn't break existing functionality

**Duration**: 2-4 hours

**Owner**: Developer + QA

**Prerequisites**:
- Phase 4 complete (all conflicts resolved and committed)
- Docker environment running

### Step 5.1: Run Backend Tests

**Description**: Run full RSpec test suite to catch regressions

**Actions**:
1. Setup test database (if needed):
   ```bash
   SETUP_DB=true task test-backend-all
   ```

2. Run full test suite:
   ```bash
   task test-backend-all
   ```

3. If tests fail:
   - Identify failure root cause (merge conflict resolution error?)
   - Fix the failing test or code
   - Re-run tests until all pass

4. Run linter:
   ```bash
   bundle exec rubocop -a
   ```

**Expected Output**:
```
Finished in X.XX seconds (files took X.XX seconds to load)
XXXX examples, 0 failures

RuboCop: no offenses detected
```

**Verification**:
- [ ] All RSpec tests passing
- [ ] No Rubocop violations
- [ ] Test coverage maintained or improved

**Common Issues**:
- **Issue**: Tests fail due to upstream breaking changes → Update test expectations to match new behavior
- **Issue**: Custom tests fail → Update tests to work with upstream changes

### Step 5.2: Run Frontend Tests

**Description**: Run Vitest test suite for Vue components and stores

**Actions**:
1. Run all frontend tests:
   ```bash
   pnpm test
   ```

2. If tests fail:
   - Check if failures are due to upstream component changes
   - Update tests or component code
   - Re-run until all pass

3. Run linter:
   ```bash
   pnpm eslint:fix
   ```

**Expected Output**:
```
✓ All tests passed (XXX tests)

ESLint: no errors, no warnings
```

**Verification**:
- [ ] All Vitest tests passing
- [ ] No ESLint errors or warnings
- [ ] Frontend builds successfully: `pnpm build` (optional)

**Common Issues**:
- **Issue**: Component tests fail → Update test to match new component structure
- **Issue**: Store tests fail → Check if upstream changed Vuex store structure

### Step 5.3: Manual Smoke Testing

**Description**: Test critical features manually to catch issues automated tests might miss

**Actions**:
1. Start development server:
   ```bash
   task docker-up
   # Wait for server to start, then visit http://localhost:3000
   ```

2. Test critical flows:
   - [ ] User authentication (login/logout)
   - [ ] Create/view conversations
   - [ ] Send/receive messages
   - [ ] Whatsapp integration (if applicable)
   - [ ] Custom features we added (check each one)

3. Check browser console for errors:
   - Open DevTools → Console
   - Should see no red errors during testing

4. Check Rails logs for errors:
   ```bash
   docker compose logs -f rails
   # Should see no exceptions or errors during testing
   ```

**Verification**:
- [ ] Login/logout works
- [ ] Core messaging features work
- [ ] Custom features functional
- [ ] No console errors
- [ ] No server errors in logs

**Common Issues**:
- **Issue**: Features broken → Investigate conflict resolution in related files
- **Issue**: JS errors → Check for missing imports or component registration issues

### Step 5.4: Review Changes

**Description**: Final review of all changed files

**Actions**:
1. Review diff of merge:
   ```bash
   git diff development...chore/sync-fork-4.4.0
   ```

2. Check for accidentally committed files:
   ```bash
   git status
   git log --oneline -10
   ```

3. Verify no sensitive data or debug code committed:
   ```bash
   git diff development...chore/sync-fork-4.4.0 | grep -E "(console.log|binding.pry|debugger|TODO|FIXME)"
   ```

**Verification**:
- [ ] All changes intentional
- [ ] No debug code committed
- [ ] No sensitive data in commits
- [ ] Commit messages clear and descriptive

### Phase 5 Deliverable

**Output**: Fully validated sync branch ready for PR

**Quality Check**:
- [ ] All tests passing (backend + frontend)
- [ ] No linting errors
- [ ] Manual testing complete
- [ ] No regressions found
- [ ] Changes reviewed and approved by developer

---

## Phase 6: PR Creation & Merge

**Objective**: Create a pull request to merge sync branch into `development` and get team approval

**Duration**: 1-2 days (includes review time)

**Owner**: Developer + Reviewer

**Prerequisites**:
- Phase 5 complete (all tests passing)
- Sync branch pushed to remote
- Ready for team review

### Step 6.1: Create Pull Request

**Description**: Create a comprehensive PR documenting the merge

**Actions**:
1. Create PR using GitHub CLI or web interface:
   ```bash
   gh pr create \
     --base development \
     --head chore/sync-fork-4.4.0 \
     --title "chore: sync upstream Chatwoot v4.4.0 into development" \
     --body "$(cat <<'EOF'
   ## Summary

   Syncs upstream Chatwoot v4.4.0 changes into our `development` branch.

   **Upstream Version**: v4.4.0
   **Merge Date**: 2025-10-31
   **Conflicts Resolved**: [Number] files

   ## Major Upstream Changes

   - Feature: [Description of upstream feature]
   - Refactor: [Description of upstream refactor]
   - Fix: [Description of upstream bug fix]
   - Dependency: [Upgraded dependencies]

   ## Conflict Resolutions

   ### Backend
   - `app/services/whatsapp/incoming_message_service.rb`: Merged upstream error handling with our custom validation logic
   - [Other backend conflicts]

   ### Frontend
   - `app/javascript/dashboard/components/MessageBubble.vue`: Adopted upstream component structure while preserving our custom fields
   - [Other frontend conflicts]

   ### Configuration
   - `Gemfile`: Upgraded to upstream dependency versions, kept our custom gems
   - `package.json`: Merged both dependency sets

   ## Testing

   - [x] All RSpec tests passing
   - [x] All Vitest tests passing
   - [x] Manual smoke testing complete
   - [x] No regressions found
   - [x] Custom features validated

   ## Test Plan for Reviewers

   - [ ] Review conflict resolution decisions (see "Conflict Resolutions" section)
   - [ ] Verify custom features still work (list critical features)
   - [ ] Check for any missed conflicts or issues
   - [ ] Run full test suite locally

   ## Risk Assessment

   **Risk Level**: [Low/Medium/High]

   **Potential Issues**:
   - [List any known issues or areas of concern]

   ## Rollback Plan

   If issues arise after merge:
   1. Revert merge commit: `git revert [merge-commit-sha]`
   2. Fix issues in new branch
   3. Re-sync with proper fixes

   Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

**Expected Output**:
```
https://github.com/[org]/[repo]/pull/XXX
```

**Verification**:
- [ ] PR created successfully
- [ ] PR description is comprehensive
- [ ] PR references correct base branch (`development`)
- [ ] PR title follows convention

### Step 6.2: Request Review

**Description**: Get team to review and approve the merge

**Actions**:
1. Assign reviewers (at least one senior developer)

2. Notify team via communication channel:
   - "PR ready for review: [link]"
   - "Please focus on conflict resolution decisions"

3. Address review feedback:
   - Make requested changes
   - Push new commits to sync branch
   - Re-request review

**Verification**:
- [ ] Reviewers assigned
- [ ] Team notified
- [ ] All review comments addressed
- [ ] PR approved by reviewer(s)

### Step 6.3: Merge PR

**Description**: Merge sync branch into `development`

**Actions**:
1. Ensure all checks passing:
   - [ ] Tests passing
   - [ ] Linters passing
   - [ ] Review approved

2. Merge PR (use GitHub interface or CLI):
   ```bash
   gh pr merge [PR-number] --merge
   ```

3. Delete sync branch:
   ```bash
   git branch -d chore/sync-fork-4.4.0
   git push origin --delete chore/sync-fork-4.4.0
   ```

4. Update local `development` branch:
   ```bash
   git checkout development
   git pull origin development
   ```

**Expected Output**:
```
✓ Pull request #XXX merged successfully
✓ Branch deleted
```

**Verification**:
- [ ] PR merged successfully
- [ ] Sync branch deleted
- [ ] Local `development` updated
- [ ] Merge commit appears in `development` history

### Step 6.4: Post-Merge Validation

**Description**: Verify merge in production-like environment

**Actions**:
1. Deploy to staging (if available):
   ```bash
   # Follow deployment process
   ```

2. Run smoke tests in staging:
   - Test critical user flows
   - Monitor error logs
   - Check for unexpected issues

3. If issues found:
   - Create hotfix branch from `development`
   - Fix issues
   - Fast-track PR and merge

**Verification**:
- [ ] Staging deployment successful
- [ ] Smoke tests passing in staging
- [ ] No critical errors in staging logs
- [ ] Team notified of successful merge

### Phase 6 Deliverable

**Output**: Sync merged successfully into `development`

**Quality Check**:
- [ ] PR merged and approved
- [ ] Sync branch deleted
- [ ] Staging validation complete
- [ ] Team notified
- [ ] Ready for production deployment (if needed)

---

## Process Checklist

### Pre-Process Setup

- [ ] Development environment ready (Docker, dependencies installed)
- [ ] Upstream changes reviewed (release notes, changelog)
- [ ] `development` branch clean and tests passing
- [ ] Custom features documented
- [ ] Team notified of upcoming sync

### Execution

- [ ] Phase 1: Pre-Sync Preparation complete
  - [ ] Upstream changes understood
  - [ ] **Fork sync directory created** (`docs/ignored/fork_sync_[version]_[date]/`)
  - [ ] **Fork analysis document created** (`docs/ignored/fork_sync_[version]_[date]/fork_analysis.md`)
  - [ ] **All critical fork features documented**
  - [ ] `development` branch clean and up-to-date
- [ ] Phase 2: Sync Branch Creation complete
  - [ ] Sync branch created and pushed
- [ ] Phase 3: Merge Execution complete
  - [ ] Merge from `develop` executed
  - [ ] Conflict status assessed
- [ ] Phase 4: Conflict Resolution complete (if conflicts existed)
  - [ ] Backend conflicts resolved
  - [ ] Frontend conflicts resolved
  - [ ] Configuration conflicts resolved
  - [ ] Migration conflicts resolved (if any)
  - [ ] Merge commit created
- [ ] Phase 5: Validation & Testing complete
  - [ ] Backend tests passing
  - [ ] Frontend tests passing
  - [ ] Manual smoke testing complete
  - [ ] Changes reviewed
- [ ] Phase 6: PR Creation & Merge complete
  - [ ] PR created with comprehensive description
  - [ ] Review approved
  - [ ] PR merged
  - [ ] Sync branch deleted
  - [ ] Post-merge validation complete

### Post-Process Completion

- [ ] All tests passing in `development`
- [ ] Staging deployment successful (if applicable)
- [ ] Team notified of merge completion
- [ ] Learnings documented (update this guide)
- [ ] Next sync scheduled (if periodic)

---

## Related Documentation

### Process Documentation

- [Development Process](../development/development_process.md) - Full development workflow
- [Code Review Process](../code_review/code_review_process.md) - Review procedures
- [PR Process](../pr/pr_process.md) - Pull request guidelines

### Technical Documentation

- [Architecture Overview](../../ARCHITECTURE.md) - Chatwoot architecture and tech stack
- [Development Guidelines](../../CLAUDE.md) - Coding standards and conventions
- [Contributing Guide](../../CONTRIBUTING.md) - Contribution guidelines

### Git Resources

- [Git Merge Documentation](https://git-scm.com/docs/git-merge)
- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Resolving Merge Conflicts](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/addressing-merge-conflicts/resolving-a-merge-conflict-using-the-command-line)

---

## Changelog

### Version 1.1.0 (2025-10-31)

**Status**: Active

**Changes**:
- **MAJOR**: Added Step 1.2 "Create Fork Analysis Document" to Phase 1
  - Mandatory pre-merge analysis of all fork-exclusive changes
  - Documents all critical fork features with file locations
  - Creates risk assessment (Critical/Medium/Low) for conflict-prone files
  - Provides merge resolution strategies for each feature area
  - Serves as reference guide throughout conflict resolution
- Updated Phase 4 prerequisites to require analysis document
- Added critical reminder in Phase 4 to reference analysis document during conflict resolution
- Updated common issues in conflict resolution to reference analysis document first
- Updated Phase 1 deliverable checklist to include analysis document
- Modified Phase Summary Table to reflect new 1-2 hour analysis step

**Rationale**:
- Complex forks with 200+ exclusive commits require systematic analysis before merge
- Analysis document prevents accidental removal of business-critical features
- Provides context for conflict resolution decisions
- Creates institutional knowledge for future syncs

**Context**:
- Added during preparation for Chatwoot v4.4.0 sync
- Based on actual need when analyzing 213 fork-exclusive commits
- Analysis document proved essential for understanding scope of changes

### Version 1.0.0 (2025-10-31)

**Status**: Superseded by v1.1.0

**Changes**:
- Initial version of fork sync process guide
- Documented systematic approach to syncing upstream Chatwoot changes
- Established 6-phase process: Preparation → Branch Creation → Merge → Conflict Resolution → Validation → PR Merge
- Included detailed conflict resolution strategies
- Added comprehensive testing requirements
- Defined success criteria and quality checks

**Context**:
- Created during sync of Chatwoot v4.4.0 into our fork
- Based on process template structure
- Incorporates learnings from previous manual syncs

---

## Document Metadata

**Document Owner**: Development Team

**Maintained By**: Development Team

**Review Cycle**: After each major sync or quarterly

**Last Reviewed**: 2025-10-31

**Next Review Due**: 2026-01-31 (or after next major sync)

**Contact**: Development team channel for questions and feedback

---

**End of Document**
