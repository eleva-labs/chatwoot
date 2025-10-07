# AI Backend Service

Comprehensive service layer for integrating Chatwoot with the AI Backend API.

## Overview

This service provides:
- **External ID Mapping**: Use Chatwoot IDs (account.id, bot.id, user.id) to query AI backend resources
- **Event-Driven Sync**: Automatic resource creation via Rails events
- **Configuration Management**: Save/retrieve configurations with scope and id_type support
- **Type Safety**: Ruby Structs for API contract validation

## ⚠️ IMPORTANT: External ID Usage

**ALL services default to using `id_type=external` with Chatwoot IDs.**

- **Stores** are referenced by `account.id` (Chatwoot account ID)
- **Agent Systems** are referenced by `agent_bot.id` (Chatwoot bot ID)
- **Users** are referenced by `user.id` (Chatwoot user ID)

When calling AI Backend APIs that require `store_id` as a parameter (like creating users or agent systems), **ALWAYS pass the Chatwoot account.id**, not the AI Backend's internal store UUID.

### ✅ Correct Pattern
```ruby
# Creating a user - use account.id for store_id
user_service = AiBackendService::UserService.new  # Defaults to id_type=external
user_service.create_user(user, account.id)  # ✅ account.id is used as store_id
# API call: POST /api/users?store_id=123&id_type=external

# Creating an agent system - use account.id for store_id
agent_system_service = AiBackendService::AgentSystemService.new
agent_system_service.create_agent_system(agent_bot, account.id)  # ✅ account.id
# API call: POST /api/agent-systems?store_id=123&id_type=external
```

### ❌ Incorrect Pattern
```ruby
# DON'T use the internal UUID returned from get_store
store_service = AiBackendService::StoreService.new
store_response = store_service.get_store(account.id)
user_service.create_user(user, store_response.id)  # ❌ Wrong! This is a UUID
# This will fail with 404 because id_type=external expects account.id, not UUID
```

---

## Constants & Enums

All services use constants defined in `constants.rb`:

### ID Types
```ruby
AiBackendService::Constants::IdType::EXTERNAL  # 'external' - Chatwoot IDs (default)
AiBackendService::Constants::IdType::INTERNAL  # 'internal' - AI Backend UUIDs
```

### Scopes (Resource Types)
```ruby
AiBackendService::Constants::Scope::STORE         # 'store'
AiBackendService::Constants::Scope::AGENT_SYSTEM  # 'agent_system'
AiBackendService::Constants::Scope::USER          # 'user'
```

### Configuration Keys
```ruby
# Store configurations
AiBackendService::Constants::ConfigKey::NOTIFICATIONS   # 'notifications_config'
AiBackendService::Constants::ConfigKey::MESSAGING       # 'messaging_config'
AiBackendService::Constants::ConfigKey::GENERAL_STORE   # 'general_store_config'
AiBackendService::Constants::ConfigKey::ECOMMERCE       # 'ecommerce_config'
AiBackendService::Constants::ConfigKey::CALENDLY        # 'calendly_config'
AiBackendService::Constants::ConfigKey::CONVERSATION    # 'conversation_config'

# Agent system configurations
AiBackendService::Constants::ConfigKey::AGENT_BEHAVIOR  # 'agent_behavior_config'
AiBackendService::Constants::ConfigKey::AGENT_KNOWLEDGE # 'agent_knowledge_config'

# User configurations
AiBackendService::Constants::ConfigKey::USER_PREFERENCES # 'user_preferences_config'
```

---

## Services

### 1. StoreService

Manage stores (mapped to Chatwoot accounts).

#### Usage

