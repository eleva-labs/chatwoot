# [Feature Name] - Design Document

**IMPORTANT**: This document MUST be created in `/docs/ignored/design/<feature_name>_design.md`

**Session ID**: <uuid-or-timestamp>
**Created**: YYYY-MM-DD HH:MM:SS
**Author**: Claude Code (Anthropic)
**Status**: Draft | Under Review | Approved
**Related Request**: <user request summary>
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Executive Summary

<!-- 2-3 paragraphs summarizing the design, problem being solved, and proposed solution -->

### Key Benefits
- Benefit 1: [Description of value delivered]
- Benefit 2: [Description of improvement]
- Benefit 3: [Description of impact]

### Effort Estimate
- **Duration**: X days
- **Complexity**: Low | Medium | High
- **Risk**: Low | Medium | High

---

## Current State Analysis

### Overview
<!-- Describe current implementation, how it works today, and what problems exist -->

### Code Examples

**Current Backend Implementation**:
```ruby
# File: app/models/store.rb:15
class Store < ApplicationRecord
  belongs_to :account
  validates :name, presence: true

  # Current logic that will be changed/extended
  def current_method
    # Existing implementation
  end
end
```

**Current Frontend Implementation**:
```vue
<!-- File: app/javascript/dashboard/components/StoreDetails.vue:20 -->
<script setup>
// Current component logic
</script>

<template>
  <div class="flex flex-col">
    <!-- Current UI -->
  </div>
</template>
```

### Problems Identified
1. **Problem 1**: [Description of limitation or issue]
   - **Impact**: [How it affects users/system]
   - **Evidence**: [Reference to code or user feedback]

2. **Problem 2**: [Description]
   - **Impact**: [Effect on system/users]
   - **Evidence**: [Supporting data]

### Files Affected
- `app/models/store.rb:15` - [Current role/purpose]
- `app/services/stores/create_service.rb:10` - [Current logic]
- `app/controllers/api/v1/accounts/stores_controller.rb:25` - [API handler]
- `app/javascript/dashboard/components/StoreDetails.vue:5` - [UI component]

---

## Proposed Solution

### High-Level Approach
<!-- Describe the solution approach in 2-3 paragraphs: what will be built, how it will work, why this approach -->

### Architecture Changes
- **Change 1**: [Description of architectural change]
- **Change 2**: [Description of pattern or structure change]
- **Change 3**: [Description of data flow change]

### Code Examples

**Proposed Backend Implementation**:
```ruby
# app/models/store.rb - AFTER changes
class Store < ApplicationRecord
  belongs_to :account
  has_many :conversations

  # New enum field
  enum priority: { low: 0, medium: 1, high: 2 }

  validates :name, presence: true
  validates :priority, presence: true, inclusion: { in: priorities.keys }

  scope :high_priority, -> { where(priority: :high) }

  # New/modified method
  def prioritized_name
    "[#{priority.upcase}] #{name}"
  end
end
```

**Proposed Frontend Implementation**:
```vue
<!-- app/javascript/dashboard/components/StorePrioritySelector.vue - NEW -->
<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

const store = useStore();
const { t } = useI18n();

const props = defineProps({
  storeId: { type: String, required: true },
});

const priority = ref('medium');
const priorities = ['low', 'medium', 'high'];

const updatePriority = async () => {
  await store.dispatch('stores/updatePriority', {
    id: props.storeId,
    priority: priority.value,
  });
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium">
      {{ t('STORE.PRIORITY') }}
    </label>
    <select v-model="priority" @change="updatePriority"
            class="border rounded px-3 py-2">
      <option v-for="p in priorities" :key="p" :value="p">
        {{ t(`STORE.PRIORITY_${p.toUpperCase()}`) }}
      </option>
    </select>
  </div>
</template>
```

### Design Patterns
- **Pattern 1**: Service Object - Encapsulates business logic for store priority updates
- **Pattern 2**: Event Dispatcher - Notifies listeners when priority changes
- **Pattern 3**: Vuex State Management - Centralized state for priority data

---

## Technical Design

### Models & Database Changes

**Files to Modify**:
- `app/models/store.rb`
- `db/migrate/YYYYMMDDHHMMSS_add_priority_to_stores.rb` (NEW)

**Changes**:
1. Add `priority` integer field with enum mapping (low:0, medium:1, high:2)
2. Add validation for priority field
3. Add scope for filtering by priority
4. Add helper method for display

