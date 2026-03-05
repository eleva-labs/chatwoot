# Chatwoot Web App — State Management Audit

**Date:** 2026-02-28 (initial), 2026-03-01 (expanded)
**Scope:** Vuex store, IndexedDB caching, WebSocket lifecycle, error recovery
**Status:** Research complete — ready for implementation planning

---

## 1. Executive Summary

### Current State

The Chatwoot web app uses a **monolithic Vuex store with 40+ namespaced modules** and no centralized state reset mechanism. Account switching relies on full page navigation (`window.location.href`), which destroys the entire JS context — this is the primary safeguard against cross-account data leakage.

Three cache-enabled API singletons (`LabelsAPI`, `InboxesAPI`, `TeamsAPI`) use IndexedDB via `DataManager`, which stores the account ID at construction time. Since these are module-level singletons (`export default new LabelsAPI()`), the `DataManager.accountId` is fixed at first import. This is safe under full page reload but fragile against bfcache, HMR, or any future SPA-style account switching.

### Key Risks

| Risk | Severity | Likelihood | Impact |
|------|----------|------------|--------|
| No global Vue error handler | **High** | High (any render error) | Broken UI with no recovery path |
| IndexedDB singleton accountId | **Medium** | Low (prod) / Medium (dev) | Stale cache from wrong account |
| 24 store modules lack reset mutations | **Medium** | Low (mitigated by page reload) | Stale data between fetches |
| ActionCable connector not stored/cleaned up | **Low** | Low (prod) / Medium (dev) | Duplicate event handlers on HMR |
| Unstoppable presence interval | **Low** | Low (prod) | Timer leak in development |
| Draft messages not scoped by account | **Low** | Low | Orphaned drafts visible in store |
| No conversation memory management | **Low** | Medium (long sessions) | Unbounded memory growth |

### Top Recommendations

1. **Add `app.config.errorHandler`** — zero risk, immediate value (Phase 1)
2. **Add reset mutations to high-visibility modules** — labels, inboxes, customViews (Phase 1)
3. **Make DataManager account-dynamic** — fix singleton stale accountId (Phase 2)
4. **Store and clean up ActionCable connector** — prevent HMR leaks (Phase 2)
5. **Evaluate Pinia migration** — long-term architectural improvement (Phase 3)

---

## 2. Architecture Overview

### How the Pieces Fit Together

