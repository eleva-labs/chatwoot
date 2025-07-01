# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::CustomersRedactJob, type: :job do
  let(:account) { create(:account) }
  let(:integration_hook) { create(:integrations_hook, app_id: 'shopify', reference_id: shop_domain, account: account) }
  let(:contact) { create(:contact, account: account, email: customer_email, name: 'John Doe', phone_number: '+1234567890') }
  let(:shop_domain) { 'test-shop.myshopify.com' }
  let(:customer_email) { 'john@example.com' }
  let(:payload) do
    {
      'shop_domain' => shop_domain,
      'customer' => {
        'id' => 123,
        'email' => customer_email,
        'phone' => '+1234567890'
      },
      'orders_to_redact' => [456, 789]
    }
  end

  before do
    integration_hook
    contact
  end

  describe '#perform' do
    context 'with valid account and contact' do
      it 'processes redaction request successfully' do
        expect(Rails.logger).to receive(:info).with(/Processing customers_redact job/)
        expect(Rails.logger).to receive(:info).with(/Successfully processed customers_redact/)
        
        described_class.perform_now(payload)
      end
      
      it 'anonymizes contact PII data correctly' do
        perform_job

        contact.reload
        expect(contact.redacted_at).to be_present
        expect(contact.name).to eq('Redacted Customer')
        expect(contact.email).to eq("redacted-customer-#{contact.id}@redacted.local")
        
        # Test international-friendly phone number format
        if contact.phone_number.present?
          # Should preserve country code or use fallback format
          expect(contact.phone_number).to match(/(\+\d{1,3}555\d{7}|REDACTED-\d{8})/)
        end
        
        expect(contact.custom_attributes['redaction_performed_at']).to be_present
        expect(contact.custom_attributes['redaction_reason']).to eq('shopify_customer_redact_webhook')
      end

      it 'preserves original country code in phone number' do
        # Test with UK phone number
        contact.update!(phone_number: '+447700123456')
        
        perform_job
        contact.reload
        
        expect(contact.phone_number).to match(/^\+44555\d{7}$/)
        expect(contact.phone_number).to include(contact.id.to_s.rjust(7, '0'))
      end

      it 'handles phone numbers without country code' do
        # Test with local format number
        contact.update!(phone_number: '1234567890')
        
        perform_job
        contact.reload
        
        expect(contact.phone_number).to match(/^REDACTED-\d{8}$/)
        expect(contact.phone_number).to include(contact.id.to_s.rjust(8, '0'))
      end

      it 'handles international numbers without plus prefix' do
        # Test with international number missing + prefix
        contact.update!(phone_number: '447700123456')
        
        perform_job
        contact.reload
        
        expect(contact.phone_number).to match(/^\+44555\d{7}$/)
      end
      
      it 'preserves conversation history' do
        conversation = create(:conversation, contact: contact, account: account)
        message = create(:message, conversation: conversation, content: 'Hello John!')
        
        described_class.perform_now(payload)
        
        contact.reload
        conversation.reload
        message.reload
        
        # Contact is anonymized but conversation still exists
        expect(contact.conversations).to include(conversation)
        expect(conversation.additional_attributes['contact_redacted_at']).to be_present
        expect(message.content).to eq('Hello John!') # Historical data preserved
      end
      
      it 'adds system message about redaction' do
        conversation = create(:conversation, contact: contact, account: account)
        
        expect { described_class.perform_now(payload) }
          .to change { conversation.reload.messages.count }.by(1)
        
        redaction_message = conversation.messages.last
        expect(redaction_message.content).to include('redacted for privacy compliance')
        expect(redaction_message.message_type).to eq('activity')
        expect(redaction_message.private?).to be true
      end
      
      it 'creates audit trail' do
        described_class.perform_now(payload)
        
        contact.reload
        expect(contact.custom_attributes['redaction_performed_at']).to be_present
        expect(contact.custom_attributes['redaction_reason']).to eq('shopify_customer_redact_webhook')
      end
    end

    context 'when contact is already redacted' do
      before do
        contact.update!(redacted_at: 1.day.ago)
      end
      
      it 'skips redaction and logs appropriately' do
        expect(Rails.logger).to receive(:info).with(/Contact already redacted, skipping/)
        
        described_class.perform_now(payload)
      end
      
      it 'does not modify already redacted contact' do
        original_redacted_at = contact.redacted_at
        
        described_class.perform_now(payload)
        
        contact.reload
        expect(contact.redacted_at).to eq(original_redacted_at)
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

    context 'when contact not found' do
      before do
        contact.destroy
      end
      
      it 'logs redaction attempt for compliance' do
        expect(Rails.logger).to receive(:info).with(/Redaction attempted for non-existent contact/)
        
        described_class.perform_now(payload)
      end
    end

    context 'with contact under legal hold' do
      before do
        contact.update!(
          custom_attributes: { 'legal_hold_active' => 'true', 'legal_hold_reason' => 'litigation' }
        )
      end
      
      it 'defers redaction instead of processing' do
        described_class.perform_now(payload)
        
        contact.reload
        expect(contact.redacted_at).to be_nil
        expect(contact.custom_attributes['redaction_deferred']).to be true
        expect(contact.custom_attributes['redaction_deferred_reason']).to eq('legal_hold')
      end
    end
  end

  describe 'contact identification' do
    it 'finds contact by Shopify customer ID' do
      contact.update!(custom_attributes: { 'shopify_customer_id' => '123' })
      
      job = described_class.new
      job.instance_variable_set(:@payload, payload.with_indifferent_access)
      
      found_contact = job.send(:find_contact_by_shopify_id, account, '123')
      expect(found_contact).to eq(contact)
    end
    
    it 'finds contact by email as fallback' do
      job = described_class.new
      job.instance_variable_set(:@payload, payload.with_indifferent_access)
      
      found_contact = job.send(:find_contact_by_email, account, customer_email)
      expect(found_contact).to eq(contact)
    end
  end

  describe 'custom attributes redaction' do
    it 'redacts PII attributes' do
      contact.update!(
        custom_attributes: {
          'full_name' => 'John Alexander Doe',
          'birthday' => '1990-01-01',
          'system_id' => 'SYS123',
          'source' => 'shopify'
        }
      )
      
      job = described_class.new
      result = job.send(:redact_custom_attributes, contact.custom_attributes)
      
      expect(result['full_name']).to eq('[redacted]')
      expect(result['birthday']).to eq('[redacted]')
      expect(result['system_id']).to eq('SYS123') # Preserved
      expect(result['source']).to eq('shopify') # Preserved
    end
  end

  describe 'redaction integrity verification' do
    it 'verifies contact anonymization' do
      contact.update!(
        name: 'Redacted Customer',
        email: 'redacted-customer-123@redacted.local',
        phone_number: 'redacted',
        redacted_at: Time.current
      )
      
      job = described_class.new
      result = job.send(:verify_contact_anonymization, contact)
      
      expect(result).to be true
    end
    
    it 'fails verification for incomplete anonymization' do
      contact.update!(name: 'John Doe') # Not properly anonymized
      
      job = described_class.new
      result = job.send(:verify_contact_anonymization, contact)
      
      expect(result).to be false
    end
  end

  describe 'job error handling' do
    it 'retries on transient failures' do
      allow_any_instance_of(described_class).to receive(:resolve_account).and_raise(ActiveRecord::ConnectionTimeoutError)
      
      expect(described_class).to receive(:retry_on).with(StandardError, anything)
      
      # This test verifies the retry configuration exists
      described_class.new
    end
  end
end 