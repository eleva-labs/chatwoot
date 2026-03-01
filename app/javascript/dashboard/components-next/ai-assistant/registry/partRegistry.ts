/**
 * Part Registry [CORE]
 *
 * Context-scoped registry for part and tool renderers using Vue provide/inject.
 * Allows consumers to override default part renderers or register custom tool renderers.
 *
 * Aligned with mobile's ComponentRegistry pattern (types/ai-chat/registry.ts)
 * but adapted for Vue's provide/inject instead of React context.
 */

import type { Component } from 'vue';
import { inject, provide, type InjectionKey } from 'vue';

export interface PartRegistryConfig {
  parts?: Record<string, Component>;
  tools?: Record<string, Component>;
}

const PART_REGISTRY_KEY: InjectionKey<PartRegistryConfig> =
  Symbol('ai-part-registry');

export function providePartRegistry(config: PartRegistryConfig): void {
  provide(PART_REGISTRY_KEY, config);
}

export function usePartRegistry(): PartRegistryConfig {
  return inject(PART_REGISTRY_KEY, { parts: {}, tools: {} });
}
