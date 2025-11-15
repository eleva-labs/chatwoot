import {
  OPERATOR_TYPES_1,
  OPERATOR_TYPES_2,
  OPERATOR_TYPES_3,
  OPERATOR_TYPES_4,
  OPERATOR_TYPES_6,
} from './operators';

export const AUTOMATIONS = {
  message_created: {
    conditions: [
      {
        key: 'message_type',
        name: 'MESSAGE_TYPE',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'content',
        name: 'MESSAGE_CONTAINS',
        inputType: 'comma_separated_plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'email',
        name: 'EMAIL',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'inbox_id',
        name: 'INBOX',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'status',
        name: 'STATUS',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'assignee_id',
        name: 'ASSIGNEE_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'team_id',
        name: 'TEAM_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'priority',
        name: 'PRIORITY',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'conversation_language',
        name: 'CONVERSATION_LANGUAGE',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'phone_number',
        name: 'PHONE_NUMBER',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_6,
      },
      {
        key: 'has_agent_bot',
        name: 'HAS_AGENT_BOT',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
        dropdownValues: [
          { id: true, name: 'Yes' },
          { id: false, name: 'No' },
        ],
      },
      {
        key: 'entry_phrase',
        name: 'ENTRY_PHRASE_MATCH',
        inputType: 'comma_separated_plain_text',
        filterOperators: OPERATOR_TYPES_2,
        customFilters: {
          message_limit: {
            type: 'number',
            default: 3,
            label: 'MESSAGE_LIMIT',
            min: 1,
            max: 10,
          },
          case_sensitive: {
            type: 'boolean',
            default: false,
            label: 'CASE_SENSITIVE',
          },
        },
      },
      {
        key: 'random_chance',
        name: 'RANDOM_PERCENTAGE',
        inputType: 'number',
        filterOperators: OPERATOR_TYPES_4,
      },
    ],
    actions: [
      {
        key: 'assign_agent',
        name: 'ASSIGN_AGENT',
      },
      {
        key: 'assign_team',
        name: 'ASSIGN_TEAM',
      },
      {
        key: 'add_label',
        name: 'ADD_LABEL',
      },
      {
        key: 'remove_label',
        name: 'REMOVE_LABEL',
      },
      {
        key: 'send_email_to_team',
        name: 'SEND_EMAIL_TO_TEAM',
      },
      {
        key: 'send_message',
        name: 'SEND_MESSAGE',
      },
      {
        key: 'send_email_transcript',
        name: 'SEND_EMAIL_TRANSCRIPT',
      },
      {
        key: 'mute_conversation',
        name: 'MUTE_CONVERSATION',
      },
      {
        key: 'snooze_conversation',
        name: 'SNOOZE_CONVERSATION',
      },
      {
        key: 'open_conversation',
        name: 'OPEN_CONVERSATION',
      },
      {
        key: 'resolve_conversation',
        name: 'RESOLVE_CONVERSATION',
      },
      {
        key: 'send_webhook_event',
        name: 'SEND_WEBHOOK_EVENT',
      },
      {
        key: 'send_attachment',
        name: 'SEND_ATTACHMENT',
      },
      {
        key: 'set_ai_enabled',
        name: 'SET_AI_ENABLED',
        inputType: 'search_select',
        dropdownValues: [
          { id: true, name: 'Enable' },
          { id: false, name: 'Disable' },
        ],
      },
    ],
  },
  conversation_created: {
    conditions: [
      {
        key: 'status',
        name: 'STATUS',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'browser_language',
        name: 'BROWSER_LANGUAGE',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'mail_subject',
        name: 'MAIL_SUBJECT',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'country_code',
        name: 'COUNTRY_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'phone_number',
        name: 'PHONE_NUMBER',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_6,
      },
      {
        key: 'referer',
        name: 'REFERER_LINK',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'email',
        name: 'EMAIL',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'inbox_id',
        name: 'INBOX',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'conversation_language',
        name: 'CONVERSATION_LANGUAGE',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'priority',
        name: 'PRIORITY',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'has_agent_bot',
        name: 'HAS_AGENT_BOT',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
        dropdownValues: [
          { id: true, name: 'Yes' },
          { id: false, name: 'No' },
        ],
      },
      {
        key: 'entry_phrase',
        name: 'ENTRY_PHRASE_MATCH',
        inputType: 'comma_separated_plain_text',
        filterOperators: OPERATOR_TYPES_2,
        customFilters: {
          message_limit: {
            type: 'number',
            default: 3,
            label: 'MESSAGE_LIMIT',
            min: 1,
            max: 10,
          },
          case_sensitive: {
            type: 'boolean',
            default: false,
            label: 'CASE_SENSITIVE',
          },
        },
      },
      {
        key: 'random_chance',
        name: 'RANDOM_PERCENTAGE',
        inputType: 'number',
        filterOperators: OPERATOR_TYPES_4,
      },
    ],
    actions: [
      {
        key: 'assign_agent',
        name: 'ASSIGN_AGENT',
      },
      {
        key: 'assign_team',
        name: 'ASSIGN_TEAM',
      },
      {
        key: 'assign_agent',
        name: 'ASSIGN_AGENT',
      },
      {
        key: 'send_email_to_team',
        name: 'SEND_EMAIL_TO_TEAM',
      },
      {
        key: 'send_message',
        name: 'SEND_MESSAGE',
      },
      {
        key: 'send_email_transcript',
        name: 'SEND_EMAIL_TRANSCRIPT',
      },
      {
        key: 'mute_conversation',
        name: 'MUTE_CONVERSATION',
      },
      {
        key: 'snooze_conversation',
        name: 'SNOOZE_CONVERSATION',
      },
      {
        key: 'resolve_conversation',
        name: 'RESOLVE_CONVERSATION',
      },
      {
        key: 'send_webhook_event',
        name: 'SEND_WEBHOOK_EVENT',
      },
      {
        key: 'send_attachment',
        name: 'SEND_ATTACHMENT',
      },
      {
        key: 'set_ai_enabled',
        name: 'SET_AI_ENABLED',
        inputType: 'search_select',
        dropdownValues: [
          { id: true, name: 'Enable' },
          { id: false, name: 'Disable' },
        ],
      },
    ],
  },
  conversation_updated: {
    conditions: [
      {
        key: 'status',
        name: 'STATUS',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'browser_language',
        name: 'BROWSER_LANGUAGE',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'mail_subject',
        name: 'MAIL_SUBJECT',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'country_code',
        name: 'COUNTRY_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'referer',
        name: 'REFERER_LINK',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'phone_number',
        name: 'PHONE_NUMBER',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_6,
      },
      {
        key: 'assignee_id',
        name: 'ASSIGNEE_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'team_id',
        name: 'TEAM_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'email',
        name: 'EMAIL',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'inbox_id',
        name: 'INBOX',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'conversation_language',
        name: 'CONVERSATION_LANGUAGE',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'priority',
        name: 'PRIORITY',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
    ],
    actions: [
      {
        key: 'assign_agent',
        name: 'ASSIGN_AGENT',
      },
      {
        key: 'assign_team',
        name: 'ASSIGN_TEAM',
      },
      {
        key: 'assign_agent',
        name: 'ASSIGN_AGENT',
      },
      {
        key: 'send_email_to_team',
        name: 'SEND_EMAIL_TO_TEAM',
      },
      {
        key: 'send_message',
        name: 'SEND_MESSAGE',
      },
      {
        key: 'send_email_transcript',
        name: 'SEND_EMAIL_TRANSCRIPT',
      },
      {
        key: 'mute_conversation',
        name: 'MUTE_CONVERSATION',
      },
      {
        key: 'snooze_conversation',
        name: 'SNOOZE_CONVERSATION',
      },
      {
        key: 'resolve_conversation',
        name: 'RESOLVE_CONVERSATION',
      },
      {
        key: 'send_webhook_event',
        name: 'SEND_WEBHOOK_EVENT',
      },
      {
        key: 'send_attachment',
        name: 'SEND_ATTACHMENT',
      },
    ],
  },
  conversation_opened: {
    conditions: [
      {
        key: 'browser_language',
        name: 'BROWSER_LANGUAGE',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'email',
        name: 'EMAIL',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'mail_subject',
        name: 'MAIL_SUBJECT',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'country_code',
        name: 'COUNTRY_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'referer',
        name: 'REFERER_LINK',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'assignee_id',
        name: 'ASSIGNEE_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'phone_number',
        name: 'PHONE_NUMBER',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_6,
      },
      {
        key: 'team_id',
        name: 'TEAM_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'inbox_id',
        name: 'INBOX',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'conversation_language',
        name: 'CONVERSATION_LANGUAGE',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'priority',
        name: 'PRIORITY',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
    ],
    actions: [
      {
        key: 'assign_agent',
        name: 'ASSIGN_AGENT',
      },
      {
        key: 'assign_team',
        name: 'ASSIGN_TEAM',
      },
      {
        key: 'assign_agent',
        name: 'ASSIGN_AGENT',
      },
      {
        key: 'send_email_to_team',
        name: 'SEND_EMAIL_TO_TEAM',
      },
      {
        key: 'send_message',
        name: 'SEND_MESSAGE',
      },
      {
        key: 'send_email_transcript',
        name: 'SEND_EMAIL_TRANSCRIPT',
      },
      {
        key: 'mute_conversation',
        name: 'MUTE_CONVERSATION',
      },
      {
        key: 'snooze_conversation',
        name: 'SNOOZE_CONVERSATION',
      },
      {
        key: 'send_webhook_event',
        name: 'SEND_WEBHOOK_EVENT',
      },
      {
        key: 'send_attachment',
        name: 'SEND_ATTACHMENT',
      },
    ],
  },
  conversation_resolved: {
    conditions: [
      {
        key: 'browser_language',
        name: 'BROWSER_LANGUAGE',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'email',
        name: 'EMAIL',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'mail_subject',
        name: 'MAIL_SUBJECT',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'country_code',
        name: 'COUNTRY_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'referer',
        name: 'REFERER_LINK',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_2,
      },
      {
        key: 'assignee_id',
        name: 'ASSIGNEE_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'phone_number',
        name: 'PHONE_NUMBER',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_6,
      },
      {
        key: 'team_id',
        name: 'TEAM_NAME',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'inbox_id',
        name: 'INBOX',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'conversation_language',
        name: 'CONVERSATION_LANGUAGE',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
      {
        key: 'priority',
        name: 'PRIORITY',
        inputType: 'multi_select',
        filterOperators: OPERATOR_TYPES_1,
      },
    ],
    actions: [
      {
        key: 'assign_agent',
        name: 'ASSIGN_AGENT',
      },
      {
        key: 'assign_team',
        name: 'ASSIGN_TEAM',
      },
      {
        key: 'send_email_to_team',
        name: 'SEND_EMAIL_TO_TEAM',
      },
      {
        key: 'send_message',
        name: 'SEND_MESSAGE',
      },
      {
        key: 'send_email_transcript',
        name: 'SEND_EMAIL_TRANSCRIPT',
      },
      {
        key: 'send_webhook_event',
        name: 'SEND_WEBHOOK_EVENT',
      },
      {
        key: 'send_attachment',
        name: 'SEND_ATTACHMENT',
      },
    ],
  },
};

export const AUTOMATION_RULE_EVENTS = [
  {
    key: 'conversation_created',
    value: 'CONVERSATION_CREATED',
  },
  {
    key: 'conversation_updated',
    value: 'CONVERSATION_UPDATED',
  },
  {
    key: 'conversation_resolved',
    value: 'CONVERSATION_RESOLVED',
  },
  {
    key: 'message_created',
    value: 'MESSAGE_CREATED',
  },
  {
    key: 'conversation_opened',
    value: 'CONVERSATION_OPENED',
  },
];

export const AUTOMATION_ACTION_TYPES = [
  {
    key: 'assign_agent',
    label: 'ASSIGN_AGENT',
    inputType: 'search_select',
  },
  {
    key: 'assign_team',
    label: 'ASSIGN_TEAM',
    inputType: 'search_select',
  },
  {
    key: 'add_label',
    label: 'ADD_LABEL',
    inputType: 'multi_select',
  },
  {
    key: 'remove_label',
    label: 'REMOVE_LABEL',
    inputType: 'multi_select',
  },
  {
    key: 'send_email_to_team',
    label: 'SEND_EMAIL_TO_TEAM',
    inputType: 'team_message',
  },
  {
    key: 'send_email_transcript',
    label: 'SEND_EMAIL_TRANSCRIPT',
    inputType: 'email',
  },
  {
    key: 'mute_conversation',
    label: 'MUTE_CONVERSATION',
    inputType: null,
  },
  {
    key: 'snooze_conversation',
    label: 'SNOOZE_CONVERSATION',
    inputType: null,
  },
  {
    key: 'resolve_conversation',
    label: 'RESOLVE_CONVERSATION',
    inputType: null,
  },
  {
    key: 'open_conversation',
    label: 'OPEN_CONVERSATION',
    inputType: null,
  },
  {
    key: 'send_webhook_event',
    label: 'SEND_WEBHOOK_EVENT',
    inputType: 'url',
  },
  {
    key: 'send_attachment',
    label: 'SEND_ATTACHMENT',
    inputType: 'attachment',
  },
  {
    key: 'send_message',
    label: 'SEND_MESSAGE',
    inputType: 'textarea',
  },
  {
    key: 'add_private_note',
    label: 'ADD_PRIVATE_NOTE',
    inputType: 'textarea',
  },
  {
    key: 'change_priority',
    label: 'CHANGE_PRIORITY',
    inputType: 'search_select',
  },
  {
    key: 'add_sla',
    label: 'ADD_SLA',
    inputType: 'search_select',
  },
];
