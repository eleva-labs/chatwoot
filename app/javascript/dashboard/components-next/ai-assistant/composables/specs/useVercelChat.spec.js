import { CHAT_STATUS } from '../../constants';

// Mock the Vercel AI SDK - must be before imports
const mockSendMessage = vi.fn();
const mockClearError = vi.fn();

vi.mock('@ai-sdk/vue', () => ({
  Chat: vi.fn().mockImplementation(() => ({
    messages: [],
    status: CHAT_STATUS.READY,
    error: null,
    sendMessage: mockSendMessage,
    clearError: mockClearError,
    regenerate: null, // Not all Chat instances have regenerate
  })),
}));

vi.mock('ai', () => ({
  DefaultChatTransport: vi.fn().mockImplementation(options => ({
    api: options.api,
    headers: options.headers,
    prepareSendMessagesRequest: options.prepareSendMessagesRequest,
    fetch: options.fetch,
  })),
}));

vi.mock('dashboard/api/auth', () => ({
  default: {
    hasAuthCookie: vi.fn(() => true),
    getAuthData: vi.fn(() => ({
      'access-token': 'test-token',
      'token-type': 'Bearer',
      client: 'test-client',
      expiry: '12345',
      uid: 'test@example.com',
    })),
  },
}));

// Mock getCurrentInstance for component lifecycle
vi.mock('vue', async () => {
  const actual = await vi.importActual('vue');
  return {
    ...actual,
    getCurrentInstance: vi.fn(() => null),
    onUnmounted: vi.fn(),
  };
});

import { useVercelChat } from '../useVercelChat';
import Auth from 'dashboard/api/auth';
import { Chat } from '@ai-sdk/vue';
import { DefaultChatTransport } from 'ai';

