# API Testing Process - Comprehensive Guide

**Version**: 2.0.0
**Last Updated**: 2025-10-06
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
9. [Quick Reference: Common Commands](#quick-reference-common-commands)
10. [Best Practices](#best-practices)
11. [Troubleshooting Common Issues](#troubleshooting-common-issues)
12. [Process Checklist](#process-checklist)
13. [Templates Location](#templates-location)
14. [Related Documentation](#related-documentation)
15. [Revision History](#revision-history)

---

## Overview

This document outlines the complete process for systematically testing REST APIs in Chatwoot. This process provides a repeatable methodology for ensuring API quality across Rails controllers and Jbuilder views.

### Purpose

Ensure comprehensive, systematic, and repeatable API testing that:
- Validates all endpoints work correctly
- Catches bugs before production
- Documents API behavior (request/response contracts)
- Provides regression test coverage (via RSpec request specs)
- Verifies Jbuilder camelCase JSON responses

### Scope

**What is Covered**:
- REST API endpoint testing (Rails controllers)
- Request/response validation (Jbuilder views)
- Error scenario testing (validation, authorization)
- Integration testing with PostgreSQL database
- Test documentation and tracking
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
   - Don't rely on previous test state
   - Use FactoryBot factories for test data

3. **Document First, Execute Second**
   - Create test plan before running tests
   - Update tracking document in real-time
   - Capture actual responses for failures

4. **Fix Fast, Verify Immediately**
   - Stop server before making code changes
   - Fix issues as discovered when blocking
   - Re-run tests immediately after fix
   - Run regression tests (RSpec request specs)

5. **Quality Over Speed**
   - Thorough testing is better than fast testing
   - Test error cases, not just happy paths
   - Validate all response fields (camelCase), not just status codes
   - Test authorization (account isolation)

6. **Learn and Improve**
   - Document issues and solutions
   - Update test plans based on learnings
   - Convert manual tests to RSpec request specs
   - Share findings with team

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

**Command:**
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

**Example Output:**
```
GET    /api/v1/accounts/:account_id/stores          api/v1/accounts/stores#index
GET    /api/v1/accounts/:account_id/stores/:id      api/v1/accounts/stores#show
POST   /api/v1/accounts/:account_id/stores          api/v1/accounts/stores#create
PATCH  /api/v1/accounts/:account_id/stores/:id      api/v1/accounts/stores#update
DELETE /api/v1/accounts/:account_id/stores/:id      api/v1/accounts/stores#destroy
```

#### 1.2 Examine Controllers

**Location**: `app/controllers/api/v1/accounts/<resource>_controller.rb`

**What to look for:**
- Controller actions (index, show, create, update, destroy)
- Strong parameters (permitted fields)
- Authentication/authorization checks
- Error handling (rescue blocks)
- Service object usage
- Render targets (Jbuilder views)

**Example:**
```ruby
# app/controllers/api/v1/accounts/stores_controller.rb
class Api::V1::Accounts::StoresController < Api::V1::Accounts::BaseController
  def index
    @stores = Current.account.stores.page(params[:page])
  end

  def create
    @store = Stores::CreateService.new(
      account: Current.account,
      params: store_params
    ).perform
    render json: @store, status: :created
  end

  private

  def store_params
    params.require(:store).permit(:name, :phone_number, :priority)
  end
end
```

#### 1.3 Examine Jbuilder Views

**Location**: `app/views/api/v1/accounts/<resource>/*.json.jbuilder`

**What to look for:**
- Response fields (should be camelCase)
- Nested associations
- Conditional fields
- Pagination metadata (`meta` key)

**Example:**
```ruby
# app/views/api/v1/accounts/stores/show.json.jbuilder
json.id @store.id
json.name @store.name
json.phoneNumber @store.phone_number
json.priority @store.priority
json.priorityLabel @store.priority.humanize
json.createdAt @store.created_at
json.updatedAt @store.updated_at
```

#### 1.4 Review Models

**Location**: `app/models/<resource>.rb`

**What to look for:**
- Validations (will affect POST/PATCH error responses)
- Enums (valid values for enum fields)
- Associations
- Scopes (may affect index filtering)

**Example:**
```ruby
# app/models/store.rb
class Store < ApplicationRecord
  belongs_to :account
  has_many :conversations

  enum priority: { low: 0, medium: 1, high: 2 }

  validates :name, presence: true
  validates :phone_number, presence: true
  validates :priority, presence: true

  scope :by_priority, -> { order(priority: :desc) }
end
```

#### 1.5 Create Discovery Summary

**Deliverable**: `/docs/ignored/tests/<feature>_api_discovery.md`

**Template:**
```markdown
# API Discovery: <Feature>

## Endpoints Identified
- GET /api/v1/accounts/:account_id/stores
- GET /api/v1/accounts/:account_id/stores/:id
- POST /api/v1/accounts/:account_id/stores
- PATCH /api/v1/accounts/:account_id/stores/:id
- DELETE /api/v1/accounts/:account_id/stores/:id

## Controller: app/controllers/api/v1/accounts/stores_controller.rb
- Actions: index, show, create, update, destroy
- Strong params: name, phone_number, priority
- Authentication: Required (api_access_token header)
- Authorization: Account-scoped

## Jbuilder Views
- Index: app/views/api/v1/accounts/stores/index.json.jbuilder
  - Returns: { payload: [], meta: {} }
- Show: app/views/api/v1/accounts/stores/show.json.jbuilder
  - Returns: { id, name, phoneNumber, priority, priorityLabel, createdAt, updatedAt }

## Model Validations
- name: required
- phone_number: required
- priority: required, enum (low: 0, medium: 1, high: 2)

## Authentication
- Header: api_access_token
- Obtained via: User.create_token.token

## Notes
- API responses use camelCase (Jbuilder)
- Pagination via Kaminari (page param)
- Account isolation enforced
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
  -H "api_access_token: ${API_TOKEN}" \
  -H "Content-Type: application/json"
```

**Expected Response**:
```json
{
  "payload": [
    {
      "id": 1,
      "name": "Store 1",
      "phoneNumber": "1234567890",
      "priority": "medium",
      "priorityLabel": "Medium",
      "createdAt": "2025-01-01T00:00:00Z",
      "updatedAt": "2025-01-01T00:00:00Z"
    }
  ],
  "meta": {
    "currentPage": 1,
    "totalPages": 1,
    "totalCount": 1
  }
}
```

**Validation**:
- [ ] HTTP status is 200
- [ ] Response contains `payload` array
- [ ] Response contains `meta` object
- [ ] Fields use camelCase (not snake_case)
- [ ] Capture `STORE_ID` from first item
```

#### 2.3 Estimate Test Effort

**Rough Estimates:**
- Simple CRUD (5 endpoints): 2-3 hours
- Complex feature (10+ endpoints): 4-6 hours
- Edge cases and error scenarios: +50% time

**Deliverable**: Test plan with estimated duration

---

## Phase 3: Environment Setup

### Objective
Prepare a clean, isolated testing environment.

### Steps

#### 3.1 Start Required Services

```bash
# Start PostgreSQL
brew services start postgresql
# OR docker-compose up -d postgres

# Start Redis
brew services start redis
# OR docker-compose up -d redis

# Verify services running
pg_isready
redis-cli ping
```

#### 3.2 Setup Test Database

```bash
# Run migrations
rails db:migrate

# Check migration status
rails db:migrate:status

# (Optional) Seed data if needed
rails db:seed
```

#### 3.3 Start Rails Server

```bash
# Option 1: Rails server only
rails server

# Option 2: Full stack with Overmind
pnpm dev

# Verify server is running
curl http://localhost:3000/api
```

#### 3.4 Setup Authentication

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

# Copy these values for testing
```

#### 3.5 Set Environment Variables

```bash
# Export for terminal session
export API_TOKEN="your_token_here"
export ACCOUNT_ID="1"
export BASE_URL="http://localhost:3000/api/v1"

# Or create .env file for automation
echo "API_TOKEN=your_token_here" > .env.test
echo "ACCOUNT_ID=1" >> .env.test
echo "BASE_URL=http://localhost:3000/api/v1" >> .env.test
```

#### 3.6 Verify Environment

```bash
# Test authentication
curl -X GET "${BASE_URL}/accounts/${ACCOUNT_ID}/conversations" \
  -H "api_access_token: ${API_TOKEN}"

# Should return 200 OK with data
```

**Deliverable**: Working test environment with authentication

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

**Approach**: Work through test plan sequentially by category

**For Each Test Case:**

1. **Update Status to In Progress**
   ```markdown
   - **Status**: 🏃 In Progress
   ```

2. **Run cURL Command**
   ```bash
   curl -X GET "${BASE_URL}/accounts/${ACCOUNT_ID}/stores" \
     -H "api_access_token: ${API_TOKEN}" \
     -v  # verbose for debugging
   ```

3. **Capture Response**
   - HTTP status code
   - Response body
   - Response time
   - Any errors

4. **Validate Response**
   - Check HTTP status matches expected
   - Verify response structure
   - Validate all fields present
   - Check camelCase naming
   - Verify data accuracy

5. **Update Test Results**
   ```markdown
   #### TC-001: List All Stores
   - **Status**: ✅ Pass
   - **HTTP Status**: 200 OK
   - **Response Time**: 45ms
   - **Captured Variables**: STORE_ID=1
   - **Notes**: All fields present, camelCase correct
   ```

   OR if failed:
   ```markdown
   - **Status**: ❌ Fail
   - **HTTP Status**: 500 Internal Server Error
   - **Actual Response**: { "error": "Internal server error" }
   - **Issue**: #1 - Server error when listing stores
   ```

6. **Move to Next Test**

#### 4.3 Handle Test Failures

**When a test fails:**

1. **Document the failure** in test results
2. **Create issue entry** in Issues & Bugs section
3. **Stop and fix** if it blocks other tests
4. **Continue** if it doesn't block

**Issue Documentation Template:**
```markdown
### Issue #1: Server Error When Listing Stores

**Severity**: 🔴 Critical
**Status**: Open
**Discovered In**: TC-001
**Discovered At**: 2025-10-06 14:30

**Description**:
GET /stores returns 500 error instead of 200

**Steps to Reproduce**:
1. Run: curl -X GET "${BASE_URL}/accounts/1/stores" -H "api_access_token: ${API_TOKEN}"
2. Observe 500 error

**Expected Behavior**: 200 OK with array of stores

**Actual Behavior**: 500 Internal Server Error

**cURL Command**:
```bash
curl -X GET "http://localhost:3000/api/v1/accounts/1/stores" \
  -H "api_access_token: ${API_TOKEN}"
```

**Response**:
```json
{
  "error": "Internal server error"
}
```

**Root Cause**: (Fill in after investigation)

**Fix Required**: (Fill in after investigation)
```

#### 4.4 Track Progress

**Update Progress Bars** in test results document:
```markdown
## Progress Overview

Discovery & List Operations:    [✅✅✅] 3/3 (100%)
Read Operations (GET):           [✅✅❌░] 2/4 (50%)
Create Operations (POST):        [░░░] 0/3 (0%)
Update Operations (PATCH):       [░░] 0/2 (0%)
Delete Operations (DELETE):      [░░] 0/2 (0%)
Validation & Error Cases:        [░░░░] 0/4 (0%)

Overall Progress: ███░░░░░░░░░░░░░░░░░ 5/18 (28%)
```

#### 4.5 Use Tools for Efficiency

**Postman/Insomnia** (Optional):
- Import collection of requests
- Use environment variables
- Save requests for regression testing
- Export results

**RSpec Request Specs** (Recommended for Regression):
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
  end
end
```

**Deliverable**: Updated test results document with progress

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
- Documentation improvements

#### 5.2 Fix Issues

**Process:**

1. **Stop Rails Server**
   ```bash
   # Ctrl+C to stop server
   ```

2. **Investigate Root Cause**
   - Check Rails logs: `tail -f log/development.log`
   - Check controller code
   - Check Jbuilder view
   - Check model validations
   - Run RSpec specs: `bundle exec rspec spec/requests/`

3. **Implement Fix**
   - Update controller, model, service, or Jbuilder view
   - Add/update RSpec specs
   - Run RuboCop: `bundle exec rubocop -a`

4. **Restart Server**
   ```bash
   rails server
   ```

5. **Re-run Failed Test**
   ```bash
   # Run exact same cURL command that failed
   ```

6. **Run Regression Tests**
   ```bash
   # Re-run previously passing tests to ensure no breakage
   bundle exec rspec spec/requests/api/v1/accounts/stores_spec.rb
   ```

7. **Update Issue Status**
   ```markdown
   **Status**: ✅ Resolved
   **Root Cause**: Jbuilder view was using snake_case instead of camelCase
   **Fix**: Updated app/views/api/v1/accounts/stores/show.json.jbuilder to use json.phoneNumber instead of json.phone_number
   **Resolved By**: Developer Name
   **Resolved At**: 2025-10-06 15:45
   ```

8. **Update Test Results**
   ```markdown
   - **Status**: ✅ Pass (after fix)
   - **Resolution**: Issue #1 fixed
   ```

#### 5.3 Document Fixes

**In Test Results Document:**
- Mark issue as Resolved
- Document root cause
- Document fix applied
- Update test status to Pass

**In Code:**
- Add RSpec request spec to prevent regression
- Update controller/Jbuilder comments if needed

**Deliverable**: All critical and major issues resolved, documented fixes

---

## Phase 6: Documentation

### Objective
Create final documentation and ensure regression prevention.

### Steps

#### 6.1 Finalize Test Results

**Update Summary Statistics:**
```markdown
## Test Summary

### Summary Statistics

| Metric | Value |
|--------|-------|
| **Total Test Cases** | 18 |
| **Passed** | 16 (89%) |
| **Failed** | 0 (0%) |
| **Skipped** | 2 (11%) |
| **Blocked** | 0 (0%) |
```

**Update Overall Result:**
```markdown
### Overall Result

**Status**: ✅ PASS

**Criteria**:
- [x] All critical tests passed
- [x] Pass rate ≥ 95%
- [x] No blocking issues
- [x] All high-severity bugs fixed
```

#### 6.2 Create RSpec Request Specs

**Convert manual tests to automated RSpec specs:**

```ruby
# spec/requests/api/v1/accounts/stores_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Stores', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:token) { user.create_token.token }
  let(:headers) { { 'api_access_token' => token } }

  describe 'GET /api/v1/accounts/:account_id/stores' do
    context 'when authenticated' do
      it 'returns list of stores' do
        create_list(:store, 3, account: account)

        get "/api/v1/accounts/#{account.id}/stores", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['payload'].size).to eq(3)
        expect(json['meta']).to have_key('currentPage')
      end

      it 'returns stores in camelCase' do
        store = create(:store, account: account, phone_number: '1234567890')

        get "/api/v1/accounts/#{account.id}/stores/#{store.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key('phoneNumber')
        expect(json).not_to have_key('phone_number')
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get "/api/v1/accounts/#{account.id}/stores"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/stores' do
    let(:valid_params) { { store: { name: 'New Store', phone_number: '1234567890' } } }

    it 'creates a new store' do
      expect {
        post "/api/v1/accounts/#{account.id}/stores",
             params: valid_params,
             headers: headers
      }.to change(Store, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'returns 422 for invalid params' do
      post "/api/v1/accounts/#{account.id}/stores",
           params: { store: { name: '' } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include(/can't be blank/)
    end
  end
end
```

**Run automated specs:**
```bash
bundle exec rspec spec/requests/api/v1/accounts/stores_spec.rb --format documentation
```

#### 6.3 Update API Documentation (Optional)

**If API documentation exists:**
- Update endpoint descriptions
- Update request/response examples
- Document new fields or parameters
- Add notes about camelCase convention

#### 6.4 Create Testing Artifacts

**Save for Future Reference:**
- Test plan document
- Test results document
- RSpec request specs
- cURL command collection
- Postman/Insomnia collection (if used)

**Location**: `/docs/ignored/tests/<feature>/`

#### 6.5 Share Results

**With Team:**
- Summary of findings
- Issues discovered and fixed
- Test coverage achieved
- Recommendations for future testing

**Deliverable**: Final test results, RSpec specs, documentation

---

## Quick Reference: Common Commands

### Rails Server

```bash
# Start server
rails server

# Start with Overmind (all services)
pnpm dev

# Check server status
curl http://localhost:3000/api
```

### Database

```bash
# Run migrations
rails db:migrate

# Check migration status
rails db:migrate:status

# Rollback last migration
rails db:rollback

# Reset database (CAUTION: deletes all data)
rails db:reset
```

### Authentication

```bash
# Get API token (Rails console)
rails console
> user = User.first
> token = user.create_token
> token.token

# Set environment variables
export API_TOKEN="your_token"
export ACCOUNT_ID="1"
```

### Testing

```bash
# Run all RSpec request specs
bundle exec rspec spec/requests/

# Run specific request spec
bundle exec rspec spec/requests/api/v1/accounts/stores_spec.rb

# Run with documentation format
bundle exec rspec --format documentation

# Run with coverage
COVERAGE=true bundle exec rspec
```

### cURL Templates

```bash
# GET request
curl -X GET "${BASE_URL}/accounts/${ACCOUNT_ID}/stores" \
  -H "api_access_token: ${API_TOKEN}"

# POST request
curl -X POST "${BASE_URL}/accounts/${ACCOUNT_ID}/stores" \
  -H "api_access_token: ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "store": {
      "name": "Test Store",
      "phone_number": "1234567890"
    }
  }'

# PATCH request
curl -X PATCH "${BASE_URL}/accounts/${ACCOUNT_ID}/stores/${STORE_ID}" \
  -H "api_access_token: ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "store": {
      "name": "Updated Name"
    }
  }'

# DELETE request
curl -X DELETE "${BASE_URL}/accounts/${ACCOUNT_ID}/stores/${STORE_ID}" \
  -H "api_access_token: ${API_TOKEN}"
```

---

## Best Practices

### General

1. **Test in Order** - Discovery → Read → Create → Update → Delete
2. **Use Variables** - Export ACCOUNT_ID, API_TOKEN, STORE_ID
3. **Save Requests** - Keep cURL commands in a file for reuse
4. **Clean Up** - Delete test data after testing (or rely on RSpec transactions)
5. **Version Control** - Commit RSpec specs, not test data

### cURL Testing

1. **Use -v for Debugging** - See full HTTP headers
2. **Format JSON** - Pipe to `jq` or `python3 -m json.tool`
3. **Save Responses** - Redirect to file for comparison
4. **Use Postman/Insomnia** - For complex request collections

### RSpec Request Specs

1. **Use FactoryBot** - Create test data with factories
2. **Test Happy Path First** - Then error scenarios
3. **Test camelCase** - Verify Jbuilder returns camelCase
4. **Test Authorization** - Verify account isolation
5. **Keep DRY** - Use shared contexts and let blocks

### Documentation

1. **Update in Real-Time** - Don't batch documentation at end
2. **Be Specific** - Include exact cURL commands, responses
3. **Screenshot Errors** - Capture logs for complex issues
4. **Link Issues** - Reference GitHub issues if using issue tracker

---

## Troubleshooting Common Issues

### Issue 1: 401 Unauthorized

**Symptoms**: All requests return 401

**Causes**:
- Invalid API token
- Expired token
- Missing `api_access_token` header
- Typo in header name

**Solutions**:
```bash
# Regenerate token
rails console
> user = User.find_by(email: 'test@example.com')
> token = user.create_token
> puts token.token

# Verify header format
curl -v ... # Check for "api_access_token: TOKEN" in headers
```

---

### Issue 2: 404 Not Found for Valid Route

**Symptoms**: GET /api/v1/accounts/1/stores returns 404

**Causes**:
- Route not defined in routes.rb
- Server not running
- Wrong base URL
- Missing account ID

**Solutions**:
```bash
# Check routes exist
rails routes | grep stores

# Verify server running
curl http://localhost:3000/api

# Check URL format
echo "${BASE_URL}/accounts/${ACCOUNT_ID}/stores"
```

---

### Issue 3: 422 Validation Error on Valid Data

**Symptoms**: POST with valid data returns 422

**Causes**:
- Missing required field
- Incorrect param nesting
- Validation rule changed
- Strong parameters not permitting field

**Solutions**:
```bash
# Check server logs
tail -f log/development.log

# Verify param structure
# Rails expects: { "store": { "name": "..." } }
# Not: { "name": "..." }

# Check strong params in controller
# params.require(:store).permit(:name, :phone_number)
```

---

### Issue 4: Response Uses snake_case Instead of camelCase

**Symptoms**: Response has `phone_number` instead of `phoneNumber`

**Causes**:
- Jbuilder view not using camelCase
- Direct JSON rendering instead of Jbuilder
- Missing json. prefix in Jbuilder

**Solutions**:
```ruby
# Fix Jbuilder view
# Wrong:
json.extract! @store, :phone_number

# Correct:
json.phoneNumber @store.phone_number
```

---

### Issue 5: Server Error (500) with No Details

**Symptoms**: 500 error with generic message

**Causes**:
- Database connection error
- Missing migration
- Nil reference in controller/view
- Service object exception

**Solutions**:
```bash
# Check Rails logs (most important)
tail -f log/development.log

# Check database
rails db:migrate:status

# Run RSpec to isolate issue
bundle exec rspec spec/requests/...

# Check Redis running (for sessions/cache)
redis-cli ping
```

---

### Issue 6: Pagination Not Working

**Symptoms**: All records returned instead of paginated subset

**Causes**:
- Missing .page(params[:page]) in controller
- Kaminari not installed
- Page param not being passed

**Solutions**:
```ruby
# Check controller uses Kaminari
def index
  @stores = Current.account.stores.page(params[:page])
end

# Check Jbuilder includes meta
# app/views/api/v1/accounts/stores/index.json.jbuilder
json.payload do
  json.array! @stores
end

json.meta do
  json.currentPage @stores.current_page
  json.totalPages @stores.total_pages
  json.totalCount @stores.total_count
end

# Test with page param
curl "${BASE_URL}/accounts/1/stores?page=2" ...
```

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
- [ ] Defined success criteria
- [ ] Estimated test effort

### Phase 3: Environment Setup
- [ ] Started PostgreSQL
- [ ] Started Redis
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
- [ ] Updated API documentation (if exists)
- [ ] Saved testing artifacts
- [ ] Shared results with team

---

## Templates Location

**Process Templates** (committed to repo):
- **Test Plan Template**: `/docs/processes/tests/TEST_PLAN_TEMPLATE.md`
- **Test Results Template**: `/docs/processes/tests/TEST_RESULTS_TEMPLATE.md`

**Runtime Documents** (created in `/docs/ignored/tests/`):
- API Discovery: `<feature>_api_discovery.md`
- Test Plan: `<feature>_test_plan.md`
- Test Results: `<feature>_test_results.md`
- RSpec Specs: `spec/requests/api/v1/accounts/<resource>_spec.rb`

---

## Related Documentation

### Internal Documentation

**Process Documentation**:
- [Development Process](/docs/processes/development/development_process.md) - Full development workflow
- [Code Review Process](/docs/processes/code_review/code_review_process.md) - Code review procedures
- [Research Process](/docs/processes/design/research_and_design_process.md) - Feature research

**Technical Documentation**:
- [CLAUDE.md](/CLAUDE.md) - Project guidelines and commands
- [ARCHITECTURE.md](/docs/ARCHITECTURE.md) - System architecture overview
- [README.md](/README.md) - Project overview and setup

**Templates**:
- [Test Plan Template](/docs/processes/tests/TEST_PLAN_TEMPLATE.md) - Test plan template
- [Test Results Template](/docs/processes/tests/TEST_RESULTS_TEMPLATE.md) - Test results template

### External Resources

- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html) - Official Rails testing documentation
- [RSpec Rails Documentation](https://rspec.info/documentation/4.0/rspec-rails/) - RSpec request specs
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot) - Test data factories
- [cURL Documentation](https://curl.se/docs/manual.html) - cURL manual
- [Postman Documentation](https://learning.postman.com/) - Postman API testing

---

## Revision History

### Version 2.0.0 (2025-10-06)

**Status**: Active

**Changes**:
- **Major Update**: Adapted for Chatwoot (Rails + Vue.js) from Python/FastAPI
- Updated all references from FastAPI to Rails controllers
- Replaced Postman collection auto-generation with Rails routes discovery
- Updated authentication from JWT to Rails api_access_token header
- Added Jbuilder view inspection (camelCase validation)
- Updated all cURL examples for Rails API structure
- Added RSpec request specs as regression test strategy
- Updated environment setup for Rails, PostgreSQL, Redis
- Added Rails-specific troubleshooting (migrations, Kaminari, Jbuilder)
- Updated test execution to use FactoryBot factories
- Added pagination testing with Kaminari
- Updated issue resolution workflow for Rails logs and debugging

### Version 1.1.0 (2025-10-05)

**Status**: Superseded

**Changes**:
- Initial version (Python/FastAPI)
- Defined 6-phase API testing process
- Created comprehensive test plan structure
- Added Postman collection integration
- Included troubleshooting section
- Added best practices for API testing

**Migration Notes**:
- Previous version focused on FastAPI with automatic OpenAPI schema generation
- New version focuses on Rails manual route discovery and Jbuilder view inspection
- Update existing test processes to use Rails-specific tools
- Convert Postman collections to RSpec request specs for regression

---

## Document Metadata

**Document Owner**: Development Team

**Maintained By**: Claude Code + Human Engineers

**Review Cycle**: Quarterly or after significant changes

**Last Reviewed**: 2025-10-06

**Next Review Due**: 2026-01-06

**Technology Stack**: Ruby on Rails 7.1+ | PostgreSQL | Redis | RSpec | FactoryBot

**Contact**: Development team channel for questions and feedback

---

**End of Document**