**Migration**:
```ruby
# db/migrate/20251006120000_add_priority_to_stores.rb
class AddPriorityToStores < ActiveRecord::Migration[7.1]
  def change
    add_column :stores, :priority, :integer, default: 1, null: false
    add_index :stores, :priority
  end
end
```

**Model Code**:
```ruby
# app/models/store.rb
class Store < ApplicationRecord
  belongs_to :account
  has_many :conversations

  enum priority: { low: 0, medium: 1, high: 2 }

  validates :name, presence: true
  validates :priority, presence: true, inclusion: { in: priorities.keys }

  scope :high_priority, -> { where(priority: :high) }
  scope :by_priority, -> { order(priority: :desc) }

  def prioritized_name
    "[#{priority.upcase}] #{name}"
  end
end
```

---

### Services & Business Logic Changes

**Files to Modify**:
- `app/services/stores/create_service.rb` - Add priority param
- `app/services/stores/update_service.rb` - Add priority param
- `app/services/stores/update_priority_service.rb` (NEW) - Dedicated service

**New Service**:
```ruby
# app/services/stores/update_priority_service.rb
class Stores::UpdatePriorityService
  def initialize(store:, priority:, user: nil)
    @store = store
    @priority = priority
    @user = user
  end

  def perform
    old_priority = @store.priority

    @store.update!(priority: @priority)

    dispatch_priority_changed_event(old_priority, @priority)

    Rails.logger.info("Store #{@store.id} priority changed: #{old_priority} -> #{@priority}")

    @store
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Priority update failed: #{e.message}")
    raise
  end

  private

  def dispatch_priority_changed_event(old_priority, new_priority)
    Rails.configuration.dispatcher.dispatch(
      STORE_PRIORITY_CHANGED,
      Time.zone.now,
      store: @store,
      old_priority: old_priority,
      new_priority: new_priority,
      user: @user
    )
  end
end
```

---

### Controllers & API Changes

**Files to Modify**:
- `app/controllers/api/v1/accounts/stores_controller.rb`

**Changes**:
1. Permit `priority` param in `store_params`
2. Add new endpoint for priority updates (optional: can use PATCH)

**Controller Code**:
```ruby
# app/controllers/api/v1/accounts/stores_controller.rb
class Api::V1::Accounts::StoresController < Api::V1::Accounts::BaseController
  before_action :set_store, only: [:show, :update, :update_priority, :destroy]

  def index
    @stores = StoresFinder.new(Current.account, params).perform
    @stores = @stores.by_priority.page(params[:page])
  end

  def update_priority
    Stores::UpdatePriorityService.new(
      store: @store,
      priority: params[:priority],
      user: Current.user
    ).perform

    render json: @store
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def set_store
    @store = Current.account.stores.find(params[:id])
  end

  def store_params
    params.permit(:name, :phone_number, :priority, :email)
  end
end
```

**Routes**:
```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :accounts do
      resources :stores do
        member do
          patch :update_priority
        end
      end
    end
  end
end
```

---

### Jbuilder Views Changes

**Files to Modify**:
- `app/views/api/v1/accounts/stores/show.json.jbuilder`
- `app/views/api/v1/accounts/stores/_store.json.jbuilder`

**Jbuilder Code**:
```ruby
# app/views/api/v1/accounts/stores/show.json.jbuilder
json.id @store.id
json.name @store.name
json.phoneNumber @store.phone_number
json.priority @store.priority  # NEW
json.email @store.email
json.createdAt @store.created_at
json.updatedAt @store.updated_at
```

---

### Jobs & Background Processing Changes

**Files to Create** (if needed):
- `app/jobs/stores/priority_notification_job.rb` (NEW)

**Job Code**:
```ruby
# app/jobs/stores/priority_notification_job.rb
class Stores::PriorityNotificationJob < ApplicationJob
  queue_as :default

  def perform(store_id, old_priority, new_priority)
    store = Store.find(store_id)

    # Notify team if store priority increased to high
    if new_priority == 'high' && old_priority != 'high'
      store.account.users.each do |user|
        NotificationMailer.high_priority_store(store, user).deliver_later
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("PriorityNotificationJob: Store #{store_id} not found")
  end
end
```

---

### Listeners & Event Handling Changes

