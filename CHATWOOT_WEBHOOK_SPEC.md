# Chatwoot Webhook Events Specification

## Overview

Chatwoot provides a comprehensive webhook system that allows external applications to receive real-time notifications about various events happening within the platform. This document outlines all available webhook events, their payload schemas, and implementation details.

## Webhook Types

Chatwoot supports **3 types of webhooks**:

1. **Account Webhooks** - Account-level events sent to configured webhook URLs
2. **Inbox Webhooks** - Inbox-specific events sent to inbox webhook configurations
3. **Agent Bot Webhooks** - Events sent to configured agent bot webhook URLs

## Standard Webhook Events

### Available Events

The following events are available for webhook subscriptions (defined in `app/models/webhook.rb`):

- `conversation_status_changed` - When a conversation status changes (open, resolved, pending, snoozed)
- `conversation_updated` - When conversation properties are updated
- `conversation_created` - When a new conversation is created
- `contact_created` - When a new contact is created
- `contact_updated` - When contact information is updated
- `message_created` - When a new message is sent or received
- `message_updated` - When a message is updated
- `webwidget_triggered` - When a web widget interaction occurs
- `inbox_created` - When a new inbox is created
- `inbox_updated` - When inbox settings are updated
- `conversation_typing_on` - When someone starts typing in a conversation
- `conversation_typing_off` - When someone stops typing in a conversation

### Webhook Configuration Schema

```json
{
  "url": "https://your-webhook-endpoint.com/webhook",
  "subscriptions": [
    "conversation_created",
    "conversation_status_changed",
    "conversation_updated",
    "message_created",
    "message_updated",
    "contact_created",
    "contact_updated",
    "webwidget_triggered"
  ]
}
```

## Agent Bot Webhook Events

Agent bots receive a subset of events automatically when connected to an inbox:

- `conversation_resolved` - When a conversation is resolved
- `conversation_opened` - When a conversation is opened
- `message_created` - When a new message is created
- `message_updated` - When a message is updated  
- `webwidget_triggered` - When a web widget interaction occurs

## Payload Schemas

### Base Data Types

#### Account Schema
```json
{
  "id": 123,
  "name": "Your Company Name"
}
```

#### Inbox Schema
```json
{
  "id": 456,
  "name": "Website Chat"
}
```

#### User Schema
```json
{
  "id": 789,
  "name": "John Doe",
  "email": "john@example.com",
  "type": "user"
}
```

#### Agent Bot Schema
```json
{
  "id": 101,
  "name": "Support Bot",
  "type": "agent_bot"
}
```

### Event Payloads

#### Contact Events (`contact_created`, `contact_updated`)

```json
{
  "event": "contact_created",
  "account": {
    "id": 123,
    "name": "Your Company Name"
  },
  "additional_attributes": {
    "company_name": "Acme Corp",
    "city": "New York",
    "country": "USA"
  },
  "avatar": "https://example.com/avatar.jpg",
  "custom_attributes": {
    "subscription_plan": "premium",
    "last_purchase": "2023-12-01"
  },
  "email": "customer@example.com",
  "id": 567,
  "identifier": "cust_12345",
  "name": "Jane Customer",
  "phone_number": "+1234567890",
  "thumbnail": "https://example.com/thumb.jpg",
  "blocked": false,
  "changed_attributes": {
    "name": ["Old Name", "New Name"]
  }
}
```

**Note**: `changed_attributes` is only present in `contact_updated` events and shows the before/after values of changed fields.

#### Message Events (`message_created`, `message_updated`)

```json
{
  "event": "message_created",
  "account": {
    "id": 123,
    "name": "Your Company Name"
  },
  "additional_attributes": {
    "external_created_at": "2023-12-01T10:00:00Z"
  },
  "content_attributes": {
    "email": {
      "subject": "Support Request",
      "cc": ["manager@example.com"],
      "bcc": []
    }
  },
  "content_type": "text",
  "content": "Hello, I need help with my account",
  "conversation": {
    // Full conversation webhook data
  },
  "created_at": "2023-12-01T10:00:00Z",
  "id": 891,
  "inbox": {
    "id": 456,
    "name": "Website Chat"
  },
  "message_type": "incoming",
  "private": false,
  "sender": {
    // User or contact webhook data
  },
  "source_id": "external_msg_123",
  "attachments": [
    {
      "id": 111,
      "file_type": "image",
      "account_id": 123,
      "file_url": "https://example.com/file.jpg",
      "thumb_url": "https://example.com/thumb.jpg"
    }
  ]
}
```

#### Conversation Events (`conversation_created`, `conversation_updated`, `conversation_status_changed`)

```json
{
  "event": "conversation_status_changed",
  "account": {
    "id": 123,
    "name": "Your Company Name"
  },
  "additional_attributes": {
    "browser": "Chrome",
    "referer": "https://example.com/pricing",
    "initiated_at": {
      "timestamp": "2023-12-01T10:00:00Z"
    }
  },
  "assignee": {
    "id": 789,
    "name": "John Agent",
    "email": "john@company.com",
    "type": "user"
  },
  "contact": {
    // Full contact webhook data
  },
  "conversation_id": 1001,
  "created_at": "2023-12-01T09:00:00Z",
  "custom_attributes": {
    "priority": "high",
    "department": "technical"
  },
  "id": 1001,
  "inbox": {
    "id": 456,
    "name": "Website Chat"
  },
  "messages": [
    // Array of message objects
  ],
  "meta": {
    "sender": {
      // Contact or user data
    },
    "assignee": {
      // User data
    }
  },
  "status": "resolved",
  "timestamp": "2023-12-01T10:30:00Z",
  "unread_count": 0,
  "changed_attributes": {
    "status": ["open", "resolved"],
    "assignee_id": [null, 789]
  }
}
```

