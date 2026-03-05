import {
  formatToolName,
  formatSessionDate,
  formatSessionTime,
} from '../formatHelpers';

describe('formatHelpers', () => {
  // =============================================================================
  // formatToolName
  // =============================================================================
  describe('formatToolName', () => {
    it('converts snake_case to Title Case', () => {
      expect(formatToolName('search_web')).toBe('Search Web');
    });

    it('converts camelCase to Title Case', () => {
      expect(formatToolName('searchWeb')).toBe('Search Web');
    });

    it('converts single word to Title Case', () => {
      expect(formatToolName('search')).toBe('Search');
    });

    it('handles multiple underscores', () => {
      expect(formatToolName('get_user_profile_data')).toBe(
        'Get User Profile Data'
      );
    });

    it('handles mixed camelCase and snake_case', () => {
      expect(formatToolName('get_userData')).toBe('Get User Data');
    });

    it('returns fallback for empty string', () => {
      expect(formatToolName('', 'Fallback')).toBe('Fallback');
    });

    it('returns default fallback when no fallback provided and name is empty', () => {
      expect(formatToolName('')).toBe('Unknown Tool');
    });

    it('returns fallback for undefined-like input', () => {
      expect(formatToolName(undefined, 'My Tool')).toBe('My Tool');
    });

    it('handles already Title Case input', () => {
      expect(formatToolName('Search Web')).toBe('Search Web');
    });
  });

  // =============================================================================
  // formatSessionDate
  // =============================================================================
  describe('formatSessionDate', () => {
    const labels = { today: 'Today', yesterday: 'Yesterday' };

    it('returns empty string for undefined input', () => {
      expect(formatSessionDate(undefined, labels)).toBe('');
    });

    it('returns empty string for empty string input', () => {
      expect(formatSessionDate('', labels)).toBe('');
    });

    it('returns "Today" for today\'s date', () => {
      const now = new Date().toISOString();
      expect(formatSessionDate(now, labels)).toBe('Today');
    });

    it('returns "Yesterday" for yesterday\'s date', () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      expect(formatSessionDate(yesterday.toISOString(), labels)).toBe(
        'Yesterday'
      );
    });

    it('returns weekday name for dates within last week', () => {
      const threeAgo = new Date();
      threeAgo.setDate(threeAgo.getDate() - 3);
      const result = formatSessionDate(threeAgo.toISOString(), labels);
      // Should be a weekday name like "Monday", "Tuesday", etc.
      expect(result).not.toBe('Today');
      expect(result).not.toBe('Yesterday');
      expect(result.length).toBeGreaterThan(0);
    });

    it('returns short date for older dates', () => {
      const oldDate = new Date('2024-01-15T10:00:00Z');
      const result = formatSessionDate(oldDate.toISOString(), labels);
      // Should be something like "Jan 15"
      expect(result).not.toBe('Today');
      expect(result).not.toBe('Yesterday');
      expect(result.length).toBeGreaterThan(0);
    });
  });

  // =============================================================================
  // formatSessionTime
  // =============================================================================
  describe('formatSessionTime', () => {
    it('returns empty string for undefined input', () => {
      expect(formatSessionTime(undefined)).toBe('');
    });

    it('returns empty string for empty string input', () => {
      expect(formatSessionTime('')).toBe('');
    });

    it('returns a formatted time string', () => {
      const result = formatSessionTime('2025-01-15T14:30:00Z');
      // Should be something like "2:30 PM" or "14:30" depending on locale
      expect(result.length).toBeGreaterThan(0);
    });
  });
});
