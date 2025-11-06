import { describe, it, expect, beforeEach } from 'vitest';

describe('i18n Dual Locale System', () => {
  describe('Module Structure', () => {
    it('should export an object with all expected language keys', async () => {
      const i18nMessages = await import('./index.js');
      const locales = i18nMessages.default;

      // Verify it exports an object
      expect(locales).toBeDefined();
      expect(typeof locales).toBe('object');

      // Verify all expected languages are present
      const expectedLanguages = [
        'ar',
        'bg',
        'ca',
        'cs',
        'da',
        'de',
        'el',
        'en',
        'es',
        'fa',
        'fi',
        'fr',
        'he',
        'hi',
        'hu',
        'id',
        'it',
        'ja',
        'ko',
        'ml',
        'lv',
        'nl',
        'no',
        'pl',
        'pt',
        'pt_BR',
        'ro',
        'ru',
        'sk',
        'sr',
        'sv',
        'ta',
        'th',
        'tr',
        'uk',
        'vi',
        'zh_CN',
        'zh_TW',
        'is',
        'lt',
      ];

      expectedLanguages.forEach(lang => {
        expect(locales).toHaveProperty(lang);
        expect(locales[lang]).toBeDefined();
        expect(typeof locales[lang]).toBe('object');
      });
    });

    it('should have valid EN locale structure', async () => {
      const i18nMessages = await import('./index.js');
      const enLocale = i18nMessages.default.en;

      // Verify EN locale has expected top-level keys
      expect(enLocale).toHaveProperty('AGENT_MGMT');
      expect(enLocale).toHaveProperty('INBOX_MGMT');
      expect(enLocale).toHaveProperty('GENERAL_SETTINGS');
      expect(enLocale).toHaveProperty('AUTOMATION');
      expect(enLocale).toHaveProperty('CONVERSATION');
    });

    it('should have valid ES locale structure', async () => {
      const i18nMessages = await import('./index.js');
      const esLocale = i18nMessages.default.es;

      // Verify ES locale has expected top-level keys
      expect(esLocale).toHaveProperty('AGENT_MGMT');
      expect(esLocale).toHaveProperty('INBOX_MGMT');
      expect(esLocale).toHaveProperty('GENERAL_SETTINGS');
      expect(esLocale).toHaveProperty('AUTOMATION');
      expect(esLocale).toHaveProperty('CONVERSATION');
    });
  });

  describe('Locale Content Verification', () => {
    let i18nMessages;

    beforeEach(async () => {
      // Re-import to get fresh module
      const module = await import('./index.js');
      i18nMessages = module.default;
    });

    it('should load EN locale with valid agent management keys', () => {
      const enLocale = i18nMessages.en;

      expect(enLocale.AGENT_MGMT).toBeDefined();
      expect(enLocale.AGENT_MGMT.HEADER).toBeDefined();
      expect(typeof enLocale.AGENT_MGMT.HEADER).toBe('string');
    });

    it('should load EN locale with valid inbox management keys', () => {
      const enLocale = i18nMessages.en;

      expect(enLocale.INBOX_MGMT).toBeDefined();
      expect(enLocale.INBOX_MGMT.HEADER).toBeDefined();
      expect(typeof enLocale.INBOX_MGMT.HEADER).toBe('string');
    });

    it('should load ES locale with valid agent management keys', () => {
      const esLocale = i18nMessages.es;

      expect(esLocale.AGENT_MGMT).toBeDefined();
      expect(esLocale.AGENT_MGMT.HEADER).toBeDefined();
      expect(typeof esLocale.AGENT_MGMT.HEADER).toBe('string');
    });

    it('should load ES locale with valid inbox management keys', () => {
      const esLocale = i18nMessages.es;

      expect(esLocale.INBOX_MGMT).toBeDefined();
      expect(esLocale.INBOX_MGMT.HEADER).toBeDefined();
      expect(typeof esLocale.INBOX_MGMT.HEADER).toBe('string');
    });

    describe('Environment-based locale selection', () => {
      it('should use correct terminology based on VITE_USE_CUSTOM_LOCALES', () => {
        const enLocale = i18nMessages.en;
        const esLocale = i18nMessages.es;

        // Check that the locale has the expected structure regardless of which is loaded
        // The actual terminology will depend on the environment variable at build time
        expect(enLocale.AGENT_MGMT.HEADER).toBeTruthy();
        expect(enLocale.INBOX_MGMT.HEADER).toBeTruthy();
        expect(esLocale.AGENT_MGMT.HEADER).toBeTruthy();
        expect(esLocale.INBOX_MGMT.HEADER).toBeTruthy();

        // Check which locale set is being used
        const usingCustom = import.meta.env.VITE_USE_CUSTOM_LOCALES === 'true';

        if (usingCustom) {
          // When using custom locales
          expect(enLocale.AGENT_MGMT.HEADER).toContain('Member');
          expect(enLocale.INBOX_MGMT.HEADER).toContain('Channel');
          expect(esLocale.AGENT_MGMT.HEADER).toContain('Miembro');
          expect(esLocale.INBOX_MGMT.HEADER).toContain('Canal');
        } else {
          // When using upstream locales
          expect(enLocale.AGENT_MGMT.HEADER).toContain('Agent');
          expect(enLocale.INBOX_MGMT.HEADER).toContain('Inbox');
          expect(esLocale.AGENT_MGMT.HEADER).toContain('Agente');
          expect(esLocale.INBOX_MGMT.HEADER).toContain('Bandeja');
        }
      });
    });
  });

  describe('Locale Completeness', () => {
    it('should have non-empty values for critical keys in EN', async () => {
      const i18nMessages = await import('./index.js');
      const enLocale = i18nMessages.default.en;

      // Critical keys that should always have values
      const criticalKeys = [
        ['AGENT_MGMT', 'HEADER'],
        ['AGENT_MGMT', 'HEADER_BTN_TXT'],
        ['INBOX_MGMT', 'HEADER'],
        ['INBOX_MGMT', 'DESCRIPTION'],
        ['GENERAL_SETTINGS', 'TITLE'],
        ['AUTOMATION', 'HEADER'],
      ];

      criticalKeys.forEach(([parent, child]) => {
        expect(enLocale[parent]).toBeDefined();
        expect(enLocale[parent][child]).toBeDefined();
        expect(enLocale[parent][child].length).toBeGreaterThan(0);
      });
    });

    it('should have non-empty values for critical keys in ES', async () => {
      const i18nMessages = await import('./index.js');
      const esLocale = i18nMessages.default.es;

      // Critical keys that should always have values
      const criticalKeys = [
        ['AGENT_MGMT', 'HEADER'],
        ['AGENT_MGMT', 'HEADER_BTN_TXT'],
        ['INBOX_MGMT', 'HEADER'],
        ['INBOX_MGMT', 'DESCRIPTION'],
        ['GENERAL_SETTINGS', 'TITLE'],
        ['AUTOMATION', 'HEADER'],
      ];

      criticalKeys.forEach(([parent, child]) => {
        expect(esLocale[parent]).toBeDefined();
        expect(esLocale[parent][child]).toBeDefined();
        expect(esLocale[parent][child].length).toBeGreaterThan(0);
      });
    });
  });

  describe('Other Languages (Unmodified)', () => {
    it('should have unmodified locales for other languages', async () => {
      const i18nMessages = await import('./index.js');
      const locales = i18nMessages.default;

      // Languages that should remain unchanged (not customized)
      const unchangedLanguages = ['ar', 'fr', 'de', 'pt', 'zh_CN'];

      unchangedLanguages.forEach(lang => {
        expect(locales[lang]).toBeDefined();
        expect(typeof locales[lang]).toBe('object');
        // Should have standard structure
        expect(
          locales[lang].AGENT_MGMT || locales[lang].INBOX_MGMT
        ).toBeDefined();
      });
    });
  });
});