```ruby
# Initialize with default id_type (external)
store_service = AiBackendService::StoreService.new

# Create store (automatically called via event listener)
account = Account.find(123)
store_response = store_service.create_store(account, 'admin@example.com')
# => Returns StoreResponse with external_id: "123"

# Get store by Chatwoot account.id
store = store_service.get_store(123)
# GET /api/stores/123?id_type=external

# Update store
store_service.update_store(123, { name: 'New Name', is_active: true })

# Use internal UUID instead
internal_service = AiBackendService::StoreService.new(id_type: AiBackendService::Constants::IdType::INTERNAL)
store = internal_service.get_store('uuid-abc-123')
# GET /api/stores/uuid-abc-123?id_type=internal
```

---

### 2. AgentSystemService

Manage agent systems (mapped to Chatwoot agent bots).

#### Usage

```ruby
agent_system_service = AiBackendService::AgentSystemService.new

# Create agent system (automatically called via event listener)
agent_bot = AgentBot.find(456)
store_id = 'store-uuid-123' # AI backend's internal store ID
agent_system_service.create_agent_system(agent_bot, store_id)
# => Creates agent system with external_id: "456"

# Get agent system by Chatwoot bot.id
agent_system = agent_system_service.get_agent_system(456)
# GET /api/agent-systems/456?id_type=external
```

---

### 3. UserService

Manage users (mapped to Chatwoot users).

#### Usage

```ruby
user_service = AiBackendService::UserService.new

# Create user (automatically called via event listener)
user = User.find(789)
store_id = 'store-uuid-123'
user_service.create_user(user, store_id)
# => Creates user with external_id: "789"

# Get user by Chatwoot user.id
user = user_service.get_user(789)
# GET /api/users/789?id_type=external
```

---

### 4. ConfigurationService ⭐ NEW

Save, retrieve, and manage configurations for any resource with scope and id_type support.

#### Usage

```ruby
# Initialize with default id_type (external)
config_service = AiBackendService::ConfigurationService.new

# Save configuration for a store (using Chatwoot account.id)
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: 123,  # Chatwoot account.id
  config_key: AiBackendService::Constants::ConfigKey::GENERAL_STORE,
  config_data: {
    timezone: 'America/New_York',
    start_business_hour: 9,
    end_business_hour: 17
  }
)

# Get configuration
config_data = config_service.get_configuration(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: 123,
  config_key: AiBackendService::Constants::ConfigKey::GENERAL_STORE
)
# => { timezone: 'America/New_York', start_business_hour: 9, ... }

# Get all configurations for a resource
all_configs = config_service.get_all_configurations(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: 123
)
# => { 'general_store_config' => {...}, 'messaging_config' => {...}, ... }

# Delete configuration
config_service.delete_configuration(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: 123,
  config_key: AiBackendService::Constants::ConfigKey::MESSAGING
)

# Batch save multiple configurations
config_service.batch_save_configurations(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: 123,
  configurations: {
    AiBackendService::Constants::ConfigKey::GENERAL_STORE => { timezone: 'UTC' },
    AiBackendService::Constants::ConfigKey::MESSAGING => { enabled: true }
  }
)

# Use with agent systems
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::AGENT_SYSTEM,
  resource_id: 456,  # Chatwoot bot.id
  config_key: AiBackendService::Constants::ConfigKey::AGENT_BEHAVIOR,
  config_data: { temperature: 0.7, max_tokens: 1000 }
)

# Use with users
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::USER,
  resource_id: 789,  # Chatwoot user.id
  config_key: AiBackendService::Constants::ConfigKey::USER_PREFERENCES,
  config_data: { language: 'en', notifications_enabled: true }
)
```

#### Configuration Merging

When saving configurations, new data is **merged** with existing data:

```ruby
# First save
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: 123,
  config_key: AiBackendService::Constants::ConfigKey::GENERAL_STORE,
  config_data: { timezone: 'UTC', start_business_hour: 9 }
)

# Second save - merges with existing data
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: 123,
  config_key: AiBackendService::Constants::ConfigKey::GENERAL_STORE,
  config_data: { end_business_hour: 17 }
)

# Result: { timezone: 'UTC', start_business_hour: 9, end_business_hour: 17 }
```

