import { useAutoResizeTextarea } from '../useAutoResizeTextarea';

describe('useAutoResizeTextarea', () => {
  let mockTextarea;

  beforeEach(() => {
    // Create mock textarea element
    mockTextarea = {
      style: { height: '' },
      scrollHeight: 0,
    };
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  // =============================================================================
  // Initialization
  // =============================================================================
  describe('initialization', () => {
    it('returns textareaRef, resize, and reset methods', () => {
      const result = useAutoResizeTextarea();

      expect(result).toHaveProperty('textareaRef');
      expect(result).toHaveProperty('resize');
      expect(result).toHaveProperty('reset');
      expect(typeof result.resize).toBe('function');
      expect(typeof result.reset).toBe('function');
    });

    it('initializes textareaRef as null', () => {
      const { textareaRef } = useAutoResizeTextarea();

      expect(textareaRef.value).toBeNull();
    });

    it('accepts custom maxHeight parameter', () => {
      const { textareaRef, resize } = useAutoResizeTextarea(200);

      // Set up mock textarea with content exceeding maxHeight
      mockTextarea.scrollHeight = 300;
      textareaRef.value = mockTextarea;

      resize();

      expect(mockTextarea.style.height).toBe('200px');
    });

    it('uses default maxHeight of 128 when not specified', () => {
      const { textareaRef, resize } = useAutoResizeTextarea();

      // Set up mock textarea with content exceeding default maxHeight
      mockTextarea.scrollHeight = 200;
      textareaRef.value = mockTextarea;

      resize();

      expect(mockTextarea.style.height).toBe('128px');
    });
  });

  // =============================================================================
  // resize()
  // =============================================================================
  describe('resize', () => {
    it('does nothing when textareaRef is null', () => {
      const { resize } = useAutoResizeTextarea();

      // Should not throw
      expect(() => resize()).not.toThrow();
    });

    it('sets height to auto then to scrollHeight when below maxHeight', () => {
      const { textareaRef, resize } = useAutoResizeTextarea(128);

      mockTextarea.scrollHeight = 80;
      textareaRef.value = mockTextarea;

      resize();

      expect(mockTextarea.style.height).toBe('80px');
    });

    it('caps height at maxHeight when scrollHeight exceeds it', () => {
      const { textareaRef, resize } = useAutoResizeTextarea(100);

      mockTextarea.scrollHeight = 150;
      textareaRef.value = mockTextarea;

      resize();

      expect(mockTextarea.style.height).toBe('100px');
    });

    it('handles zero scrollHeight', () => {
      const { textareaRef, resize } = useAutoResizeTextarea();

      mockTextarea.scrollHeight = 0;
      textareaRef.value = mockTextarea;

      resize();

      expect(mockTextarea.style.height).toBe('0px');
    });
  });

  // =============================================================================
  // reset()
  // =============================================================================
  describe('reset', () => {
    it('does nothing when textareaRef is null', () => {
      const { reset } = useAutoResizeTextarea();

      // Should not throw
      expect(() => reset()).not.toThrow();
    });

    it('resets height to auto', () => {
      const { textareaRef, reset } = useAutoResizeTextarea();

      mockTextarea.style.height = '100px';
      textareaRef.value = mockTextarea;

      reset();

      expect(mockTextarea.style.height).toBe('auto');
    });
  });
});
