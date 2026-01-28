# Chatwoot Architecture Overview

**Version**: 1.0.0
**Last Updated**: 2025-10-06
**Status**: Active
**Purpose**: Reference document for understanding Chatwoot's architecture, stack, and patterns

---

## Table of Contents

1. [Overview](#overview)
2. [Technology Stack](#technology-stack)
3. [Application Architecture](#application-architecture)
4. [Directory Structure](#directory-structure)
5. [Key Components](#key-components)
6. [Development Patterns](#development-patterns)
7. [Testing Strategy](#testing-strategy)
8. [Related Documentation](#related-documentation)

---

## Overview

### What is Chatwoot?

Chatwoot is an **open-source customer engagement platform** built as a full-stack Ruby on Rails application with a Vue.js frontend. It provides:
- Multi-channel messaging (WhatsApp, Email, Social Media, Web Chat)
- Customer support and conversation management
- Team collaboration features
- Automation and chatbot capabilities
- Analytics and reporting

### Architecture Style

**Monolithic Rails Application** with:
- **Backend**: Ruby on Rails 7.1+ (MVC + Service-oriented architecture)
- **Frontend**: Vue 3 (Composition API) with Vuex state management
- **Database**: PostgreSQL (primary), Redis (cache + real-time)
- **Real-time**: ActionCable (WebSockets)
- **Background Jobs**: Sidekiq (Redis-backed)

### Key Architectural Principles

1. **Rails MVC Pattern** - Models, Views, Controllers with service objects
2. **Component-Based Frontend** - Reusable Vue 3 components
3. **Real-time First** - WebSocket-driven updates via ActionCable
4. **Multi-tenancy** - Account-based isolation (no schema separation)
5. **Service-oriented** - Business logic extracted into service classes
6. **Event-driven** - Listeners and dispatchers for decoupled operations

---

## Technology Stack

### Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| **Ruby** | 3.x | Programming language |
| **Rails** | 7.1+ | Web framework (MVC, ORM, migrations) |
| **PostgreSQL** | Latest | Primary database |
| **Redis** | Latest | Cache, sessions, real-time, job queue |
| **Sidekiq** | Latest | Background job processing |
| **ActionCable** | Built-in | WebSocket server for real-time |
| **Puma** | Built-in | Application server |

**Key Gems**:
- `acts-as-taggable-on` - Tagging functionality
- `kaminari` - Pagination
- `jbuilder` - JSON API responses
- `liquid` - Template parsing (for automation)
- `commonmarker` - Markdown parsing
- `rack-attack` - Rate limiting
- `flag_shih_tzu` - Feature flags

### Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| **Vue.js** | 3.5+ | UI framework (Composition API) |
| **Vuex** | 4.1+ | State management |
| **Vue Router** | 4.4+ | Client-side routing |
| **Vite** | 5.4+ | Build tool (replaces Webpacker) |
| **Tailwind CSS** | 3.4+ | Utility-first CSS framework |
| **Axios** | 1.8+ | HTTP client |
| **ActionCable** | 6.1.3 | WebSocket client |

**Key Libraries**:
- `@vueuse/core` - Vue composition utilities
- `vue-i18n` - Internationalization
- `chart.js` + `vue-chartjs` - Analytics charts
- `floating-vue` - Tooltips and popovers
- `prosemirror` - Rich text editor
- `vitest` - Testing framework

### Development Tools

| Tool | Purpose |
|------|---------|
| **RuboCop** | Ruby linting and formatting |
| **ESLint** | JavaScript/Vue linting |
| **Prettier** | Code formatting |
| **RSpec** | Ruby testing framework |
| **Vitest** | Vue/JavaScript testing |
| **Overmind** | Process manager for development |
| **Husky** | Git hooks for pre-commit checks |

---

## Application Architecture

### Rails Application Structure

```
app/
├── actions/           # Service objects for complex operations
├── builders/          # Builder pattern implementations
├── channels/          # ActionCable channel definitions
├── controllers/       # HTTP request handlers (API + Web)
│   ├── api/          # API controllers (JSON responses)
│   ├── public/       # Public-facing controllers
│   └── webhooks/     # Webhook receivers
├── dispatchers/       # Event dispatchers (pub/sub)
├── fields/            # Custom field definitions
├── finders/           # Query objects (complex database queries)
├── helpers/           # View helpers
├── jobs/              # Background job classes (Sidekiq)
├── listeners/         # Event listeners (subscribe to events)
├── mailboxes/         # ActionMailbox for inbound email
├── mailers/           # Email sending logic
├── models/            # ActiveRecord models (domain objects)
├── policies/          # Authorization logic (Pundit-style)
├── presenters/        # Presentation layer objects
├── services/          # Service objects (business logic)
└── views/             # HTML/JSON views (mostly Jbuilder for API)
```

### Vue Application Structure

```
app/javascript/
├── dashboard/           # Main application
│   ├── api/            # API client modules
│   ├── assets/         # Images, fonts, static files
│   ├── components/     # Reusable Vue components
│   ├── components-next/ # New component architecture (message bubbles)
│   ├── helper/         # Utility functions
│   ├── i18n/           # Internationalization (en.json, es.json, etc.)
│   ├── mixins/         # Vue mixins (being deprecated for Composition API)
│   ├── routes/         # Vue Router configuration
│   ├── store/          # Vuex store modules
│   └── views/          # Page-level components
├── sdk/                 # Customer-facing widget SDK
├── survey/              # Survey widget
└── widget/              # Live chat widget
```

---

## Directory Structure

### Backend Key Directories

| Directory | Purpose |
|-----------|---------|
| `app/models/` | ActiveRecord models representing database tables |
| `app/controllers/api/` | REST API endpoints (JSON) |
| `app/services/` | Business logic service objects |
| `app/jobs/` | Background jobs (email sending, notifications, etc.) |
| `app/listeners/` | Event-driven listeners (decouple actions) |
| `app/builders/` | Complex object builders (e.g., message builders) |
| `app/finders/` | Query objects for complex database queries |
| `db/migrate/` | Database migrations (ActiveRecord) |
| `config/` | Application configuration |
| `lib/` | Custom libraries and utilities |
| `spec/` | RSpec tests (models, controllers, services, etc.) |

### Frontend Key Directories

| Directory | Purpose |
|-----------|---------|
| `app/javascript/dashboard/` | Main Vue 3 application |
| `app/javascript/dashboard/store/` | Vuex state management modules |
| `app/javascript/dashboard/routes/` | Vue Router routes |
| `app/javascript/dashboard/i18n/` | Translations (en.json, es.json) |
| `app/javascript/dashboard/api/` | API client wrappers |
| `app/javascript/dashboard/components/` | Reusable components |
| `app/javascript/dashboard/components-next/` | New architecture (preferred) |

### Enterprise Overlay

```
enterprise/
├── app/
│   ├── controllers/   # Enterprise-specific controllers
│   ├── models/        # Enterprise model extensions
│   ├── services/      # Enterprise services
│   └── ...            # Mirrors OSS structure
└── spec/              # Enterprise tests
```

**Note**: Enterprise features extend OSS via Rails engines and `prepend_mod_with` pattern.

---

## Key Components

### 1. Models (Domain Layer)

**Location**: `app/models/`

**Core Models**:
- `Account` - Multi-tenant account (workspace)
- `User` - System users (agents, administrators)
- `Contact` - Customers/end-users
- `Conversation` - Chat/email threads
- `Message` - Individual messages in conversations
- `Inbox` - Communication channels (referred to as "Channels" in UI)
- `Team` - Agent groups
- `Webhook` - Outbound webhook configurations

**Patterns**:
- Uses ActiveRecord associations (`has_many`, `belongs_to`, etc.)
- Validations defined in models
- Callbacks for lifecycle events (`before_save`, `after_create`, etc.)
- Scopes for common queries

### 2. Controllers (API Layer)

**Location**: `app/controllers/api/v1/`, `app/controllers/api/v2/`

**Structure**:
```ruby
module Api::V1::Accounts
  class ConversationsController < Api::V1::Accounts::BaseController
    before_action :set_conversation, only: [:show, :update]

    def index
      @conversations = ConversationsFinder.new(current_user, params).perform
    end

    def show
      # Return conversation details
    end
  end
end
```

**Patterns**:
- Namespaced under `Api::V1` or `Api::V2`
- Inherits from `BaseController` (handles auth, account scoping)
- Uses `before_action` for setup
- Delegates complex queries to Finder objects
- Returns JSON via Jbuilder views

### 3. Services (Business Logic Layer)

**Location**: `app/services/`

**Purpose**: Extract complex business logic from controllers/models

**Example Services**:
- `Messages::MessageBuilder` - Create messages
- `Conversations::AssignmentService` - Assign conversations to agents
- `Whatsapp::IncomingMessageService` - Process WhatsApp webhooks
- `Contacts::ContactMergeService` - Merge duplicate contacts

**Pattern**:
```ruby
class Conversations::AssignmentService
  def initialize(conversation:, assignee:)
    @conversation = conversation
    @assignee = assignee
  end

  def perform
    # Business logic here
    @conversation.update!(assignee: @assignee)
    dispatch_assignment_event
  end

  private

  def dispatch_assignment_event
    Rails.configuration.dispatcher.dispatch(
      CONVERSATION_ASSIGNED,
      Time.zone.now,
      conversation: @conversation
    )
  end
end
```

### 4. Jobs (Background Processing)

**Location**: `app/jobs/`

**Purpose**: Asynchronous task processing (email, notifications, webhooks)

**Example Jobs**:
- `SendReplyJob` - Send message replies via channel
- `WebhookJob` - Send outbound webhook events
- `ConversationResolveJob` - Auto-resolve conversations

**Pattern**:
```ruby
class SendReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find(message_id)
    # Send via channel provider
  end
end
```

### 5. Listeners (Event-Driven Architecture)

**Location**: `app/listeners/`

**Purpose**: React to domain events (decoupled from source)

**Example Listeners**:
- `ConversationListener` - Listen to conversation events
- `MessageListener` - Listen to message events
- `NotificationListener` - Trigger notifications

**Pattern**:
```ruby
class ConversationListener < BaseListener
  def conversation_created(event)
    conversation = event.data[:conversation]
    # Trigger notifications, webhooks, etc.
  end

  def conversation_resolved(event)
    # Handle resolution
  end
end
```

### 6. Vue Components (Frontend)

**Location**: `app/javascript/dashboard/components/`

**Structure**:
```vue
<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';

const store = useStore();
const message = ref('');

const sendMessage = () => {
  store.dispatch('sendMessage', { content: message.value });
};
</script>

<template>
  <div class="flex flex-col">
    <input v-model="message" class="border p-2" />
    <button @click="sendMessage" class="bg-blue-500 text-white">
      Send
    </button>
  </div>
</template>
```

**Patterns**:
- Always use Composition API (`<script setup>`)
- Always use Tailwind CSS utility classes (no custom CSS)
- Use `useStore()` for Vuex access
- PascalCase for component names
- camelCase for events

### 7. Vuex Store (State Management)

**Location**: `app/javascript/dashboard/store/modules/`

**Modules**:
- `conversations` - Conversation state
- `contacts` - Contact state
- `agents` - Agent/user state
- `inboxes` - Inbox state
- `notifications` - Notification state

**Pattern**:
```javascript
export default {
  namespaced: true,
  state: {
    records: [],
    uiFlags: { isFetching: false }
  },
  getters: {
    getConversations: (state) => state.records
  },
  actions: {
    async fetchConversations({ commit }) {
      commit('setFetching', true);
      const data = await ConversationAPI.get();
      commit('setConversations', data);
      commit('setFetching', false);
    }
  },
  mutations: {
    setConversations(state, data) {
      state.records = data;
    }
  }
};
```

---

## Development Patterns

### 1. Service Object Pattern

**When to use**: Complex business logic that doesn't fit in models/controllers

**Structure**:
```ruby
class MyFeature::MyService
  def initialize(param1:, param2:)
    @param1 = param1
    @param2 = param2
  end

  def perform
    # Main logic
    result
  end

  private

  def helper_method
    # ...
  end
end
```

### 2. Finder Pattern

**When to use**: Complex database queries

**Structure**:
```ruby
class ConversationsFinder
  def initialize(user, params)
    @user = user
    @params = params
  end

  def perform
    conversations = @user.account.conversations
    conversations = filter_by_status(conversations)
    conversations = filter_by_assignee(conversations)
    conversations
  end

  private

  def filter_by_status(conversations)
    # ...
  end
end
```

### 3. Builder Pattern

**When to use**: Complex object construction

**Structure**:
```ruby
class Messages::MessageBuilder
  def initialize(user:, conversation:, params:)
    @user = user
    @conversation = conversation
    @params = params
  end

  def perform
    @message = @conversation.messages.build(message_params)
    @message.save!
    @message
  end
end
```

### 4. Event Dispatcher Pattern

**When to use**: Decouple actions triggered by domain events

**Dispatch Event**:
```ruby
Rails.configuration.dispatcher.dispatch(
  CONVERSATION_CREATED,
  Time.zone.now,
  conversation: @conversation
)
```

**Listen to Event**:
```ruby
class ConversationListener < BaseListener
  def conversation_created(event)
    conversation = event.data[:conversation]
    # Handle event
  end
end
```

### 5. Policy Pattern

**When to use**: Authorization logic

**Structure**:
```ruby
class ConversationPolicy
  def initialize(user, conversation)
    @user = user
    @conversation = conversation
  end

  def show?
    @user.account_id == @conversation.account_id
  end

  def update?
    show? && @user.agent?
  end
end
```

---

## Testing Strategy

### Backend Testing (RSpec)

**Location**: `spec/`

**Structure**:
```
spec/
├── models/            # Model specs
├── controllers/       # Controller specs
│   └── api/
├── services/          # Service specs
├── jobs/              # Job specs
├── listeners/         # Listener specs
├── finders/           # Finder specs
└── fixtures/          # Test data
```

**Running Tests**:
```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/models/conversation_spec.rb

# Specific line
bundle exec rspec spec/models/conversation_spec.rb:25

# With overrides
POSTGRES_HOST=localhost POSTGRES_USERNAME=postgres POSTGRES_PASSWORD=password bundle exec rspec
```

**Patterns**:
- Use `FactoryBot` for test data
- Use `shoulda-matchers` for associations/validations
- Test happy path + edge cases + error scenarios

### Frontend Testing (Vitest)

**Location**: `app/javascript/**/*.spec.js`

**Running Tests**:
```bash
# All tests
pnpm test

# Watch mode
pnpm test:watch

# Coverage
pnpm test:coverage
```

**Patterns**:
- Use `@vue/test-utils` for component testing
- Mock API calls with `vitest.mock()`
- Test user interactions, not implementation details

---

## Related Documentation

### Internal Documentation

- **[CLAUDE.md](../CLAUDE.md)** - Development guidelines and coding standards
- **[CONTRIBUTING.md](../CONTRIBUTING.md)** - Contribution guidelines
- **[Development Process](./processes/development/development_process.md)** - Full development workflow
- **[Code Review Process](./processes/code_review/code_review_process.md)** - Review procedures
- **[API Testing Process](./processes/tests/api_testing_process.md)** - API testing guide

### External Resources

- **[Ruby on Rails Guides](https://guides.rubyonrails.org/)** - Rails documentation
- **[Vue.js Documentation](https://vuejs.org/)** - Vue 3 documentation
- **[Tailwind CSS](https://tailwindcss.com/)** - Utility-first CSS
- **[RSpec Documentation](https://rspec.info/)** - Testing framework
- **[Vitest Documentation](https://vitest.dev/)** - Testing framework

---

## Changelog

### Version 1.0.0 (2025-10-06)

**Status**: Active

**Changes**:
- Initial architecture documentation
- Documented technology stack (Ruby/Rails 7.1, Vue 3, PostgreSQL, Redis)
- Documented application structure (MVC + Services)
- Documented directory structure
- Documented key components (Models, Controllers, Services, Jobs, Listeners, Vue)
- Documented development patterns (Services, Finders, Builders, Events, Policies)
- Documented testing strategy (RSpec, Vitest)
- Added related documentation links

---

**Document Owner**: Development Team
**Maintained By**: Development Team
**Review Cycle**: Quarterly or after major architectural changes
**Last Reviewed**: 2025-10-06
**Next Review Due**: 2026-01-06