```
┌─────────────────────────────────────────────────────────────────┐
│                        Vue App (dashboard.js)                   │
│                                                                 │
│  ┌─────────┐  ┌──────────────┐  ┌────────────┐  ┌───────────┐ │
│  │ Router  │  │  Vuex Store   │  │ ActionCable │  │  Sentry   │ │
│  │ (sync)  │──│  40+ modules  │──│ Connector   │  │ (errors)  │ │
│  └─────────┘  └──────┬───────┘  └──────┬──────┘  └───────────┘ │
│                      │                 │                        │
│               ┌──────┴───────┐  ┌──────┴──────┐                │
│               │  API Clients │  │  WebSocket  │                │
│               │  (singletons)│  │  (Rails)    │                │
│               └──────┬───────┘  └─────────────┘                │
│                      │                                          │
│           ┌──────────┴──────────┐                               │
│           │ CacheEnabledClient  │                               │
│           │  ┌───────────────┐  │                               │
│           │  │  DataManager  │──┼──> IndexedDB (cw-store-{id}) │
│           │  │  (singleton)  │  │                               │
│           │  └───────────────┘  │                               │
│           └─────────────────────┘                               │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │  LocalStorage   │  │  SessionStorage  │                      │
│  │  (drafts, IDB   │  │  (sidebar state, │                      │
│  │   names)        │  │   impersonation) │                      │
│  └─────────────────┘  └─────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

### Account Switching Flow

Account switching uses **full page navigation**, not SPA routing:

**`SidebarAccountSwitcher.vue:36-37`**:
```js
const onChangeAccount = newId => {
  window.location.href = `/app/accounts/${newId}/dashboard`;
};
```

This triggers a complete page reload → new Vue app instance → fresh Vuex store → new ActionCable connection. The current account ID is derived from the URL via the router:

**`auth.js:55-60`**:
```js
getCurrentAccountId(_, __, rootState) {
  if (rootState.route.params && rootState.route.params.accountId) {
    return Number(rootState.route.params.accountId);
  }
  return null;
}
```

### Initialization Sequence

1. `entrypoints/dashboard.js` — creates Vue app, Vuex store, router; mounts on `window.onload`
2. `App.vue` watcher on `currentAccountId` (immediate) calls `initializeAccount()`
3. `initializeAccount()`:
   - Dispatches `accounts/get` and `inboxes/get`
   - Sets active account, locale
   - Calls `vueActionCable.init(store, pubsubToken)` — **return value not stored**
   - Creates `ReconnectService`
4. Sidebar `onMounted` — dispatches fetches for labels, inboxes, notifications, teams, attributes, custom views

### Store Module Count

**`store/index.js`** registers **41 modules** in the root Vuex store (including 10 captain/copilot modules).

---

## 3. Cross-Account Issues

### Root Cause Analysis

**Primary finding: Cross-account Vuex state carryover is impossible in normal production flow.** The full page reload destroys the entire JS context.

There are three edge-case scenarios where cross-account contamination could occur:

#### Scenario A: IndexedDB DataManager Singleton (Medium Risk)

The `CacheEnabledApiClient` creates a `DataManager` at construction time:

**`CacheEnabledApiClient.js:8`**:
```js
constructor(resource, options = {}) {
  super(resource, options);
  this.dataManager = new DataManager(this.accountIdFromRoute);
}
```

**`DataManager.js:5-8`**:
```js
constructor(accountId) {
  this.modelsToSync = ['inbox', 'label', 'team'];
  this.accountId = accountId;  // Fixed at construction time
  this.db = null;
}
```

Three singletons are affected:
- `labels.js:14` — `export default new LabelsAPI()`
- `inboxes.js:37` — `export default new Inboxes()`
- `teams.js:42` — `export default new TeamsAPI()`

**The bug:** `DataManager.accountId` is set once when the module is first imported. The `accountIdFromRoute` getter re-evaluates from `window.location.pathname`, but `DataManager` stores the value at construction time. If the JS module system survives (bfcache, HMR, service worker keeping page alive), the DataManager points to the wrong account's IndexedDB.

**Note:** The `getFromCache()` method in `CacheEnabledApiClient.js:46` also calls:
```js
const { data } = await axios.get(
  `/api/v1/accounts/${this.accountIdFromRoute}/cache_keys`
);
```
This correctly uses the dynamic getter for the API call, but then validates cache keys against the stale DataManager's database. The mismatch could cause the cache to appear "valid" (key matches) while serving data from account A's IndexedDB when account B is active.

#### Scenario B: Browser Back/Forward Cache (Low Risk)

Modern browsers may cache page state on navigation. If bfcache restores the old page, the JS modules (including singletons) would have account A's data while the URL shows account B. Browsers generally don't bfcache pages with open WebSocket connections, but this isn't guaranteed.

#### Scenario C: Draft Messages Not Account-Scoped (Low Risk)

**`draftMessages.js:8`**:
```js
records: LocalStorage.get(LOCAL_STORAGE_KEYS.DRAFT_MESSAGES) || {},
```

Draft message keys include conversation IDs (globally unique), so cross-account collision won't happen. However, drafts from account A remain in LocalStorage when viewing account B — they're cleaned only on logout, not on account switch.

**`store/utils/api.js:53-55`**:
```js
export const clearLocalStorageOnLogout = () => {
  LocalStorage.remove(LOCAL_STORAGE_KEYS.DRAFT_MESSAGES);
};
```

---

## 4. Store Module Audit

### Classification Criteria

- **Has Reset:** Module has a CLEAR/RESET/EMPTY mutation that returns state to initial values
- **Implicit Reset via SET:** Module uses `MutationHelpers.set` which replaces the entire `records` array on fetch — effectively a clear+set, but leaves a window where old data is visible before the fetch response arrives
- **No Reset:** No mechanism to clear state

### Detailed Module Table

| Module | State Shape | Has Reset? | Fetch Clears? | Sidebar? | Risk | Notes |
|--------|-------------|------------|---------------|----------|------|-------|
| **conversations** | `allConversations: []` | `EMPTY_ALL_CONVERSATION`, `CLEAR_CURRENT_CHAT_WINDOW` | No (merges) | Yes | Medium | Messages persist indefinitely per conversation |
| **contacts** | `records: {}` | `CLEAR_CONTACTS` | Yes (before get) | No | Low | Good pattern — clears before fetch |
| **labels** | `records: []` | **NO** | SET replaces | Yes | **High** | Visible in sidebar; cache-backed |
| **inboxes** | `records: []` | **NO** | SET replaces | Yes | **Medium** | Visible in sidebar; cache-backed |
| **agents** | `records: []` | **NO** | SET replaces | No | Medium | Used in assignment dropdowns |
| **teams** | `records: {}` | `CLEAR_TEAMS` | Yes (before get) | Yes | Low | Good pattern |
| **notifications** | `records: {}` | `CLEAR_NOTIFICATIONS` | Yes (before get) | Yes | Low | Good pattern |
| **customViews** | `{conversation: {records:[]}, contact: {records:[]}}` | **NO** | SET replaces | Yes | **Medium** | Sidebar folders; no clear on switch |
| **conversationLabels** | `records: {}` | **NO** | Additive (per conv) | No | Medium | Accumulates across conversations |
| **contactLabels** | `records: {}` | **NO** | Per-contact | No | Low | |
| **conversationMetadata** | `records: {}` | **NO** | Per-conversation | No | Low | |
| **conversationTypingStatus** | `records: {}` | **NO** | Add/remove per event | No | Low | |
| **accounts** | `records: []` | **NO** | SET replaces | No | Low | Account data is additive |
| **campaigns** | `records: []` | **NO** | SET replaces | No | Low | |
| **cannedResponse** | `records: []` | **NO** | SET replaces | No | Low | |
| **automations** | `records: []` | **NO** | SET replaces | No | Low | |
| **attributes** | `records: []` | **NO** | SET replaces | No | Low | |
| **macros** | `records: []` | **NO** | SET replaces | No | Low | |
| **integrations** | `records: []` | **NO** | SET replaces | No | Low | |
| **webhooks** | `records: []` | **NO** | SET replaces | No | Low | |
| **agentBots** | `records: []` | **NO** | SET replaces | No | Low | |
| **sla** | `records: []` | **NO** | SET replaces | No | Low | |
| **assignmentPolicies** | `records: []` | **NO** | SET replaces | No | Low | |
| **agentCapacityPolicies** | `records: []` | **NO** | SET replaces | No | Low | |
| **dashboardApps** | `records: []` | **NO** | SET replaces | No | Low | |
| **customRole** | `records: []` | **NO** | SET replaces | No | Low | |
| **prompts** | `records: []` | **NO** | SET replaces | No | Low | |
| **draftMessages** | `records: {}` | **NO** | N/A (LocalStorage) | No | Low | Not scoped by account |
| **auth** | `currentUser: {}` | `CLEAR_USER` | On logout | No | Low | |
| **articles** | Records | `CLEAR_ARTICLES` | Yes | No | Low | |
| **categories** | Records | `CLEAR_CATEGORIES` | Yes | No | Low | |
| **portals** | Records | `CLEAR_PORTALS` | Yes | No | Low | |
| **conversationSearch** | Results | `CLEAR_SEARCH_RESULTS` | On new search | No | Low | |
| **conversationPage** | Page data | `CLEAR_CONVERSATION_PAGE` | Before fetch | No | Low | |
| **bulkActions** | IDs | `CLEAR_SELECTED_CONVERSATION_IDS` | Explicit | No | Low | |
| **Captain stores** (10 modules) | `records: []` | **NO** | SET replaces (factory) | No | Low | All use `storeFactory.js` |

### Summary

- **24 modules** have no explicit reset/clear mutation
- **10 modules** have proper clear mechanisms (contacts, teams, notifications, auth, articles, categories, portals, conversationSearch, conversationPage, bulkActions)
- **All 24 lacking-reset modules** use `MutationHelpers.set` which replaces `records` on fetch — this provides an implicit reset but with a race window

### Captain Store Factory Analysis

**`store/captain/storeFactory.js`** generates CRUD stores for captain modules. It creates:
- `SET_*` mutation via `MutationHelpers.set` (replaces entire records array)
- `ADD_*`, `EDIT_*`, `DELETE_*` mutations
- **No `CLEAR_*` mutation** in the factory

To add reset capability to all captain stores, the fix would be a single change in the factory:

```js
// storeFactory.js — proposed addition
export const createMutations = mutationTypes => ({
  // ...existing mutations...
  [mutationTypes.CLEAR || `CLEAR_${name.toUpperCase()}`]: (state) => {
    state.records = [];
  },
});
```

---

## 5. Caching Layer Analysis

### IndexedDB Architecture

The caching layer uses `idb` (IndexedDB wrapper) to cache three models: **inbox**, **label**, **team**.

**Database naming:** `cw-store-{accountId}` — correctly scoped per account.

**Cache flow:**

```
getFromCache()
  ├── initDb() — opens/creates IndexedDB
  ├── GET /api/v1/accounts/{id}/cache_keys — fetch server cache keys
  ├── validateCacheKey() — compare server key with local key
  │   ├── Keys match → read from IndexedDB
  │   └── Keys don't match → refetchAndCommit()
  │       ├── GET /api/v1/accounts/{id}/{resource} — fetch from network
  │       ├── replace() — clear and write to IndexedDB
  │       └── setCacheKeys() — update local cache key
  └── return data