---

## Event-Driven Synchronization

Resources are automatically synced to AI backend via Rails events (handled by `AiBackendListener`):

### Account Creation → Store Creation
```ruby
# When account is created
account = Account.create!(name: 'Test Store')

# Event dispatcher triggers:
Rails.configuration.dispatcher.dispatch(ACCOUNT_CREATED, Time.zone.now, account: account)

# AiBackendListener.account_created handles it:
# - Creates store in AI backend with external_id = account.id
# - Logs success/failure
# - Non-blocking (errors logged, not raised)
```

### Agent Bot Creation → Agent System Creation
```ruby
# When bot is created
agent_bot = AgentBot.create!(account: account, name: 'Support Bot')

# Event dispatcher triggers:
Rails.configuration.dispatcher.dispatch(AGENT_BOT_CREATED, Time.zone.now, agent_bot: agent_bot)

# AiBackendListener.agent_bot_created handles it:
# - Gets store by account.id using external_id
# - Creates agent system with external_id = agent_bot.id
# - System bots (account_id: nil) are skipped
```

### User Addition → User Creation
```ruby
# When user is added to account
AccountUser.create!(account: account, user: user, role: :agent)

# Event dispatcher triggers:
Rails.configuration.dispatcher.dispatch(AGENT_ADDED, Time.zone.now, account: account, account_user: account_user)

# AiBackendListener.agent_added handles it:
# - Gets store by account.id
# - Creates user with external_id = user.id
```

---

## Data Schemas

Type-safe request/response schemas defined in `schemas.rb`:

### StoreRequest
```ruby
store_request = AiBackendService::Schemas::StoreRequest.from_account(account, 'admin@example.com')
store_request.to_h
# => { name: 'Store Name', email: 'admin@example.com', external_id: '123', is_active: true, ... }
```

### AgentSystemRequest
```ruby
agent_system_request = AiBackendService::Schemas::AgentSystemRequest.from_agent_bot(agent_bot, store_id)
agent_system_request.to_h
# => { name: 'Bot Name', external_id: '456', store_id: 'uuid-...', ... }
```

### UserRequest
```ruby
user_request = AiBackendService::Schemas::UserRequest.from_user(user, store_id)
user_request.to_h
# => { name: 'User Name', email: 'user@example.com', external_id: '789', ... }
```

---

## Error Handling

All services have custom exception classes:

```ruby
begin
  store_service.get_store(999)  # Non-existent store
rescue AiBackendService::StoreService::StoreError => e
  Rails.logger.error "Store lookup failed: #{e.message}"
end

begin
  config_service.save_configuration(...)
rescue AiBackendService::ConfigurationService::ConfigurationError => e
  Rails.logger.error "Configuration save failed: #{e.message}"
end
```

Listener operations are wrapped in rescue blocks and **do not raise errors** to avoid blocking Chatwoot operations.

---

## Testing

Use WebMock to stub HTTP requests:

```ruby
RSpec.describe 'My Feature' do
  let(:ai_backend_url) { 'https://test.ai-backend.com' }

  before do
    allow(Rails.application.config).to receive(:ai_backend_api_url).and_return(ai_backend_url)

    stub_request(:post, "#{ai_backend_url}/api/stores")
      .to_return(status: 200, body: { id: 'uuid-123', external_id: '123' }.to_json)
  end

  it 'creates store in AI backend' do
    service = AiBackendService::StoreService.new
    service.create_store(account, 'test@example.com')

    expect(a_request(:post, "#{ai_backend_url}/api/stores")).to have_been_made
  end
end
```

---

## Configuration Examples