**Files to Create/Modify**:
- `app/listeners/store_listener.rb` - Add priority changed handler

**Listener Code**:
```ruby
# app/listeners/store_listener.rb
class StoreListener < BaseListener
  def store_priority_changed(event)
    store = event.data[:store]
    old_priority = event.data[:old_priority]
    new_priority = event.data[:new_priority]

    # Trigger notification job
    Stores::PriorityNotificationJob.perform_later(
      store.id,
      old_priority,
      new_priority
    )

    # Update analytics
    AnalyticsJob.perform_later('store_priority_changed', {
      store_id: store.id,
      old_priority: old_priority,
      new_priority: new_priority
    })
  rescue StandardError => e
    Rails.logger.error("StoreListener priority_changed error: #{e.message}")
    Sentry.capture_exception(e)
  end
end
```

---

### Frontend - Vue Components Changes

**Files to Create**:
- `app/javascript/dashboard/components/StorePrioritySelector.vue` (NEW)

**Files to Modify**:
- `app/javascript/dashboard/components/StoreDetails.vue` - Integrate priority selector

**Component Integration**:
```vue
<!-- app/javascript/dashboard/components/StoreDetails.vue -->
<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import StorePrioritySelector from './StorePrioritySelector.vue';

const store = useStore();
const props = defineProps({ storeId: { type: String, required: true } });
const storeData = computed(() => store.getters['stores/getStore'](props.storeId));
</script>

<template>
  <div class="flex flex-col gap-4 p-4">
    <h2 class="text-lg font-semibold">{{ storeData.name }}</h2>

    <!-- NEW: Priority Selector -->
    <StorePrioritySelector :store-id="storeId" />

    <!-- Rest of component -->
  </div>
</template>
```

---

### Frontend - Vuex Store Changes

**Files to Modify**:
- `app/javascript/dashboard/store/modules/stores.js`

**Vuex Changes**:
```javascript
// app/javascript/dashboard/store/modules/stores.js

// Add to actions:
async updatePriority({ commit }, { id, priority }) {
  commit('setUpdating', true);
  try {
    const response = await StoresAPI.updatePriority(id, priority);
    commit('updateStore', response.data);
    return response.data;
  } catch (error) {
    console.error('Update priority failed:', error);
    throw error;
  } finally {
    commit('setUpdating', false);
  }
}
```

---

### Frontend - API Client Changes

**Files to Modify**:
- `app/javascript/dashboard/api/stores.js`

**API Client Code**:
```javascript
// app/javascript/dashboard/api/stores.js
import ApiClient from './ApiClient';

class StoresAPI extends ApiClient {
  constructor() {
    super('stores', { accountScoped: true });
  }

  // ... existing methods ...

  updatePriority(id, priority) {
    return axios.patch(`${this.url}/${id}/update_priority`, { priority });
  }
}

export default new StoresAPI();
```

---

### Frontend - i18n Changes

**Files to Modify**:
- `app/javascript/dashboard/i18n/locale/en.json`
- `app/javascript/dashboard/i18n/locale/es.json`
- `config/locales/en.yml` (backend if needed)
- `config/locales/es.yml` (backend if needed)

**i18n Updates**:
```json
// app/javascript/dashboard/i18n/locale/en.json
{
  "STORE": {
    "PRIORITY": "Priority",
    "PRIORITY_LOW": "Low",
    "PRIORITY_MEDIUM": "Medium",
    "PRIORITY_HIGH": "High",
    "PRIORITY_UPDATED": "Priority updated successfully",
    "PRIORITY_UPDATE_FAILED": "Failed to update priority"
  }
}

// app/javascript/dashboard/i18n/locale/es.json
{
  "STORE": {
    "PRIORITY": "Prioridad",
    "PRIORITY_LOW": "Baja",
    "PRIORITY_MEDIUM": "Media",
    "PRIORITY_HIGH": "Alta",
    "PRIORITY_UPDATED": "Prioridad actualizada exitosamente",
    "PRIORITY_UPDATE_FAILED": "Error al actualizar la prioridad"
  }
}
```

---

## Impact Analysis

### Files Affected

#### Backend - Models (1 file, 1 new migration)
1. `app/models/store.rb` - Add enum, validations, scopes
2. `db/migrate/YYYYMMDDHHMMSS_add_priority_to_stores.rb` - NEW migration

