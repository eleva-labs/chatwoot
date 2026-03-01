# Chatwoot Web App - State Management Audit

## Date: 2026-02-28

---

## 1. How Account Switching Works

### Mechanism

Account switching uses **full page navigation** (`window.location.href`), not SPA routing.

**File:** `app/javascript/dashboard/components-next/sidebar/SidebarAccountSwitcher.vue:36-37`
```js
const onChangeAccount = newId => {
  const accountUrl = `/app/accounts/${newId}/dashboard`;
  window.location.href = accountUrl;
};
```

This triggers a complete page reload, which means:
- The entire Vue app is destroyed and recreated
- A fresh Vuex store is instantiated
- All components unmount and remount
- ActionCable connections are torn down and re-established

### Account ID Resolution

The current account ID is derived from the URL via the router:

**File:** `app/javascript/dashboard/store/modules/auth.js:55-60`
```js
getCurrentAccountId(_, __, rootState) {
  if (rootState.route.params && rootState.route.params.accountId) {
    return Number(rootState.route.params.accountId);
  }
  return null;
},
```

### Initialization Flow

1. `entrypoints/dashboard.js` creates the Vue app, Vuex store, and router
2. `App.vue` watches `currentAccountId` and calls `initializeAccount()` when it changes
3. `initializeAccount()` (App.vue:115-146) fetches account data, inboxes, sets locale, initializes ActionCable, and starts ReconnectService
4. `Sidebar.vue` `onMounted` (line 80-88) dispatches fetches for labels, inboxes, notifications, teams, attributes, and custom views

**File:** `app/javascript/dashboard/App.vue:82-88`
```js
currentAccountId: {
  immediate: true,
  handler() {
    if (this.currentAccountId) {
      this.initializeAccount();
    }
  },
},
```

### Conclusion on Cross-Account Label Bleeding

Since account switching uses `window.location.href` (full page navigation), **cross-account label bleeding via Vuex state carryover is effectively impossible** in the standard flow. The entire JS context is destroyed and recreated.

However, there are two possible scenarios where label bleeding could occur:

#### Scenario A: IndexedDB Cache Cross-Contamination

The `CacheEnabledApiClient` uses IndexedDB for caching labels, inboxes, and teams. The database is scoped by account ID (`cw-store-{accountId}`), which is correct. However:

**File:** `app/javascript/dashboard/api/CacheEnabledApiClient.js:8`
```js
this.dataManager = new DataManager(this.accountIdFromRoute);
```

**File:** `app/javascript/dashboard/api/ApiClient.js:17-26`
```js
get accountIdFromRoute() {
  const isInsideAccountScopedURLs =
    window.location.pathname.includes('/app/accounts');
  if (isInsideAccountScopedURLs) {
    return window.location.pathname.split('/')[3];
  }
  return '';
}
```

**Risk:** The `accountIdFromRoute` is derived from `window.location.pathname` at construction time. The `LabelsAPI` is instantiated as a **singleton** (`export default new LabelsAPI()` at `api/labels.js:14`). If the `DataManager` is initialized once with account A's ID and the page somehow navigates without a full reload (e.g., via browser back/forward cache, or a race condition during navigation), the `DataManager` could serve stale data from account A's IndexedDB when account B is active.

However, since `accountIdFromRoute` is a getter (not a stored value), it should re-evaluate on each call. The `DataManager` constructor stores the account ID at construction time though:

**File:** `app/javascript/dashboard/helper/CacheHelper/DataManager.js:5-8`
```js
constructor(accountId) {
  this.modelsToSync = ['inbox', 'label', 'team'];
  this.accountId = accountId;  // <-- Stored at construction time
  this.db = null;
}
```

**BUG FOUND:** The `DataManager` is created once per `CacheEnabledApiClient` construction. Since `LabelsAPI` is a module-level singleton, the `DataManager`'s `accountId` is set **once** when the module is first imported. On a full page reload, this is fine. But if there's any scenario where the module survives (e.g., HMR during development, or browser page cache/bfcache), the `DataManager` would point to the wrong account's IndexedDB.

**Severity:** Low in production (full page reload clears modules), Medium in development (HMR could cause this).

#### Scenario B: Browser Back/Forward Cache (bfcache)