```

### Staleness Risks

1. **Singleton DataManager with fixed accountId** (see Section 3, Scenario A)
   - `DataManager.accountId` set at construction time
   - IndexedDB database name derived from this fixed value
   - API calls use the dynamic `accountIdFromRoute` getter
   - Mismatch possible under bfcache/HMR

2. **Race condition in `validateCacheKey`**: If the cache key validation succeeds (keys match) but the IndexedDB data is from a previous session that was interrupted before a full replace, partial data could be served.

3. **`DataManager.replace()` is not atomic** (`DataManager.js:41-45`):
   ```js
   async replace({ modelName, data }) {
     this.validateModel(modelName);
     this.db.clear(modelName);      // Step 1: Clear
     return this.push({ modelName, data }); // Step 2: Write
   }
   ```
   If the page closes between clear and push, the next load will see empty data but a valid cache key. The cache validation will pass, and `getFromCache` will see `localData.length === 0`, which correctly triggers a refetch (`CacheEnabledApiClient.js:59-61`). So this specific race is handled.

4. **Cache version is hardcoded** (`version.js`): `DATA_VERSION = '1678706392'` (March 2023). If the data schema changes, old IndexedDB stores won't be automatically migrated unless this version is bumped.

### Logout Cleanup

**`store/utils/api.js:61-85`** — `deleteIndexedDBOnLogout()`:
- Uses `indexedDB.databases()` API (Chrome/Edge only) with fallback to `localStorage.getItem('cw-idb-names')`
- Deletes all IndexedDB databases on logout
- This is thorough but **not called on account switch** — only on logout

### Proposed Fixes for Caching

#### Fix 1: Dynamic accountId in DataManager (Recommended)

Make `DataManager` re-derive `accountId` on each operation instead of storing it at construction:

```js
class DataManager {
  constructor(getAccountId) {
    this.modelsToSync = ['inbox', 'label', 'team'];
    this._getAccountId = typeof getAccountId === 'function'
      ? getAccountId
      : () => getAccountId;
    this.db = null;
    this._currentAccountId = null;
  }

