# {Feature} API Test Results

**IMPORTANT**: This document MUST be created in `/docs/ignored/tests/<feature>_test_results.md`

**Test Date**: YYYY-MM-DD
**Test Start Time**: HH:MM:SS
**Test End Time**: HH:MM:SS
**Total Duration**: X hours Y minutes
**Tester**: [Your Name or "Automated"]
**Environment**: Local Development | Staging | Production
**Server Version**: [Git commit hash or version tag]
**Test Plan**: [Link to test plan document]
**Project**: Chatwoot (Rails + Vue.js)

---

## Test Summary

### Summary Statistics

| Metric | Value |
|--------|-------|
| **Total Test Cases** | XX |
| **Passed** | XX (XX%) |
| **Failed** | XX (XX%) |
| **Skipped** | XX (XX%) |
| **Blocked** | XX (XX%) |

---

### Results by Category

| Category | Total | Passed | Failed | Skipped | Pass Rate |
|----------|-------|--------|--------|---------|-----------|
| Discovery & List Operations | 3 | 0 | 0 | 0 | 0% |
| Read Operations (GET) | 4 | 0 | 0 | 0 | 0% |
| Create Operations (POST) | 3 | 0 | 0 | 0 | 0% |
| Update Operations (PATCH) | 2 | 0 | 0 | 0 | 0% |
| Delete Operations (DELETE) | 2 | 0 | 0 | 0 | 0% |
| Validation & Error Cases | 0 | 0 | 0 | 0 | 0% |
| **TOTAL** | **14** | **0** | **0** | **0** | **0%** |

---

### Overall Result

**Status**: ✅ PASS | ❌ FAIL | 🔄 IN PROGRESS | ⏸️ BLOCKED

**Criteria**:
- [ ] All critical tests passed
- [ ] Pass rate ≥ 95%
- [ ] No blocking issues
- [ ] All high-severity bugs fixed

---

## Test Environment Details

### Server Configuration

- **Base URL**: `http://localhost:3000/api/v1`
- **Rails Version**: 7.1.x
- **Ruby Version**: 3.x.x
- **Database**: PostgreSQL X.X
- **Redis**: Running
- **Git Commit**: [hash]

### Authentication

- **Account ID**: 1
- **User**: test@example.com
- **API Token**: [first 10 chars]...

---

## Test Execution Checklist

### Discovery & List Operations

#### TC-001: List All Resources

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Captured Variables**:
  - `RESOURCE_ID`: [value]