#### Backend - Services (2 files, 1 new)
1. `app/services/stores/create_service.rb` - Permit priority param
2. `app/services/stores/update_service.rb` - Permit priority param
3. `app/services/stores/update_priority_service.rb` - NEW service

#### Backend - Controllers (1 file)
1. `app/controllers/api/v1/accounts/stores_controller.rb` - Add update_priority action

#### Backend - Views (2 files)
1. `app/views/api/v1/accounts/stores/show.json.jbuilder` - Add priority field
2. `app/views/api/v1/accounts/stores/_store.json.jbuilder` - Add priority field

#### Backend - Jobs (1 new file)
1. `app/jobs/stores/priority_notification_job.rb` - NEW job

#### Backend - Listeners (1 file)
1. `app/listeners/store_listener.rb` - Add priority_changed handler

#### Frontend - Components (1 new, 1 modified)
1. `app/javascript/dashboard/components/StorePrioritySelector.vue` - NEW component
2. `app/javascript/dashboard/components/StoreDetails.vue` - Integrate selector

#### Frontend - Store (1 file)
1. `app/javascript/dashboard/store/modules/stores.js` - Add updatePriority action

#### Frontend - API (1 file)
1. `app/javascript/dashboard/api/stores.js` - Add updatePriority method

#### Frontend - i18n (2 files)
1. `app/javascript/dashboard/i18n/locale/en.json` - Add priority translations
2. `app/javascript/dashboard/i18n/locale/es.json` - Add priority translations

#### Tests (Multiple new/modified)
1. `spec/models/store_spec.rb` - Test enum, validations, scopes
2. `spec/services/stores/update_priority_service_spec.rb` - NEW service spec
3. `spec/requests/api/v1/accounts/stores_spec.rb` - Test update_priority endpoint
4. `spec/jobs/stores/priority_notification_job_spec.rb` - NEW job spec
5. `app/javascript/dashboard/components/__tests__/StorePrioritySelector.spec.js` - NEW

**Total Files**: 8 backend files (3 new), 5 frontend files (1 new), 5 test files (3 new) = **18 files**

---

### Breaking Changes

**API Breaking Changes**: No

**Backward Compatibility**:
- New `priority` field has default value (medium), so existing stores automatically get medium priority
- API clients can ignore priority field if not needed
- All existing endpoints continue to work without changes

---

### Database Migrations

**Migration 1**: Add priority column to stores table
- **Type**: Schema change
- **Risk**: Low (additive change only, has default value)
- **Reversible**: Yes (can rollback by dropping column)
- **Estimated Time**: ~1 second (for small tables), up to 1 minute (for large tables)
- **Rollback Plan**: `rails db:rollback` will drop the priority column

**Migration Script**:
```bash
# Generate and run migration
rails g migration AddPriorityToStores priority:integer
rails db:migrate

# If rollback needed
rails db:rollback
```

---

### API Changes

#### New Endpoints
- `PATCH /api/v1/accounts/:account_id/stores/:id/update_priority` - Update store priority

**Request**:
```json
{
  "priority": "high"
}
```

**Response** (200 OK):
```json
{
  "id": 1,
  "name": "Store Name",
  "priority": "high",
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-01-06T12:00:00Z"
}
```

#### Modified Endpoints
- `GET /api/v1/accounts/:account_id/stores` - Now includes `priority` field in response
- `GET /api/v1/accounts/:account_id/stores/:id` - Now includes `priority` field
- `POST /api/v1/accounts/:account_id/stores` - Now accepts optional `priority` param
- `PATCH /api/v1/accounts/:account_id/stores/:id` - Now accepts optional `priority` param

#### Deprecated Endpoints
- None

---

## Testing Strategy

### Backend Tests

**Model Specs** (`spec/models/store_spec.rb`):
```ruby
RSpec.describe Store, type: :model do
  describe 'enums' do
    it { should define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2) }
  end

  describe 'validations' do
    it { should validate_presence_of(:priority) }
    it { should validate_inclusion_of(:priority).in_array(Store.priorities.keys) }
  end

  describe 'scopes' do
    describe '.high_priority' do
      # Test high priority scope returns correct records
    end
  end

  describe '#prioritized_name' do
    # Test name formatting with priority
  end
end
```