  get accountId() {
    return this._getAccountId();
  }

  async initDb() {
    const accountId = this.accountId;
    // Reopen if accountId changed
    if (this.db && this._currentAccountId !== accountId) {
      this.db.close();
      this.db = null;
    }
    if (this.db) return this.db;
    this._currentAccountId = accountId;
    // ...rest of initDb
  }
}
```

And update `CacheEnabledApiClient`:
```js
constructor(resource, options = {}) {
  super(resource, options);
  this.dataManager = new DataManager(() => this.accountIdFromRoute);
}
```

#### Fix 2: Lazy DataManager (Simpler)

Create a new `DataManager` on each cache operation instead of storing one:

```js
get dataManager() {
  return new DataManager(this.accountIdFromRoute);
}
```

Tradeoff: Creates a new object per call, but `DataManager` is lightweight. The `initDb()` call opens a new connection each time, which `idb` handles efficiently.

---

## 6. Error Recovery

### Current State: No Error Handling

**`entrypoints/dashboard.js`** — No `app.config.errorHandler` is set (lines 44-111). Sentry is initialized for reporting but provides no recovery logic.

**Consequences of an unhandled render error:**
1. Vue logs to console, Sentry captures
2. Component tree left in inconsistent state
3. Vuex store retains the data that caused the crash
4. No toast/notification shown to user
5. User must manually refresh to recover

### Proposed: Global Error Handler

**File to modify:** `app/javascript/entrypoints/dashboard.js`

Add after line 44 (`const app = createApp(App);`):

```js
app.config.errorHandler = (err, instance, info) => {
  // 1. Report to Sentry (Sentry's Vue integration may already capture,
  //    but this ensures we have the component context)
  if (window.errorLoggingConfig) {
    Sentry.captureException(err, {
      extra: {
        component: instance?.$options?.name || 'Unknown',
        lifecycleHook: info,
      },
    });
  }

  // 2. Log for debugging
  console.error(`[Vue Error] ${info}:`, err);

  // 3. Show user-facing notification
  if (instance?.$store) {
    instance.$store.dispatch('alerts/add', {
      type: 'warning',
      message: 'Something went wrong. Try refreshing if the issue persists.',
    });
  }

  // 4. If the error is in a conversation message render, attempt recovery
  //    by clearing the selected conversation state
  if (info?.includes?.('render') && instance?.$store) {
    const selectedChatId = instance.$store.state.conversations?.selectedChatId;
    if (selectedChatId) {
      console.warn('[Recovery] Clearing conversation state after render error');
      // Don't clear — that would disrupt the user. Instead, mark the
      // conversation as having an error so the UI can show a fallback.
    }
  }
};
```

### Proposed: Error Boundary Component

Create a reusable error boundary for wrapping sections that render user-generated content (message bubbles, attachments):

```vue
<!-- ErrorBoundary.vue -->
<script setup>
import { ref, onErrorCaptured } from 'vue';

