# Pull Request Creation Process Guide

**Version**: 2.0.0
**Last Updated**: 2025-10-12
**Status**: Active
**Document Type**: Process Guide

---

## Table of Contents

1. [Overview](#overview)
2. [PR Types & Decision Tree](#pr-types--decision-tree)
3. [Key Principles](#key-principles)
4. [Common Process Workflow](#common-process-workflow)
5. [Phase 1: Analyze Changes](#phase-1-analyze-changes)
6. [Phase 2: Create PR Summary](#phase-2-create-pr-summary)
7. [Phase 3: Create Pull Request (Type-Specific)](#phase-3-create-pull-request-type-specific)
8. [Best Practices](#best-practices)
9. [Process Checklist](#process-checklist)
10. [Templates & Examples](#templates--examples)
11. [Troubleshooting](#troubleshooting)
12. [Quick Reference](#quick-reference)
13. [Related Documentation](#related-documentation)
14. [Changelog](#changelog)

---

## Overview

### Purpose

This process documents how to create pull requests across all workflow stages, from feature development to production releases, ensuring appropriate documentation and review workflows for each PR type.

### Scope

**What is Covered**:
- **Feature PRs**: Feature branches to `development`
- **Bug Fix/Hotfix PRs**: Bug fixes to `development` or critical fixes to `main`
- **Release PRs**: `development` to `main` (production releases)
- Analyzing commit history and code changes
- Creating type-appropriate PR documentation
- Generating pull request titles and descriptions
- Creating PRs via GitHub CLI

**What is NOT Covered**:
- Draft PRs for early feedback
- WIP (Work in Progress) PRs
- Code review process after PR creation
- Merge strategies and conflict resolution
- Deployment procedures

### Process Summary

This process provides a flexible framework for creating well-documented pull requests. It includes common phases that all PRs go through (analyzing changes, creating summaries) and type-specific guidance for the final PR creation step. The process adapts based on whether you're creating a feature PR (5-10 minutes), bug fix/hotfix PR (3-7 minutes), or release PR (15-30 minutes).

---

## PR Types & Decision Tree

### Overview of PR Types

Our workflow supports three distinct types of pull requests, each with specific purposes, naming conventions, and documentation requirements:

#### 1. Feature PRs 🚀

**Branch Flow**: `feature/<name>` → `development`

**Purpose**: Introduce new functionality or significant enhancements to existing features

**Characteristics**:
- Single feature or tightly-related set of changes
- Focused scope with clear functional boundaries
- Technical details are acceptable when needed
- Moderate documentation depth

**Naming Convention**:
```
feat: <Brief description>
Feature: <Name of feature>
```

**Examples**:
- `feat: Add WhatsApp QR code authentication`
- `Feature: Content templates for quick replies`

**Documentation Level**: **Medium**
- What was added (feature description)
- Why it was needed (business context)
- How to use/test it
- Related tickets/issues
- File-level details acceptable if clarifying complex changes

---

#### 2. Bug Fix/Hotfix PRs 🐛🔥

**Branch Flow**:
- Bug fixes: `bugfix/<name>` → `development`
- Hotfixes: `hotfix/<name>` → `main`

**Purpose**: Correct errors, resolve issues, or apply critical production fixes

**Characteristics**:
- **Bug fixes**: Non-urgent fixes through normal workflow
- **Hotfixes**: Urgent production fixes bypassing development
- Narrow scope focused on the specific issue
- Clear before/after behavior description
- Root cause explanation (if relevant)

**Naming Convention**:
```
fix: <Brief description of what was fixed>
hotfix: <Critical issue description>
```

**Examples**:
- `fix: Resolve audio upload error in WhatsApp channels`
- `hotfix: Prevent duplicate reauthorization emails`

**Documentation Level**: **Focused**
- What was broken
- What was fixed
- Root cause (if known and relevant)
- How to verify the fix
- Related incident/issue references
- File-level details acceptable for hotfixes (context matters)

---

#### 3. Release PRs 🎉

**Branch Flow**: `development` → `main`

**Purpose**: Promote accumulated changes from development to production

**Characteristics**:
- Multiple features, fixes, and improvements
- Comprehensive scope covering a sprint/release cycle
- High-level, business-value focused documentation
- Stakeholder-friendly language
- Categorized by change type

**Naming Convention**:
```
Release: <Version/Sprint/Date> - <Key highlights>
```

**Examples**:
- `Release: Sprint 12 - WhatsApp Integration & UI Improvements`
- `Release: v2.3.0 - Assignment Policies & Captain Enhancements`
- `Release: 2025-10-12 - Q4 Feature Bundle`

**Documentation Level**: **Comprehensive & High-Level**
- Overview of entire release
- Changes categorized (Features, Fixes, Refactors, UI/UX, etc.)
- Business value focus (no technical jargon)
- NO file-level details (unless absolutely critical)
- Deployment notes and testing summary
- Breaking changes highlighted

---

### Decision Tree: Which PR Type Should I Use?

```
START: What are you merging?
    |
    ├─ Is this a production release? (development → main)
    |   └─ YES → [RELEASE PR]
    |
    ├─ Is this a critical production fix? (urgent, can't wait for normal cycle)
    |   └─ YES → [HOTFIX PR] (hotfix-branch → main)
    |
    ├─ Is this a bug fix? (non-urgent error correction)
    |   └─ YES → [BUG FIX PR] (bugfix-branch → development)
    |
    └─ Is this new functionality or enhancement?
        └─ YES → [FEATURE PR] (feature-branch → development)
```

### Quick Reference Table

| PR Type | From → To | Urgency | Scope | Doc Level | Duration |
|---------|-----------|---------|-------|-----------|----------|
| **Feature** | feature → dev | Normal | Single feature | Medium | 5-10 min |
| **Bug Fix** | bugfix → dev | Normal | Single issue | Focused | 3-7 min |
| **Hotfix** | hotfix → main | **URGENT** | Single critical issue | Focused | 3-7 min |
| **Release** | dev → main | Scheduled | Multiple changes | Comprehensive | 15-30 min |

---

## Key Principles

### Universal Principles (All PR Types)

1. **Right-Sized Documentation** - Match documentation depth to PR type: comprehensive for releases, focused for fixes, medium for features
2. **Clear Communication** - Write for your audience: stakeholders for releases, developers for features, incident responders for hotfixes
3. **Contextual Detail** - Use file-level details only when they clarify critical context (acceptable for features/hotfixes, avoid for releases)
4. **Traceable History** - All changes should reference commits, tickets, or incidents for audit trails

### Type-Specific Principles

**For Release PRs**:
- Categorized organization (Features, Fixes, Refactors, UI/UX, etc.)
- High-level business value focus
- NO file-level details unless absolutely critical
- Stakeholder-friendly language

**For Feature PRs**:
- Clear feature boundaries and scope
- Technical details welcome when helpful
- Business context for "why"
- Testing instructions

**For Bug Fix/Hotfix PRs**:
- Root cause identification (when known)
- Clear before/after behavior
- Verification steps
- Incident references (for hotfixes)

### Success Criteria

The process is successful when:
- [ ] PR type correctly identified
- [ ] Changes analyzed and understood
- [ ] Documentation matches PR type requirements
- [ ] PR created with appropriate title format
- [ ] Description provides necessary context for reviewers
- [ ] Base and head branches are correct

---

## Common Process Workflow

**Note**: Phases 1 and 2 are common to all PR types. Phase 3 varies based on PR type (see type-specific sections).

### Process Flow Diagram

```
[Identify PR Type] ← Use Decision Tree
    ↓
[COMMON: Phase 1 - Analyze Changes]
    ↓
[Review commit history]
    ↓
[Analyze code diffs]
    ↓
[COMMON: Phase 2 - Create PR Summary]
    ↓
[Categorize changes]
    ↓
[Document according to PR type]
    ↓
[TYPE-SPECIFIC: Phase 3 - Create Pull Request]
    ↓
    ├─ [Release PR] → Comprehensive, categorized, high-level
    ├─ [Feature PR] → Focused, with technical context
    └─ [Bug/Hotfix PR] → Issue-focused, with root cause
    ↓
[Create PR via gh CLI]
    ↓
[Verify PR created successfully]
```

### Phase Summary Table

| Phase | Objective | Scope | Deliverable | Duration |
|-------|-----------|-------|-------------|----------|
| **0. Identify Type** | Determine which PR type | All | PR type decision | 1 min |
| **1. Analyze Changes** (Common) | Understand scope of changes | All | Categorized change list | 3-15 min* |
| **2. Create Summary** (Common) | Document changes appropriately | All | PR summary draft | 2-10 min* |
| **3. Create PR** (Type-Specific) | Format and submit PR | Varies by type | Active GitHub PR | 2-5 min |

*Duration varies by PR type: Feature (shorter), Release (longer)

### Prerequisites (All PR Types)

- [ ] On the correct source branch with proper naming convention
- [ ] All changes are committed
- [ ] Branch is up-to-date with remote
- [ ] Push access to repository
- [ ] GitHub CLI (`gh`) installed and authenticated
- [ ] Target branch exists (development or main)

### Branch Naming Convention

**Format**: `<type>/<description>` or `<type>-<description>`

**Valid Types** (matches semantic commit types):
- `feat` - New features
- `fix` - Bug fixes
- `hotfix` - Critical production fixes
- `chore` - Maintenance tasks, builds, releases
- `docs` - Documentation changes
- `refactor` - Code refactoring
- `test` - Test additions or modifications
- `perf` - Performance improvements
- `ci` - CI/CD changes
- `style` - Code style/formatting changes

**Examples**:
- `feat/whatsapp-qr-auth`
- `fix/audio-upload-error`
- `hotfix/duplicate-emails`
- `chore/bump-version-0.2.0`
- `docs/update-pr-process`
- `refactor/ai-backend-service`

**Notes**:
- Use kebab-case for descriptions (lowercase with hyphens)
- Keep branch names concise but descriptive
- Both `/` and `-` separators are acceptable (prefer `/` for consistency)
- Branch names don't need to match PR titles exactly, but should use the same type prefix

---

## Phase 1: Analyze Changes

**Objective**: Understand the complete scope of changes between the source and target branches

**Duration**: 3-15 minutes (varies by PR type)
- Feature PR: 3-5 minutes
- Bug Fix/Hotfix: 2-3 minutes
- Release PR: 10-15 minutes

**Applies To**: All PR types

### Step 1.1: Review Commit History

**Actions**:
1. Get the list of commits between target and source branches
2. Review commit messages to understand the nature of changes
3. Identify patterns (features, fixes, refactors, etc.)
4. For feature/bugfix: Usually 1-5 commits; for releases: many commits

**Tools/Commands**:
```bash
# Generic format (replace BASE and HEAD with your branches)
# BASE = target branch (where you're merging TO)
# HEAD = source branch (where you're merging FROM)
git log BASE..HEAD --oneline --no-merges

# Specific examples by PR type:

# Release PR (development → main)
git log main..development --oneline --no-merges

# Feature PR (feature/my-feature → development)
git log development..feature/my-feature --oneline --no-merges

# Hotfix PR (hotfix/critical-fix → main)
git log main..hotfix/critical-fix --oneline --no-merges

# Get detailed commit messages
git log BASE..HEAD --pretty=format:"%s" --no-merges

# Count number of commits
git rev-list --count BASE..HEAD
```

**Common Issues**:
- **Issue 1**: Too many commits to review manually → Group by keywords (fix, feat, refactor, CU-)
- **Issue 2**: Unclear commit messages → Review the actual diffs for those commits

### Step 1.2: Analyze Code Differences

**Actions**:
1. Review the diff statistics to understand scope of changes
2. Identify which areas of the codebase were modified most
3. Look for patterns in file changes
4. For release PRs: Focus on high-level patterns
5. For feature/bugfix PRs: Review specific changes more closely

**Tools/Commands**:
```bash
# Generic format
git diff BASE...HEAD --stat
git diff BASE...HEAD --shortstat
git diff BASE...HEAD --name-only

# Specific examples:
# Release PR
git diff main...development --stat

# Feature PR
git diff development...feature/my-feature --stat

# Hotfix PR
git diff main...hotfix/critical-fix --stat
```

**Common Issues**:
- **Issue 1**: Too many files changed (Release PRs) → Focus on high-level patterns, not individual files
- **Issue 2**: Large diffs → Use `--stat` instead of full diff output
- **Issue 3**: Need specific file details → Acceptable for Feature/Hotfix PRs, avoid for Release PRs

### Step 1.3: Categorize Changes

**Actions**:
1. Group changes based on PR type requirements
2. Identify ticket/issue references (e.g., CU-xxxxx, incident IDs)
3. Note any breaking changes or major updates

**Categorization by PR Type**:

**Release PRs** - Comprehensive categorization:
- **Features**: New functionality added
- **Fixes**: Bug fixes and error corrections
- **Refactors**: Code improvements without functional changes
- **UI/UX**: User interface and experience improvements
- **Tests**: Test additions or modifications
- **Documentation**: Documentation updates
- **Infrastructure**: CI/CD, deployment, configuration changes
- **Integrations**: Third-party service integrations

**Feature PRs** - Simpler categorization:
- What was added/changed (main feature)
- Related changes (supporting modifications)
- Tests (if any)

**Bug Fix/Hotfix PRs** - Issue-focused:
- What was broken
- What was fixed
- Related changes (if any)

### Deliverable

**Output**: Categorized list of changes between branches

**Quality Check**:
- [ ] All commits have been reviewed
- [ ] Changes are grouped into logical categories
- [ ] Major themes/patterns are identified
- [ ] Breaking changes (if any) are noted

---

## Phase 2: Create PR Summary

**Objective**: Document all changes in a structured, reviewable format appropriate for the PR type

**Duration**: 2-10 minutes (varies by PR type)
- Feature PR: 2-5 minutes
- Bug Fix/Hotfix: 2-3 minutes
- Release PR: 5-10 minutes

**Applies To**: All PR types

### Step 2.1: Create Summary Document Structure

**Actions**:
1. Create a new PR summary document (can be temporary or stored)
2. Use the categorization from Phase 1
3. Write descriptions appropriate for PR type (see below)

**Document Structure by PR Type**:

**Release PR** (Comprehensive, high-level):
```markdown
# PR Summary: Development → Main
## Date: YYYY-MM-DD

## Overview
[2-3 sentences about the overall scope of this release]

## Features
- Feature 1 description (high-level, business value)
- Feature 2 description

## Fixes
- Fix 1 description (what was fixed, not how)
- Fix 2 description

## Refactors
- Refactor 1 description

## UI/UX Improvements
- UI change 1
- UI change 2

## Infrastructure & Configuration
- Infrastructure change 1

## Testing
- Test changes summary

## Deployment Notes
- Any special considerations
```

**Feature PR** (Moderate detail, technical context okay):
```markdown
# PR Summary: Feature - [Feature Name]

## Overview
[2-3 sentences about what this feature does and why]

## Changes
- Main feature implementation
- Supporting changes
- Related updates

## Technical Notes (optional)
- Key technical decisions
- File-level details if helpful

## Testing
- How to test this feature
```

**Bug Fix/Hotfix PR** (Focused, issue-specific):
```markdown
# PR Summary: Fix - [Issue Description]

## Issue
[What was broken/the problem]

## Root Cause
[Why it was happening, if known]

## Solution
[What was changed to fix it]

## Verification
[How to verify the fix works]

## Related
- Incident ID: [if hotfix]
- Ticket: [CU-xxxxx]
```

**Best Practices by Type**:

**Release PRs**:
- Use bullet points for readability
- Focus on WHAT changed, not HOW (no file names unless critical)
- Keep descriptions concise (one line per item)
- Use past tense (Added, Fixed, Updated)
- Business-value focused

**Feature PRs**:
- Technical details are welcome
- File-level details acceptable if clarifying
- Explain "why" for architectural decisions
- Include testing instructions

**Bug Fix/Hotfix PRs**:
- Clear before/after behavior
- Root cause explanation helpful
- File-level details acceptable
- Verification steps important

### Step 2.2: Write Descriptions

**Actions**:
1. For each category, write clear descriptions matching PR type
2. Adjust technical depth based on PR type
3. Focus on appropriate audience (stakeholders vs. developers)
4. Reference ticket IDs, incidents where applicable

**Writing Guidelines by PR Type**:

**Release PRs** (high-level only):
- ✅ "Added WhatsApp channel integration with QR code setup"
- ❌ "Updated app/controllers/api/v1/accounts/whapi_channels_controller.rb"
- ✅ "Fixed audio attachment upload errors"
- ❌ "Fixed bug in line 234 of attachment handler"

**Feature/Bug PRs** (technical detail okay):
- ✅ "Added WhatsApp QR code auth via WhapiChannel controller"
- ✅ "Fixed audio upload by preventing preview generation for audio files in AttachmentProcessor"
- ✅ "Updated conversation card layout to fix AI banner positioning issue"

### Deliverable

**Output**: Complete PR summary document with categorized changes

**Quality Check**:
- [ ] All major changes are documented
- [ ] Descriptions are clear and concise
- [ ] No specific file paths mentioned
- [ ] Business value is evident for each item
- [ ] Document is well-organized and scannable

---

## Phase 3: Create Pull Request (Type-Specific)

**Objective**: Create the pull request on GitHub with appropriate documentation for the PR type

**Duration**: 2-5 minutes

**Note**: This phase has type-specific variations. Choose the section that matches your PR type.

---

### 3A. Release PR (development → main)

**Target Audience**: Stakeholders, product managers, technical reviewers

**Title Format** (must follow semantic commit convention):
```
chore(release): v<version> - <Key highlights>
chore: release v<version> - <Key highlights>
```

**Note**: Repository enforces semantic PR titles via `.github/workflows/lint_pr.yml`. Use lowercase `chore` type (not `release` - it's not a valid semantic commit type).

**Title Examples**:
- `chore(release): v2.3.0 - WhatsApp Integration & UI Improvements`
- `chore(release): v0.1.1 - Email Fixes & Localization Updates`
- `chore: release v2.4.0 - Assignment Policies & Captain Enhancements`

**Description Format**:
```markdown
## Summary
[2-3 sentences about the overall scope and impact of this release]

## Changes

### Features
- Feature 1 (high-level, business value)
- Feature 2
- Feature 3

### Fixes
- Fix 1 (what was fixed, not how)
- Fix 2

### UI/UX Improvements
- UI improvement 1
- UI improvement 2

### Refactors
- Refactor 1 (if notable)

### Infrastructure & Configuration
- Infrastructure change 1

### Testing
- Test improvements summary

## Testing Summary
[High-level overview of testing performed]

## Deployment Notes
[Any special deployment considerations, breaking changes, migration steps]

## Breaking Changes (if any)
- Breaking change 1
- Breaking change 2
```

**Commands**:
```bash
# Verify you're on development branch
git branch --show-current

# Push if needed
git push -u origin development

# Create Release PR
gh pr create --base main --head development \
  --title "Release: <Title>" \
  --body "$(cat pr_summary.md)"

# Or interactive mode
gh pr create --base main --head development

# Add label
gh pr edit --add-label "release"

# View PR
gh pr view --web
```

**Quality Check**:
- [ ] Title follows "Release: ..." format
- [ ] All changes categorized by type
- [ ] High-level, business-value focused
- [ ] NO file-level details (unless critical)
- [ ] Deployment notes included
- [ ] Breaking changes highlighted (if any)

---

### 3B. Feature PR (feature → development)

**Target Audience**: Technical reviewers, developers

**Title Format** (must follow semantic commit convention):
```
feat: <Brief description>
feat(<scope>): <Brief description>
```

**Note**: Repository enforces semantic PR titles via `.github/workflows/lint_pr.yml`. Always use lowercase `feat:`.

**Title Examples**:
- `feat: add WhatsApp QR code authentication`
- `feat(templates): implement content templates for quick replies`
- `feat(assignment): implement assignment policies for inbox capacity`
- `feat: AI Backend full synchronization refactor`

**Description Format**:
```markdown
## Summary
[2-3 sentences about what this feature does and why it's needed]

## Changes
- Main feature implementation
- Supporting changes
- Related updates

## Technical Notes (optional)
- Key architectural decisions
- File-level changes if relevant (e.g., "Added WhapiChannelController")
- Dependencies or prerequisites

## Testing
- How to test this feature
- Test scenarios covered
- Edge cases considered

## Related
- Ticket: CU-xxxxx
- Design: [link if applicable]
```

**Commands**:
```bash
# Verify you're on feature branch
git branch --show-current

# Push if needed
git push -u origin feature/<feature-name>

# Create Feature PR
gh pr create --base development --head feature/<feature-name> \
  --title "feat: <Description>" \
  --body "$(cat pr_summary.md)"

# Or interactive mode
gh pr create --base development --head feature/<feature-name>

# Add label
gh pr edit --add-label "feature"

# View PR
gh pr view --web
```

**Quality Check**:
- [ ] Title follows "feat:" or "Feature:" format
- [ ] Clear feature description
- [ ] Technical details included
- [ ] Testing instructions provided
- [ ] Related tickets referenced

---

### 3C. Bug Fix/Hotfix PR (bugfix → development OR hotfix → main)

**Target Audience**: Developers, incident responders (for hotfixes)

**Title Format** (must follow semantic commit convention):
```
fix: <Brief description of what was fixed>
fix(<scope>): <Brief description>
```

**Note**: Repository enforces semantic PR titles via `.github/workflows/lint_pr.yml`. Use lowercase `fix:`. For hotfixes, still use `fix:` as the type (hotfix is not a standard semantic commit type).

**Title Examples**:
- `fix: resolve audio upload error in WhatsApp channels`
- `fix(auth): prevent duplicate reauthorization emails`
- `fix(ui): correct AI banner positioning in conversation card`
- `fix(instagram): resolve contact creation issue`

**Description Format**:
```markdown
## Issue
[Clear description of what was broken/the problem]

## Root Cause
[Why it was happening - technical explanation acceptable]

## Solution
[What was changed to fix it]
- Changed X in Y
- Updated Z to handle edge case
- File-level details are fine here

## Verification Steps
1. Step to reproduce original issue
2. Step to verify fix works
3. Step to test edge cases

## Related
- Incident ID: [if hotfix]
- Ticket: CU-xxxxx
- Logs/Screenshots: [if helpful]
```

**Commands**:

**For Bug Fixes** (bugfix → development):
```bash
# Verify you're on bugfix branch
git branch --show-current

# Push if needed
git push -u origin bugfix/<bug-name>

# Create Bug Fix PR
gh pr create --base development --head bugfix/<bug-name> \
  --title "fix: <Description>" \
  --body "$(cat pr_summary.md)"

# Add label
gh pr edit --add-label "bug"

# View PR
gh pr view --web
```

**For Hotfixes** (hotfix → main):
```bash
# Verify you're on hotfix branch
git branch --show-current

# Push if needed
git push -u origin hotfix/<hotfix-name>

# Create Hotfix PR
gh pr create --base main --head hotfix/<hotfix-name> \
  --title "hotfix: <Description>" \
  --body "$(cat pr_summary.md)"

# Add labels
gh pr edit --add-label "hotfix" --add-label "urgent"

# Notify team immediately
gh pr view --web
```

**Quality Check**:
- [ ] Title follows "fix:" or "hotfix:" format
- [ ] Issue clearly described
- [ ] Root cause explained
- [ ] Solution documented with technical details
- [ ] Verification steps provided
- [ ] Incident/ticket referenced
- [ ] For hotfixes: Team notified

---

### Common Steps (All PR Types)

**Common Issues**:
- **Issue 1**: Branch not pushed → Run `git push -u origin <branch-name>`
- **Issue 2**: No permission → Check GitHub access rights
- **Issue 3**: PR already exists → Update existing PR or close it first
- **Issue 4**: Wrong base branch → Verify with `git branch --show-current` and decision tree

**After PR Creation**:
1. Open PR in browser: `gh pr view --web`
2. Verify base and head branches are correct
3. Add reviewers: `gh pr edit --add-reviewer @username`
4. Add appropriate labels
5. Share PR link with team
6. Monitor for review feedback

---

## Best Practices

### For Developers

#### Do's ✅
1. **Review Before Documenting**: Always review changes before writing the summary to understand the full scope
2. **Use Consistent Categorization**: Stick to the standard categories for consistency across PRs
3. **Focus on Business Value**: Write descriptions that non-technical stakeholders can understand
4. **Keep It Concise**: One line per change; avoid paragraphs of explanation
5. **Link to Issues**: Include ticket/issue references where applicable (e.g., CU-xxxxx)
6. **Proofread**: Check for typos and clarity before creating the PR

#### Don'ts ❌
1. **Don't List Files**: Avoid mentioning specific file paths in the summary
2. **Don't Skip Categories**: If a category has no changes, omit it entirely rather than leaving it empty
3. **Don't Rush**: Take time to properly categorize and document changes
4. **Don't Use Jargon**: Avoid overly technical language that obscures the business value
5. **Don't Forget Context**: Ensure reviewers have enough information to understand why changes were made

### For Reviewers

#### Do's ✅
1. **Read Summary First**: Start with the PR summary to understand scope before diving into code
2. **Verify Categorization**: Ensure changes are properly categorized
3. **Check for Completeness**: Verify all major changes are documented
4. **Test Locally**: Pull the branch and test critical functionality
5. **Provide Constructive Feedback**: Focus on improving the PR, not criticizing

---

## Process Checklist

### Pre-Process Setup

- [ ] Currently on `development` branch
- [ ] All changes are committed
- [ ] Branch is up to date with remote
- [ ] GitHub CLI is installed and authenticated
- [ ] Have write access to repository

### Phase 1: Analyze Changes

- [ ] Reviewed commit history
- [ ] Analyzed code diffs
- [ ] Changes categorized into groups
- [ ] Major themes identified
- [ ] Breaking changes noted (if any)

### Phase 2: Create PR Summary

- [ ] Summary document created
- [ ] All categories populated
- [ ] Descriptions are clear and concise
- [ ] No file paths mentioned
- [ ] Business value is evident
- [ ] Document proofread

### Phase 3: Create Pull Request

- [ ] PR title prepared
- [ ] PR description written
- [ ] Branch pushed to remote
- [ ] PR created via gh CLI
- [ ] PR verified in browser
- [ ] Base branch is `main`
- [ ] Head branch is `development`
- [ ] Reviewers assigned (if needed)

### Post-Process Completion

- [ ] PR link shared with team
- [ ] PR summary archived (if needed)
- [ ] Team notified of pending review
- [ ] Documentation updated (if needed)

---

## Templates & Examples

### Template: PR Summary Document

**Purpose**: Document changes between branches in a structured format

**Location**: `/docs/ignored/pr_summaries/YYYY-MM-DD_development_to_main.md`

**Usage**:
1. Create new file with date prefix
2. Fill in all applicable categories
3. Use as source for PR description

**Key Sections**:
```markdown
# PR Summary: Development → Main
## Date: YYYY-MM-DD

## Overview
[Brief description of the overall changes]

## Features
- [Feature description]

## Fixes
- [Fix description]

## Refactors
- [Refactor description]

## UI/UX Improvements
- [UI change description]

## Infrastructure & Configuration
- [Infrastructure change]

## Testing
- [Test changes]

## Breaking Changes (if any)
- [Breaking change description]

## Deployment Notes
- [Special deployment considerations]
```

### Example: Feature Release PR

**Scenario**: Multiple features and fixes accumulated in development branch over sprint

**Walkthrough**:
1. Developer analyzes 50+ commits between main and development
2. Identifies 3 major features, 12 fixes, and various improvements
3. Creates summary document categorizing all changes
4. Creates PR with title "Release: Sprint 12 - WhatsApp Integration & UI Improvements"
5. PR description includes categorized summary and testing notes

**Key Takeaways**:
- Large PRs benefit most from structured documentation
- Categorization makes review manageable
- Clear summary helps stakeholders understand release content

---

## Troubleshooting

### Common Issues Quick Reference

| Issue | Symptoms | Quick Solution | Prevention |
|-------|----------|----------------|------------|
| **Too many commits** | Cannot review all commits manually | Group by keywords, focus on patterns | Regular smaller releases |
| **PR already exists** | Error when creating PR | Close old PR or update it | Check existing PRs first |
| **Branch not pushed** | Cannot create remote PR | Run `git push -u origin development` | Push before creating PR |
| **Unclear commit messages** | Cannot categorize changes | Review actual diffs for context | Enforce commit message standards |
| **Missing context** | Reviewers ask too many questions | Add more detail to PR description | Include "why" for major changes |
| **Wrong base branch** | PR created against wrong branch | Close and recreate with correct base | Double-check branch in command |
| **PR title lint fails** | "Lint PR" check fails | Use semantic commit format (see below) | Follow PR title conventions |

### PR Title Lint Check Failures

**Symptom**: The "Lint PR / Validate PR title" GitHub check fails

**Cause**: PR title doesn't follow [Conventional Commits](https://www.conventionalcommits.org/) format

**Valid PR Title Format**:
```
<type>: <description>
<type>(<scope>): <description>
```

**Valid Types**:
- `feat` - New features
- `fix` - Bug fixes
- `chore` - Maintenance, builds, releases
- `docs` - Documentation changes
- `refactor` - Code refactoring
- `test` - Test changes
- `perf` - Performance improvements
- `ci` - CI/CD changes
- `style` - Code style changes
- `build` - Build system changes
- `revert` - Revert previous changes

**Common Mistakes**:
- ❌ `release: v0.2.0` - **Invalid** (`release` is not a valid type)
- ✅ `chore(release): v0.2.0` - **Valid** (use `chore` for releases)
- ❌ `Release: Sprint 12` - **Invalid** (capitalized, invalid type)
- ✅ `chore: release Sprint 12` - **Valid** (lowercase `chore`)
- ❌ `Add new feature` - **Invalid** (missing type prefix)
- ✅ `feat: add new feature` - **Valid**

**How to Fix**:
1. Go to your PR on GitHub
2. Click "Edit" on the PR title
3. Update to follow `<type>: <description>` format
4. Use lowercase for type prefix
5. The check will re-run automatically

**Note**: The lint check validates PR **titles** only, not branch names or commit messages.

### When to Escalate

- **Large Breaking Changes**: Notify team lead before creating PR
- **Urgent Releases**: Follow hotfix process instead of standard process
- **Merge Conflicts**: Resolve before creating PR or document conflicts clearly
- **Failed CI/CD**: Ensure all checks pass before requesting review

---

## Quick Reference

### Common Commands

```bash
# Analyze changes
git log main..development --oneline --no-merges
git diff main...development --stat

# Create PR
gh pr create --base main --head development --title "Release: [Title]"

# View PR
gh pr view
gh pr view --web

# Update PR
gh pr edit --add-reviewer @username
gh pr edit --add-label "release"

# Check branch status
git branch --show-current
git status
```

### File Locations

| Type | Location | Description |
|------|----------|-------------|
| Process Documents | `/docs/processes/git/` | Git-related process documentation |
| PR Summaries | `/docs/ignored/pr_summaries/` | Temporary PR summary documents |
| Release Notes | `/docs/releases/` | Published release documentation |

### Key Terminology

- **Base Branch**: The branch you're merging INTO (usually `main`)
- **Head Branch**: The branch you're merging FROM (usually `development`)
- **PR Summary**: Structured document of changes for the PR description
- **Release PR**: Pull request from development to main for production release

---

## Related Documentation

### Internal Documentation

**Process Documentation**:
- [Git Workflow](/docs/processes/git/git_workflow.md) - Overall git workflow
- [Hotfix Process](/docs/processes/git/hotfix_process.md) - Emergency fix process

**Technical Documentation**:
- [CLAUDE.md](/CLAUDE.md) - Development guidelines
- [Contributing Guide](/CONTRIBUTING.md) - Contribution guidelines

**Templates**:
- [PR Summary Template](/docs/templates/pr_summary_template.md) - Reusable template

### External Resources

- [GitHub CLI Documentation](https://cli.github.com/manual/) - gh CLI reference
- [Git Documentation](https://git-scm.com/doc) - Git command reference
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message standards

---

## Changelog

### Version 2.0.0 (2025-10-12)

**Status**: Active

**Changes**:
- **MAJOR**: Added PR type categorization (Feature, Bug Fix/Hotfix, Release)
- Added PR Types & Decision Tree section
- Updated all phases to support multiple PR types
- Completely rewrote Phase 3 with type-specific subsections (3A, 3B, 3C)
- Added type-specific naming conventions and formats
- Updated Key Principles with type-specific guidance
- Added Quick Reference Table for PR types
- Enhanced examples and templates for each PR type
- Updated documentation depth guidelines (high-level for releases, technical details okay for features/bugs)

**Migration Notes**:
- Existing release PR process (development → main) is now section 3A
- New guidance added for feature PRs (section 3B) and bug/hotfix PRs (section 3C)
- All previous release PR guidance remains valid, now with added context

---

### Version 1.0.0 (2025-10-12)

**Status**: Superseded by 2.0.0

**Changes**:
- Initial version of PR creation process (release PRs only)
- Defined 3-phase workflow
- Created templates and examples
- Added troubleshooting guide
- Documented best practices

**Migration Notes**: N/A - First version

---

## Document Metadata

**Document Owner**: Engineering Team

**Maintained By**: Lead Developer

**Review Cycle**: Quarterly or after major process changes

**Last Reviewed**: 2025-10-12

**Next Review Due**: 2026-01-12

**Contact**: #engineering-team or engineering@company.com

---

**End of Document**
