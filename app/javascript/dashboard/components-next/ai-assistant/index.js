// AI Assistant Components
// Following Vercel AI Elements pattern for Vue 3

// Conversation
export { default as AiConversation } from './conversation/AiConversation.vue';
export { default as AiConversationContent } from './conversation/AiConversationContent.vue';
export { default as AiConversationEmptyState } from './conversation/AiConversationEmptyState.vue';

// Message
export { default as AiMessage } from './message/AiMessage.vue';
export { default as AiMessageContent } from './message/AiMessageContent.vue';
export { default as AiMessageActions } from './message/AiMessageActions.vue';
export { default as AiMessageAction } from './message/AiMessageAction.vue';

// Parts
export { default as AiPartRenderer } from './parts/AiPartRenderer.vue';
export { default as AiTextPart } from './parts/AiTextPart.vue';
export { default as AiReasoningPart } from './parts/AiReasoningPart.vue';
export { default as AiToolPart } from './parts/AiToolPart.vue';
export { default as AiCollapsiblePart } from './parts/AiCollapsiblePart.vue';

// Input
export { default as AiPromptInput } from './input/AiPromptInput.vue';
export { default as AiVoiceButton } from './input/AiVoiceButton.vue';

// Feedback
export { default as AiLoader } from './feedback/AiLoader.vue';
export { default as AiChatError } from './feedback/AiChatError.vue';

// Suggestions
export { default as AiSuggestions } from './suggestions/AiSuggestions.vue';
export { default as AiSuggestion } from './suggestions/AiSuggestion.vue';

// Containers
export { default as AiChatPanel } from './containers/AiChatPanel.vue';

// Main Component
export { default as AiAssistant } from './AiAssistant.vue';

// Composables
export { useAiAssistant } from './composables/useAiAssistant';

// Utilities
export * from './constants';
export { useAiChatContext, provideAiChatContext } from './provider';