const props = defineProps({
  fallbackMessage: {
    type: String,
    default: 'This content could not be displayed.',
  },
});

const hasError = ref(false);
const errorInfo = ref(null);

onErrorCaptured((err, instance, info) => {
  hasError.value = true;
  errorInfo.value = { err, info };
  console.error('[ErrorBoundary]', err, info);
  return false; // Prevent propagation
});
</script>

<template>
  <slot v-if="!hasError" />
  <div v-else class="p-2 text-sm text-ash-600 bg-ash-50 rounded">
    {{ fallbackMessage }}
  </div>
</template>
```

**Usage in conversation message list:**
```vue
<ErrorBoundary
  v-for="message in messages"
  :key="message.id"
  :fallback-message="$t('CONVERSATION.MESSAGE_RENDER_ERROR')"
>
  <MessageBubble :message="message" />
</ErrorBoundary>
```

---

## 7. WebSocket Lifecycle

### Current Architecture

**`BaseActionCableConnector.js`** creates:
1. An ActionCable consumer (WebSocket connection)
2. A subscription to `RoomChannel` with `pubsub_token`, `account_id`, `user_id`
3. A recursive `setTimeout` presence interval (every 20s)

**`actionCable.js`** extends it with:
- Event handlers for 19 event types
- `isAValidEvent` check (validates `account_id` on each received event)
- Emitter-based reconnect/disconnect notifications

### Identified Gaps

#### Gap 1: ActionCable Connector Not Stored for Cleanup

**`App.vue:135`**:
```js
vueActionCable.init(this.store, pubsubToken);
```

The return value (the connector instance) is discarded. The `unmounted` hook only cleans up `reconnectService`:

```js
unmounted() {
  if (this.reconnectService) {
    this.reconnectService.disconnect();
  }
}
```

**Impact:** On HMR in development, `initializeAccount()` can be called multiple times without cleaning up previous connectors. Each creates a new WebSocket connection and a new presence interval. All process events independently, causing duplicate store dispatches.

**Fix:**
```js
// App.vue — store connector reference
data() {
  return {
    actionCableConnector: null,
    // ...existing
  };
},
methods: {
  initializeAccount() {
    // Clean up previous connector
    if (this.actionCableConnector) {
      this.actionCableConnector.disconnect();
    }
    // ...existing init code...
    this.actionCableConnector = vueActionCable.init(this.store, pubsubToken);
    // ...
  },
},
unmounted() {
  if (this.actionCableConnector) {
    this.actionCableConnector.disconnect();
  }
  if (this.reconnectService) {
    this.reconnectService.disconnect();
  }
}
```

#### Gap 2: Unstoppable Presence Timer

**`BaseActionCableConnector.js:36-42`**:
```js
this.triggerPresenceInterval = () => {
  setTimeout(() => {
    this.subscription.updatePresence();
    this.triggerPresenceInterval();
  }, PRESENCE_INTERVAL);
};
this.triggerPresenceInterval();
```

This creates a recursive `setTimeout` chain with no way to stop it. The `disconnect()` method only calls `this.consumer.disconnect()` — it doesn't clear the timer.

**Fix:**
```js
constructor(...) {
  // ...
  this.presenceTimer = null;
  this.startPresenceInterval();
}

