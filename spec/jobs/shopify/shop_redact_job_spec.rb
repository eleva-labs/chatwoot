# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::ShopRedactJob, type: :job do
  let(:account) { create(:account) }
  let(:integration_hook) { create(:integrations_hook, app_id: 'shopify', reference_id: shop_domain, account: account) }
  let!(:contact1) { create(:contact, account: account, email: 'customer1@example.com', name: 'Customer One') }
  let!(:contact2) { create(:contact, account: account, email: 'customer2@example.com', name: 'Customer Two') }
  let!(:contact3) { create(:contact, account: account, email: 'customer3@example.com', name: 'Customer Three') }
  let(:shop_domain) { 'test-shop.myshopify.com' }
  let(:payload) do
    {
      'shop_domain' => shop_domain,
      'shop_id' => 12345
    }
  end

  before do
    integration_hook
  end

  describe '#perform' do
    context 'with valid account and contacts' do
      it 'processes shop redaction successfully' do
        expect(Rails.logger).to receive(:info).with(/Processing shop_redact job/)
        expect(Rails.logger).to receive(:info).with(/Successfully processed shop_redact/)
        
        described_class.perform_now(payload)
      end
      
      it 'redacts all contacts in the account' do
        # Set different phone numbers to test international support
        contact1.update!(phone_number: '+447700123456') # UK number
        contact2.update!(phone_number: '+12345678901')  # US number  
        contact3.update!(phone_number: '9876543210')    # Local format
        
        described_class.perform_now(payload)

        [contact1, contact2, contact3].each do |contact|
          contact.reload
          expect(contact.redacted_at).to be_present
          expect(contact.name).to eq('Redacted Customer')
          expect(contact.email).to match(/redacted-customer-\d+@redacted\.local/)
          
          # Verify international-friendly phone number format
          if contact == contact1
            expect(contact.phone_number).to match(/^\+44555\d{7}$/)
          elsif contact == contact2
            expect(contact.phone_number).to match(/^\+1555\d{7}$/)
          elsif contact == contact3
            expect(contact.phone_number).to match(/^REDACTED-\d{8}$/)
          end
        end
      end
      
      it 'disables the integration hook' do
        described_class.perform_now(payload)
        
        integration_hook.reload
        expect(integration_hook.status).to eq('disabled')
        expect(integration_hook.settings['redacted_at']).to be_present
        expect(integration_hook.settings['redaction_reason']).to eq('shopify_shop_redact_webhook')
      end
      
      it 'preserves conversation history for all contacts' do
        conversation1 = create(:conversation, contact: contact1, account: account)
        conversation2 = create(:conversation, contact: contact2, account: account)
        message1 = create(:message, conversation: conversation1, content: 'Hello Customer One!')
        message2 = create(:message, conversation: conversation2, content: 'Hello Customer Two!')
        
        described_class.perform_now(payload)
        
        [conversation1, conversation2].each do |conversation|
          conversation.reload
          expect(conversation.additional_attributes['contact_redacted_at']).to be_present
          expect(conversation.additional_attributes['original_contact_info']['redaction_reason']).to eq('shop_wide_privacy_compliance')
        end
        
        # Messages should still exist with original content
        [message1, message2].each(&:reload)
        expect(message1.content).to eq('Hello Customer One!')
        expect(message2.content).to eq('Hello Customer Two!')
      end
      
      it 'adds system messages to all conversations' do
        conversation1 = create(:conversation, contact: contact1, account: account)
        conversation2 = create(:conversation, contact: contact2, account: account)
        
        initial_message_count = account.conversations.joins(:messages).count
        
        described_class.perform_now(payload)
        
        final_message_count = account.conversations.joins(:messages).count
        expect(final_message_count).to eq(initial_message_count + 2) # One system message per conversation
        
        [conversation1, conversation2].each do |conversation|
          conversation.reload
          redaction_message = conversation.messages.where(message_type: 'activity').last
          expect(redaction_message.content).to include('Shop data has been redacted due to app uninstallation')
          expect(redaction_message.content_attributes['redaction_scope']).to eq('shop_wide')
        end
      end
      
      it 'generates compliance report' do
        allow(Rails.logger).to receive(:info)
        
        described_class.perform_now(payload)
        
        expect(Rails.logger).to have_received(:info).with(/Compliance report generated/)
      end
      
      it 'processes contacts in batches' do
        # Simulate large number of contacts by stubbing batch size
        allow_any_instance_of(described_class).to receive(:get_redaction_batch_size).and_return(2)
        
        expect(Rails.logger).to receive(:info).with(/Starting batch redaction process/)
        expect(Rails.logger).to receive(:info).with(/Processing redaction batch/).at_least(2).times
        expect(Rails.logger).to receive(:info).with(/Batch redaction process completed/)
        
        described_class.perform_now(payload)
      end
    end

    context 'when shop is already redacted' do
      before do
        integration_hook.update!(
          settings: { 'redacted_at' => 1.day.ago.iso8601 }
        )
      end
      
      it 'skips redaction and logs appropriately' do
        expect(Rails.logger).to receive(:info).with(/Shop already redacted/)
        
        described_class.perform_now(payload)
        
        # Contacts should not be modified
        account.contacts.reload.each do |contact|
          expect(contact.redacted_at).to be_nil
        end
      end
    end

    context 'when account not found' do
      before do
        integration_hook.destroy
      end
      
      it 'logs warning and completes without error' do
        expect(Rails.logger).to receive(:warn).with(/Account not found for shop_domain/)
        
        expect { described_class.perform_now(payload) }.not_to raise_error
      end
    end

    context 'when integration hook not found for shop redaction' do
      before do
        integration_hook.update!(reference_id: 'different-shop.myshopify.com')
      end
      
      it 'logs error and returns early' do
        expect(Rails.logger).to receive(:error).with(/Invalid shop redaction request/)
        
        described_class.perform_now(payload)
        
        # Contacts should not be modified
        account.contacts.reload.each do |contact|
          expect(contact.redacted_at).to be_nil
        end
      end
    end

    context 'with some contacts already redacted' do
      before do
        contact1.update!(redacted_at: 1.day.ago)
      end
      
      it 'only redacts non-redacted contacts' do
        described_class.perform_now(payload)
        
        contact1.reload
        contact2.reload
        contact3.reload
        
        # Contact1 should remain unchanged (already redacted)
        expect(contact1.redacted_at).to be < 1.hour.ago
        
        # Contact2 and Contact3 should be newly redacted
        expect(contact2.redacted_at).to be > 1.minute.ago
        expect(contact3.redacted_at).to be > 1.minute.ago
      end
      
      it 'reports correct redaction counts' do
        allow(Rails.logger).to receive(:info)
        
        described_class.perform_now(payload)
        
        # Should log that only 2 contacts were found for redaction
        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            contacts_to_redact: 2,
            already_redacted: 1
          )
        )
      end
    end

    context 'with system contacts' do
      let!(:system_contact) do
        create(:contact, 
               account: account, 
               email: 'shopify-compliance@system.local', 
               name: 'Shopify Compliance System')
      end
      
      it 'excludes system contacts from redaction' do
        described_class.perform_now(payload)
        
        system_contact.reload
        expect(system_contact.redacted_at).to be_nil
        expect(system_contact.email).to eq('shopify-compliance@system.local')
        
        # Regular contacts should still be redacted
        [contact1, contact2, contact3].each do |contact|
          contact.reload
          expect(contact.redacted_at).to be_present
        end
      end
    end

    context 'when batch processing fails for some contacts' do
      before do
        # Simulate failure on contact2
        allow(Contact).to receive(:transaction) do |&block|
          if @current_contact&.id == contact2.id
            raise ActiveRecord::RecordInvalid.new(contact2)
          else
            Contact.connection.transaction(&block)
          end
        end
        
        allow_any_instance_of(described_class).to receive(:redact_single_contact) do |job, contact|
          @current_contact = contact
          job.send(:redact_single_contact_original, contact, account)
        end
        
        # Store original method
        allow_any_instance_of(described_class).to receive(:redact_single_contact_original) do |job, contact, account|
          job.class.superclass.instance_method(:redact_single_contact).bind(job).call(contact, account)
        end
      end
      
      it 'logs failures but continues processing other contacts' do
        expect(Rails.logger).to receive(:error).with(/Failed to redact contact in batch/)
        
        described_class.perform_now(payload)
        
        # Contact2 should fail, but Contact1 and Contact3 should succeed
        contact1.reload
        contact3.reload
        expect(contact1.redacted_at).to be_present
        expect(contact3.redacted_at).to be_present
      end
      
      it 'reports failure rate' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        
        described_class.perform_now(payload)
        
        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            total_failed: 1,
            success_rate: be_within(1).of(67) # 2 out of 3 succeeded
          )
        )
      end
    end

    it 'preserves conversation history while anonymizing contacts' do
      # Create conversations for testing
      conversation1 = create(:conversation, account: account, contact: contact1)
      conversation2 = create(:conversation, account: account, contact: contact2)
      
      described_class.perform_now(payload)

      # Verify conversations still exist and are linked to anonymized contacts
      [conversation1, conversation2].each do |conversation|
        conversation.reload
        expect(conversation.contact).to be_present
        expect(conversation.contact.redacted_at).to be_present
        expect(conversation.additional_attributes['contact_redacted_at']).to be_present
      end
    end
  end

  describe 'batch processing configuration' do
    it 'uses configurable batch size' do
      allow(ENV).to receive(:fetch).with('SHOPIFY_REDACTION_BATCH_SIZE', 50).and_return('25')
      
      job = described_class.new
      expect(job.send(:get_redaction_batch_size)).to eq(25)
    end
    
    it 'defaults to 50 if not configured' do
      allow(ENV).to receive(:fetch).with('SHOPIFY_REDACTION_BATCH_SIZE', 50).and_return(50)
      
      job = described_class.new
      expect(job.send(:get_redaction_batch_size)).to eq(50)
    end
  end

  describe 'integration hook validation' do
    it 'validates shop redaction request correctly' do
      job = described_class.new
      job.instance_variable_set(:@payload, payload.with_indifferent_access)
      
      result = job.send(:validate_shop_redaction_request, account, payload['shop_id'], payload['shop_domain'])
      expect(result).to be true
    end
    
    it 'fails validation when hook not found' do
      job = described_class.new
      job.instance_variable_set(:@payload, payload.with_indifferent_access)
      
      result = job.send(:validate_shop_redaction_request, account, payload['shop_id'], 'nonexistent-shop.myshopify.com')
      expect(result).to be false
    end
  end

  describe 'health monitoring' do
    it 'provides health report' do
      # Create additional test data
      create(:integrations_hook, app_id: 'shopify', settings: { 'compliance_webhooks_subscribed' => 'true' })
      create(:integrations_hook, app_id: 'shopify', settings: { 'redacted_at' => Time.current.iso8601 })
      
      report = described_class.webhook_subscription_health_report
      
      expect(report).to include(:total_hooks, :successful_subscriptions, :redacted_shops, :success_rate)
      expect(report[:total_hooks]).to be > 0
    end
  end

  describe 'job timeout configuration' do
    it 'has longer timeout for bulk operations' do
      # Check that timeout is configured to 600 seconds (10 minutes)
      expect(described_class.around_perform_callbacks.any? { |callback|
        callback.filter.to_s.include?('600')
      }).to be true
    end
  end
end 