- **Expected**: Return array in `payload`, metadata in `meta`, camelCase fields
- **Actual**: [What actually happened]
- **Notes**: [Any observations]
- **Issues**: [Reference to issue # if failed]

---

#### TC-002: List with Pagination

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: Paginated results, correct `meta.currentPage`
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

#### TC-003: List with Filters

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: Only filtered resources returned
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

### Read Operations (GET)

#### TC-004: Get Resource by ID

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: Single resource object, camelCase fields
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

#### TC-005: Get Non-Existent Resource

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 404 Not Found with error message
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

#### TC-006: Get Without Authentication

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 401 Unauthorized
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

#### TC-007: Get Resource from Different Account

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 404 Not Found or 403 Forbidden
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

### Create Operations (POST)

#### TC-008: Create Resource Successfully

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Captured Variables**:
  - `NEW_RESOURCE_ID`: [value]
- **Expected**: 201 Created, resource persisted, timestamps populated
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

#### TC-009: Create with Missing Required Field

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 422 Unprocessable Entity with validation error
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

#### TC-010: Create with Invalid Data

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 422 with all validation errors
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

### Update Operations (PATCH)

#### TC-011: Update Resource Successfully

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 200 OK, updated resource, changed `updatedAt`
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

#### TC-012: Update with Invalid Data

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 422 Unprocessable Entity with error
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

### Delete Operations (DELETE)

#### TC-013: Delete Resource Successfully

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 204 No Content, resource removed
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

#### TC-014: Delete Non-Existent Resource

- **Status**: ⏳ Pending | ✅ Pass | ❌ Fail | ⏭️ Skipped
- **HTTP Status**: [Actual status code]
- **Response Time**: [X ms]
- **Expected**: 404 Not Found
- **Actual**: [What actually happened]
- **Notes**: [Any observations]

---

## Issues & Bugs Found

### Issue #1: [Issue Title]

**Severity**: 🔴 Critical | 🟡 High | 🟢 Medium | ⚪ Low
**Status**: Open | In Progress | Resolved | Won't Fix
**Discovered In**: [Test Case ID]
**Discovered At**: YYYY-MM-DD HH:MM

**Description**:
[Detailed description of the issue]

**Steps to Reproduce**:
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior**:
[What should happen]

**Actual Behavior**:
[What actually happened]

**cURL Command**:
```bash
[Command that reproduces the issue]
```

**Response**:
```json
[Actual response]
```

**Root Cause** (if known):
[Analysis of why the issue occurred]

**Fix Required**:
[What needs to be fixed]

**Resolution**:
[How it was resolved - fill in when resolved]

**Resolved By**: [Name]
**Resolved At**: YYYY-MM-DD HH:MM

---

## Performance Observations

### Response Time Statistics

| Endpoint | Min (ms) | Max (ms) | Avg (ms) | Notes |
|----------|----------|----------|----------|-------|
| GET /resources | X | Y | Z | [Notes] |
| GET /resources/:id | X | Y | Z | [Notes] |
| POST /resources | X | Y | Z | [Notes] |
| PATCH /resources/:id | X | Y | Z | [Notes] |
| DELETE /resources/:id | X | Y | Z | [Notes] |

### Performance Issues

- **Issue 1**: [Description, if any slow endpoints]
- **Issue 2**: [Description]

---

## Coverage Analysis

### Covered Scenarios

- [X] Happy path (all CRUD operations)
- [X] Validation errors (required fields, format validation)
- [X] Authentication (with/without token)
- [X] Authorization (account isolation)
- [X] Not found scenarios (404)
- [X] Pagination
- [ ] Edge cases (optional - list if covered)

### Not Covered (Out of Scope)

- Concurrency testing
- Load testing
- Security penetration testing
- Performance benchmarking
- [Other items not tested]

---

## Automated Test Results (RSpec)

If automated request specs were run:

```bash
# Command used
bundle exec rspec spec/requests/api/v1/accounts/resources_spec.rb --format documentation

# Results
Finished in X.XX seconds (files took X.XX seconds to load)
XX examples, X failures, X pending

# Coverage
Coverage: XX% of changed files
```

**Coverage Report**: [Link to coverage/index.html]

---

## Recommendations

### Critical Actions Required

1. **Action 1**: [Description, priority, assignee]
2. **Action 2**: [Description, priority, assignee]

### Improvements for Future

1. **Improvement 1**: Add more edge case tests
2. **Improvement 2**: Set up automated regression testing
3. **Improvement 3**: Add performance benchmarking

### Test Plan Updates

- [ ] Update test plan with new test cases discovered
- [ ] Document any undocumented endpoints found
- [ ] Add missing validation scenarios

---

## Sign-Off

### Tester Sign-Off

**Name**: [Your Name]
**Date**: YYYY-MM-DD
**Comments**: [Any final comments]

**Approval**:
- [ ] All tests executed as planned
- [ ] All issues documented
- [ ] Results accurately reflect API state
- [ ] Ready for deployment (if pass) / Need fixes (if fail)

### Developer Sign-Off (if applicable)

**Name**: [Developer Name]
**Date**: YYYY-MM-DD
**Comments**: [Comments on failures, fixes applied, etc.]

---

## Appendix

### Test Data Used

**Accounts**:
- Account ID: 1
- Name: Test Account

**Users**:
- User ID: 1
- Email: test@example.com

**Resources Created During Testing**:
- Resource IDs: [list of IDs created for testing]
- Cleaned up: Yes | No

### Environment Variables

```bash
export API_TOKEN="abc123..."
export ACCOUNT_ID="1"
export BASE_URL="http://localhost:3000/api/v1"
```

### Commands Used

```bash
# Server startup
pnpm dev

# Database setup
rails db:migrate

# Test execution
[List of cURL commands or RSpec commands used]
```

---

**End of Test Results**
