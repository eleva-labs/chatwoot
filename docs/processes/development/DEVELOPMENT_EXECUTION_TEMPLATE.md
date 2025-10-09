# [Feature Name] - Execution Plan

**IMPORTANT**: This document MUST be created in `/docs/ignored/development/<feature_name>_execution.md`

**Session ID**: <uuid-or-timestamp>
**Created**: YYYY-MM-DD HH:MM:SS
**Started**: Not started | YYYY-MM-DD HH:MM:SS
**Completed**: In Progress | YYYY-MM-DD HH:MM:SS
**Status**: Not Started | In Progress | Completed | Blocked | Paused
**Design Doc**: [Link to design document](/docs/ignored/design/feature_name_design.md)
**Related Request**: <user request summary>

---

## Progress Overview

```
Phase 1: Models & Migrations    [░░░░░░░░] 0/4 (0%)
Phase 2: Services & Logic       [░░░░░░░░] 0/3 (0%)
Phase 3: Controllers & API      [░░░░░░░░] 0/4 (0%)
Phase 4: Jobs & Background      [░░░░░░░░] 0/2 (0%)
Phase 5: Frontend (Vue.js)      [░░░░░░░░] 0/5 (0%)
Phase 6: Testing                [░░░░░░░░] 0/4 (0%)

Overall Progress: ░░░░░░░░░░░░░░░░░░░░ 0/22 (0%)
```

**Legend**:
- ✅ Completed
- 🔄 In Progress
- ⏸️ Blocked
- ❌ Failed
- ░ Not Started

---

## Quick Navigation