describe('useVercelChat', () => {
  const api = '/api/v1/accounts/1/ai_chat/stream';

  beforeEach(() => {
    vi.clearAllMocks();
  });

  // =============================================================================
  // Initialization
  // =============================================================================
  describe('initialization', () => {
    it('returns expected state and methods', () => {
      const chat = useVercelChat({ api });

      expect(chat).toHaveProperty('messages');
      expect(chat).toHaveProperty('status');
      expect(chat).toHaveProperty('error');
      expect(chat).toHaveProperty('sendMessage');
      expect(chat).toHaveProperty('setMessages');
      expect(chat).toHaveProperty('clearError');
      expect(chat).toHaveProperty('dispose');
    });

    it('initializes with empty messages', () => {
      const chat = useVercelChat({ api });
      expect(chat.messages.value).toEqual([]);
    });

    it('initializes with ready status', () => {
      const chat = useVercelChat({ api });
      expect(chat.status.value).toBe(CHAT_STATUS.READY);
    });

    it('initializes with null error', () => {
      const chat = useVercelChat({ api });
      expect(chat.error.value).toBeNull();
    });

    it('creates DefaultChatTransport with correct API', () => {
      useVercelChat({ api });

      expect(DefaultChatTransport).toHaveBeenCalledWith(
        expect.objectContaining({
          api,
        })
      );
    });

    it('creates Chat instance with transport', () => {
      useVercelChat({ api });

      expect(Chat).toHaveBeenCalled();
    });
  });

  // =============================================================================
  // Authentication
  // =============================================================================
  describe('authentication', () => {
    it('includes auth headers when auth cookie exists', () => {
      Auth.hasAuthCookie.mockReturnValue(true);
      useVercelChat({ api });

      // Get the headers function passed to DefaultChatTransport
      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const headers = transportCall.headers();

      expect(headers).toEqual(
        expect.objectContaining({
          'access-token': 'test-token',
          'Content-Type': 'application/json',
        })
      );
    });

    it('uses minimal headers when no auth cookie', () => {
      Auth.hasAuthCookie.mockReturnValue(false);
      useVercelChat({ api });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const headers = transportCall.headers();

      expect(headers).toEqual({ 'Content-Type': 'application/json' });
    });
  });

  // =============================================================================
  // Message Preparation
  // =============================================================================
  describe('message preparation', () => {
    it('transforms UIMessages to backend format', async () => {
      const body = { agent_bot_id: 123 };
      useVercelChat({ api, body });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [
        { role: 'user', parts: [{ type: 'text', text: 'Hello' }] },
      ];

      const result = await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(result.body).toEqual({
        messages: [{ role: 'user', content: 'Hello' }],
        agent_bot_id: 123,
      });
    });

    it('handles body as a function', async () => {
      const bodyFn = vi.fn(() => ({ agent_bot_id: 456 }));
      useVercelChat({ api, body: bodyFn });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [
        { role: 'user', parts: [{ type: 'text', text: 'Test' }] },
      ];

      await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(bodyFn).toHaveBeenCalled();
    });

    it('extracts text from multiple parts', async () => {
      useVercelChat({ api });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [
        {
          role: 'user',
          parts: [
            { type: 'text', text: 'Hello ' },
            { type: 'text', text: 'World' },
          ],
        },
      ];

      const result = await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(result.body.messages[0].content).toBe('Hello World');
    });

    it('filters out non-text parts', async () => {
      useVercelChat({ api });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [
        {
          role: 'user',
          parts: [
            { type: 'text', text: 'Answer: ' },
            { type: 'reasoning', text: 'thinking...' },
            { type: 'text', text: '42' },
          ],
        },
      ];

      const result = await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(result.body.messages[0].content).toBe('Answer: 42');
    });

    it('uses content fallback when no parts', async () => {
      useVercelChat({ api });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [{ role: 'user', content: 'Direct content' }];

      const result = await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(result.body.messages[0].content).toBe('Direct content');
    });

    it('handles empty parts array', async () => {
      useVercelChat({ api });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [{ role: 'user', parts: [] }];

      const result = await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(result.body.messages[0].content).toBe('');
    });
  });

  // =============================================================================
  // Session ID Extraction
  // =============================================================================
  describe('session ID extraction', () => {
    it('calls onSessionId with extracted session ID from headers', async () => {
      const onSessionId = vi.fn();

      // Mock window.fetch
      const originalHeaders = new Headers();
      originalHeaders.set('X-Chat-Session-Id', 'session-123');
      const mockResponse = { headers: originalHeaders };

      vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse));

      useVercelChat({ api, onSessionId });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      await transportCall.fetch('/test', {});

      expect(onSessionId).toHaveBeenCalledWith('session-123');

      vi.unstubAllGlobals();
    });

    it('does not call onSessionId when header is missing', async () => {
      const onSessionId = vi.fn();
      const mockResponse = { headers: new Headers() };

      vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse));

      useVercelChat({ api, onSessionId });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      await transportCall.fetch('/test', {});

      expect(onSessionId).not.toHaveBeenCalled();

      vi.unstubAllGlobals();
    });

    it('does not call onSessionId when callback not provided', async () => {
      const mockResponse = { headers: new Headers() };
      vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse));

      // Should not throw even without onSessionId callback
      useVercelChat({ api });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      await expect(transportCall.fetch('/test', {})).resolves.toBeDefined();

      vi.unstubAllGlobals();
    });
  });

  // =============================================================================
  // dispose
  // =============================================================================
  describe('dispose', () => {
    it('does not throw when called', () => {
      const chat = useVercelChat({ api });

      // Should not throw
      expect(() => chat.dispose()).not.toThrow();
    });

    it('can be called multiple times without error', () => {
      const chat = useVercelChat({ api });

      expect(() => {
        chat.dispose();
        chat.dispose();
      }).not.toThrow();
    });
  });

  // =============================================================================
  // Callbacks
  // =============================================================================
  describe('callbacks', () => {
    it('passes onFinish callback to Chat', () => {
      const onFinish = vi.fn();
      useVercelChat({ api, onFinish });

      expect(Chat).toHaveBeenCalledWith(
        expect.objectContaining({
          onFinish,
        })
      );
    });

    it('passes onError callback to Chat', () => {
      const onError = vi.fn();
      useVercelChat({ api, onError });

      expect(Chat).toHaveBeenCalledWith(
        expect.objectContaining({
          onError,
        })
      );
    });

    it('handles missing callbacks gracefully', () => {
      // Should not throw when no callbacks provided
      expect(() => useVercelChat({ api })).not.toThrow();
    });
  });

  // =============================================================================
  // Body parameter
  // =============================================================================
  describe('body parameter', () => {
    it('handles undefined body gracefully', async () => {
      useVercelChat({ api });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [
        { role: 'user', parts: [{ type: 'text', text: 'Hello' }] },
      ];

      const result = await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(result.body).toEqual({
        messages: [{ role: 'user', content: 'Hello' }],
      });
    });

    it('handles null body gracefully', async () => {
      useVercelChat({ api, body: null });

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [
        { role: 'user', parts: [{ type: 'text', text: 'Hello' }] },
      ];

      const result = await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(result.body).toEqual({
        messages: [{ role: 'user', content: 'Hello' }],
      });
    });
  });
});