**Service Specs** (`spec/services/stores/update_priority_service_spec.rb`):
```ruby
RSpec.describe Stores::UpdatePriorityService do
  let(:store) { create(:store, priority: :medium) }
  let(:service) { described_class.new(store: store, priority: 'high') }

  describe '#perform' do
    it 'updates store priority' do
      service.perform
      expect(store.reload.priority).to eq('high')
    end

    it 'dispatches priority changed event' do
      # Test event dispatching
    end

    context 'with invalid priority' do
      # Test error handling
    end
  end
end
```

**Request Specs** (`spec/requests/api/v1/accounts/stores_spec.rb`):
```ruby
RSpec.describe 'Api::V1::Accounts::Stores', type: :request do
  describe 'PATCH /api/v1/accounts/:account_id/stores/:id/update_priority' do
    it 'updates store priority successfully' do
      # Test successful priority update
    end

    it 'returns error for invalid priority' do
      # Test validation error handling
    end
  end
end
```

### Frontend Tests

**Component Specs** (`app/javascript/dashboard/components/__tests__/StorePrioritySelector.spec.js`):
```javascript
import { describe, it, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import StorePrioritySelector from '../StorePrioritySelector.vue';

describe('StorePrioritySelector', () => {
  const mockStore = {
    namespaced: true,
    actions: { updatePriority: vi.fn() },
  };

  const store = createStore({ modules: { stores: mockStore } });

  it('renders priority selector', () => {
    // Test component renders correctly
  });

  it('calls updatePriority action on change', async () => {
    // Test action is called with correct params
  });
});
```

### Coverage Goals
- Backend: ≥85% for changed files
- Frontend: ≥80% for new components

---

## Risk Assessment

### Technical Risks

**Risk 1**: Migration fails on large stores table
- **Probability**: Low
- **Impact**: High (blocks deployment)
- **Mitigation**: Test migration on production-like data volume, have rollback plan ready

**Risk 2**: Event dispatcher performance impact
- **Probability**: Low
- **Impact**: Medium
- **Mitigation**: Events are async via Sidekiq, won't block request

**Risk 3**: Frontend state management bugs
- **Probability**: Medium
- **Impact**: Low (affects UI only, backend data is safe)
- **Mitigation**: Comprehensive component tests, manual QA testing

### Business Risks

**Risk 1**: Users confused by new priority field
- **Probability**: Low
- **Impact**: Low
- **Mitigation**: Clear labels, tooltips, documentation

---

## Deployment Plan

### Pre-Deployment Checklist
- [ ] All tests passing (RSpec + Vitest)
- [ ] Code review approved
- [ ] Migration tested on staging
- [ ] i18n verified (en + es)
- [ ] Documentation updated
- [ ] Rollback plan documented

### Deployment Steps
1. Merge feature branch to `develop`
2. Deploy to staging environment
3. Run migrations: `rails db:migrate`
4. Smoke test priority functionality
5. Deploy to production
6. Run migrations in production
7. Monitor logs for errors

### Rollback Plan
```bash
# If issues found in production
rails db:rollback  # Removes priority column
git revert <commit-hash>
# Redeploy previous version
```

---

## Open Questions

1. **Q**: Should we allow filtering stores by priority in the API?
   - **Impact**: Would require additional endpoint parameter
   - **Recommendation**: Yes, add `?priority=high` filter to index endpoint

2. **Q**: Should priority changes create audit log entries?
   - **Impact**: Additional database writes
   - **Recommendation**: Yes if audit trail is critical, otherwise use Rails logger

---

## Next Steps

1. [ ] Get design approval from stakeholders
2. [ ] Create feature branch: `feature/store-priority`
3. [ ] Create execution tracking document from DEVELOPMENT_EXECUTION_TEMPLATE.md
4. [ ] Begin implementation following development_process.md
5. [ ] Schedule code review after implementation

**Estimated Timeline**: 3-4 days
- Backend implementation: 1.5 days
- Frontend implementation: 1 day
- Testing: 0.5 days
- Code review & fixes: 1 day

---

## Related Documentation

- **Architecture**: [docs/ARCHITECTURE.md](../../ARCHITECTURE.md)
- **Development Guidelines**: [CLAUDE.md](../../CLAUDE.md)
- **Development Process**: [../development/development_process.md](../development/development_process.md)
- **Research Report**: [Link to research document]

---

**Last Updated**: YYYY-MM-DD HH:MM:SS
**Updated By**: Claude Code (Anthropic)
**Status**: Draft
