require 'rails_helper'

RSpec.describe 'Rack::Attack cache store' do
  it 'wraps RedisCacheStore with the velma namespace' do
    store = Rack::Attack.cache.store
    redis_cache_store = store.__getobj__

    expect(store).to be_a(Rack::Attack::StoreProxy::RedisCacheStoreProxy)
    expect(redis_cache_store).to be_a(ActiveSupport::Cache::RedisCacheStore)
    expect(redis_cache_store.instance_variable_get(:@options)[:namespace]).to eq('velma')
    expect(redis_cache_store.instance_variable_get(:@redis)).to be_a(ConnectionPool)
  end
end
