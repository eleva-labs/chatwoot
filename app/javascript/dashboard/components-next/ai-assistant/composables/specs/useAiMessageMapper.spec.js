import {
  toUIMessage,
  toUIMessages,
  toBackendMessage,
  useAiMessageMapper,
} from '../useAiMessageMapper';
import { PART_TYPES, MESSAGE_ROLE } from '../../constants';

describe('useAiMessageMapper', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  // =============================================================================
  // toUIMessage
  // =============================================================================
  describe('toUIMessage', () => {
    it('transforms backend message with snake_case keys to UIMessage format', () => {
      const backendMsg = {
        id: '123',
        message_role: 'user',
        content: 'Hello, AI!',
        sent_date: '2025-01-15T10:30:00Z',
      };

      const result = toUIMessage(backendMsg);

      expect(result).toEqual({
        id: '123',
        role: 'user',
        parts: [{ type: PART_TYPES.TEXT, text: 'Hello, AI!' }],
        createdAt: new Date('2025-01-15T10:30:00Z'),
      });
    });

    it('transforms backend message with camelCase keys', () => {
      const backendMsg = {
        id: '456',
        messageRole: 'assistant',
        content: 'Hello! How can I help?',
        sentDate: '2025-01-15T10:31:00Z',
      };

      const result = toUIMessage(backendMsg);

      expect(result.role).toBe('assistant');
      expect(result.parts[0].text).toBe('Hello! How can I help?');
    });

    it('uses externalId when available', () => {
      const backendMsg = {
        id: '123',
        externalId: 'ext-456',
        message_role: 'user',
        content: 'Test',
      };

      const result = toUIMessage(backendMsg);

      expect(result.id).toBe('ext-456');
    });

    it('returns null for tool messages', () => {
      const backendMsg = {
        id: '123',
        message_role: MESSAGE_ROLE.TOOL,
        content: '{"result": "success"}',
      };

      const result = toUIMessage(backendMsg);

      expect(result).toBeNull();
    });

    it('returns null for assistant messages with empty content', () => {
      const backendMsg = {
        id: '123',
        message_role: MESSAGE_ROLE.ASSISTANT,
        content: '   ',
      };

      const result = toUIMessage(backendMsg);

      expect(result).toBeNull();
    });

    it('handles empty content string', () => {
      const backendMsg = {
        id: '123',
        message_role: 'user',
        content: '',
      };

      const result = toUIMessage(backendMsg);

      expect(result.parts[0].text).toBe('');
    });

    it('handles missing content field', () => {
      const backendMsg = {
        id: '123',
        message_role: 'user',
      };

      const result = toUIMessage(backendMsg);

      expect(result.parts[0].text).toBe('');
    });

    it('uses current date when no timestamp provided', () => {
      const backendMsg = {
        id: '123',
        message_role: 'user',
        content: 'Hello',
      };

      const beforeTime = new Date();
      const result = toUIMessage(backendMsg);
      const afterTime = new Date();

      expect(result.createdAt.getTime()).toBeGreaterThanOrEqual(
        beforeTime.getTime()
      );
      expect(result.createdAt.getTime()).toBeLessThanOrEqual(
        afterTime.getTime()
      );
    });

    it('handles createdAt timestamp field', () => {
      const backendMsg = {
        id: '123',
        message_role: 'user',
        content: 'Hello',
        createdAt: '2025-01-15T10:30:00Z',
      };

      const result = toUIMessage(backendMsg);

      expect(result.createdAt).toEqual(new Date('2025-01-15T10:30:00Z'));
    });

    it('handles timestamp field', () => {
      const backendMsg = {
        id: '123',
        message_role: 'user',
        content: 'Hello',
        timestamp: '2025-01-15T10:30:00Z',
      };

      const result = toUIMessage(backendMsg);

      expect(result.createdAt).toEqual(new Date('2025-01-15T10:30:00Z'));
    });
  });

  // =============================================================================
  // toUIMessages
  // =============================================================================
  describe('toUIMessages', () => {
    it('transforms array of backend messages to UIMessages', () => {
      const messages = [
        { id: '1', message_role: 'user', content: 'Hello' },
        { id: '2', message_role: 'assistant', content: 'Hi there!' },
      ];

      const result = toUIMessages(messages);

      expect(result).toHaveLength(2);
      expect(result[0].role).toBe('user');
      expect(result[1].role).toBe('assistant');
    });

    it('filters out tool messages', () => {
      const messages = [
        { id: '1', message_role: 'user', content: 'Hello' },
        { id: '2', message_role: 'tool', content: '{}' },
        { id: '3', message_role: 'assistant', content: 'Hi!' },
      ];

      const result = toUIMessages(messages);

      expect(result).toHaveLength(2);
      expect(result.every(m => m.role !== 'tool')).toBe(true);
    });

    it('filters out empty assistant messages', () => {
      const messages = [
        { id: '1', message_role: 'user', content: 'Hello' },
        { id: '2', message_role: 'assistant', content: '' },
        { id: '3', message_role: 'assistant', content: 'Hi!' },
      ];

      const result = toUIMessages(messages);

      expect(result).toHaveLength(2);
      expect(result[1].parts[0].text).toBe('Hi!');
    });

    it('returns empty array for non-array input', () => {
      expect(toUIMessages(null)).toEqual([]);
      expect(toUIMessages(undefined)).toEqual([]);
      expect(toUIMessages('string')).toEqual([]);
      expect(toUIMessages({})).toEqual([]);
    });

    it('returns empty array for empty input', () => {
      expect(toUIMessages([])).toEqual([]);
    });
  });

  // =============================================================================
  // toBackendMessage
  // =============================================================================
  describe('toBackendMessage', () => {
    it('transforms UIMessage to backend format', () => {
      const uiMessage = {
        id: '123',
        role: 'user',
        parts: [{ type: PART_TYPES.TEXT, text: 'Hello, AI!' }],
        createdAt: new Date('2025-01-15T10:30:00Z'),
      };

      const result = toBackendMessage(uiMessage);

      expect(result).toEqual({
        id: '123',
        message_role: 'user',
        content: 'Hello, AI!',
        sent_date: '2025-01-15T10:30:00.000Z',
      });
    });

    it('combines multiple text parts', () => {
      const uiMessage = {
        id: '123',
        role: 'assistant',
        parts: [
          { type: PART_TYPES.TEXT, text: 'Hello ' },
          { type: PART_TYPES.TEXT, text: 'World!' },
        ],
        createdAt: new Date(),
      };

      const result = toBackendMessage(uiMessage);

      expect(result.content).toBe('Hello World!');
    });

    it('ignores non-text parts', () => {
      const uiMessage = {
        id: '123',
        role: 'assistant',
        parts: [
          { type: PART_TYPES.TEXT, text: 'Answer: ' },
          { type: PART_TYPES.REASONING, text: 'thinking...' },
          { type: PART_TYPES.TEXT, text: '42' },
        ],
        createdAt: new Date(),
      };

      const result = toBackendMessage(uiMessage);

      expect(result.content).toBe('Answer: 42');
    });

    it('handles missing parts array', () => {
      const uiMessage = {
        id: '123',
        role: 'user',
        createdAt: new Date(),
      };

      const result = toBackendMessage(uiMessage);

      expect(result.content).toBe('');
    });

    it('handles missing createdAt', () => {
      const uiMessage = {
        id: '123',
        role: 'user',
        parts: [{ type: PART_TYPES.TEXT, text: 'Hello' }],
      };

      const beforeTime = new Date();
      const result = toBackendMessage(uiMessage);
      const afterTime = new Date();

      const resultDate = new Date(result.sent_date);
      expect(resultDate.getTime()).toBeGreaterThanOrEqual(beforeTime.getTime());
      expect(resultDate.getTime()).toBeLessThanOrEqual(afterTime.getTime());
    });
  });

  // =============================================================================
  // useAiMessageMapper (composable hook)
  // =============================================================================
  describe('useAiMessageMapper', () => {
    it('returns all transformation functions', () => {
      const mapper = useAiMessageMapper();

      expect(mapper).toHaveProperty('toUIMessage');
      expect(mapper).toHaveProperty('toUIMessages');
      expect(mapper).toHaveProperty('toBackendMessage');
      expect(typeof mapper.toUIMessage).toBe('function');
      expect(typeof mapper.toUIMessages).toBe('function');
      expect(typeof mapper.toBackendMessage).toBe('function');
    });
  });
});