Modern browsers may cache the entire page state when navigating away. If a user is on account A, navigates to account B via `window.location.href`, then presses the browser back button, the browser might restore account A's page from bfcache with account B's URL. This would show account A's labels (from the cached Vuex state) with account B's URL.

**Severity:** Low (browsers generally don't bfcache pages with WebSocket connections).

---

## 2. Root Cause of Cross-Account Label Bleeding

### Primary Finding: This is NOT a Vuex state carryover issue

Since account switching uses full page navigation, the Vuex store is always fresh. The most likely causes of perceived "label bleeding" are:

1. **Visual flash during page load**: After `window.location.href` triggers navigation, there's a brief period where the old page is still visible before the new page loads. If the user clicks the account switcher, sees the old labels briefly, then the page reloads with correct labels, this could be perceived as "bleeding."

2. **Cache key validation race condition**: The `revalidate` action in the labels store checks if the cache key is valid before deciding whether to refetch:

**File:** `app/javascript/dashboard/store/modules/labels.js:35-44`
```js
revalidate: async function revalidate({ commit }, { newKey }) {
  try {
    const isExistingKeyValid = await LabelsAPI.validateCacheKey(newKey);
    if (!isExistingKeyValid) {
      const response = await LabelsAPI.refetchAndCommit(newKey);
      commit(types.SET_LABELS, response.data.payload);
    }
  } catch (error) {
    // Ignore error
  }
},
```

If the cache validation succeeds (returns `true`) but the cached data in IndexedDB is actually from a previous account (due to the `DataManager` singleton issue mentioned above), stale labels would be displayed.

3. **Sidebar fetches labels on `onMounted` but has no "loading" state for labels section**: The sidebar renders labels immediately from the Vuex store (initially empty `[]`), then fetches them. If the cache serves stale data, the stale labels appear instantly and are never corrected (because the cache key appears valid).

### Labels Store Architecture

**File:** `app/javascript/dashboard/store/modules/labels.js`

- **State:** `records: []` (flat array, no account scoping)
- **No clear/reset mutation** - there is no `CLEAR_LABELS` or `RESET_LABELS` mutation type
- **Fetch:** `get` action calls `LabelsAPI.get(true)` (with cache=true), which goes through IndexedDB
- **No account ID filtering** in the store - relies entirely on the API returning account-scoped data

---

## 3. All State Cleanup Gaps Found

### Stores WITHOUT any clear/reset mechanism

The following store modules have **no clear, reset, or empty mutation** and accumulate data across the session:

| Store Module | File | Has Clear/Reset? | Risk Level |
|---|---|---|---|
| `labels` | `store/modules/labels.js` | **NO** | High (shown in sidebar) |
| `agents` | `store/modules/agents.js` | **NO** | Medium |
| `accounts` | `store/modules/accounts.js` | **NO** | Low (additive) |
| `cannedResponse` | `store/modules/cannedResponse.js` | **NO** | Low |
| `campaigns` | `store/modules/campaigns.js` | **NO** | Low |
| `customViews` | `store/modules/customViews.js` | **NO** | Medium (shown in sidebar) |
| `customRole` | `store/modules/customRole.js` | **NO** | Low |
| `automations` | `store/modules/automations.js` | **NO** | Low |
| `attributes` | `store/modules/attributes.js` | **NO** | Low |
| `integrations` | `store/modules/integrations.js` | **NO** | Low |
| `webhooks` | `store/modules/webhooks.js` | **NO** | Low |
| `macros` | `store/modules/macros.js` | **NO** | Low |
| `agentBots` | `store/modules/agentBots.js` | **NO** | Low |
| `sla` | `store/modules/sla.js` | **NO** | Low |
| `assignmentPolicies` | `store/modules/assignmentPolicies.js` | **NO** | Low |
| `agentCapacityPolicies` | `store/modules/agentCapacityPolicies.js` | **NO** | Low |
| `dashboardApps` | `store/modules/dashboardApps.js` | **NO** | Low |
| `inboxes` | `store/modules/inboxes.js` | **NO** | Medium (shown in sidebar) |
| `prompts` | `store/modules/prompts.js` | **NO** | Low |
| `conversationLabels` | `store/modules/conversationLabels.js` | **NO** | Medium |
| `contactLabels` | `store/modules/contactLabels.js` | **NO** | Low |
| `conversationMetadata` | `store/modules/conversationMetadata.js` | **NO** | Low |
| `conversationTypingStatus` | `store/modules/conversationTypingStatus.js` | **NO** | Low |
| Captain stores | `store/captain/*.js` | **NO** | Low |

### Stores WITH clear/reset mechanisms

| Store Module | Clear Mechanism | When Triggered |
|---|---|---|
| `conversations` | `EMPTY_ALL_CONVERSATION` | Manual action only |
| `conversations` | `CLEAR_CURRENT_CHAT_WINDOW` | `beforeRouteLeave`, explicit dispatch |
| `conversations` | `CLEAR_CONVERSATION_FILTERS` | Explicit action |
| `contacts` | `CLEAR_CONTACTS` | Before each `get` call |
| `notifications` | `CLEAR_NOTIFICATIONS` | Before each `get` call |
| `teams` | `CLEAR_TEAMS` | Before each `get` call |
| `auth` | `CLEAR_USER` | On logout |
| `articles` | `CLEAR_ARTICLES` | Before fetch |
| `categories` | `CLEAR_CATEGORIES` | Before fetch |
| `portals` | `CLEAR_PORTALS` | Before fetch |
| `conversationSearch` | `CLEAR_SEARCH_RESULTS` | On new search |
| `conversationPage` | `CLEAR_CONVERSATION_PAGE` | Before fetch |
| `bulkActions` | `CLEAR_SELECTED_CONVERSATION_IDS` | Explicit action |

### Key Observation

Most stores use a "set" pattern (via `MutationHelpers.set`) that **replaces** the entire `records` array on fetch. This is effectively a "clear + set" operation. However, this only works correctly if:
1. The fetch is triggered on account switch (which it is via full page reload)
2. The fetch completes before the UI renders with stale data (race condition possible with cached data)

---

## 4. Stale Conversation Data Issues

### After Errors (e.g., Audio URL Crash)

**Problem:** When an unhandled error occurs during message rendering (e.g., invalid audio URL), Vue's component rendering may fail, but:

1. **No global error handler exists**: There is no `app.config.errorHandler` set in `entrypoints/dashboard.js`
2. **No error boundary components**: No `onErrorCaptured` hooks found in any component
3. **Sentry captures but doesn't recover**: Sentry is initialized for error reporting but has no recovery logic

**File:** `app/javascript/entrypoints/dashboard.js:50-72` - Sentry init with no `beforeSend` cleanup or state reset.

**Consequence:** If a render error occurs:
- The conversation component tree may be left in a broken state
- The Vuex store retains all messages (including the one that caused the crash)
- No automatic retry or state cleanup happens
- The user must manually refresh to recover

### Conversation Messages Are Never Cleared on Navigation

**File:** `app/javascript/dashboard/store/modules/conversations/index.js`

Messages are stored inside each conversation object in `allConversations`:
```js
state = {
  allConversations: [], // Each has a .messages array
  selectedChatId: null,
  // ...
}
```

When navigating between conversations:
- `CLEAR_CURRENT_CHAT_WINDOW` only sets `selectedChatId = null` (line 70-72)
- The messages array on each conversation object persists
- This is by design (for performance - avoids refetching when going back to a conversation)

However, this means:
- Memory grows unbounded as more conversations are opened
- Stale messages persist if the conversation was updated while viewing another one
- The `syncActiveConversationMessages` action handles reconnection but not general staleness

### `SET_ALL_CONVERSATION` Race Condition

**File:** `app/javascript/dashboard/store/modules/conversations/index.js:29-56`

The `SET_ALL_CONVERSATION` mutation preserves messages for the currently selected conversation:
```js
if (conversation.id !== _state.selectedChatId) {
  newAllConversations[indexInCurrentList] = conversation;
} else {
  // Preserve messages, allMessagesLoaded, dataFetched
  newAllConversations[indexInCurrentList] = {
    ...conversation,
    allMessagesLoaded: existingConversation.allMessagesLoaded,
    messages: existingConversation.messages,
    dataFetched: existingConversation.dataFetched,
  };
}
```

This means WebSocket updates to the current conversation don't replace its messages, which is correct. But if a conversation update arrives via WebSocket with new metadata while the user has stale messages, the metadata updates but messages don't sync.

---

## 5. WebSocket Subscription Audit

### Initialization

**File:** `app/javascript/dashboard/App.vue:135`
```js
vueActionCable.init(this.store, pubsubToken);
```

**File:** `app/javascript/shared/helpers/BaseActionCableConnector.js:9-43`

The ActionCable subscription is created with:
- `pubsub_token`: User's pubsub token
- `account_id`: Current account ID from store getter
- `user_id`: Current user ID

### Event Validation

**File:** `app/javascript/dashboard/helper/actionCable.js:52-54`
```js
isAValidEvent = data => {
  return this.app.$store.getters.getCurrentAccountId === data.account_id;
};
```

This check ensures that only events for the current account are processed. This is a good safeguard.

### Cleanup on Account Switch

Since account switching triggers `window.location.href` (full page navigation):
- The old ActionCable consumer is destroyed when the page unloads
- A new consumer is created during `initializeAccount()` for the new account
- There is **no explicit `disconnect()` call** before navigation, but the browser handles WebSocket teardown on page unload

### Potential Issues

1. **No cleanup in `App.vue` unmounted hook for ActionCable**: `App.vue:99-103` only disconnects `reconnectService`, not the ActionCable connector:
```js
unmounted() {
  if (this.reconnectService) {
    this.reconnectService.disconnect();
  }
},
```

2. **ActionCable connector is not stored for cleanup**: `vueActionCable.init()` returns the connector but `App.vue` doesn't store or clean it up. The connector has an internal `triggerPresenceInterval` that runs indefinitely:

**File:** `app/javascript/shared/helpers/BaseActionCableConnector.js:36-42`
```js
this.triggerPresenceInterval = () => {
  setTimeout(() => {
    this.subscription.updatePresence();
    this.triggerPresenceInterval();
  }, PRESENCE_INTERVAL);
};
this.triggerPresenceInterval();
```

This creates a `setTimeout` chain that can never be stopped (no `clearTimeout`). On page unload this is fine, but during HMR in development, previous instances would continue running.

3. **Multiple ActionCable instances on HMR**: In development with HMR, `initializeAccount()` could be called multiple times, creating multiple ActionCable connectors. Each one would process events and dispatch to the store independently, potentially causing duplicate state updates.

4. **`isAValidEvent` gap for some events**: Several event handlers call methods that don't re-check `account_id`:
   - `onPresenceUpdate` (line 60-65) dispatches directly without additional account validation
   - `onCopilotMessageCreated` (line 212-214) dispatches without account validation
   
   The `onReceived` handler in `BaseActionCableConnector.js:82-88` does call `isAValidEvent` before dispatching, so these are protected at the top level. However, the `account_id` check relies on the WebSocket server sending `account_id` with every event, which it should.

### Reconnection Behavior

**File:** `app/javascript/dashboard/helper/ReconnectService.js`

On reconnect:
1. Fetches conversations updated since disconnect
2. Syncs messages for the currently viewed conversation
3. Revalidates caches for labels, inboxes, teams

This is well-implemented and handles the common case of temporary disconnections.

---

## 6. Caching Mechanisms

### IndexedDB Cache (via `CacheEnabledApiClient`)

**Scope:** Labels, Inboxes, Teams
**File:** `app/javascript/dashboard/helper/CacheHelper/DataManager.js`

- Database named `cw-store-{accountId}` (correctly scoped per account)
- Cache keys stored alongside data for validation
- Cache is validated on each fetch by comparing server cache key with local key
- If cache is invalid, data is refetched from network and IndexedDB is updated

**Issue:** `DataManager.accountId` is set at construction time of the singleton `LabelsAPI`/`InboxesAPI`/`TeamsAPI`. Since these are module-level singletons, the `DataManager` is initialized once per full page load. See Section 2, Scenario A.

### LocalStorage

**File:** `app/javascript/dashboard/store/modules/draftMessages.js:8`
```js
records: LocalStorage.get(LOCAL_STORAGE_KEYS.DRAFT_MESSAGES) || {},
```

Draft messages are persisted in LocalStorage with **no account scoping**. Draft keys include the conversation ID, which is globally unique, so this doesn't cause cross-account issues. But drafts from account A are visible in the store when viewing account B (they just won't match any conversation).

