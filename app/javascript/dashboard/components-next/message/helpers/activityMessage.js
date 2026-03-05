/**
 * Mapping of regex patterns to i18n keys for activity messages.
 *
 * The backend sends activity messages as pre-formatted English strings
 * (via Rails I18n.t in ActivityMessageHandler concerns). This helper
 * parses those strings and maps them to frontend i18n keys so the UI
 * can render them in the user's locale.
 *
 * Order matters — more specific patterns must come before general ones.
 */
const ACTIVITY_PATTERNS = [
  // --- Status changes ---
  {
    regex: /^Conversation was marked resolved by (.+) due to inactivity$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.CAPTAIN_RESOLVED',
    extractParams: m => ({ user_name: m[1] }),
  },
  {
    regex:
      /^Conversation was marked open by system due to an error with the agent bot\.$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.AGENT_BOT_ERROR',
    extractParams: () => ({}),
  },
  {
    regex: /^System reopened the conversation due to a new incoming message\.$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.SYSTEM_AUTO_OPEN',
    extractParams: () => ({}),
  },
  {
    regex:
      /^Conversation was marked resolved by system due to (\d+) days? of inactivity$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.AUTO_RESOLVED_DAYS',
    extractParams: m => ({ count: m[1] }),
  },
  {
    regex:
      /^Conversation was marked resolved by system due to (\d+) hours? of inactivity$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.AUTO_RESOLVED_HOURS',
    extractParams: m => ({ count: m[1] }),
  },
  {
    regex:
      /^Conversation was marked resolved by system due to (\d+) minutes? of inactivity$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.AUTO_RESOLVED_MINUTES',
    extractParams: m => ({ count: m[1] }),
  },
  {
    regex: /^Conversation was marked resolved by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.RESOLVED',
    extractParams: m => ({ user_name: m[1] }),
  },
  {
    regex: /^Conversation was resolved by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.CONTACT_RESOLVED',
    extractParams: m => ({ contact_name: m[1] }),
  },
  {
    regex: /^Conversation was reopened by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.OPEN',
    extractParams: m => ({ user_name: m[1] }),
  },
  {
    regex: /^Conversation was marked open by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.CAPTAIN_OPEN',
    extractParams: m => ({ user_name: m[1] }),
  },
  {
    regex: /^Conversation was marked as pending by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.PENDING',
    extractParams: m => ({ user_name: m[1] }),
  },
  {
    regex: /^Conversation was snoozed by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.STATUS.SNOOZED',
    extractParams: m => ({ user_name: m[1] }),
  },

  // --- Priority ---
  {
    regex: /^(.+) changed the priority from (.+) to (.+)$/,
    key: 'CONVERSATION.ACTIVITY.PRIORITY.UPDATED',
    extractParams: m => ({
      user_name: m[1],
      old_priority: m[2],
      new_priority: m[3],
    }),
  },
  {
    regex: /^(.+) set the priority to (.+)$/,
    key: 'CONVERSATION.ACTIVITY.PRIORITY.ADDED',
    extractParams: m => ({ user_name: m[1], new_priority: m[2] }),
  },
  {
    regex: /^(.+) removed the priority$/,
    key: 'CONVERSATION.ACTIVITY.PRIORITY.REMOVED',
    extractParams: m => ({ user_name: m[1] }),
  },

  // --- Assignee & Team ---
  // Team "assigned_with_assignee" must come before generic "Assigned to X by Y"
  {
    regex: /^(.+) self-assigned this conversation$/,
    key: 'CONVERSATION.ACTIVITY.ASSIGNEE.SELF_ASSIGNED',
    extractParams: m => ({ user_name: m[1] }),
  },
  {
    regex: /^Assigned to (.+) via (.+) by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.TEAM.ASSIGNED_WITH_ASSIGNEE',
    extractParams: m => ({
      assignee_name: m[1],
      team_name: m[2],
      user_name: m[3],
    }),
  },
  {
    regex: /^Assigned to (.+) by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.ASSIGNEE.ASSIGNED',
    extractParams: m => ({ assignee_name: m[1], user_name: m[2] }),
  },
  {
    regex: /^Conversation unassigned by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.ASSIGNEE.REMOVED',
    extractParams: m => ({ user_name: m[1] }),
  },
  {
    regex: /^Unassigned from (.+) by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.TEAM.REMOVED',
    extractParams: m => ({ team_name: m[1], user_name: m[2] }),
  },

  // --- SLA (must come before Labels) ---
  {
    regex: /^(.+) added SLA policy (.+)$/,
    key: 'CONVERSATION.ACTIVITY.SLA.ADDED',
    extractParams: m => ({ user_name: m[1], sla_name: m[2] }),
  },
  {
    regex: /^(.+) removed SLA policy (.+)$/,
    key: 'CONVERSATION.ACTIVITY.SLA.REMOVED',
    extractParams: m => ({ user_name: m[1], sla_name: m[2] }),
  },

  // --- Labels (generic — must come after more specific patterns) ---
  {
    regex: /^(.+) added (.+)$/,
    key: 'CONVERSATION.ACTIVITY.LABELS.ADDED',
    extractParams: m => ({ user_name: m[1], labels: m[2] }),
  },
  {
    regex: /^(.+) removed (.+)$/,
    key: 'CONVERSATION.ACTIVITY.LABELS.REMOVED',
    extractParams: m => ({ user_name: m[1], labels: m[2] }),
  },

  // --- Linear ---
  {
    regex: /^Linear issue (.+) was created by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.LINEAR.ISSUE_CREATED',
    extractParams: m => ({ issue_id: m[1], user_name: m[2] }),
  },
  {
    regex: /^Linear issue (.+) was linked by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.LINEAR.ISSUE_LINKED',
    extractParams: m => ({ issue_id: m[1], user_name: m[2] }),
  },
  {
    regex: /^Linear issue (.+) was unlinked by (.+)$/,
    key: 'CONVERSATION.ACTIVITY.LINEAR.ISSUE_UNLINKED',
    extractParams: m => ({ issue_id: m[1], user_name: m[2] }),
  },

  // --- Mute ---
  {
    regex: /^(.+) has muted the conversation$/,
    key: 'CONVERSATION.ACTIVITY.MUTED',
    extractParams: m => ({ user_name: m[1] }),
  },
  {
    regex: /^(.+) has unmuted the conversation$/,
    key: 'CONVERSATION.ACTIVITY.UNMUTED',
    extractParams: m => ({ user_name: m[1] }),
  },

  // --- CSAT ---
  {
    regex: /^CSAT survey not sent due to outgoing message restrictions$/,
    key: 'CONVERSATION.ACTIVITY.CSAT.NOT_SENT',
    extractParams: () => ({}),
  },

  // --- Auto-resolve ---
  {
    regex:
      /^Auto-resolve message not sent due to outgoing message restrictions$/,
    key: 'CONVERSATION.ACTIVITY.AUTO_RESOLVE.NOT_SENT',
    extractParams: () => ({}),
  },
];

/**
 * Attempts to localize a backend-generated activity message.
 * If no pattern matches (e.g. a new activity type), returns null
 * so the caller can fall back to the raw content.
 *
 * @param {string} content - The raw activity message from the backend
 * @param {Function} t - The i18n translate function ($t or t from useI18n)
 * @returns {{ key: string, params: Record<string, string> } | null}
 */
export function parseActivityMessage(content) {
  if (!content) return null;

  const matched = ACTIVITY_PATTERNS.find(pattern =>
    pattern.regex.test(content)
  );

  if (matched) {
    const match = content.match(matched.regex);
    return {
      key: matched.key,
      params: matched.extractParams(match),
    };
  }

  return null;
}

/**
 * Localizes an activity message content string.
 * Falls back to the original string if no pattern matches.
 *
 * @param {string} content - The raw activity message from the backend
 * @param {Function} t - The i18n translate function
 * @returns {string}
 */
export function localizeActivityMessage(content, t) {
  const parsed = parseActivityMessage(content);
  if (parsed) {
    // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
    return t(parsed.key, parsed.params);
  }
  return content || '';
}