#### Web Widget Events (`webwidget_triggered`)

```json
{
  "event": "webwidget_triggered",
  "id": 234,
  "contact": {
    // Full contact webhook data
  },
  "inbox": {
    "id": 456,
    "name": "Website Chat"
  },
  "account": {
    "id": 123,
    "name": "Your Company Name"
  },
  "current_conversation": {
    // Current conversation data if exists, null otherwise
  },
  "source_id": "web_widget_12345",
  "event_info": {
    "browser": "Chrome",
    "browser_version": "120.0",
    "os": "Windows",
    "referer": "https://example.com/contact",
    "initiated_at": "2023-12-01T10:00:00Z"
  }
}
```

#### Typing Events (`conversation_typing_on`, `conversation_typing_off`)

```json
{
  "event": "conversation_typing_on",
  "user": {
    "id": 789,
    "name": "John Agent",
    "email": "john@company.com",
    "type": "user"
  },
  "conversation": {
    // Full conversation webhook data
  },
  "is_private": false
}
```

#### Inbox Events (`inbox_created`, `inbox_updated`)

```json
{
  "event": "inbox_created",
  "id": 456,
  "avatar_url": "https://example.com/inbox-avatar.jpg",
  "channel_id": 789,
  "channel_type": "Channel::WebWidget",
  "name": "Website Chat",
  "page_id": null,
  "webhook_url": "",
  "phone_number": null,
  "account_id": 123,
  "changed_attributes": {
    "name": ["Old Name", "New Name"]
  }
}
```

**Note**: `changed_attributes` is only present in `inbox_updated` events.

## Agent Bot Webhook Payloads

Agent bot webhooks receive the same payload structures as standard webhooks, but are automatically triggered for active agent bot configurations. The payloads follow the same schemas as above, with the event name indicating the specific trigger.

### Agent Bot Specific Events

- **`conversation_resolved`**: Sent when a conversation in a bot-enabled inbox is resolved
- **`conversation_opened`**: Sent when a conversation in a bot-enabled inbox is opened

## HTTP Delivery Details

### Request Format

All webhooks are delivered as HTTP POST requests with the following characteristics:

- **Method**: POST
- **Content-Type**: `application/json`
- **Accept**: `application/json`
- **Timeout**: 5 seconds
- **Body**: JSON payload as described above

### Example HTTP Request

```http
POST /your-webhook-endpoint HTTP/1.1
Host: your-domain.com
Content-Type: application/json
Accept: application/json

{
  "event": "message_created",
  "account": {
    "id": 123,
    "name": "Your Company Name"
  },
  "content": "Hello, I need help!",
  "message_type": "incoming",
  // ... rest of payload
}
```

### Error Handling

- Webhooks that fail to deliver (non-2xx response or timeout) are logged
- For API channel webhooks, failed message deliveries update the message status to "failed"
- No automatic retry mechanism is implemented
- Failed webhooks are logged with the error message

## Implementation Notes

### Event Processing Flow

1. **Event Dispatch**: Events are dispatched through Rails event system
2. **Webhook Listener**: `WebhookListener` processes standard webhook events
3. **Agent Bot Listener**: `AgentBotListener` processes agent bot webhook events
4. **Background Job**: `WebhookJob` handles actual HTTP delivery asynchronously
5. **HTTP Delivery**: `Webhooks::Trigger` makes the POST request to configured URLs

### Filtering Rules

- Messages must pass `webhook_sendable?` validation to trigger webhooks
- Private messages may be filtered based on context
- Agent bot webhooks only trigger for active agent bot configurations
- Typing events automatically timeout after 30 seconds

### Special Behaviors

- **Typing Events**: Include `is_private` flag and have automatic timeout behavior
- **Changed Attributes**: Update events include before/after values for changed fields
- **Attachments**: Only included in payloads when present on messages
- **Conversation Data**: Full conversation context included in message events

## Webhook Configuration

### Creating Account Webhooks

```http
POST /api/v1/accounts/{account_id}/webhooks
Content-Type: application/json

{
  "url": "https://your-endpoint.com/webhook",
  "subscriptions": [
    "conversation_created", 
    "message_created",
    "contact_created"
  ]
}
```

### Agent Bot Configuration

Agent bots are configured with:
- `outgoing_url`: The webhook URL to receive events
- `bot_type`: Currently only "webhook" type is supported
- Events are automatically sent when the agent bot is active on an inbox

## Security Considerations

- Webhook URLs must use HTTPS in production
- Implement proper authentication/verification on your webhook endpoints
- Validate webhook payloads before processing
- Consider implementing idempotency checks using event IDs
- Monitor webhook delivery failures and implement alerting

## Rate Limiting

- No explicit rate limiting is documented for webhook deliveries
- Consider implementing rate limiting on your webhook endpoints
- Failed deliveries may impact system performance if webhook URLs are slow

This specification covers all webhook events and payloads available in Chatwoot. For the most up-to-date information, refer to the official Chatwoot documentation and API specifications. 