- [Phase 1: Models & Migrations](#phase-1-models--migrations)
- [Phase 2: Services & Logic](#phase-2-services--logic)
- [Phase 3: Controllers & API](#phase-3-controllers--api)
- [Phase 4: Jobs & Background Processing](#phase-4-jobs--background-processing)
- [Phase 5: Frontend (Vue.js)](#phase-5-frontend-vuejs)
- [Phase 6: Testing](#phase-6-testing)
- [Issues & Blockers](#issues--blockers)
- [Comments & Notes](#comments--notes)
- [Completion Checklist](#completion-checklist)

---

## Phase 1: Models & Migrations

**Goal**: Update database schema and ActiveRecord models
**Status**: [ ] Not Started

---

### Task 1.1: Create Database Migration

**Status**: [ ] Not Started

**Files**:
- `db/migrate/YYYYMMDDHHMMSS_migration_name.rb`

**Subtasks**:
- [ ] Generate migration file
- [ ] Implement `change` method (or `up`/`down`)
- [ ] Add indexes for foreign keys and queried columns
- [ ] Add default values if needed
- [ ] Test migration is reversible

**Expected Changes**:
```ruby
# db/migrate/20251006120000_add_priority_to_stores.rb
class AddPriorityToStores < ActiveRecord::Migration[7.1]
  def change
    add_column :stores, :priority, :integer, default: 1, null: false
    add_index :stores, :priority
  end
end
```

**Verification**:
```bash
# Run migration
rails db:migrate

# Verify migration ran
rails db:migrate:status

# Test rollback
rails db:rollback

# Re-run migration
rails db:migrate
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 1.2: Update ActiveRecord Model

**Status**: [ ] Not Started

**Files**:
- `app/models/model_name.rb`

**Subtasks**:
- [ ] Add validations for new fields
- [ ] Add associations if needed
- [ ] Add scopes for common queries
- [ ] Add enums if applicable
- [ ] Update model methods
- [ ] Add comments for complex logic

**Expected Changes**:
```ruby
# app/models/store.rb
class Store < ApplicationRecord
  # Associations
  belongs_to :account
  has_many :conversations

  # Enums (if adding enum field)
  enum priority: { low: 0, medium: 1, high: 2 }

  # Validations
  validates :name, presence: true
  validates :priority, presence: true, inclusion: { in: priorities.keys }
  validates :phone_number, phone: { allow_blank: true }

  # Scopes
  scope :high_priority, -> { where(priority: :high) }
  scope :active, -> { where(archived: false) }

  # Instance methods
  def display_name
    name || "Unnamed Store"
  end
end
```

**Verification**:
```bash
# Rails console test
rails console
> Store.create(name: "Test", priority: :high)
> Store.high_priority.count
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 1.3: Update Model Specs

**Status**: [ ] Not Started

**Files**:
- `spec/models/model_name_spec.rb`

**Subtasks**:
- [ ] Add tests for new validations
- [ ] Add tests for new associations
- [ ] Add tests for new scopes
- [ ] Add tests for new methods
- [ ] Add tests for enum values (if applicable)

**Expected Changes**:
```ruby
# spec/models/store_spec.rb
RSpec.describe Store, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:priority) }
    it { should validate_inclusion_of(:priority).in_array(Store.priorities.keys) }
  end

  describe 'associations' do
    it { should belong_to(:account) }
    it { should have_many(:conversations) }
  end

  describe 'enums' do
    it { should define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2) }
  end

  describe 'scopes' do
    describe '.high_priority' do
      let!(:high_store) { create(:store, priority: :high) }
      let!(:low_store) { create(:store, priority: :low) }

      it 'returns only high priority stores' do
        expect(Store.high_priority).to include(high_store)
        expect(Store.high_priority).not_to include(low_store)
      end
    end
  end

  describe '#display_name' do
    it 'returns name when present' do
      store = build(:store, name: 'Test Store')
      expect(store.display_name).to eq('Test Store')
    end

    it 'returns default when name is nil' do
      store = build(:store, name: nil)
      expect(store.display_name).to eq('Unnamed Store')
    end
  end
end
```

**Verification**:
```bash
bundle exec rspec spec/models/store_spec.rb
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 1.4: Check Enterprise Edition Impact

**Status**: [ ] Not Started

**Files**:
- Check `enterprise/app/models/` for corresponding model

**Subtasks**:
- [ ] Search for enterprise overlay of this model
- [ ] Ensure changes are compatible with enterprise extensions
- [ ] Update enterprise model if needed
- [ ] Update enterprise specs if needed

**Verification**:
```bash
# Search for enterprise model
find enterprise/app/models -name "*model_name*"

# Search for prepend_mod_with usage
grep -r "prepend_mod_with" app/models/model_name.rb
```

**Notes**:
<!-- Add implementation notes here -->

---

## Phase 2: Services & Logic

**Goal**: Implement business logic in service objects
**Status**: [ ] Not Started

---

### Task 2.1: Create/Update Service Object

**Status**: [ ] Not Started

**Files**:
- `app/services/domain/action_service.rb`

**Subtasks**:
- [ ] Create service class with `initialize` and `perform` methods
- [ ] Inject dependencies via `initialize`
- [ ] Implement business logic in `perform`
- [ ] Add error handling with custom exceptions
- [ ] Dispatch events if needed
- [ ] Add logging for debugging

**Expected Changes**:
```ruby
# app/services/stores/create_service.rb
class Stores::CreateService
  def initialize(account:, params:, user: nil)
    @account = account
    @params = params
    @user = user
  end

  def perform
    store = @account.stores.build(store_params)

    ActiveRecord::Base.transaction do
      if store.save
        dispatch_store_created_event(store)
        Rails.logger.info("Store created: #{store.id} by user: #{@user&.id}")
        store
      else
        raise ActiveRecord::RecordInvalid, store
      end
    end
  rescue StandardError => e
    Rails.logger.error("Store creation failed: #{e.message}")
    raise
  end

  private

  def store_params
    @params.permit(:name, :phone_number, :priority, :email)
  end

  def dispatch_store_created_event(store)
    Rails.configuration.dispatcher.dispatch(
      STORE_CREATED,
      Time.zone.now,
      store: store,
      user: @user
    )
  end
end
```

**Verification**:
```bash
# Rails console test
rails console
> service = Stores::CreateService.new(account: Account.first, params: { name: "Test" })
> store = service.perform
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 2.2: Update Service Specs

**Status**: [ ] Not Started

**Files**:
- `spec/services/domain/action_service_spec.rb`

**Subtasks**:
- [ ] Test successful execution
- [ ] Test validation failures
- [ ] Test error scenarios
- [ ] Test event dispatching
- [ ] Test transaction rollback

**Expected Changes**:
```ruby
# spec/services/stores/create_service_spec.rb
RSpec.describe Stores::CreateService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:valid_params) { { name: 'Test Store', priority: 'high' } }
  let(:service) { described_class.new(account: account, params: valid_params, user: user) }

  describe '#perform' do
    it 'creates a store successfully' do
      expect { service.perform }.to change(Store, :count).by(1)
    end

    it 'returns the created store' do
      store = service.perform
      expect(store).to be_persisted
      expect(store.name).to eq('Test Store')
      expect(store.priority).to eq('high')
    end

    it 'dispatches store created event' do
      expect(Rails.configuration.dispatcher).to receive(:dispatch)
        .with(STORE_CREATED, anything, hash_including(store: instance_of(Store)))

      service.perform
    end

    context 'with invalid params' do
      let(:valid_params) { { name: '' } }

      it 'raises RecordInvalid' do
        expect { service.perform }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'does not create a store' do
        expect { service.perform rescue nil }.not_to change(Store, :count)
      end
    end
  end
end
```

**Verification**:
```bash
bundle exec rspec spec/services/stores/create_service_spec.rb
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 2.3: Update Listener (if event-driven)

**Status**: [ ] Not Started

**Files**:
- `app/listeners/listener_name.rb`

**Subtasks**:
- [ ] Create or update listener class
- [ ] Implement event handler methods
- [ ] Add error handling
- [ ] Delegate heavy work to background jobs

**Expected Changes**:
```ruby
# app/listeners/store_listener.rb
class StoreListener < BaseListener
  def store_created(event)
    store = event.data[:store]
    user = event.data[:user]

    # Trigger notifications
    NotificationJob.perform_later(store.id, user&.id)

    # Update analytics
    AnalyticsJob.perform_later('store_created', store.id)

  rescue StandardError => e
    Rails.logger.error("StoreListener error: #{e.message}")
    Sentry.capture_exception(e)
  end

  def store_updated(event)
    # Handle store updates
  end
end
```

**Verification**:
```bash
# Test event dispatch in console
Rails.configuration.dispatcher.dispatch(STORE_CREATED, Time.zone.now, store: Store.first)
```

**Notes**:
<!-- Add implementation notes here -->

---

## Phase 3: Controllers & API

**Goal**: Implement HTTP endpoints and JSON responses
**Status**: [ ] Not Started

---

### Task 3.1: Update API Controller

**Status**: [ ] Not Started

**Files**:
- `app/controllers/api/v1/accounts/resource_controller.rb`

**Subtasks**:
- [ ] Update/add controller actions
- [ ] Add authentication/authorization
- [ ] Use service objects for business logic
- [ ] Use Finder objects for queries
- [ ] Add strong parameters
- [ ] Add error handling
- [ ] Return appropriate HTTP status codes

**Expected Changes**:
```ruby
# app/controllers/api/v1/accounts/stores_controller.rb
class Api::V1::Accounts::StoresController < Api::V1::Accounts::BaseController
  before_action :set_store, only: [:show, :update, :destroy]

  def index
    @stores = StoresFinder.new(Current.account, params).perform
    @stores = @stores.page(params[:page])
  end

  def show
    # @store set by before_action
  end

  def create
    @store = Stores::CreateService.new(
      account: Current.account,
      params: store_params,
      user: Current.user
    ).perform

    render json: @store, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    Stores::UpdateService.new(
      store: @store,
      params: store_params,
      user: Current.user
    ).perform

    render json: @store
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    @store.destroy!
    head :no_content
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

**Verification**:
```bash
# Start server
rails server

# Test with cURL
curl -X GET "http://localhost:3000/api/v1/accounts/1/stores" \
  -H "api_access_token: YOUR_TOKEN"

curl -X POST "http://localhost:3000/api/v1/accounts/1/stores" \
  -H "api_access_token: YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Store", "priority": "high"}'
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 3.2: Update Jbuilder Views

**Status**: [ ] Not Started

**Files**:
- `app/views/api/v1/accounts/resources/index.json.jbuilder`
- `app/views/api/v1/accounts/resources/show.json.jbuilder`

**Subtasks**:
- [ ] Update JSON response structure
- [ ] Add new fields to response
- [ ] Use camelCase for field names
- [ ] Add pagination metadata
- [ ] Ensure sensitive data is not exposed

**Expected Changes**:
```ruby
# app/views/api/v1/accounts/stores/show.json.jbuilder
json.id @store.id
json.name @store.name
json.phoneNumber @store.phone_number
json.priority @store.priority
json.email @store.email
json.createdAt @store.created_at
json.updatedAt @store.updated_at

# app/views/api/v1/accounts/stores/index.json.jbuilder
json.payload do
  json.array! @stores do |store|
    json.partial! 'api/v1/accounts/stores/store', store: store
  end
end

json.meta do
  json.currentPage @stores.current_page
  json.totalPages @stores.total_pages
  json.totalCount @stores.total_count
end
```

**Verification**:
```bash
# Test JSON response
curl -X GET "http://localhost:3000/api/v1/accounts/1/stores/1.json" | python -m json.tool
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 3.3: Update Routes

**Status**: [ ] Not Started

**Files**:
- `config/routes.rb`

**Subtasks**:
- [ ] Add/update resource routes
- [ ] Add custom routes if needed
- [ ] Ensure routes are namespaced correctly
- [ ] Verify no route conflicts

**Expected Changes**:
```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :accounts do
      resources :stores do
        # Custom routes if needed
        member do
          post :archive
        end
      end
    end
  end
end
```

**Verification**:
```bash
# View routes
rails routes | grep stores

# Check specific route
rails routes | grep "api/v1/accounts/stores"
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 3.4: Update Request Specs

**Status**: [ ] Not Started

**Files**:
- `spec/requests/api/v1/accounts/resources_spec.rb`

**Subtasks**:
- [ ] Test all CRUD operations
- [ ] Test authentication/authorization
- [ ] Test validation errors
- [ ] Test edge cases
- [ ] Test JSON response structure

**Expected Changes**:
```ruby
# spec/requests/api/v1/accounts/stores_spec.rb
RSpec.describe 'Api::V1::Accounts::Stores', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:token) { user.create_token.token }
  let(:headers) { { 'api_access_token' => token } }

  describe 'GET /api/v1/accounts/:account_id/stores' do
    before do
      create_list(:store, 3, account: account)
    end

    it 'returns list of stores' do
      get "/api/v1/accounts/#{account.id}/stores", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['payload'].size).to eq(3)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/stores' do
    let(:valid_params) { { name: 'Test Store', priority: 'high' } }

    it 'creates a new store' do
      expect {
        post "/api/v1/accounts/#{account.id}/stores",
             params: valid_params,
             headers: headers
      }.to change(Store, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('Test Store')
      expect(json['priority']).to eq('high')
    end

    context 'with invalid params' do
      let(:valid_params) { { name: '' } }

      it 'returns validation errors' do
        post "/api/v1/accounts/#{account.id}/stores",
             params: valid_params,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end
    end
  end
end
```

**Verification**:
```bash
bundle exec rspec spec/requests/api/v1/accounts/stores_spec.rb --format documentation
```

**Notes**:
<!-- Add implementation notes here -->

---

## Phase 4: Jobs & Background Processing

**Goal**: Implement asynchronous tasks
**Status**: [ ] Not Started

---

### Task 4.1: Create Background Job

**Status**: [ ] Not Started

**Files**:
- `app/jobs/domain/action_job.rb`

**Subtasks**:
- [ ] Create job class inheriting from ApplicationJob
- [ ] Set queue name
- [ ] Implement perform method
- [ ] Add error handling and retry logic
- [ ] Ensure job is idempotent

**Expected Changes**:
```ruby
# app/jobs/stores/notification_job.rb
class Stores::NotificationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(store_id, user_id = nil)
    store = Store.find(store_id)
    user = User.find_by(id: user_id)

    # Send notification to team members
    store.account.users.each do |team_member|
      NotificationMailer.store_created(store, team_member).deliver_later
    end

    # Update metrics
    Analytics.track('store_created', store_id: store.id)

  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("NotificationJob: Record not found - #{e.message}")
    # Don't retry if record doesn't exist
  end
end
```

**Verification**:
```bash
# Rails console test
rails console
> Stores::NotificationJob.perform_later(Store.first.id)

# Check Sidekiq dashboard
open http://localhost:3000/sidekiq
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 4.2: Update Job Specs

**Status**: [ ] Not Started

**Files**:
- `spec/jobs/domain/action_job_spec.rb`

**Subtasks**:
- [ ] Test job enqueues successfully
- [ ] Test job performs expected actions
- [ ] Test error handling
- [ ] Test idempotency

**Expected Changes**:
```ruby
# spec/jobs/stores/notification_job_spec.rb
RSpec.describe Stores::NotificationJob, type: :job do
  let(:store) { create(:store) }
  let(:user) { create(:user, account: store.account) }

  describe '#perform' do
    it 'enqueues the job' do
      expect {
        described_class.perform_later(store.id, user.id)
      }.to have_enqueued_job(described_class)
    end

    it 'sends notifications to team members' do
      expect(NotificationMailer).to receive(:store_created).and_call_original

      described_class.perform_now(store.id, user.id)
    end

    it 'tracks analytics event' do
      expect(Analytics).to receive(:track).with('store_created', hash_including(store_id: store.id))

      described_class.perform_now(store.id, user.id)
    end

    context 'when store not found' do
      it 'logs error and does not retry' do
        expect(Rails.logger).to receive(:error).with(/Record not found/)

        described_class.perform_now(0, user.id)
      end
    end
  end
end
```

**Verification**:
```bash
bundle exec rspec spec/jobs/stores/notification_job_spec.rb
```

**Notes**:
<!-- Add implementation notes here -->

---

## Phase 5: Frontend (Vue.js)

**Goal**: Implement UI components and frontend logic
**Status**: [ ] Not Started

---

### Task 5.1: Update Vue Component

**Status**: [ ] Not Started

**Files**:
- `app/javascript/dashboard/components/ComponentName.vue`

**Subtasks**:
- [ ] Create/update component using Composition API
- [ ] Use Tailwind CSS only (no custom CSS)
- [ ] Add i18n keys (en.json + es.json)
- [ ] Add component logic
- [ ] Add event handlers
- [ ] Ensure accessibility

**Expected Changes**:
```vue
<!-- app/javascript/dashboard/components/StoreDetails.vue -->
<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

const store = useStore();
const { t } = useI18n();

const props = defineProps({
  storeId: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['update', 'close']);

const isLoading = ref(false);
const storeData = computed(() => store.getters['stores/getStore'](props.storeId));

const priorities = ['low', 'medium', 'high'];

const handleUpdate = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('stores/update', {
      id: props.storeId,
      data: storeData.value,
    });
    emit('update');
  } catch (error) {
    console.error('Update failed:', error);
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-4 p-4">
    <h2 class="text-lg font-semibold text-gray-900">
      {{ t('STORE.DETAILS_TITLE') }}
    </h2>

    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-gray-700">
        {{ t('STORE.NAME') }}
      </label>
      <input
        v-model="storeData.name"
        class="border border-gray-300 rounded px-3 py-2 focus:ring-2 focus:ring-blue-500"
        type="text"
      />
    </div>

    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-gray-700">
        {{ t('STORE.PRIORITY') }}
      </label>
      <select
        v-model="storeData.priority"
        class="border border-gray-300 rounded px-3 py-2 focus:ring-2 focus:ring-blue-500"
      >
        <option v-for="priority in priorities" :key="priority" :value="priority">
          {{ t(`STORE.PRIORITY_${priority.toUpperCase()}`) }}
        </option>
      </select>
    </div>

    <div class="flex gap-2 mt-4">
      <button
        @click="handleUpdate"
        :disabled="isLoading"
        class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {{ isLoading ? t('STORE.UPDATING') : t('STORE.UPDATE') }}
      </button>
      <button
        @click="emit('close')"
        class="bg-gray-200 text-gray-800 px-4 py-2 rounded hover:bg-gray-300"
      >
        {{ t('STORE.CANCEL') }}
      </button>
    </div>
  </div>
</template>
```

**Verification**:
```bash
# Component will be tested in browser after starting dev server
pnpm dev
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 5.2: Update Vuex Store Module

**Status**: [ ] Not Started

**Files**:
- `app/javascript/dashboard/store/modules/stores.js`

**Subtasks**:
- [ ] Add state properties
- [ ] Add getters
- [ ] Add actions (API calls)
- [ ] Add mutations (state updates)
- [ ] Add error handling

**Expected Changes**:
```javascript
// app/javascript/dashboard/store/modules/stores.js
import StoresAPI from '../../api/stores';

export default {
  namespaced: true,

  state: {
    records: [],
    currentStore: null,
    uiFlags: {
      isFetching: false,
      isCreating: false,
      isUpdating: false,
    },
  },

  getters: {
    getStores: (state) => state.records,
    getStore: (state) => (id) => state.records.find(s => s.id === id),
    getCurrentStore: (state) => state.currentStore,
    getUIFlags: (state) => state.uiFlags,
  },

  actions: {
    async fetchStores({ commit }, params) {
      commit('setFetching', true);
      try {
        const response = await StoresAPI.getAll(params);
        commit('setStores', response.data.payload);
      } catch (error) {
        console.error('Fetch stores failed:', error);
        throw error;
      } finally {
        commit('setFetching', false);
      }
    },

    async createStore({ commit }, storeData) {
      commit('setCreating', true);
      try {
        const response = await StoresAPI.create(storeData);
        commit('addStore', response.data);
        return response.data;
      } catch (error) {
        console.error('Create store failed:', error);
        throw error;
      } finally {
        commit('setCreating', false);
      }
    },

    async updateStore({ commit }, { id, data }) {
      commit('setUpdating', true);
      try {
        const response = await StoresAPI.update(id, data);
        commit('updateStore', response.data);
        return response.data;
      } catch (error) {
        console.error('Update store failed:', error);
        throw error;
      } finally {
        commit('setUpdating', false);
      }
    },
  },

  mutations: {
    setStores(state, stores) {
      state.records = stores;
    },

    addStore(state, store) {
      state.records.push(store);
    },

    updateStore(state, updatedStore) {
      const index = state.records.findIndex(s => s.id === updatedStore.id);
      if (index !== -1) {
        state.records.splice(index, 1, updatedStore);
      }
    },

    setCurrentStore(state, store) {
      state.currentStore = store;
    },

    setFetching(state, value) {
      state.uiFlags.isFetching = value;
    },

    setCreating(state, value) {
      state.uiFlags.isCreating = value;
    },

    setUpdating(state, value) {
      state.uiFlags.isUpdating = value;
    },
  },
};
```

**Verification**:
```bash
# Will be tested via component interaction
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 5.3: Update i18n Translations

**Status**: [ ] Not Started

**Files**:
- `app/javascript/dashboard/i18n/locale/en.json`
- `app/javascript/dashboard/i18n/locale/es.json`
- `config/locales/en.yml` (if backend needs i18n)
- `config/locales/es.yml` (if backend needs i18n)

**Subtasks**:
- [ ] Add English translations (en.json)
- [ ] Add Spanish translations (es.json)
- [ ] Add backend translations if needed (en.yml, es.yml)
- [ ] Verify keys match between languages
- [ ] Ensure no bare strings in components

**Expected Changes**:
```json
// app/javascript/dashboard/i18n/locale/en.json
{
  "STORE": {
    "DETAILS_TITLE": "Store Details",
    "NAME": "Store Name",
    "PRIORITY": "Priority",
    "PRIORITY_LOW": "Low",
    "PRIORITY_MEDIUM": "Medium",
    "PRIORITY_HIGH": "High",
    "UPDATE": "Update Store",
    "UPDATING": "Updating...",
    "CANCEL": "Cancel",
    "CREATE": "Create Store",
    "DELETE": "Delete Store",
    "CONFIRM_DELETE": "Are you sure you want to delete this store?"
  }
}

// app/javascript/dashboard/i18n/locale/es.json
{
  "STORE": {
    "DETAILS_TITLE": "Detalles de la Tienda",
    "NAME": "Nombre de la Tienda",
    "PRIORITY": "Prioridad",
    "PRIORITY_LOW": "Baja",
    "PRIORITY_MEDIUM": "Media",
    "PRIORITY_HIGH": "Alta",
    "UPDATE": "Actualizar Tienda",
    "UPDATING": "Actualizando...",
    "CANCEL": "Cancelar",
    "CREATE": "Crear Tienda",
    "DELETE": "Eliminar Tienda",
    "CONFIRM_DELETE": "¿Está seguro de que desea eliminar esta tienda?"
  }
}
```

**Verification**:
```bash
# Compare keys between en and es
diff <(jq -S . app/javascript/dashboard/i18n/locale/en.json) \
     <(jq -S . app/javascript/dashboard/i18n/locale/es.json)

# Should show only value differences, not key differences
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 5.4: Update API Client

**Status**: [ ] Not Started

**Files**:
- `app/javascript/dashboard/api/stores.js`

**Subtasks**:
- [ ] Create/update API client module
- [ ] Add methods for CRUD operations
- [ ] Handle authentication
- [ ] Handle errors consistently

**Expected Changes**:
```javascript
// app/javascript/dashboard/api/stores.js
import ApiClient from './ApiClient';

class StoresAPI extends ApiClient {
  constructor() {
    super('stores', { accountScoped: true });
  }

  getAll(params = {}) {
    return axios.get(this.url, { params });
  }

  get(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(storeData) {
    return axios.post(this.url, storeData);
  }

  update(id, storeData) {
    return axios.patch(`${this.url}/${id}`, storeData);
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new StoresAPI();
```

**Verification**:
```bash
# Will be tested via Vuex actions
```

**Notes**:
<!-- Add implementation notes here -->

---

### Task 5.5: Write Component Tests

**Status**: [ ] Not Started

**Files**:
- `app/javascript/dashboard/components/__tests__/ComponentName.spec.js`

**Subtasks**:
- [ ] Test component rendering
- [ ] Test user interactions
- [ ] Test prop validation
- [ ] Test event emissions
- [ ] Test Vuex integration

**Expected Changes**:
```javascript
// app/javascript/dashboard/components/__tests__/StoreDetails.spec.js
import { describe, it, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import StoreDetails from '../StoreDetails.vue';

describe('StoreDetails', () => {
  const mockStore = {
    namespaced: true,
    state: {
      records: [
        { id: '1', name: 'Test Store', priority: 'high' },
      ],
    },
    getters: {
      getStore: (state) => (id) => state.records.find(s => s.id === id),
    },
    actions: {
      update: vi.fn(),
    },
  };

  const store = createStore({
    modules: {
      stores: mockStore,
    },
  });

  const createWrapper = (props = {}) => {
    return mount(StoreDetails, {
      props: {
        storeId: '1',
        ...props,
      },
      global: {
        plugins: [store],
        mocks: {
          $t: (key) => key,
        },
      },
    });
  };

  it('renders store details', () => {
    const wrapper = createWrapper();
    expect(wrapper.find('h2').text()).toBe('STORE.DETAILS_TITLE');
    expect(wrapper.find('input').element.value).toBe('Test Store');
  });

  it('emits update event when update button clicked', async () => {
    const wrapper = createWrapper();
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('update')).toBeTruthy();
  });

  it('calls store action on update', async () => {
    const wrapper = createWrapper();
    await wrapper.find('button').trigger('click');
    expect(mockStore.actions.update).toHaveBeenCalled();
  });
});
```

**Verification**:
```bash
pnpm test -- StoreDetails.spec.js
```

**Notes**:
<!-- Add implementation notes here -->

---

## Phase 6: Testing

**Goal**: Ensure comprehensive test coverage
**Status**: [ ] Not Started

---

### Task 6.1: Run Backend Tests

**Status**: [ ] Not Started

**Subtasks**:
- [ ] Run model specs
- [ ] Run service specs
- [ ] Run controller specs
- [ ] Run request specs
- [ ] Run job specs
- [ ] Check test coverage

**Verification**:
```bash
# Run all backend tests
bundle exec rspec

# Run specific test types
bundle exec rspec spec/models
bundle exec rspec spec/services
bundle exec rspec spec/controllers
bundle exec rspec spec/requests
bundle exec rspec spec/jobs

# Run with coverage
bundle exec rspec --format documentation

# Check coverage report
open coverage/index.html
```

**Test Results**:
<!-- Update after running tests -->
- **Total Tests**: X
- **Passed**: X
- **Failed**: X
- **Coverage**: X%

**Notes**:
<!-- Add implementation notes here -->

---

### Task 6.2: Run Frontend Tests

**Status**: [ ] Not Started

**Subtasks**:
- [ ] Run component tests
- [ ] Run Vuex store tests
- [ ] Check test coverage

**Verification**:
```bash
# Run all frontend tests
pnpm test

# Run with coverage
pnpm test:coverage

# Run in watch mode
pnpm test:watch

# Check coverage report
open coverage/index.html
```

**Test Results**:
<!-- Update after running tests -->
- **Total Tests**: X
- **Passed**: X
- **Failed**: X
- **Coverage**: X%

**Notes**:
<!-- Add implementation notes here -->

---

### Task 6.3: Run Linters

**Status**: [ ] Not Started

**Subtasks**:
- [ ] Run RuboCop
- [ ] Run ESLint
- [ ] Fix all linting errors

**Verification**:
```bash
# Backend linting
bundle exec rubocop

# Auto-fix backend issues
bundle exec rubocop -a

# Frontend linting
pnpm eslint

# Auto-fix frontend issues
pnpm eslint:fix
```

**Linting Results**:
<!-- Update after running linters -->
- **RuboCop**: Pass | Fail (X offenses)
- **ESLint**: Pass | Fail (X errors)

**Notes**:
<!-- Add implementation notes here -->

---

### Task 6.4: Manual Testing

**Status**: [ ] Not Started

**Subtasks**:
- [ ] Test happy path in browser
- [ ] Test error scenarios
- [ ] Test edge cases
- [ ] Test on different browsers (Chrome, Firefox, Safari)
- [ ] Test responsive design
- [ ] Test accessibility (keyboard navigation, screen readers)

**Test Scenarios**:
1. [ ] Create new store successfully
2. [ ] Update store with valid data
3. [ ] Attempt to create store with invalid data
4. [ ] Delete store
5. [ ] Test priority dropdown
6. [ ] Test form validation
7. [ ] Test loading states
8. [ ] Test error messages

**Notes**:
<!-- Add manual testing notes here -->

---

## Issues & Blockers

### Issue #1: [Issue Title]

**Status**: Open | In Progress | Resolved | Blocked
**Created**: YYYY-MM-DD HH:MM
**Severity**: 🔴 Critical | 🟡 Major | 🟢 Minor

**Description**:
<!-- Describe the issue -->

**Impact**:
<!-- What tasks are blocked or affected -->

**Related Tasks**:
- Task X.Y: [Task name]

**Root Cause**:
<!-- Analysis of why the issue occurred -->

**Resolution Plan**:
1. Step 1: [Description]
2. Step 2: [Description]

**Resolution**:
<!-- How it was resolved - fill in when resolved -->

**Resolved**: YYYY-MM-DD HH:MM

---

## Comments & Notes

### Implementation Notes

<!-- General notes about the implementation -->

#### Phase 1 Notes
- Note 1: [Description]
- Note 2: [Description]

#### Phase 2 Notes
- Note 1: [Description]
- Note 2: [Description]

---

### Decisions Made

**Decision 1**: [Decision Title]
- **Date**: YYYY-MM-DD
- **Context**: [Why this decision was needed]
- **Decision**: [What was decided]
- **Rationale**: [Why this approach was chosen]
- **Alternatives Considered**: [What else was considered]

**Decision 2**: [Decision Title]
- [Same structure as above]

---

### Items for Later Review

- [ ] Item 1: [Description] - Priority: High | Medium | Low
- [ ] Item 2: [Description] - Priority: High | Medium | Low

---

### Gotchas & Learnings

**Gotcha 1**: [Description]
- **What went wrong**: [Description]
- **How to avoid**: [Lesson learned]

**Gotcha 2**: [Description]
- **What went wrong**: [Description]
- **How to avoid**: [Lesson learned]

---

### Performance Notes

**Observed Performance**:
- Metric 1: [Measurement]
- Metric 2: [Measurement]

**Optimization Opportunities**:
- Opportunity 1: [Description]
- Opportunity 2: [Description]

---

## Completion Checklist

### Definition of Done

- [ ] All tasks completed and marked ✅
- [ ] All tests passing (RSpec + Vitest)
- [ ] Linting passes (RuboCop + ESLint)
- [ ] Code coverage ≥ 80% for changed files
- [ ] Documentation updated (comments, README)
- [ ] API endpoints tested (cURL or request specs)
- [ ] Database migrations tested (up and down)
- [ ] i18n complete (en.json + es.json, en.yml + es.yml)
- [ ] Frontend components use Composition API
- [ ] Only Tailwind CSS used (no custom/scoped/inline styles)
- [ ] No open critical or major issues
- [ ] Code reviewed (if applicable)
- [ ] Enterprise compatibility verified (if applicable)

---

### Final Validation

**Pre-Merge Checklist**:
- [ ] Full test suite passes locally
- [ ] Manual testing completed in browser
- [ ] No regressions identified
- [ ] Performance acceptable
- [ ] Security considerations reviewed
- [ ] Error handling validated
- [ ] Logging adequate for debugging
- [ ] Accessibility tested (keyboard, screen readers)

**Deployment Checklist**:
- [ ] Migration scripts ready
- [ ] Rollback plan documented
- [ ] Database backup taken (if production)
- [ ] Deployment runbook reviewed
- [ ] Team notified of deployment

---

### Code Review Notes

**Reviewer**: [Name]
**Review Date**: YYYY-MM-DD
**Status**: Approved | Changes Requested | Pending

**Feedback**:
- Feedback 1: [Description]
- Feedback 2: [Description]

**Changes Made**:
- Change 1: [Description]
- Change 2: [Description]

---

## Completion Summary

**Completion Date**: YYYY-MM-DD HH:MM:SS
**Total Duration**: X days
**Status**: ✅ Completed Successfully | ⚠️ Completed with Issues | ❌ Incomplete

### What Was Accomplished

1. Accomplishment 1: [Description]
2. Accomplishment 2: [Description]
3. Accomplishment 3: [Description]

### Deviations from Design

**Change 1**: [Description]
- **Reason**: [Why the deviation was necessary]
- **Impact**: [How it affects the system]
- **Approved By**: [Name/Role]

### Known Limitations

1. Limitation 1: [Description]
2. Limitation 2: [Description]

### Recommendations for Future Work

1. Recommendation 1: [Description]
2. Recommendation 2: [Description]

---

**Last Updated**: YYYY-MM-DD HH:MM:SS
**Updated By**: Development Team
