# Chatwoot: Ruby on Rails Architecture & Design Patterns

This Chatwoot project is a sophisticated **Ruby on Rails application** that implements several classic and modern design patterns. This document breaks down the architecture and patterns for developers coming from other frameworks and languages.

## 1. Overall Architecture: Layered + Event-Driven + Service-Oriented

The application follows a **multi-layered architecture** with these key components:

```
┌─────────────────────────────────────────┐
│           Frontend (Vue.js)             │
├─────────────────────────────────────────┤
│           API Layer (Controllers)       │
├─────────────────────────────────────────┤
│        Business Logic (Services)        │
├─────────────────────────────────────────┤
│       Domain Models (ActiveRecord)      │
├─────────────────────────────────────────┤
│     Background Jobs (Sidekiq/Redis)     │
├─────────────────────────────────────────┤
│         Database (PostgreSQL)           │
└─────────────────────────────────────────┘
```

## 2. Key Ruby/Rails Design Patterns

### A. MVC (Model-View-Controller) Pattern

Rails follows the classic MVC pattern:
- **Models**: `app/models/` - Domain entities like `Account`, `Conversation`, `Contact`
- **Views**: JSON responses through JBuilder templates 
- **Controllers**: `app/controllers/` - Handle HTTP requests and coordinate responses

### B. Service Objects Pattern

Instead of bloating models with business logic, Chatwoot uses **Service Objects**:

```ruby
# Example: app/services/whatsapp/send_on_whatsapp_service.rb
class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  def perform_reply
    should_send_template_message = template_params.present? || !message.conversation.can_reply?
    if should_send_template_message
      send_template_message
    else
      send_session_message
    end
  end
end
```

This follows the **Single Responsibility Principle** - each service handles one specific business operation.

### C. Repository/Finder Pattern

Complex queries are extracted into **Finder** classes:

```ruby
# app/finders/conversation_finder.rb
class ConversationFinder
  # Encapsulates complex database queries
  # Keeps controllers and models clean
end
```

## 3. Advanced Ruby Patterns

### A. Concerns (Mixins) Pattern

Ruby modules are used extensively for **code reuse** and **composition**:

```ruby
# app/models/concerns/featurable.rb
module Featurable
  extend ActiveSupport::Concern
  
  def enable_features(*names)
    names.each { |name| send("feature_#{name}=", true) }
  end
  
  def feature_enabled?(name)
    send("feature_#{name}?")
  end
end
```

Then included in models:
```ruby
class Account < ApplicationRecord
  include Featurable  # Now Account has feature management
end
```

### B. Decorator/Presenter Pattern

**Presenters** handle view logic and data formatting:

```ruby
# app/presenters/mail_presenter.rb
class MailPresenter
  # Transforms raw email data for display
  # Keeps view logic out of models
end
```

### C. Builder Pattern

**Builders** handle complex object creation:

```ruby
# app/builders/account_builder.rb
class AccountBuilder
  def perform
    ActiveRecord::Base.transaction do
      @account = create_account
      @user = create_and_link_user
    end
    [@user, @account]
  end
end
```

## 4. Event-Driven Architecture

One of the most sophisticated patterns in Chatwoot is its **event-driven system**:

### A. Dispatcher Pattern

```ruby
# app/dispatchers/dispatcher.rb
class Dispatcher
  def dispatch(event_name, timestamp, data, async = false)
    @sync_dispatcher.dispatch(event_name, timestamp, data)
    @async_dispatcher.dispatch(event_name, timestamp, data)
  end
end
```

### B. Observer/Listener Pattern

```ruby
# app/listeners/automation_rule_listener.rb
class AutomationRuleListener < BaseListener
  def conversation_updated(event)
    conversation = event.data[:conversation]
    # React to conversation changes
    rules.each do |rule|
      conditions_match = AutomationRules::ConditionsFilterService.new(rule, conversation).perform
      AutomationRules::ActionService.new(rule, account, conversation).perform if conditions_match
    end
  end
end
```

Events are dispatched throughout the application:
```ruby
# In models, this triggers events:
Rails.configuration.dispatcher.dispatch(CONVERSATION_CREATED, Time.zone.now, conversation: self)
```

## 5. Background Job Patterns

### A. Job Inheritance Hierarchy

```ruby
# Base job with common functionality
class ApplicationJob < ActiveJob::Base
  # Common job behavior
end

# Specialized jobs for different purposes
class MutexApplicationJob < ApplicationJob
  # Jobs that need distributed locking
end
```

### B. Strategy Pattern for Jobs

Different job strategies for different operations:
- **Immediate**: Real-time operations
- **Background**: Non-critical operations  
- **Scheduled**: Time-based operations

## 6. Template Method & Strategy Patterns

### A. Base Service Classes

```ruby
# app/services/base/send_on_channel_service.rb
class Base::SendOnChannelService
  def perform
    validate_target_channel
    return unless outgoing_message?
    return if invalid_message?
    
    perform_reply  # Template method - subclasses implement this
  end
  
  def perform_reply
    raise 'Overwrite this method in child class'  # Must be implemented
  end
end
```