startPresenceInterval() {
  this.presenceTimer = setInterval(() => {
    this.subscription.updatePresence();
  }, PRESENCE_INTERVAL);
}

disconnect() {
  if (this.presenceTimer) {
    clearInterval(this.presenceTimer);
    this.presenceTimer = null;
  }
  this.clearReconnectTimer();
  this.consumer.disconnect();
}
```

#### Gap 3: No Disconnect on Page Visibility Change

When a tab is in the background for extended periods, the WebSocket may disconnect silently. The `ReconnectService` handles reconnection well, but there's no proactive disconnection when the page becomes hidden (which would save server resources).

This is a nice-to-have, not a bug.

### ReconnectService Assessment

**`ReconnectService.js`** is well-implemented:
- Listens for `online` event and WebSocket reconnect/disconnect bus events
- On reconnect: fetches updated conversations, syncs messages for current conversation, revalidates caches
- Force-reloads if disconnected for >3 hours
- Handles route-specific fetch logic (conversation vs notification routes)

**No significant issues found.** The one minor concern is that `onReconnect` doesn't handle errors in `handleRouteSpecificFetch` — if one of the fetch calls fails, `revalidateCaches` won't run.

---

## 8. Migration Plan

### Phase 1: Quick Wins (Low Risk, 1-2 days)

These changes are defensive improvements with virtually no regression risk.

#### 1.1 Add Global Error Handler

**Files:** `app/javascript/entrypoints/dashboard.js`
**Effort:** 30 minutes
**Risk:** None — purely additive

Add `app.config.errorHandler` as described in Section 6. This immediately prevents broken UI states and gives users a notification when something goes wrong.

#### 1.2 Add CLEAR Mutations to High-Visibility Modules

**Files:**
- `store/mutation-types.js` — add new mutation type constants
- `store/modules/labels.js` — add `CLEAR_LABELS` mutation
- `store/modules/inboxes.js` — add `CLEAR_INBOXES` mutation (not currently defined)
- `store/modules/customViews.js` — add `CLEAR_CUSTOM_VIEWS` mutation
- `store/modules/conversationLabels.js` — add `CLEAR_CONVERSATION_LABELS` mutation
- `store/modules/agents.js` — add `CLEAR_AGENTS` mutation

**Effort:** 1-2 hours
**Risk:** Low — mutations are only triggered explicitly; adding them doesn't change existing behavior until they're called.

**Example for labels:**
```js
// mutation-types.js
CLEAR_LABELS: 'CLEAR_LABELS',

// labels.js mutations
[types.CLEAR_LABELS]: (_state) => {
  _state.records = [];
},
```

#### 1.3 Clear Labels Before Fetching

**File:** `store/modules/labels.js`
**Effort:** 15 minutes
**Risk:** Low — brief empty state during fetch (covered by `isFetching` UI flag)

```js
get: async function getLabels({ commit }) {
  commit(types.SET_LABEL_UI_FLAG, { isFetching: true });
  commit(types.SET_LABELS, []);  // Clear immediately
  try {
    const response = await LabelsAPI.get(true);
    const sortedLabels = response.data.payload.sort((a, b) =>
      a.title.localeCompare(b.title)
    );
    commit(types.SET_LABELS, sortedLabels);
  } catch (error) {
    // Ignore error
  } finally {
    commit(types.SET_LABEL_UI_FLAG, { isFetching: false });
  }
},
```

#### 1.4 Add CLEAR Mutation to Captain Store Factory

**File:** `store/captain/storeFactory.js`
**Effort:** 15 minutes
**Risk:** None — adds capability without changing behavior

```js
export const generateMutationTypes = name => {
  const capitalizedName = name.toUpperCase();
  return {
    // ...existing
    CLEAR: `CLEAR_${capitalizedName}`,
  };
};

