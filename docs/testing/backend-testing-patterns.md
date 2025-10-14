# Backend Testing Patterns (RSpec)

## Table of Contents
1. [Setup and Configuration](#setup-and-configuration)
2. [Testing Framework and Tools](#testing-framework-and-tools)
3. [Test Structure and Organization](#test-structure-and-organization)
4. [Factory Pattern](#factory-pattern)
5. [Mocking and Stubbing](#mocking-and-stubbing)
6. [Request/API Testing](#requestapi-testing)
7. [Model Testing](#model-testing)
8. [Service Testing](#service-testing)
9. [Job Testing](#job-testing)
10. [Mailer Testing](#mailer-testing)
11. [Listener/Observer Testing](#listenerobserver-testing)
12. [Best Practices](#best-practices)
13. [Running Tests](#running-tests)

---

## Setup and Configuration

### Configuration Files

#### `spec/spec_helper.rb`
- Loads WebMock for HTTP request stubbing
- Disables external network connections (except localhost)
- Configures RSpec expectations and mocks
- Provides `with_modified_env` helper for testing with environment variables

```ruby
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
```

#### `spec/rails_helper.rb`
- Loads Rails environment and RSpec Rails integration
- Includes Pundit for authorization testing
- Configures Sidekiq testing mode
- Loads test-prof optimization tools (`before_all`, `let_it_be`)
- Auto-loads all support files from `spec/support/**/*.rb`
- Includes FactoryBot syntax methods
- Mocks Stripe billing jobs globally (unless testing billing specifically)
- Uses transactional fixtures (`config.use_transactional_fixtures = true`)
- Includes test helpers (SlackStubs, FileUploadHelpers, CsvSpecHelpers, etc.)
- Configures Devise test helpers for request specs
- Includes ActiveSupport TimeHelpers and ActionCable TestHelper
- Configures Shoulda Matchers for Rails

### Environment Requirements

Tests require specific environment variables to be overridden:
- `POSTGRES_HOST`: Database host (usually `localhost` for tests)
- `REDIS_URL`: Redis connection string (e.g., `redis://:password@localhost:6379/0`)
- `RAILS_ENV=test`: Must be set to `test`

Example:
```bash
POSTGRES_HOST=localhost REDIS_URL=redis://localhost:6379/0 RAILS_ENV=test bundle exec rspec
```

---

## Testing Framework and Tools

### Core Testing Tools

| Tool | Purpose |
|------|---------|
| **RSpec** | Main testing framework |
| **FactoryBot** | Test data generation |
| **WebMock** | HTTP request stubbing |
| **Shoulda Matchers** | Rails-specific matchers (associations, validations) |
| **Pundit RSpec** | Authorization policy testing |
| **Sidekiq::Testing** | Background job testing |
| **test-prof** | Test suite optimization (`before_all`, `let_it_be`) |
| **Devise Test Helpers** | Authentication helpers for request specs |
| **ActiveSupport::Testing::TimeHelpers** | Time manipulation (`travel_to`, `freeze_time`) |
| **ActionCable::TestHelper** | WebSocket testing |
| **ActiveJob::TestHelper** | Job queue testing |

---

## Test Structure and Organization

### Directory Structure

```
spec/
├── factories/              # FactoryBot factory definitions
├── fixtures/               # Static test data files
├── support/                # Shared helpers and configuration
│   ├── slack_stubs.rb
│   ├── file_upload_helpers.rb
│   ├── csv_spec_helpers.rb
│   └── instagram_spec_helpers.rb
├── models/                 # Model specs
├── services/               # Service object specs
├── jobs/                   # Background job specs
├── mailers/                # Mailer specs
├── requests/               # API/Controller request specs
├── listeners/              # Event listener specs
└── enterprise/             # Enterprise edition specs
```

### File Naming Convention

- Model specs: `spec/models/account_spec.rb`
- Service specs: `spec/services/ai_backend_service/configuration_service_spec.rb`
- Request specs: `spec/requests/api/v1/integrations/webhooks_request_spec.rb`
- Job specs: `spec/jobs/billing/provision_stripe_subscription_job_spec.rb`
- Mailer specs: `spec/mailers/confirmation_instructions_spec.rb`
- Listener specs: `spec/listeners/ai_backend_listener_spec.rb`

### Spec File Structure

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ModelOrClassName do
  # Test type can be inferred or explicitly set
  # describe 'Class.method_name' do ... end (for class methods)
  # describe '#method_name' do ... end (for instance methods)

  describe '#method_name' do
    let(:variable_name) { create(:factory_name) }

    context 'when condition is met' do
      it 'does something specific' do
        expect(result).to eq(expected_value)
      end
    end

    context 'when condition is not met' do
      it 'handles the alternate case' do
        expect { action }.to raise_error(ErrorClass)
      end
    end
  end
end
```

---

## Factory Pattern

### FactoryBot Configuration

Factories are located in `spec/factories/` and use the FactoryBot DSL.

#### Basic Factory Example

```ruby
# spec/factories/accounts.rb
FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    status { 'active' }
    domain { 'test.com' }
    support_email { 'support@test.com' }
  end
end
```

#### Using Factories in Tests

```ruby
# Create and persist
account = create(:account)

# Build without persisting
account = build(:account)

# Build with attributes
account = build(:account, name: 'Custom Name')

# Create with associations
inbox = create(:inbox, account: account)
```

#### Factory Traits and Advanced Patterns

Factories can include traits, associations, and callbacks:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { 'Test User' }
    password { 'password123' }

    trait :administrator do
      role { :administrator }
    end

    trait :skip_confirmation do
      after(:create) { |user| user.confirm }
    end
  end
end

# Usage
admin_user = create(:user, :administrator, :skip_confirmation)
```

---

## Mocking and Stubbing

### RSpec Mocking Patterns

#### Stubbing Methods

```ruby
# Stub instance method
allow(service).to receive(:method_name).and_return(value)

# Stub class method
allow(ClassName).to receive(:method_name).and_return(value)

# Stub method chain
allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(url)
```

#### Expectations (Verification)

```ruby
# Verify method was called
expect(service).to have_received(:method_name)

# Verify with specific arguments
expect(service).to have_received(:method_name).with(arg1, arg2)

# Verify call count
expect(service).to have_received(:method_name).once
expect(service).to have_received(:method_name).twice
expect(service).to have_received(:method_name).exactly(3).times
```

#### Doubles and Spies

```ruby
# Create a double
service_double = double('ServiceName')
allow(service_double).to receive(:perform).and_return({ success: true })

# Create an instance double (stricter, verifies method exists)
service_double = instance_double(ServiceClass)
allow(service_double).to receive(:perform).and_return(result)

# Spy pattern (allow first, verify later)
allow(Service).to receive(:method_name)
# ... test code ...
expect(Service).to have_received(:method_name)
```

#### Stubbing HTTP Requests (WebMock)

```ruby
# Stub a GET request
stub_request(:get, "#{api_url}/api/configurations")
  .to_return(status: 200, body: { data: 'value' }.to_json)

# Stub a POST request
stub_request(:post, "#{api_url}/api/endpoint")
  .with(body: hash_including({ key: 'value' }))
  .to_return(status: 201, body: { id: 123 }.to_json)

# Verify request was made
expect(a_request(:get, url)).to have_been_made
```

#### Stubbing Rails Logger

```ruby
allow(Rails.logger).to receive(:info)
allow(Rails.logger).to receive(:error)

# Verify logging
expect(Rails.logger).to have_received(:info).with(/pattern/)
```

---

## Request/API Testing

### Basic Request Spec Structure

```ruby
require 'rails_helper'

RSpec.describe 'Api::V1::Integrations::Webhooks' do
  describe 'POST /api/v1/integrations/webhooks' do
    it 'consumes webhook' do
      builder = Integrations::Slack::IncomingMessageBuilder.new({})
      expect(builder).to receive(:perform).and_return(true)
      expect(Integrations::Slack::IncomingMessageBuilder).to receive(:new).and_return(builder)

      post '/api/v1/integrations/webhooks', params: {}

      expect(response).to have_http_status(:success)
    end
  end
end
```

### Authentication in Request Specs

```ruby
# Include Devise helpers (already configured globally)
let(:user) { create(:user) }

before do
  sign_in user  # Devise helper
end

it 'authenticates successfully' do
  get '/api/v1/accounts'
  expect(response).to have_http_status(:ok)
end
```

### Common Request Matchers

```ruby
# Status matchers
expect(response).to have_http_status(:success)       # 2xx
expect(response).to have_http_status(:ok)            # 200
expect(response).to have_http_status(:created)       # 201
expect(response).to have_http_status(:unauthorized)  # 401
expect(response).to have_http_status(:not_found)     # 404

# Response body
parsed_body = JSON.parse(response.body)
expect(parsed_body['key']).to eq('value')
```

---

## Model Testing

### Association Testing (Shoulda Matchers)

```ruby
RSpec.describe Account do
  # Associations
  it { is_expected.to have_many(:users).through(:account_users) }
  it { is_expected.to have_many(:inboxes).dependent(:destroy_async) }
  it { is_expected.to belong_to(:parent).optional }

  # Validations
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:email) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }
end
```

### Custom Model Behavior Testing

```ruby
describe '#method_name' do
  let(:account) { create(:account) }

  it 'returns expected value' do
    expect(account.method_name).to eq(expected_value)
  end

  context 'when condition changes' do
    before do
      account.update(attribute: new_value)
    end

    it 'adapts behavior' do
      expect(account.method_name).to eq(different_value)
    end
  end
end
```

### Testing with Environment Variables

```ruby
it 'uses environment variable when domain is nil' do
  account.update(domain: nil)
  with_modified_env MAILER_INBOUND_EMAIL_DOMAIN: 'test.com' do
    expect(account.inbound_email_domain).to eq('test.com')
  end
end
```

### Testing Scopes

```ruby
describe '.with_auto_resolve' do
  it 'finds accounts with auto_resolve_after set' do
    account.update(auto_resolve_after: 40 * 24 * 60)
    expect(described_class.with_auto_resolve).to include(account)
  end

  it 'excludes accounts without auto_resolve_after' do
    account.update(auto_resolve_after: nil)
    expect(described_class.with_auto_resolve).not_to include(account)
  end
end
```

---

## Service Testing

### Service Object Testing Pattern

```ruby
RSpec.describe AiBackendService::ConfigurationService do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }
  let(:service) { described_class.new }
  let(:scope) { AiBackendService::Constants::Scope::STORE }
  let(:resource_id) { 123 }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)
  end

  describe '#save_configuration' do
    let(:config_data) { { timezone: 'America/New_York' } }

    before do
      stub_request(:put, "#{ai_backend_url}/api/configurations")
        .to_return(status: 200, body: { success: true }.to_json)
    end

    it 'saves configuration successfully' do
      service.save_configuration(
        scope: scope,
        resource_id: resource_id,
        config_key: config_key,
        config_data: config_data
      )

      expect(a_request(:put, "#{ai_backend_url}/api/configurations")).to have_been_made
    end
  end
end
```

### Testing Service Dependencies

```ruby
it 'uses configuration service to fetch data' do
  config_service = instance_double(ConfigurationService)
  allow(ConfigurationService).to receive(:new).and_return(config_service)
  allow(config_service).to receive(:get_configuration).and_return({})

  service.perform

  expect(config_service).to have_received(:get_configuration)
end
```

---

## Job Testing

### Background Job Testing Pattern

```ruby
RSpec.describe Billing::ProvisionStripeSubscriptionJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:plan_name) { 'starter' }

  describe '#perform' do
    it 'enqueues the job' do
      expect {
        described_class.perform_later(account.id, plan_name)
      }.to have_enqueued_job(described_class)
        .with(account.id, plan_name)
        .on_queue('default')
    end

    it 'calls the service with correct arguments' do
      service_double = double('ServiceClass')
      allow(ServiceClass).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:perform).and_return({ success: true })

      described_class.new.perform(account.id, plan_name)

      expect(ServiceClass).to have_received(:new).with(account, plan_name, hash_including(:trial_period_days))
    end
  end
end
```

### Testing Job State Changes

```ruby
it 'updates account status after job completion' do
  described_class.new.perform(account.id, plan_name)

  account.reload
  expect(account.custom_attributes['billing_status']).to eq('completed')
end
```

### Testing Job Error Handling

```ruby
it 'logs error and updates status on failure' do
  allow(service_double).to receive(:perform).and_raise(StandardError, 'Network error')

  expect(Rails.logger).to receive(:error).with(/Network error/)

  expect {
    described_class.new.perform(account.id, plan_name)
  }.to raise_error(StandardError, 'Network error')

  account.reload
  expect(account.custom_attributes['billing_status']).to eq('failed')
end
```

---

## Mailer Testing

### Mailer Spec Pattern

```ruby
RSpec.describe 'Devise::Mailer' do
  let(:account) { create(:account) }
  let(:confirmable_user) { create(:user, account: account) }
  let(:mail) { Devise::Mailer.confirmation_instructions(confirmable_user.reload, nil, {}) }

  before do
    confirmable_user.update!(confirmed_at: nil)
    confirmable_user.send(:generate_confirmation_token)
  end

  it 'has the correct header data' do
    expect(mail.reply_to).to contain_exactly('accounts@chatwoot.com')
    expect(mail.to).to contain_exactly(confirmable_user.email)
    expect(mail.subject).to eq('Confirmation Instructions')
  end

  it 'includes expected content' do
    expect(mail.body).to match("Hi #{CGI.escapeHTML(confirmable_user.name)}")
    expect(mail.body).to include("confirmation_token=#{confirmable_user.confirmation_token}")
  end
end
```

### Testing Conditional Email Content

```ruby
context 'when there is an inviter' do
  let(:inviter) { create(:user, :administrator, account: account) }
  let(:confirmable_user) { create(:user, inviter: inviter, account: account) }

  it 'refers to the inviter in email' do
    expect(mail.body).to match(CGI.escapeHTML(inviter.name))
  end
end
```

---

## Listener/Observer Testing

### Event Listener Testing Pattern

```ruby
RSpec.describe AiBackendListener do
  let(:listener) { described_class.instance }

  describe '#account_created' do
    let(:account) { create(:account, id: 123) }
    let(:user) { create(:user, email: 'admin@example.com') }
    let(:event) { double(data: { account: account }) }

    before do
      allow(account).to receive(:users).and_return([user])
    end

    it 'creates store in AI backend' do
      store_service = instance_double(AiBackendService::StoreService)
      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(store_service).to receive(:create_store)

      listener.account_created(event)

      expect(store_service).to have_received(:create_store).with(account, 'admin@example.com')
    end

    it 'logs success message' do
      allow(AiBackendService::StoreService).to receive(:new).and_return(store_service)
      allow(Rails.logger).to receive(:info)

      listener.account_created(event)

      expect(Rails.logger).to have_received(:info).with(/Store created for account 123/)
    end
  end
end
```

### Testing Error Handling in Listeners

```ruby
it 'logs error on failure' do
  allow(ServiceClass).to receive(:new).and_raise(ServiceClass::CustomError.new('API error'))
  allow(Rails.logger).to receive(:error)

  listener.event_handler(event)

  expect(Rails.logger).to have_received(:error).with(/error message pattern/)
end

it 'does not raise error on failure' do
  allow(ServiceClass).to receive(:new).and_raise(StandardError)

  expect { listener.event_handler(event) }.not_to raise_error
end
```

---

## Best Practices

### 1. Use `let` and `let!` Appropriately

```ruby
# Lazy evaluation (only created when referenced)
let(:account) { create(:account) }

# Eager evaluation (created before each test)
let!(:account) { create(:account) }
```

### 2. Use `before` Blocks for Setup

```ruby
before do
  # Runs before each test in this context
  setup_test_data
end
```

### 3. Use Contexts for Different Scenarios

```ruby
context 'when user is authenticated' do
  # tests
end

context 'when user is not authenticated' do
  # tests
end
```

### 4. Use Descriptive Test Names

```ruby
# Good
it 'creates store with admin email when users exist' do

# Avoid
it 'works' do
```

### 5. Test One Thing Per Test

```ruby
# Good
it 'creates a user' do
  expect { subject }.to change(User, :count).by(1)
end

it 'sends welcome email' do
  expect(WelcomeMailer).to receive(:send_welcome).once
  subject
end

# Avoid testing multiple things
it 'creates user and sends email and logs event' do
  # Too much in one test
end
```

### 6. Use Appropriate Matchers

```ruby
# Shoulda matchers for models
it { is_expected.to validate_presence_of(:email) }

# Change matchers
expect { action }.to change(Model, :count).by(1)

# Have_received for mocks
expect(service).to have_received(:method)

# Raise error
expect { action }.to raise_error(ErrorClass)
```

### 7. Stub External Dependencies

```ruby
# Always stub HTTP requests
stub_request(:get, url).to_return(status: 200, body: '{}')

# Stub expensive operations
allow(ExpensiveService).to receive(:call).and_return(result)
```

### 8. Test Edge Cases and Error Conditions

```ruby
context 'when account does not exist' do
  it 'logs error and returns early' do
    described_class.new.perform(invalid_id, plan_name)
    expect(Service).not_to receive(:new)
  end
end
```

### 9. Use Test Optimization Tools

```ruby
# test-prof optimization
let_it_be(:account) { create(:account) }  # Created once per example group

before_all do
  # Runs once for the entire example group
  @account = create(:account)
end
```

### 10. Keep Tests Isolated

- Each test should be able to run independently
- Use transactional fixtures (enabled by default)
- Don't rely on test execution order
- Clean up after tests (handled automatically with transactions)

---

## Running Tests

### Run All Tests

```bash
bundle exec rspec
```

### Run Specific File

```bash
bundle exec rspec spec/models/account_spec.rb
```

### Run Specific Test by Line Number

```bash
bundle exec rspec spec/models/account_spec.rb:42
```

### Run Tests with Environment Variables

```bash
POSTGRES_HOST=localhost REDIS_URL=redis://localhost:6379/0 bundle exec rspec
```

### Run Tests with Filtering

```bash
# Run only tests marked with focus: true
bundle exec rspec --tag focus

# Exclude slow tests
bundle exec rspec --tag ~slow
```

### Run Tests in Parallel (if configured)

```bash
bundle exec parallel_rspec spec/
```

### Run Tests with Coverage

```bash
COVERAGE=true bundle exec rspec
```

### Debugging Tests

```bash
# Add binding.pry in test code
require 'pry'

it 'debugs here' do
  binding.pry  # Execution will pause here
  expect(result).to eq(value)
end
```

---

## Common Patterns Summary

| Pattern | Example |
|---------|---------|
| **Model associations** | `it { is_expected.to have_many(:users) }` |
| **Request specs** | `post '/api/endpoint', params: {}` |
| **HTTP stubbing** | `stub_request(:get, url).to_return(body: '{}')` |
| **Method stubbing** | `allow(service).to receive(:method).and_return(value)` |
| **Expectation** | `expect(service).to have_received(:method)` |
| **Factory creation** | `create(:account)` |
| **Instance double** | `instance_double(ClassName)` |
| **Job enqueuing** | `expect { job }.to have_enqueued_job(JobClass)` |
| **Error testing** | `expect { action }.to raise_error(ErrorClass)` |
| **Time manipulation** | `travel_to(Time.current) { ... }` |

---

## Troubleshooting

### Common Issues

1. **Tests fail due to external HTTP calls**
   - Solution: Stub with WebMock: `stub_request(:get, url)`

2. **Database connection errors**
   - Solution: Override `POSTGRES_HOST` environment variable

3. **Redis connection errors**
   - Solution: Override `REDIS_URL` environment variable

4. **Billing job interference**
   - Rails helper automatically mocks billing jobs globally

5. **Transient test failures**
   - Use `travel_to` for time-dependent tests
   - Ensure proper test isolation
   - Check for race conditions in async operations

6. **Slow tests**
   - Use `let_it_be` and `before_all` from test-prof
   - Reduce factory creation overhead
   - Profile tests: `bundle exec rspec --profile`