### Store Configuration
```ruby
config_service = AiBackendService::ConfigurationService.new

# General store settings
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: account.id,
  config_key: AiBackendService::Constants::ConfigKey::GENERAL_STORE,
  config_data: {
    timezone: 'America/Costa_Rica',
    start_business_hour: 6,
    end_business_hour: 19
  }
)

# Messaging configuration
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: account.id,
  config_key: AiBackendService::Constants::ConfigKey::MESSAGING,
  config_data: {
    whatsapp: {
      type: 'whapi',
      enabled: true,
      api_key: ENV['WHAPI_API_KEY']
    }
  }
)

# Ecommerce configuration
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::STORE,
  resource_id: account.id,
  config_key: AiBackendService::Constants::ConfigKey::ECOMMERCE,
  config_data: {
    type: 'appointment_setting',
    spreadsheet_id: 'your-spreadsheet-id'
  }
)
```

### Agent System Configuration
```ruby
config_service.save_configuration(
  scope: AiBackendService::Constants::Scope::AGENT_SYSTEM,
  resource_id: agent_bot.id,
  config_key: AiBackendService::Constants::ConfigKey::AGENT_BEHAVIOR,
  config_data: {
    temperature: 0.7,
    max_tokens: 1000,
    personality: 'helpful and friendly'
  }
)
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Chatwoot                              │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Account  │    │AgentBot  │    │   User   │              │
│  │(id: 123) │    │(id: 456) │    │(id: 789) │              │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘              │
│       │               │               │                      │
│       │ ACCOUNT_      │ AGENT_BOT_    │ AGENT_               │
│       │ CREATED       │ CREATED       │ ADDED                │
│       ▼               ▼               ▼                      │
│  ┌───────────────────────────────────────────┐              │
│  │        AiBackendListener                  │              │
│  └───────────────────────────────────────────┘              │
│       │               │               │                      │
│       │ StoreService  │ AgentSystem   │ UserService          │
│       │               │ Service       │                      │
│       ▼               ▼               ▼                      │
└───────┼───────────────┼───────────────┼──────────────────────┘
        │               │               │
        │               │               │
        ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                     AI Backend API                           │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Store      │  │AgentSystem   │  │    User      │      │
│  │              │  │              │  │              │      │
│  │id: uuid-abc  │  │id: uuid-def  │  │id: uuid-ghi  │      │
│  │external_id:  │  │external_id:  │  │external_id:  │      │
│  │    '123'     │  │    '456'     │  │    '789'     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Configurations (scope + resource_id)       │   │
│  │  - general_store_config                              │   │
│  │  - messaging_config                                  │   │
│  │  - agent_behavior_config                             │   │
│  │  - user_preferences_config                           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Best Practices

1. **Always use constants** instead of hardcoded strings:
   ```ruby
   # Good
   AiBackendService::Constants::Scope::STORE

   # Bad
   'store'
   ```

2. **Use external ID type** (default) for querying with Chatwoot IDs:
   ```ruby
   store_service.get_store(account.id)  # Uses external_id automatically
   ```

3. **Handle errors gracefully** in application code:
   ```ruby
   begin
     config_service.save_configuration(...)
   rescue AiBackendService::ConfigurationService::ConfigurationError => e
     # Log error, show user message, etc.
   end
   ```

4. **Let event listeners handle sync** - don't call services directly unless needed:
   ```ruby
   # Automatic (preferred)
   Account.create!(name: 'New Store')  # Event listener creates store in AI backend

   # Manual (only if needed)
   AiBackendService::StoreService.new.create_store(account, email)
   ```

5. **Configuration merging** - Save incremental updates:
   ```ruby
   # Update only specific fields, existing data is preserved
   config_service.save_configuration(..., config_data: { timezone: 'UTC' })
   ```

---

## Contributing

When adding new configuration keys:

1. Add constant to `Constants::ConfigKey`
2. Add to appropriate scope array (`STORE_CONFIGS`, `AGENT_CONFIGS`, `USER_CONFIGS`)
3. Update this README with usage examples
4. Add specs for the new configuration

---

**Last Updated**: 2025-10-06
**Version**: 2.0.0