export const createMutations = mutationTypes => ({
  // ...existing
  [mutationTypes.CLEAR]: (state) => {
    state.records = [];
    state.meta = {};
  },
});
```

### Phase 2: Medium-Impact Fixes (Medium Risk, 3-5 days)

#### 2.1 Fix DataManager Singleton AccountId

**Files:**
- `helper/CacheHelper/DataManager.js`
- `api/CacheEnabledApiClient.js`

**Approach:** Pass a getter function instead of a fixed value.

**Effort:** 2-3 hours (including test updates)
**Risk:** Medium — changes the caching flow; needs testing of cache hit/miss scenarios

See Section 5 "Fix 1: Dynamic accountId" for implementation details.

#### 2.2 Store and Clean Up ActionCable Connector

**Files:**
- `App.vue`
- `shared/helpers/BaseActionCableConnector.js`

**Effort:** 1-2 hours
**Risk:** Low-Medium — changes WebSocket lifecycle; needs manual testing of reconnection behavior

See Section 7 "Gap 1" and "Gap 2" for implementation details.

#### 2.3 Add Error Boundary Component

**Files:**
- Create `components-next/shared/ErrorBoundary.vue`
- Update message list components to wrap message bubbles

**Effort:** 2-3 hours
**Risk:** Low — purely additive; wraps existing components

See Section 6 "Error Boundary Component" for implementation.

#### 2.4 Scope Draft Messages by Account

**File:** `store/modules/draftMessages.js`
**Effort:** 1 hour
**Risk:** Low — only affects LocalStorage key naming

```js
const getAccountScopedKey = () => {
  const accountId = window.location.pathname.split('/')[3] || 'global';
  return `${LOCAL_STORAGE_KEYS.DRAFT_MESSAGES}_${accountId}`;
};

const state = {
  records: LocalStorage.get(getAccountScopedKey()) || {},
  replyEditorMode: REPLY_EDITOR_MODES.REPLY,
};
```

**Migration:** On first load with new key, the old unscoped drafts would be invisible. Consider a one-time migration function that reads the old key and splits drafts by account.

### Phase 3: Architectural Improvements (Long-Term)

#### 3.1 Evaluate Pinia Migration

**Why Pinia:**
- Official recommended state management for Vue 3 (Vuex is in maintenance mode)
- First-class TypeScript support
- No mutation layer (actions directly mutate state) — less boilerplate
- Built-in `$reset()` method on every store — solves the reset problem globally
- Better DevTools integration
- Smaller bundle size

**Why NOT Pinia (right now):**
- Chatwoot has 41 Vuex modules — massive migration effort
- Upstream Chatwoot uses Vuex — diverging increases merge conflict risk
- No functional benefit that can't be achieved with Vuex improvements
- Risk of introducing regressions during migration

**Recommendation:** Do NOT migrate to Pinia unless:
1. Upstream Chatwoot announces a Pinia migration
2. A major Vue version upgrade forces the hand
3. The team decides to fully fork from upstream

#### 3.2 Central Store Reset Action

Instead of migrating to Pinia, implement a centralized reset mechanism within Vuex:

```js
// store/index.js — add root action
const actions = {
  resetAllStores({ commit }) {
    // High-priority modules (sidebar-visible)
    commit('labels/CLEAR_LABELS');
    commit('inboxes/CLEAR_INBOXES');
    commit('customViews/CLEAR_CUSTOM_VIEWS');
    commit('agents/CLEAR_AGENTS');
    // Medium-priority modules
    commit('conversationLabels/CLEAR_CONVERSATION_LABELS');
    commit('conversations/EMPTY_ALL_CONVERSATION');
    commit('contacts/CLEAR_CONTACTS');
    commit('teams/CLEAR_TEAMS');
    commit('notifications/CLEAR_NOTIFICATIONS');
    // ... extend as CLEAR mutations are added
  },
};
```

This could be called:
- Before `initializeAccount()` as a defensive measure
- On logout (supplement existing `CLEAR_USER`)
- On error recovery

#### 3.3 Conversation Memory Management

The `allConversations` array grows unboundedly as conversations are opened. Each conversation retains its full `messages` array.

**Proposed:** Implement an LRU eviction policy for conversation messages:

```js
const MAX_CACHED_CONVERSATIONS_WITH_MESSAGES = 20;