**File:** `app/javascript/dashboard/store/utils/api.js:53-55` - Draft messages are cleared on logout but NOT on account switch.

### SessionStorage

The sidebar's expanded item state uses `sessionStorage`:

**File:** `app/javascript/dashboard/components-next/sidebar/Sidebar.vue:58-62`
```js
const expandedItem = useStorage(
  'next-sidebar-expanded-item',
  null,
  sessionStorage
);
```

This persists across account switches (since it's sessionStorage, not cleared on navigation). The expanded sidebar section from account A will remain expanded on account B. This is cosmetic but could be confusing.

### Service Worker

**File:** `public/sw.js`

The service worker only handles push notifications (display and click). It does **not** cache any API responses or assets. No risk of serving stale data via service worker.

### HTTP Caching

No explicit HTTP cache headers are set by the frontend. The API endpoints use standard Rails caching. The `cache_keys` endpoint is called on each page load to validate IndexedDB cache, so HTTP-level caching of the cache keys endpoint itself could cause stale cache validation. However, this is a server-side concern.

---

## 7. Vue Component Lifecycle on Account Switch

### No `:key` binding on account-scoped components

**File:** `app/javascript/dashboard/routes/dashboard/dashboard.routes.js:17-29`
```js
{
  path: frontendURL('accounts/:accountId'),
  component: AppContainer,
  children: [...]
}
```

The `Dashboard.vue` component (`AppContainer`) does not use `:key="accountId"`. However, since account switching uses full page navigation, Vue never tries to reuse the component - it's always freshly mounted.

**File:** `app/javascript/dashboard/App.vue:163-167`
```js
<router-view v-slot="{ Component }">
  <transition name="fade" mode="out-in">
    <component :is="Component" />
  </transition>
</router-view>
```

No `:key` on the router-view, but again, full page reload makes this moot.

### ConversationView Cleanup

**File:** `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue:22-28`
```js
beforeRouteLeave(to, from, next) {
  if (this.conversationId) {
    this.$store.dispatch('clearSelectedState');
  }
  next();
},
```

Good: clears selected conversation on route leave. But only clears `selectedChatId`, not the conversation's messages.

---

## 8. Error Recovery Recommendations

### Problem: No Global Error Boundary

Currently, if a component render error occurs (e.g., accessing `.url` on an undefined audio attachment), Vue will:
1. Log the error to the console
2. Report to Sentry (if configured)
3. Leave the component tree in an inconsistent state
4. Not trigger any store cleanup

### Proposed Fix: Add Global Error Handler

**File to modify:** `app/javascript/entrypoints/dashboard.js`

Add after line 44:
```js
app.config.errorHandler = (err, instance, info) => {
  console.error('Unhandled Vue error:', err, info);
  // Sentry already captures via its integration, but we can add recovery logic:
  // Option 1: Show a toast notification
  // Option 2: Reset the conversation view state
  // Option 3: Force re-render the broken component
};
```

### Proposed Fix: Error Boundary Component

Create an error boundary component that can wrap conversation message rendering to catch and recover from individual message render errors without breaking the entire conversation view.

---

## 9. Proposed Fixes (Prioritized by Impact)

### Priority 1: High Impact, Low Effort

#### 1a. Add missing `CLEAR_LABELS` mechanism (defensive, for future use)

Although full page reload currently prevents cross-account contamination, adding a clear mechanism makes the labels store more robust:

**File:** `app/javascript/dashboard/store/mutation-types.js`
- Add: `CLEAR_LABELS: 'CLEAR_LABELS'`

**File:** `app/javascript/dashboard/store/modules/labels.js`
- Add mutation: `[types.CLEAR_LABELS]: (_state) => { _state.records = []; }`
- Modify `get` action to clear before fetching: `commit(types.CLEAR_LABELS);` before the try block

This ensures labels from a previous fetch are cleared before new ones arrive, eliminating any window where stale labels could be visible.

#### 1b. Add global error handler

**File:** `app/javascript/entrypoints/dashboard.js`

Add `app.config.errorHandler` to prevent unhandled errors from leaving the app in a broken state. At minimum, log the error and show a user-facing notification.

### Priority 2: Medium Impact, Medium Effort

#### 2a. Fix `DataManager` singleton issue

**File:** `app/javascript/dashboard/api/CacheEnabledApiClient.js`

Change `DataManager` initialization to be lazy (per-call) rather than at construction time:
```js
get dataManager() {
  return new DataManager(this.accountIdFromRoute);
}
```

Or make the accountId dynamic in `DataManager`:
```js
class DataManager {
  constructor(getAccountId) {
    this.getAccountId = getAccountId; // function instead of value
  }
  get accountId() { return this.getAccountId(); }
}
```

#### 2b. Clear labels before setting new ones in `get` action

**File:** `app/javascript/dashboard/store/modules/labels.js:47-59`

```js
get: async function getLabels({ commit }) {
  commit(types.SET_LABEL_UI_FLAG, { isFetching: true });
  commit(types.SET_LABELS, []); // Clear immediately
  try {
    const response = await LabelsAPI.get(true);
    const sortedLabels = response.data.payload.sort(...);
    commit(types.SET_LABELS, sortedLabels);
  } catch (error) {
    // Ignore error
  } finally {
    commit(types.SET_LABEL_UI_FLAG, { isFetching: false });
  }
},
```

#### 2c. Scope draft messages by account

**File:** `app/javascript/dashboard/store/modules/draftMessages.js`

Change the LocalStorage key to include accountId:
```js
const getDraftKey = () => {
  const accountId = window.location.pathname.split('/')[3];
  return `${LOCAL_STORAGE_KEYS.DRAFT_MESSAGES}_${accountId}`;
};
```

### Priority 3: Low Impact, High Effort (Architecture Improvements)

#### 3a. Store ActionCable connector reference for cleanup

**File:** `app/javascript/dashboard/App.vue`

Store the ActionCable connector returned by `vueActionCable.init()` and disconnect it in the `unmounted` hook:
```js
this.actionCableConnector = vueActionCable.init(this.store, pubsubToken);
// ...
unmounted() {
  if (this.actionCableConnector) {
    this.actionCableConnector.disconnect();
  }
  if (this.reconnectService) {
    this.reconnectService.disconnect();
  }
}
```

#### 3b. Add stoppable presence interval

**File:** `app/javascript/shared/helpers/BaseActionCableConnector.js`

Replace the recursive `setTimeout` with a stoppable interval:
```js
constructor(...) {
  // ...
  this.presenceTimer = setInterval(() => {
    this.subscription.updatePresence();
  }, PRESENCE_INTERVAL);
}

disconnect() {
  clearInterval(this.presenceTimer);
  this.consumer.disconnect();
}
```

#### 3c. Add error boundary component for conversation messages

Create a component that wraps individual message rendering with `onErrorCaptured` to catch and gracefully handle render errors from problematic messages (e.g., malformed audio URLs, missing attachment data).

#### 3d. Conversation memory management

Consider adding a maximum number of cached conversations with messages in `allConversations`, evicting the oldest when the limit is reached. This prevents unbounded memory growth during long sessions.

---

## 10. Summary of Findings

### Cross-Account Label Bleeding
- **Root cause:** Not a Vuex state issue. Full page reload prevents this.
- **Possible contributor:** IndexedDB `DataManager` singleton could theoretically serve cached data from wrong account in edge cases (bfcache, HMR).
- **Fix:** Make `DataManager` account-aware per call, and clear labels before refetching.

### Stale Conversation Data
- **Root cause:** No error recovery mechanism. Conversation messages persist indefinitely in the store.
- **Fix:** Add global error handler, error boundary components, and consider memory management for cached conversations.

### State Cleanup Gaps
- **Scope:** 20+ store modules have no clear/reset mechanism.
- **Mitigated by:** Full page reload on account switch, and `MutationHelpers.set` replacing entire records array on fetch.
- **Remaining risk:** Between fetch dispatch and response, stale data from a previous fetch could be visible.

### WebSocket Subscriptions
- **Generally well-implemented:** `isAValidEvent` check prevents cross-account event processing.
- **Gap:** No explicit cleanup of ActionCable connector or presence interval timer.
- **Risk:** Low in production, higher in development (HMR creates duplicate connectors).

### Error Recovery
- **Critical gap:** No `app.config.errorHandler` or error boundary components.
- **Impact:** Any unhandled render error (e.g., audio URL crash) leaves the UI in a broken state with no automatic recovery.
