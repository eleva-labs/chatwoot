import {
  validateMessage,
  validateAndNormalizeParts,
  validateAndNormalizeMessages,
} from '../messageValidation';

describe('messageValidation', () => {
  // =============================================================================
  // validateMessage
  // =============================================================================
  describe('validateMessage', () => {
    it('returns true for valid message', () => {
      const message = {
        id: '123',
        role: 'user',
        parts: [{ type: 'text', text: 'Hello' }],
      };
      expect(validateMessage(message)).toBe(true);
    });

    it('returns false when id is missing', () => {
      const message = {
        id: '',
        role: 'user',
        parts: [{ type: 'text', text: 'Hello' }],
      };
      expect(validateMessage(message)).toBe(false);
    });

    it('returns false when role is missing', () => {
      const message = {
        id: '123',
        role: '',
        parts: [{ type: 'text', text: 'Hello' }],
      };
      expect(validateMessage(message)).toBe(false);
    });

    it('returns false when parts is empty', () => {
      const message = {
        id: '123',
        role: 'user',
        parts: [],
      };
      expect(validateMessage(message)).toBe(false);
    });

    it('returns false when parts is not an array', () => {
      const message = {
        id: '123',
        role: 'user',
        parts: 'not an array',
      };
      expect(validateMessage(message)).toBe(false);
    });

    it('returns false when parts is undefined', () => {
      const message = {
        id: '123',
        role: 'user',
      };
      expect(validateMessage(message)).toBe(false);
    });
  });

  // =============================================================================
  // validateAndNormalizeParts
  // =============================================================================
  describe('validateAndNormalizeParts', () => {
    it('keeps valid parts with type property', () => {
      const parts = [
        { type: 'text', text: 'Hello' },
        { type: 'reasoning', text: 'Thinking...' },
      ];
      expect(validateAndNormalizeParts(parts)).toEqual(parts);
    });

    it('filters out null entries', () => {
      const parts = [{ type: 'text', text: 'Hello' }, null];
      expect(validateAndNormalizeParts(parts)).toEqual([
        { type: 'text', text: 'Hello' },
      ]);
    });

    it('filters out undefined entries', () => {
      const parts = [undefined, { type: 'text', text: 'Hello' }];
      expect(validateAndNormalizeParts(parts)).toEqual([
        { type: 'text', text: 'Hello' },
      ]);
    });

    it('filters out non-object entries', () => {
      const parts = ['string', 123, { type: 'text', text: 'Hello' }];
      expect(validateAndNormalizeParts(parts)).toEqual([
        { type: 'text', text: 'Hello' },
      ]);
    });

    it('filters out objects without type property', () => {
      const parts = [{ text: 'no type' }, { type: 'text', text: 'has type' }];
      expect(validateAndNormalizeParts(parts)).toEqual([
        { type: 'text', text: 'has type' },
      ]);
    });

    it('returns empty array for empty input', () => {
      expect(validateAndNormalizeParts([])).toEqual([]);
    });
  });

  // =============================================================================
  // validateAndNormalizeMessages
  // =============================================================================
  describe('validateAndNormalizeMessages', () => {
    it('returns valid messages with normalized parts', () => {
      const messages = [
        {
          id: '1',
          role: 'user',
          parts: [{ type: 'text', text: 'Hello' }],
        },
        {
          id: '2',
          role: 'assistant',
          parts: [{ type: 'text', text: 'Hi!' }],
        },
      ];

      const result = validateAndNormalizeMessages(messages);
      expect(result).toHaveLength(2);
    });

    it('filters out invalid messages', () => {
      const messages = [
        {
          id: '1',
          role: 'user',
          parts: [{ type: 'text', text: 'Hello' }],
        },
        {
          id: '',
          role: 'assistant',
          parts: [{ type: 'text', text: 'Invalid' }],
        },
      ];

      const result = validateAndNormalizeMessages(messages);
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('1');
    });

    it('normalizes parts within valid messages', () => {
      const messages = [
        {
          id: '1',
          role: 'user',
          parts: [{ type: 'text', text: 'Hello' }, null, { text: 'no type' }],
        },
      ];

      const result = validateAndNormalizeMessages(messages);
      expect(result).toHaveLength(1);
      expect(result[0].parts).toEqual([{ type: 'text', text: 'Hello' }]);
    });

    it('returns empty array for empty input', () => {
      expect(validateAndNormalizeMessages([])).toEqual([]);
    });

    it('filters messages with empty parts', () => {
      const messages = [
        {
          id: '1',
          role: 'user',
          parts: [],
        },
      ];

      const result = validateAndNormalizeMessages(messages);
      expect(result).toHaveLength(0);
    });
  });
});