// When setting active chat, evict oldest conversations' messages
[types.SET_CURRENT_CHAT_WINDOW](_state, activeChat) {
  _state.selectedChatId = activeChat?.id;

  // Count conversations with loaded messages
  const conversationsWithMessages = _state.allConversations
    .filter(c => c.messages?.length > 0 && c.id !== activeChat?.id);

  if (conversationsWithMessages.length > MAX_CACHED_CONVERSATIONS_WITH_MESSAGES) {
    // Sort by last access time (or last_activity_at), evict oldest
    const toEvict = conversationsWithMessages
      .sort((a, b) => new Date(a.last_activity_at) - new Date(b.last_activity_at))
      .slice(0, conversationsWithMessages.length - MAX_CACHED_CONVERSATIONS_WITH_MESSAGES);

    toEvict.forEach(conv => {
      conv.messages = [];
      conv.dataFetched = false;
      conv.allMessagesLoaded = false;
    });
  }
}
```

#### 3.4 Add `pageshow` Event Listener for bfcache

Detect bfcache restoration and force a reload to prevent stale state:

```js
// entrypoints/dashboard.js
window.addEventListener('pageshow', (event) => {
  if (event.persisted) {
    // Page was restored from bfcache — force reload to get fresh state
    window.location.reload();
  }
});
```

---

## 9. Best Practices Reference

### Multi-Tenant State Management in Vue

**Pattern 1: Account-scoped store namespacing**
Large multi-tenant Vue apps prefix store module keys with account IDs:
```js
// Instead of: store.state.labels.records
// Use: store.state['labels_123'].records
```
Vuex supports dynamic module registration (`store.registerModule`) for this, but it's complex and doesn't match Chatwoot's architecture.

**Pattern 2: Full state reset on tenant switch (Chatwoot's approach)**
Destroy and recreate the entire app context when switching tenants. This is the simplest and most reliable approach. Chatwoot does this correctly via `window.location.href`.

**Pattern 3: Store factory with `$reset()`**
Pinia's built-in `$reset()` resets state to initial values. In Vuex, this can be simulated:
```js
const initialState = () => ({ records: [], uiFlags: { ... } });

const mutations = {
  RESET(state) {
    Object.assign(state, initialState());
  },
};
```

**Recommendation for Chatwoot:** The current full-page-reload approach (Pattern 2) is correct. Supplement with Pattern 3 (reset mutations) for defense-in-depth.

### Global Error Handling in Vue 3

The Vue 3 error handling hierarchy:
1. `onErrorCaptured` (component-level) — catches errors from descendant components
2. `app.config.errorHandler` (app-level) — catches all unhandled errors
3. `window.onerror` / `window.addEventListener('unhandledrejection')` — catches non-Vue errors

**Best practice:** Use all three layers:
- Error boundaries (`onErrorCaptured`) for graceful per-component degradation
- `app.config.errorHandler` for centralized logging and user notification
- Window-level handlers for non-Vue errors (already handled by Sentry)

### WebSocket Lifecycle Management

**Best practice for ActionCable in SPAs:**
1. Store subscription references for cleanup
2. Disconnect explicitly on `unmounted`/`beforeUnmount`
3. Use `setInterval` instead of recursive `setTimeout` (stoppable)
4. Validate event data against current app state (Chatwoot does this well with `isAValidEvent`)
5. Implement exponential backoff for reconnection (Chatwoot uses a simple 1s timer — acceptable)

### IndexedDB Cache Management

**Best practices:**
1. Always scope databases by tenant/account (Chatwoot does this: `cw-store-{accountId}`)
2. Use version numbers for schema migrations (Chatwoot has this but hasn't bumped since March 2023)
3. Validate cache integrity on each read (Chatwoot does this via cache keys)
4. Clean up old databases on logout (Chatwoot does this)
5. **Don't** store account-scoped database references in singletons (Chatwoot violates this)

---

## 10. Summary of Findings

### What's Working Well
- Full page reload on account switch — prevents most cross-account issues
- `isAValidEvent` check on ActionCable events — prevents cross-account WebSocket contamination
- Cache key validation system — ensures IndexedDB cache freshness
- `ReconnectService` — well-designed reconnection and state sync
- IndexedDB cleanup on logout — thorough database deletion
- Account-scoped IndexedDB database naming (`cw-store-{accountId}`)

### What Needs Fixing (Priority Order)
1. **No `app.config.errorHandler`** — any render error leaves UI broken
2. **DataManager singleton stores accountId at construction** — theoretical cache cross-contamination
3. **24 store modules lack reset mutations** — no defense-in-depth for state cleanup
4. **ActionCable connector not stored for cleanup** — timer and connection leaks in development
5. **Presence timer uses recursive setTimeout** — cannot be stopped
6. **Draft messages not scoped by account** — orphaned data in LocalStorage

### What's Not Worth Fixing Now
- Pinia migration — high effort, low benefit given Vuex works and upstream uses it
- Dynamic store module registration per account — over-engineering for current needs
- SessionStorage sidebar state scoping — purely cosmetic issue
- Service worker caching — SW only handles push notifications, no data caching
