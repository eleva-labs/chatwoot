import { ref } from 'vue';

/**
 * Composable for auto-resizing textarea elements.
 * Automatically adjusts height based on content up to a max height.
 *
 * @param {number} maxHeight - Maximum height in pixels (default: 128)
 * @returns {Object} - { textareaRef, resize, reset }
 */
export function useAutoResizeTextarea(maxHeight = 128) {
  const textareaRef = ref(null);

  const resize = () => {
    if (!textareaRef.value) return;
    textareaRef.value.style.height = 'auto';
    const newHeight = Math.min(textareaRef.value.scrollHeight, maxHeight);
    textareaRef.value.style.height = `${newHeight}px`;
  };

  const reset = () => {
    if (!textareaRef.value) return;
    textareaRef.value.style.height = 'auto';
  };

  return {
    textareaRef,
    resize,
    reset,
  };
}
