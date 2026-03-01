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

import { useAiChat } from '../useAiChat';
import { Chat } from '@ai-sdk/vue';
import { DefaultChatTransport } from 'ai';
import { getAuthHeaders } from '../../utils/auth';

describe('useAiChat', () => {
  const api = '/api/v1/accounts/1/ai_chat/stream';

  // Helper to create a minimal TransportConfig
  const createTransportConfig = (overrides = {}) => ({
    streamEndpoint: api,
    getHeaders: getAuthHeaders,
    ...overrides,
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  // =============================================================================
  // Initialization
  // =============================================================================
  describe('initialization', () => {
    it('returns expected state and methods', () => {
      const chat = useAiChat(createTransportConfig());

      expect(chat).toHaveProperty('messages');
      expect(chat).toHaveProperty('status');
      expect(chat).toHaveProperty('error');
      expect(chat).toHaveProperty('sendMessage');
      expect(chat).toHaveProperty('setMessages');
      expect(chat).toHaveProperty('clearError');
      expect(chat).toHaveProperty('dispose');
    });

    it('initializes with empty messages', () => {
      const chat = useAiChat(createTransportConfig());
      expect(chat.messages.value).toEqual([]);
    });

    it('initializes with ready status', () => {
      const chat = useAiChat(createTransportConfig());
      expect(chat.status.value).toBe(CHAT_STATUS.READY);
    });

    it('initializes with null error', () => {
      const chat = useAiChat(createTransportConfig());
      expect(chat.error.value).toBeNull();
    });

    it('creates DefaultChatTransport with correct API', () => {
      useAiChat(createTransportConfig());

      expect(DefaultChatTransport).toHaveBeenCalledWith(
        expect.objectContaining({
          api,
        })
      );
    });

    it('creates Chat instance with transport', () => {
      useAiChat(createTransportConfig());

      expect(Chat).toHaveBeenCalled();
    });

    it('resolves streamEndpoint function', () => {
      const dynamicApi = '/api/v1/accounts/2/ai_chat/stream';
      useAiChat(
        createTransportConfig({
          streamEndpoint: () => dynamicApi,
        })
      );

      expect(DefaultChatTransport).toHaveBeenCalledWith(
        expect.objectContaining({
          api: dynamicApi,
        })
      );
    });
  });

  // =============================================================================
  // Authentication (via TransportConfig.getHeaders)
  // =============================================================================
  describe('authentication', () => {
    it('uses getHeaders from TransportConfig', () => {
      const customHeaders = vi.fn(() => ({
        Authorization: 'Bearer custom-token',
      }));
      useAiChat(createTransportConfig({ getHeaders: customHeaders }));

      // Get the headers function passed to DefaultChatTransport
      const transportCall = DefaultChatTransport.mock.calls[0][0];
      expect(transportCall.headers).toBe(customHeaders);
    });

    it('includes auth headers when using default getAuthHeaders', () => {
      useAiChat(createTransportConfig());

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const headers = transportCall.headers();

      expect(headers).toEqual(
        expect.objectContaining({
          'access-token': 'test-token',
          'Content-Type': 'application/json',
        })
      );
    });
  });

  // =============================================================================
  // Message Preparation (default fallback when no prepareRequest)
  // =============================================================================
  describe('message preparation', () => {
    it('uses default text extraction when no prepareRequest', async () => {
      useAiChat(createTransportConfig());

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

    it('delegates to prepareRequest when provided in config', async () => {
      const prepareRequest = vi.fn(({ lastMessage, headers }) => ({
        body: {
          messages: [{ role: lastMessage.role, content: 'custom' }],
          agent_bot_id: 123,
        },
        headers,
      }));

      useAiChat(createTransportConfig({ prepareRequest }));

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [
        { role: 'user', parts: [{ type: 'text', text: 'Hello' }] },
      ];

      await transportCall.prepareSendMessagesRequest({
        messages,
        headers: { 'Content-Type': 'application/json' },
      });

      expect(prepareRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          lastMessage: expect.objectContaining({ role: 'user' }),
          headers: expect.objectContaining({
            'Content-Type': 'application/json',
          }),
          metadata: {},
        })
      );
    });

    it('extracts text from multiple parts', async () => {
      useAiChat(createTransportConfig());

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
      useAiChat(createTransportConfig());

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
      useAiChat(createTransportConfig());

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      const messages = [{ role: 'user', content: 'Direct content' }];

      const result = await transportCall.prepareSendMessagesRequest({
        messages,
        headers: {},
      });

      expect(result.body.messages[0].content).toBe('Direct content');
    });

    it('handles empty parts array', async () => {
      useAiChat(createTransportConfig());

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
    it('calls onSessionId when extractSessionId is provided', async () => {
      const onSessionId = vi.fn();

      // Mock window.fetch
      const originalHeaders = new Headers();
      originalHeaders.set('X-Chat-Session-Id', 'session-123');
      const mockResponse = { headers: originalHeaders };

      vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse));

      useAiChat(
        createTransportConfig({
          extractSessionId: response =>
            response.headers.get('X-Chat-Session-Id'),
        }),
        undefined,
        { onSessionId }
      );

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      await transportCall.fetch('/test', {});

      expect(onSessionId).toHaveBeenCalledWith('session-123');

      vi.unstubAllGlobals();
    });

    it('does not call onSessionId when header is missing', async () => {
      const onSessionId = vi.fn();
      const mockResponse = { headers: new Headers() };

      vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse));

      useAiChat(
        createTransportConfig({
          extractSessionId: response =>
            response.headers.get('X-Chat-Session-Id'),
        }),
        undefined,
        { onSessionId }
      );

      const transportCall = DefaultChatTransport.mock.calls[0][0];
      await transportCall.fetch('/test', {});

      expect(onSessionId).not.toHaveBeenCalled();

      vi.unstubAllGlobals();
    });

    it('does not call onSessionId when no extractSessionId in config', async () => {
      const mockResponse = { headers: new Headers() };
      vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse));

      // No extractSessionId in config
      useAiChat(createTransportConfig());

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
      const chat = useAiChat(createTransportConfig());

      // Should not throw
      expect(() => chat.dispose()).not.toThrow();
    });

    it('can be called multiple times without error', () => {
      const chat = useAiChat(createTransportConfig());

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
      useAiChat(createTransportConfig(), undefined, { onFinish });

      expect(Chat).toHaveBeenCalledWith(
        expect.objectContaining({
          onFinish,
        })
      );
    });

    it('passes onError callback to Chat', () => {
      const onError = vi.fn();
      useAiChat(createTransportConfig(), undefined, { onError });

      expect(Chat).toHaveBeenCalledWith(
        expect.objectContaining({
          onError,
        })
      );
    });

    it('handles missing callbacks gracefully', () => {
      // Should not throw when no callbacks provided
      expect(() => useAiChat(createTransportConfig())).not.toThrow();
    });
  });

  // =============================================================================
  // Behavior config
  // =============================================================================
  describe('behavior config', () => {
    it('passes sendAutomaticallyWhen from behaviorConfig to Chat', () => {
      const sendAutomaticallyWhen = vi.fn(() => true);
      useAiChat(createTransportConfig(), { sendAutomaticallyWhen });

      expect(Chat).toHaveBeenCalledWith(
        expect.objectContaining({
          sendAutomaticallyWhen,
        })
      );
    });

    it('does not set sendAutomaticallyWhen when not provided', () => {
      useAiChat(createTransportConfig(), {});

      const chatCall = Chat.mock.calls[0][0];
      expect(chatCall).not.toHaveProperty('sendAutomaticallyWhen');
    });
  });
});
