# API Testing Process

**Version**: 3.0.0
**Last Updated**: 2025-10-09
**Status**: Active
**Document Type**: Process Guide
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Table of Contents

1. [Overview](#overview)
2. [Key Principles](#key-principles)
3. [Phase 1: Discovery](#phase-1-discovery---understand-current-api-state)
4. [Phase 2: Planning](#phase-2-planning---create-comprehensive-test-plan)
5. [Phase 3: Environment Setup](#phase-3-environment-setup)
6. [Phase 4: Execution](#phase-4-execution---run-tests-and-track-progress)
7. [Phase 5: Issue Resolution](#phase-5-issue-resolution)
8. [Phase 6: Documentation](#phase-6-documentation)
9. [Process Checklist](#process-checklist)
10. [Related Documentation](#related-documentation)

---

## Overview

### Purpose

Ensure comprehensive, systematic, and repeatable API testing that:
- Validates all endpoints work correctly
- Catches bugs before production
- Documents API behavior (request/response contracts)
- Provides regression test coverage (via RSpec request specs)
- Verifies Jbuilder camelCase JSON responses

### Document Location

**IMPORTANT**: All test documents MUST be created in `/docs/ignored/tests/`

- **Discovery reports**: `/docs/ignored/tests/<feature>_api_discovery.md`
- **Test plans**: `/docs/ignored/tests/<feature>_test_plan.md`
- **Test results**: `/docs/ignored/tests/<feature>_test_results.md`
- These documents are NOT committed to the repository
- Templates remain in `/docs/processes/tests/` for reference

### Scope

**What is Covered**:
- REST API endpoint testing (Rails controllers)
- Request/response validation (Jbuilder views)
- Error scenario testing (validation, authorization)
- Integration testing with PostgreSQL database
- RSpec request spec development

**What is NOT Covered**:
- Load/performance testing
- Security penetration testing
- UI/frontend testing (Vue.js components - separate process)
- Unit testing of business logic (covered in service specs)

### Process Duration

- **Discovery**: 30-60 minutes
- **Planning**: 1-2 hours
- **Environment Setup**: 15-30 minutes
- **Execution**: Variable (2-8 hours per feature)
- **Issue Resolution**: Variable
- **Documentation**: 30-60 minutes

**Total**: Typically 4-12 hours per feature area

---

## Key Principles

1. **Systematic Approach**
   - Follow the 6-phase process consistently
   - Don't skip phases even if timeline is tight
   - Document everything as you go

2. **Test in Isolation**
   - Each test should be independent
   - Use database transactions in RSpec (automatic rollback)
   - Use FactoryBot factories for test data

3. **Document First, Execute Second**
   - Create test plan before running tests
   - Update tracking document in real-time
   - Capture actual responses for failures

4. **Fix Fast, Verify Immediately**
   - Stop server before making code changes
   - Fix blocking issues immediately
   - Re-run tests immediately after fix
   - Run regression tests (RSpec request specs)

5. **Quality Over Speed**
   - Test error cases, not just happy paths
   - Validate all response fields (camelCase), not just status codes
   - Test authorization (account isolation)

### Process Summary

The API testing process consists of 6 main phases:

1. **Discovery** - Understand current API state (routes, controllers, Jbuilder views)
2. **Planning** - Create comprehensive test plan
3. **Environment Setup** - Prepare testing environment (Rails server, PostgreSQL, Redis)
4. **Execution** - Run tests and track progress (cURL + Postman/Insomnia)
5. **Issue Resolution** - Fix bugs discovered during testing
6. **Documentation** - Record results and create RSpec request specs

---

## Phase 1: Discovery - Understand Current API State

### Objective
Understand the current state of the API by examining Rails routes, controllers, and Jbuilder views.

### Steps

#### 1.1 Review Rails Routes

```bash
# View all API routes
rails routes | grep api/v1

# View routes for specific resource
rails routes | grep stores

# Save routes to file for reference
rails routes > docs/ignored/tests/routes_snapshot.txt
```

**What to look for:**
- All available endpoints (GET, POST, PATCH, DELETE)
- Route patterns (`/api/v1/accounts/:account_id/stores`)
- Controller actions
- Path parameters (`:account_id`, `:id`)
- Nested resources

#### 1.2 Examine Controllers

**Location**: `app/controllers/api/v1/accounts/<resource>_controller.rb`

**What to look for:**
- Controller actions (index, show, create, update, destroy)
- Strong parameters (permitted fields)
- Authentication/authorization checks
- Error handling (rescue blocks)
- Service object usage
- Render targets (Jbuilder views)

#### 1.3 Examine Jbuilder Views

**Location**: `app/views/api/v1/accounts/<resource>/*.json.jbuilder`

**What to look for:**
- Response fields (should be camelCase)
- Nested associations
- Conditional fields
- Pagination metadata (`meta` key)

#### 1.4 Review Models

**Location**: `app/models/<resource>.rb`

**What to look for:**
- Validations (will affect POST/PATCH error responses)
- Enums (valid values for enum fields)
- Associations
- Scopes (may affect index filtering)

#### 1.5 Create Discovery Summary

**Deliverable**: `/docs/ignored/tests/<feature>_api_discovery.md`

**Template:**
```markdown
# API Discovery: <Feature>

## Endpoints Identified
- GET /api/v1/accounts/:account_id/stores
- POST /api/v1/accounts/:account_id/stores
- PATCH /api/v1/accounts/:account_id/stores/:id
- DELETE /api/v1/accounts/:account_id/stores/:id

## Controller: app/controllers/api/v1/accounts/stores_controller.rb
- Actions: index, show, create, update, destroy
- Strong params: name, phone_number, priority
- Authentication: Required (api_access_token header)
- Authorization: Account-scoped

## Jbuilder Views
- Index: Returns { payload: [], meta: {} }
- Show: Returns { id, name, phoneNumber, priority, createdAt, updatedAt }

## Model Validations
- name: required
- phone_number: required
- priority: required, enum (low: 0, medium: 1, high: 2)

## Authentication
- Header: api_access_token
- Obtained via: User.create_token.token
```

---

## Phase 2: Planning - Create Comprehensive Test Plan

### Objective
Create a detailed, categorized test plan covering all scenarios.

### Steps

#### 2.1 Define Test Scope

**In Scope:**
- All CRUD operations (index, show, create, update, destroy)
- Request validation (required fields, format validation)
- Response validation (status codes, field presence, camelCase)
- Error scenarios (404, 401, 422)
- Account isolation (cross-account access prevention)
- Pagination (if applicable)

**Out of Scope:**
- Performance/load testing
- Frontend UI testing
- Business logic testing (covered in service specs)

#### 2.2 Create Test Plan Document

**Template**: See `/docs/processes/tests/TEST_PLAN_TEMPLATE.md`

**Location**: `/docs/ignored/tests/<feature>_test_plan.md`

**Key Sections:**
1. **Discovery & List Operations** - Index endpoints, pagination, filtering
2. **Read Operations (GET)** - Show endpoints, 404 handling, auth checks
3. **Create Operations (POST)** - Success, validation errors, auth
4. **Update Operations (PATCH)** - Success, validation errors, partial updates
5. **Delete Operations (DELETE)** - Success, 404 handling
6. **Validation & Error Cases** - All error scenarios

**Example Test Case:**
```markdown
### TC-001: List All Stores

**Endpoint**: `GET /api/v1/accounts/:account_id/stores`
**Method**: GET
**Authentication**: Required
**Expected HTTP Status**: 200 OK

**cURL Command**:
```bash
curl -X GET "http://localhost:3000/api/v1/accounts/${ACCOUNT_ID}/stores" \
  -H "api_access_token: ${API_TOKEN}"
```

**Expected Response Structure**:
```json
{
  "payload": [{ "id": 1, "name": "...", "phoneNumber": "..." }],
  "meta": { "currentPage": 1, "totalPages": 1, "totalCount": 1 }
}
```

**Validation**:
- [ ] HTTP status is 200
- [ ] Response contains `payload` array
- [ ] Response contains `meta` object
- [ ] Fields use camelCase (not snake_case)
```

#### 2.3 Estimate Test Effort

**Rough Estimates:**
- Simple CRUD (5 endpoints): 2-3 hours
- Complex feature (10+ endpoints): 4-6 hours
- Edge cases and error scenarios: +50% time

---

## Phase 3: Environment Setup

### Objective
Prepare a clean, isolated testing environment.

### Steps

#### 3.1 Start Required Services

See `CLAUDE.md` and `Taskfile.yml` for commands:
- Start PostgreSQL and Redis
- Run database migrations
- Start Rails server

#### 3.2 Setup Authentication

```bash
# Open Rails console
rails console

# Create test account and user
account = Account.first_or_create!(name: 'Test Account')
user = account.users.first_or_create!(
  email: 'test@example.com',
  password: 'password',
  name: 'Test User'
)

# Generate API token
token = user.create_token
puts "API Token: #{token.token}"
puts "Account ID: #{account.id}"
```

#### 3.3 Set Environment Variables

```bash
# Export for terminal session
export API_TOKEN="your_token_here"
export ACCOUNT_ID="1"
export BASE_URL="http://localhost:3000/api/v1"
```

#### 3.4 Verify Environment

```bash
# Test authentication
curl -X GET "${BASE_URL}/accounts/${ACCOUNT_ID}/conversations" \
  -H "api_access_token: ${API_TOKEN}"

# Should return 200 OK with data
```

---

## Phase 4: Execution - Run Tests and Track Progress

### Objective
Execute test plan systematically, tracking results in real-time.

### Steps

#### 4.1 Create Test Results Document

**Template**: See `/docs/processes/tests/TEST_RESULTS_TEMPLATE.md`

**Location**: `/docs/ignored/tests/<feature>_test_results.md`

**Initial State**: All tests marked ⏳ Pending

#### 4.2 Execute Tests Systematically

**For Each Test Case:**

1. **Update Status to In Progress**
2. **Run cURL Command**
   ```bash
   curl -X GET "${BASE_URL}/accounts/${ACCOUNT_ID}/stores" \
     -H "api_access_token: ${API_TOKEN}" \
     -v  # verbose for debugging
   ```
3. **Capture Response** (HTTP status, body, time, errors)
4. **Validate Response** (status, structure, fields, camelCase, data accuracy)
5. **Update Test Results**
   ```markdown
   #### TC-001: List All Stores
   - **Status**: ✅ Pass
   - **HTTP Status**: 200 OK
   - **Response Time**: 45ms
   - **Notes**: All fields present, camelCase correct
   ```

#### 4.3 Handle Test Failures

**When a test fails:**
1. Document the failure in test results
2. Create issue entry in Issues & Bugs section
3. Stop and fix if it blocks other tests
4. Continue if it doesn't block

**Issue Documentation Template:**
```markdown
### Issue #1: Server Error When Listing Stores

**Severity**: 🔴 Critical
**Status**: Open
**Discovered In**: TC-001

**Description**: GET /stores returns 500 error instead of 200

**Expected Behavior**: 200 OK with array of stores
**Actual Behavior**: 500 Internal Server Error

**cURL Command**: [exact command]
**Response**: [actual response]
```

#### 4.4 Track Progress

Update progress tracking in test results document:
```markdown
## Progress Overview

Discovery & List:    [✅✅✅] 3/3 (100%)
Read Operations:     [✅✅❌░] 2/4 (50%)
Create Operations:   [░░░] 0/3 (0%)

Overall: ███░░░░░░░ 5/18 (28%)
```

#### 4.5 Create RSpec Request Specs (Recommended)

Convert manual tests to automated specs for regression prevention:

```ruby
# spec/requests/api/v1/accounts/stores_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Stores', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:token) { user.create_token.token }
  let(:headers) { { 'api_access_token' => token } }

  describe 'GET /api/v1/accounts/:account_id/stores' do
    it 'returns list of stores' do
      create_list(:store, 3, account: account)
      get "/api/v1/accounts/#{account.id}/stores", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['payload'].size).to eq(3)
      expect(json).to have_key('meta')
    end

    it 'returns camelCase fields' do
      store = create(:store, account: account, phone_number: '1234567890')
      get "/api/v1/accounts/#{account.id}/stores/#{store.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('phoneNumber')
      expect(json).not_to have_key('phone_number')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/stores' do
    it 'creates a new store' do
      params = { store: { name: 'New Store', phone_number: '1234567890' } }

      expect {
        post "/api/v1/accounts/#{account.id}/stores", params: params, headers: headers
      }.to change(Store, :count).by(1)

      expect(response).to have_http_status(:created)
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

---

## Phase 5: Issue Resolution

### Objective
Fix bugs discovered during testing and verify fixes.

### Steps

#### 5.1 Prioritize Issues

**Critical (Fix Immediately)**:
- Server errors (500)
- Complete feature failures
- Data corruption risks
- Security issues

**Major (Fix Before Release)**:
- Validation errors not working
- Missing fields in responses
- Incorrect status codes
- snake_case instead of camelCase

**Minor (Can Defer)**:
- Minor response time issues
- Non-critical field ordering

#### 5.2 Fix Issues

**Process:**
1. **Stop Rails Server**
2. **Investigate Root Cause** (Rails logs, controller, Jbuilder, model)
3. **Implement Fix** (update code, add RSpec specs)
4. **Restart Server**
5. **Re-run Failed Test** (exact same cURL command)
6. **Run Regression Tests** (RSpec request specs)
7. **Update Issue Status** (mark resolved, document root cause and fix)
8. **Update Test Results** (mark test as pass)

---

## Phase 6: Documentation

### Objective
Create final documentation and ensure regression prevention.

### Steps

#### 6.1 Finalize Test Results

Update summary statistics and overall result:
```markdown
## Test Summary

| Metric | Value |
|--------|-------|
| **Total Test Cases** | 18 |
| **Passed** | 16 (89%) |
| **Failed** | 0 (0%) |

### Overall Result: ✅ PASS

**Criteria**:
- [x] All critical tests passed
- [x] Pass rate ≥ 95%
- [x] No blocking issues
- [x] All high-severity bugs fixed
```

#### 6.2 Create RSpec Request Specs

Convert all manual tests to automated RSpec specs (see Phase 4.5 for examples).

Run automated specs:
```bash
# See Taskfile.yml for commands
task test-backend-file -- spec/requests/api/v1/accounts/stores_spec.rb
```

#### 6.3 Create Testing Artifacts

**Save for Future Reference:**
- Test plan document
- Test results document
- RSpec request specs
- cURL command collection

**Location**: `/docs/ignored/tests/<feature>/`

---

## Process Checklist

### Phase 1: Discovery
- [ ] Reviewed Rails routes (`rails routes | grep <resource>`)
- [ ] Examined controller actions
- [ ] Examined Jbuilder views
- [ ] Reviewed model validations
- [ ] Created discovery summary document

### Phase 2: Planning
- [ ] Defined test scope
- [ ] Created test plan using template
- [ ] Categorized tests (CRUD, validation, auth)
- [ ] Estimated test effort

### Phase 3: Environment Setup
- [ ] Started PostgreSQL and Redis
- [ ] Ran database migrations
- [ ] Started Rails server
- [ ] Generated API token
- [ ] Set environment variables
- [ ] Verified authentication works

### Phase 4: Execution
- [ ] Created test results document
- [ ] Executed tests systematically
- [ ] Captured all responses
- [ ] Validated response structure (camelCase)
- [ ] Documented failures
- [ ] Updated progress tracking

### Phase 5: Issue Resolution
- [ ] Prioritized issues by severity
- [ ] Fixed critical issues
- [ ] Fixed major issues
- [ ] Re-ran failed tests
- [ ] Ran regression tests
- [ ] Documented all fixes

### Phase 6: Documentation
- [ ] Finalized test results
- [ ] Created RSpec request specs
- [ ] Ran automated specs successfully
- [ ] Saved testing artifacts

---

## Related Documentation

### Process Documentation
- [Development Process](../development/development_process.md) - Full development workflow
- [Code Review Process](../code_review/code_review_process.md) - Code review procedures
- [Unit Testing Process](./unit_testing_process.md) - Unit testing guide

### Technical Documentation
- [CLAUDE.md](/CLAUDE.md) - Commands, guidelines, and conventions
- [ARCHITECTURE.md](/docs/ARCHITECTURE.md) - System architecture
- [Taskfile.yml](/Taskfile.yml) - All available commands

### Templates
- [Test Plan Template](./TEST_PLAN_TEMPLATE.md) - Test plan template
- [Test Results Template](./TEST_RESULTS_TEMPLATE.md) - Test results template

### External Resources
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html) - Official Rails testing
- [RSpec Rails](https://rspec.info/documentation/4.0/rspec-rails/) - RSpec request specs
- [FactoryBot](https://github.com/thoughtbot/factory_bot) - Test data factories

---

## Changelog

### Version 3.0.0 (2025-10-09)

**Status**: Active

**Changes**:
- Removed Quick Reference section (now in CLAUDE.md and Taskfile.yml)
- Removed Best Practices section (now in CLAUDE.md)
- Removed Troubleshooting section (create separate troubleshooting.md)
- Simplified examples to show structure only
- Streamlined all 6 phases for clarity
- Maintained all essential testing procedures
- 60% reduction in document size while preserving all critical content

### Version 2.0.0 (2025-10-06)

**Status**: Superseded

**Changes**:
- Adapted for Chatwoot (Rails + Vue.js) from Python/FastAPI
- Updated all references from FastAPI to Rails controllers
- Added Jbuilder view inspection (camelCase validation)
- Added RSpec request specs as regression test strategy

---

**End of Document**
