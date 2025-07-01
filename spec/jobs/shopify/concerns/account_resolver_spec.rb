# frozen_string_literal: true

require 'rails_helper'

# Test class to include the concern
class TestJobWithAccountResolver
  include Shopify::Concerns::AccountResolver
  
  attr_accessor :shop_domain, :payload, :job_started_at
  
  def initialize(shop_domain = nil)
    @shop_domain = shop_domain
    @payload = { 'shop_domain' => shop_domain }.with_indifferent_access
    @job_started_at = Time.current
  end
  
  def job_context
    {
      job_class: self.class.name,
      shop_domain: @shop_domain,
      timestamp: Time.current
    }
  end
  
  def self.name
    'TestJobWithAccountResolver'
  end
end

RSpec.describe Shopify::Concerns::AccountResolver do
  let(:test_job) { TestJobWithAccountResolver.new }
  let(:account) { create(:account) }
  let(:shop_domain) { 'test-shop.myshopify.com' }
  let(:short_domain) { 'test-shop' }
  
  let!(:integration_hook) do
    create(:integrations_hook,
           app_id: 'shopify',
           reference_id: shop_domain,
           account: account,
           status: 'enabled')
  end

  describe '#resolve_account' do
    context 'with valid shop domain' do
      it 'resolves account successfully' do
        test_job.shop_domain = shop_domain
        
        expect(Rails.logger).to receive(:debug).with(/Starting account resolution/)
        expect(Rails.logger).to receive(:debug).with(/Resolved account for shop/)
        
        result = test_job.send(:resolve_account, shop_domain)
        expect(result).to eq(account)
      end

      it 'includes comprehensive logging context' do
        test_job.shop_domain = shop_domain
        
        expect(Rails.logger).to receive(:debug).with(hash_including(
          shop_domain: shop_domain,
          job_class: 'TestJobWithAccountResolver'
        ))
        
        expect(Rails.logger).to receive(:debug).with(hash_including(
          account_id: account.id,
          account_name: account.name,
          hook_id: integration_hook.id
        ))
        
        test_job.send(:resolve_account, shop_domain)
      end
    end

    context 'with blank shop domain' do
      it 'returns nil immediately' do
        result = test_job.send(:resolve_account, nil)
        expect(result).to be_nil
        
        result = test_job.send(:resolve_account, '')
        expect(result).to be_nil
      end
    end

    context 'with inactive account' do
      before do
        account.update!(status: 'suspended')
      end

      it 'returns nil for inactive accounts' do
        test_job.shop_domain = shop_domain
        
        result = test_job.send(:resolve_account, shop_domain)
        expect(result).to be_nil
      end
    end

    context 'when primary lookup fails' do
      let(:non_existent_domain) { 'non-existent-shop.myshopify.com' }

      it 'logs debugging information for failed lookups' do
        test_job.shop_domain = non_existent_domain

        expect(Rails.logger).to receive(:warn).with(/No integration hook found for shop domain/)
        expect(Rails.logger).to receive(:warn).with(hash_including(
          requested_domain: non_existent_domain,
          available_shopify_hooks: be_an(Array),
          total_shopify_hooks: be_an(Integer),
          job_class: 'TestJobWithAccountResolver'
        ))
        
        result = test_job.send(:resolve_account, non_existent_domain)
        expect(result).to be_nil
      end
    end

    context 'with normalization fallback' do
      before do
        # Remove the original hook and create one with normalized domain
        integration_hook.destroy
        create(:integrations_hook,
               app_id: 'shopify',
               reference_id: 'test-shop.myshopify.com',
               account: account,
               status: 'enabled')
      end

      it 'resolves using normalized domain fallback' do
        test_job.shop_domain = short_domain

        expect(Rails.logger).to receive(:debug).with(/Starting account resolution/)
        expect(Rails.logger).to receive(:debug).with(/Trying normalized domain fallback/)
        expect(Rails.logger).to receive(:info).with(/Account resolved using normalized domain/)
        expect(Rails.logger).to receive(:debug).with(/Resolved account for shop/)
        
        result = test_job.send(:resolve_account, short_domain)
        expect(result).to eq(account)
      end

      it 'includes normalization context in logs' do
        test_job.shop_domain = short_domain

        expect(Rails.logger).to receive(:debug).with(hash_including(
          original_domain: short_domain,
          normalized_domain: 'test-shop.myshopify.com',
          job_class: 'TestJobWithAccountResolver'
        ))
        
        expect(Rails.logger).to receive(:info).with(hash_including(
          original_domain: short_domain,
          normalized_domain: 'test-shop.myshopify.com',
          hook_id: be_an(Integer)
        ))
        
        test_job.send(:resolve_account, short_domain)
      end
    end

    context 'when errors occur' do
      before do
        allow(Integrations::Hook).to receive(:active).and_raise(StandardError.new('Database connection failed'))
      end

      it 'logs errors and returns nil' do
        test_job.shop_domain = shop_domain

        expect(Rails.logger).to receive(:error).with(/Error resolving account/)
        expect(Rails.logger).to receive(:error).with(hash_including(
          shop_domain: shop_domain,
          error: 'Database connection failed',
          backtrace: be_an(Array),
          job_class: 'TestJobWithAccountResolver'
        ))
        
        result = test_job.send(:resolve_account, shop_domain)
        expect(result).to be_nil
      end
    end
  end

  describe '#find_integration_hook' do
    it 'finds hook by exact domain match' do
      hook = test_job.send(:find_integration_hook, shop_domain)
      expect(hook).to eq(integration_hook)
    end

    it 'tries normalized domain as fallback' do
      integration_hook.destroy
      normalized_hook = create(:integrations_hook,
                               app_id: 'shopify',
                               reference_id: 'test-shop.myshopify.com',
                               account: account,
                               status: 'enabled')

      hook = test_job.send(:find_integration_hook, short_domain)
      expect(hook).to eq(normalized_hook)
    end

    it 'returns nil when no hooks found' do
      hook = test_job.send(:find_integration_hook, 'non-existent-shop.myshopify.com')
      expect(hook).to be_nil
    end

    it 'only finds active hooks' do
      integration_hook.update!(status: 'disabled')
      
      hook = test_job.send(:find_integration_hook, shop_domain)
      expect(hook).to be_nil
    end
  end

  describe '#normalize_shop_domain' do
    it 'adds .myshopify.com to short domains' do
      result = test_job.send(:normalize_shop_domain, 'test-shop')
      expect(result).to eq('test-shop.myshopify.com')
    end

    it 'leaves already normalized domains unchanged' do
      result = test_job.send(:normalize_shop_domain, 'test-shop.myshopify.com')
      expect(result).to eq('test-shop.myshopify.com')
    end

    it 'handles edge cases' do
      expect(test_job.send(:normalize_shop_domain, '')).to eq('.myshopify.com')
      expect(test_job.send(:normalize_shop_domain, 'already.myshopify.com.test')).to eq('already.myshopify.com.test')
    end
  end

  describe '#log_available_hooks_for_debugging' do
    let!(:other_hook) do
      create(:integrations_hook,
             app_id: 'shopify',
             reference_id: 'other-shop.myshopify.com',
             account: create(:account),
             status: 'enabled')
    end

    it 'logs available hooks for debugging' do
      test_job.shop_domain = 'non-existent-shop.myshopify.com'

      expect(Rails.logger).to receive(:warn).with(/No integration hook found for shop domain/)
      expect(Rails.logger).to receive(:warn).with(hash_including(
        requested_domain: 'non-existent-shop.myshopify.com',
        available_shopify_hooks: be_an(Array),
        total_shopify_hooks: 2, # integration_hook + other_hook
        job_class: 'TestJobWithAccountResolver'
      ))
      
      test_job.send(:log_available_hooks_for_debugging, 'non-existent-shop.myshopify.com')
    end

    it 'handles errors gracefully when fetching debug info' do
      allow(Integrations::Hook).to receive(:where).and_raise(StandardError.new('Database error'))

      expect(Rails.logger).to receive(:debug).with(/Could not fetch debug information/)
      expect(Rails.logger).to receive(:debug).with(hash_including(
        error: 'Database error',
        shop_domain: 'test-domain'
      ))
      
      test_job.send(:log_available_hooks_for_debugging, 'test-domain')
    end

    it 'limits the number of hooks in debug output' do
      # Create 10 additional hooks
      10.times do |i|
        create(:integrations_hook,
               app_id: 'shopify',
               reference_id: "shop-#{i}.myshopify.com",
               account: create(:account),
               status: 'enabled')
      end

      expect(Integrations::Hook).to receive(:where).and_call_original
      expect_any_instance_of(ActiveRecord::Relation).to receive(:limit).with(5).and_call_original
      
      test_job.send(:log_available_hooks_for_debugging, 'non-existent-shop.myshopify.com')
    end
  end

  describe '#log_account_not_found' do
    it 'logs enhanced account not found message' do
      test_job.shop_domain = 'missing-shop.myshopify.com'

      expect(test_job).to receive(:job_context).and_return({
        job_class: 'TestJobWithAccountResolver',
        shop_domain: 'missing-shop.myshopify.com'
      })

      expect(Rails.logger).to receive(:warn).with(/Account not found for shop_domain/)
      expect(Rails.logger).to receive(:warn).with(hash_including(
        job_class: 'TestJobWithAccountResolver',
        shop_domain: 'missing-shop.myshopify.com',
        resolution_attempted: true,
        fallback_attempted: true
      ))
      
      test_job.send(:log_account_not_found)
    end
  end

  describe 'concern inclusion' do
    it 'extends ActiveSupport::Concern' do
      expect(Shopify::Concerns::AccountResolver.ancestors).to include(ActiveSupport::Concern)
    end

    it 'adds private methods when included' do
      expect(test_job.private_methods).to include(
        :resolve_account,
        :find_integration_hook,
        :normalize_shop_domain,
        :log_available_hooks_for_debugging,
        :log_account_not_found
      )
    end
  end
end 