### B. Channel Strategy Pattern

Different messaging channels (WhatsApp, Telegram, Email) implement the same interface:

```ruby
class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  def perform_reply
    # WhatsApp-specific implementation
  end
end

class Telegram::SendOnTelegramService < Base::SendOnChannelService  
  def perform_reply
    # Telegram-specific implementation
  end
end
```

## 7. Enterprise Module Pattern

Chatwoot uses a sophisticated **module composition system** for enterprise features:

```ruby
# This automatically includes enterprise modules
Account.prepend_mod_with('Account')
Account.include_mod_with('Concerns::Account') 
Account.include_mod_with('Audit::Account')
```

This allows:
- **Clean separation** between open-source and enterprise code
- **Runtime composition** of features
- **Flexible deployment** options

## 8. Domain-Driven Design Elements

### A. Value Objects

Complex data is encapsulated in value objects through JSON attributes:

```ruby
class Account < ApplicationRecord
  # settings is a JSON column that acts like a value object
  store_accessor :settings, :auto_resolve_after, :auto_resolve_message
end
```

### B. Aggregates

Related entities are grouped logically:
- **Account** aggregate: Users, Conversations, Contacts
- **Conversation** aggregate: Messages, Attachments, Participants

## 9. Key Ruby Concepts Used

### A. Metaprogramming

```ruby
# Dynamic method creation
def enable_features(*names)
  names.each do |name|
    send("feature_#{name}=", true)  # Dynamically calls methods
  end
end
```

### B. DSL (Domain Specific Language)

```ruby
# ActiveRecord associations create a DSL
has_many :conversations, dependent: :destroy_async
has_one :access_token, as: :owner, dependent: :destroy
```

### C. Delegation

```ruby
delegate :auto_resolve_after, to: :account
delegate :contact, :contact_inbox, :inbox, to: :conversation
```

## 10. Comparison to Other Languages

Coming from **Python/C#**, here are the key differences:

| Pattern | Python/C# | Ruby/Rails |
|---------|-----------|------------|
| **Dependency Injection** | Explicit constructors | Convention + modules |
| **Interface Implementation** | Abstract classes/interfaces | Duck typing + modules |
| **Event Handling** | Observer pattern classes | Block-based listeners |
| **ORM** | SQLAlchemy/Entity Framework | ActiveRecord (Active Record pattern) |
| **Background Jobs** | Celery/Task queues | ActiveJob + Sidekiq |

## 11. Rails Conventions

Rails follows **"Convention over Configuration"**:
- **File naming**: `app/models/user.rb` → `User` class
- **Database naming**: `users` table → `User` model  
- **Routing**: RESTful by default
- **Associations**: Automatically inferred from foreign keys

## 12. Directory Structure & Patterns

```
app/
├── controllers/          # HTTP request handling (MVC)
│   ├── api/             # API versioning
│   └── concerns/        # Shared controller behavior
├── models/              # Domain models (ActiveRecord)
│   └── concerns/        # Shared model behavior (mixins)
├── services/            # Business logic (Service Objects)
├── jobs/                # Background processing
├── listeners/           # Event handlers
├── builders/            # Complex object creation
├── presenters/          # View logic and formatting
├── policies/            # Authorization logic
├── finders/             # Query encapsulation
├── dispatchers/         # Event distribution
└── workers/             # Background job workers
```

## 13. Core Domain Models

### Key Entities

```ruby
# Central tenant model
class Account < ApplicationRecord
  include Featurable, Reportable
  has_many :users, :conversations, :contacts, :inboxes
end

# Communication thread
class Conversation < ApplicationRecord
  include Labelable, AssignmentHandler, ActivityMessageHandler
  belongs_to :account, :inbox, :contact
  has_many :messages
end

# Individual communication
class Message < ApplicationRecord
  belongs_to :conversation, :account
  has_many :attachments
end
```

## 14. Authentication & Authorization

- **Authentication**: Devise Token Auth for API authentication
- **Authorization**: Pundit policies for fine-grained permissions
- **Multi-tenancy**: Account-based data isolation

## 15. Integration Patterns

### Webhook Pattern
```ruby
# app/jobs/hook_job.rb
class HookJob < ApplicationJob
  # Handles outbound webhook deliveries
  # Implements retry logic and failure handling
end
```

### Channel Abstraction
Each communication channel (Email, WhatsApp, Telegram) implements a common interface while having channel-specific logic.

## Conclusion

This is a **mature, enterprise-ready Ruby on Rails application** that demonstrates sophisticated use of:
- Ruby's object-oriented features
- Rails conventions and patterns
- Modern architectural patterns
- Event-driven design
- Modular enterprise extensions

The codebase shows excellent separation of concerns, extensibility through modules, and scalable background processing, making it an excellent reference for Ruby on Rails best practices. 