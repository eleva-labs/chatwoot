import { ref, type Ref } from 'vue';

/**
 * Composable for auto-resizing textarea elements.
 * Automatically adjusts height based on content up to a max height.
 *
 * @param maxHeight - Maximum height in pixels (default: 128)
 * @returns textareaRef, resize, reset
 */
export function useAutoResizeTextarea(maxHeight: number = 128): {
  textareaRef: Ref<HTMLTextAreaElement | null>;
  resize: () => void;
  reset: () => void;
} {
  const textareaRef = ref<HTMLTextAreaElement | null>(null);

  const resize = (): void => {
    if (!textareaRef.value) return;
    textareaRef.value.style.height = 'auto';
    const newHeight = Math.min(textareaRef.value.scrollHeight, maxHeight);
    textareaRef.value.style.height = `${newHeight}px`;
  };

  const reset = (): void => {
    if (!textareaRef.value) return;
    textareaRef.value.style.height = 'auto';
  };

  return {
    textareaRef,
    resize,
    reset,
  };
}
