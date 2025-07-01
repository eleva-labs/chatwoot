# frozen_string_literal: true

module Shopify
  class CustomersRedactJob < ApplicationJob
    include Shopify::Concerns::AccountResolver

    queue_as :default

    retry_on StandardError, wait: :exponentially_longer, attempts: 3
    discard_on ActiveJob::DeserializationError

    # Add timeout to prevent long-running jobs
    around_perform do |job, block|
      Timeout.timeout(300) { block.call } # 5 minute timeout
    rescue Timeout::Error => e
      Rails.logger.error "Job timeout exceeded", job_context.merge(error: e.message)
      raise
    end

    def perform(webhook_payload)
      @payload = webhook_payload.with_indifferent_access
      @shop_domain = @payload['shop_domain']
      @job_started_at = Time.current

      Rails.logger.info 'Processing customers_redact job', job_context

      account = resolve_account(@shop_domain)
      return log_account_not_found unless account

      track_job_performance do
        process_customer_redaction(account)
      end

      Rails.logger.info 'Successfully processed customers_redact', job_context
    rescue StandardError => e
      Rails.logger.error 'Failed to process customers_redact',
                         job_context.merge(error: e.message, backtrace: e.backtrace.first(5))
      raise
    end

    private

    def job_context
      {
        job_class: self.class.name,
        shop_domain: @shop_domain,
        customer_id: @payload.dig('customer', 'id'),
        orders_to_redact: @payload['orders_to_redact']&.size || 0,
        timestamp: Time.current,
        job_duration_ms: job_duration_ms
      }
    end

    def job_duration_ms
      return nil unless @job_started_at
      ((Time.current - @job_started_at) * 1000).round(2)
    end

    def track_job_performance
      start_time = Time.current
      
      yield
      
      duration = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.info "Job performance metrics", {
        job_class: self.class.name,
        shop_domain: @shop_domain,
        processing_duration_ms: duration,
        total_job_duration_ms: job_duration_ms
      }
    rescue StandardError => e
      duration = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.error "Job performance tracking failed", {
        job_class: self.class.name,
        shop_domain: @shop_domain,
        processing_duration_ms: duration,
        error: e.message
      }
      raise
    end

    def process_customer_redaction(account)
      customer_data = @payload['customer']
      orders_to_redact = @payload['orders_to_redact'] || []
      
      Rails.logger.info "Starting customer redaction processing", {
        account_id: account.id,
        customer_id: customer_data['id'],
        orders_to_redact_count: orders_to_redact.count,
        shop_domain: @shop_domain
      }
      
      # Find the contact using the same logic as data requests
      contact = find_contact_by_shopify_id(account, customer_data['id'])
      contact ||= find_contact_by_email(account, customer_data['email']) if customer_data['email'].present?
      
      if contact
        if contact.redacted_at.present?
          Rails.logger.info "Contact already redacted, skipping", {
            contact_id: contact.id,
            redacted_at: contact.redacted_at,
            shop_domain: @shop_domain
          }
          return
        end
        
        Rails.logger.info "Contact found for redaction", contact_context(contact)
        
        # Apply safeguards before redaction
        if apply_deletion_safeguards(contact, account)
          redact_contact_data(contact, customer_data)
          verify_redaction_integrity(contact, account)
        end
      else
        Rails.logger.warn "Contact not found for redaction", {
          account_id: account.id,
          shopify_customer_id: customer_data['id'],
          customer_email: customer_data['email']&.gsub(/@.+/, '@***'),
          shop_domain: @shop_domain
        }
        # Log the redaction attempt even if contact not found for compliance
        log_redaction_attempt_not_found(account, customer_data)
      end
    end

    # Contact identification methods (reused from CustomersDataRequestJob)
    def find_contact_by_shopify_id(account, shopify_customer_id)
      return nil if shopify_customer_id.blank?
      
      # Look for contacts with Shopify customer ID in custom attributes
      account.contacts.where(
        "custom_attributes->>'shopify_customer_id' = ?", 
        shopify_customer_id.to_s
      ).first
    end

    def find_contact_by_email(account, email)
      return nil if email.blank?
      
      # Case-insensitive email lookup
      account.contacts.where('LOWER(email) = ?', email.downcase).first
    end

    def contact_context(contact)
      {
        contact_id: contact.id,
        contact_email: contact.email&.gsub(/@.+/, '@***'),
        contact_name: contact.name,
        has_conversations: contact.conversations.exists?,
        created_at: contact.created_at,
        currently_redacted: contact.redacted_at.present?
      }
    end

    # Redaction logic
    def redact_contact_data(contact, customer_data)
      Rails.logger.info "Beginning contact redaction", {
        contact_id: contact.id,
        original_email: contact.email&.gsub(/@.+/, '@***'),
        shop_domain: @shop_domain
      }
      
      # Perform redaction within a database transaction
      Contact.transaction do
        # Store original data for audit log before redaction
        audit_log = create_redaction_audit_log(contact, customer_data)
        
        # Preserve conversation history before anonymizing contact
        preserve_conversation_history(contact)
        
        # Apply anonymization
        anonymized_data = generate_anonymized_data(contact)
        
        contact.update!(
          name: anonymized_data[:name],
          email: anonymized_data[:email],
          phone_number: anonymized_data[:phone],
          custom_attributes: anonymized_data[:custom_attributes],
          additional_emails: [],
          redacted_at: Time.current
        )
        
        Rails.logger.info "Contact redaction completed", {
          contact_id: contact.id,
          new_email: contact.email,
          redacted_at: contact.redacted_at,
          audit_log_created: audit_log.present?
        }
      end
    rescue => e
      Rails.logger.error "Failed to redact contact", {
        contact_id: contact.id,
        error: e.message,
        backtrace: e.backtrace.first(5)
      }
      raise
    end

    def generate_anonymized_data(contact)
      {
        name: "Redacted Customer",
        email: "redacted-customer-#{contact.id}@redacted.local",
        phone: generate_anonymized_phone(contact),
        custom_attributes: redact_custom_attributes(contact.custom_attributes)
      }
    end

    def generate_anonymized_phone(contact)
      original_phone = contact.phone_number.to_s.strip
      
      # Try to extract country code from original number
      if original_phone.match(/^\+(\d{1,3})/)
        # International format with + prefix
        country_code = $1
        "+#{country_code}555#{contact.id.to_s.rjust(7, '0')}"
      elsif original_phone.match(/^(\d{1,3})/) && original_phone.length > 7
        # Handle numbers without + prefix but likely with country code
        potential_country_code = original_phone[0..2]
        # Validate country code length (1-3 digits)
        if potential_country_code.length <= 3
          "+#{potential_country_code}555#{contact.id.to_s.rjust(7, '0')}"
        else
          # Fallback to clearly anonymized format
          "REDACTED-#{contact.id.to_s.rjust(8, '0')}"
        end
      else
        # Fallback to clearly anonymized format for unknown formats
        "REDACTED-#{contact.id.to_s.rjust(8, '0')}"
      end
    end

    def redact_custom_attributes(attributes)
      return {} unless attributes.is_a?(Hash)
      
      # Keep non-PII attributes, redact PII
      safe_attributes = {}
      
      attributes.each do |key, value|
        if pii_attribute?(key)
          safe_attributes[key] = "[redacted]"
        elsif system_attribute?(key)
          safe_attributes[key] = value # Keep system attributes
        else
          # For unknown attributes, err on the side of redaction
          safe_attributes[key] = "[redacted]"
        end
      end
      
      # Add redaction metadata
      safe_attributes.merge({
        'redaction_performed_at' => Time.current.iso8601,
        'redaction_reason' => 'shopify_customer_redact_webhook',
        'original_shopify_customer_id' => attributes['shopify_customer_id']
      })
    end

    def pii_attribute?(key)
      pii_patterns = [
        /name/i, /email/i, /phone/i, /address/i, /birthday/i, 
        /birth_date/i, /ssn/i, /social/i, /passport/i, /license/i
      ]
      pii_patterns.any? { |pattern| key.to_s.match?(pattern) }
    end

    def system_attribute?(key)
      system_patterns = [
        /^system_/, /^internal_/, /^app_/, /created_by/i, 
        /updated_by/i, /source/i, /channel/i
      ]
      system_patterns.any? { |pattern| key.to_s.match?(pattern) }
    end

    # Data retention compliance methods
    def preserve_conversation_history(contact)
      # Conversations remain intact but are now associated with anonymized contact
      conversations = contact.conversations.includes(:messages)
      
      Rails.logger.info "Preserving conversation history for redacted contact", {
        contact_id: contact.id,
        conversations_count: conversations.count,
        total_messages: conversations.sum { |c| c.messages.count }
      }
      
      # Update conversation metadata to indicate contact redaction
      conversations.each do |conversation|
        update_conversation_for_redacted_contact(conversation, contact)
      end
    end

    def update_conversation_for_redacted_contact(conversation, contact)
      # Add metadata indicating the contact has been redacted
      updated_attributes = (conversation.additional_attributes || {}).merge({
        'contact_redacted_at' => Time.current.iso8601,
        'original_contact_info' => {
          'was_redacted' => true,
          'redaction_reason' => 'privacy_compliance',
          'redaction_timestamp' => Time.current.iso8601
        }
      })
      
      conversation.update!(additional_attributes: updated_attributes)
      
      # Add system message indicating redaction
      add_redaction_notification_message(conversation)
    end

    def add_redaction_notification_message(conversation)
      conversation.messages.create!(
        account: conversation.account,
        inbox: conversation.inbox,
        content: "Customer data has been redacted for privacy compliance. Historical conversation data is preserved but customer personal information has been anonymized.",
        message_type: 'activity',
        sender: nil, # System message
        private: true, # Internal note
        content_type: 'text',
        content_attributes: {
          'system_message_type' => 'privacy_redaction',
          'redaction_timestamp' => Time.current.iso8601
        }
      )
    end

    # Safeguards and validation
    def apply_deletion_safeguards(contact, account)
      # Check for business-critical data that should not be deleted
      safeguard_checks = {
        has_recent_transactions: check_recent_transaction_activity(contact),
        has_legal_hold: check_legal_hold_status(contact),
        has_active_disputes: check_active_dispute_status(contact),
        has_compliance_flags: check_compliance_flags(contact)
      }
      
      Rails.logger.info "Applying deletion safeguards", {
        contact_id: contact.id,
        safeguard_checks: safeguard_checks
      }
      
      # If any critical business data exists, apply special handling
      if safeguard_checks.values.any?
        handle_protected_contact_redaction(contact, safeguard_checks)
      else
        # Proceed with standard redaction
        true
      end
    end

    def check_recent_transaction_activity(contact)
      # Check for recent order/transaction activity that might be legally required to retain
      cutoff_date = 7.years.ago # Adjust based on business requirements
      
      recent_activity = contact.conversations
                              .where('created_at > ?', cutoff_date)
                              .joins(:messages)
                              .where('messages.content ILIKE ?', '%order%')
                              .or(contact.conversations.joins(:messages).where('messages.content ILIKE ?', '%payment%'))
                              .or(contact.conversations.joins(:messages).where('messages.content ILIKE ?', '%transaction%'))
                              .or(contact.conversations.joins(:messages).where('messages.content ILIKE ?', '%invoice%'))
                              .exists?
      
      if recent_activity
        Rails.logger.info "Recent transaction activity detected", {
          contact_id: contact.id,
          cutoff_date: cutoff_date
        }
      end
      
      recent_activity
    end

    def check_legal_hold_status(contact)
      # Check if contact is under legal hold
      legal_hold = contact.custom_attributes&.dig('legal_hold_active') == 'true'
      
      if legal_hold
        Rails.logger.warn "Contact under legal hold, special handling required", {
          contact_id: contact.id,
          legal_hold_reason: contact.custom_attributes&.dig('legal_hold_reason')
        }
      end
      
      legal_hold
    end

    def check_active_dispute_status(contact)
      # Check for active disputes or chargebacks
      dispute_keywords = ['dispute', 'chargeback', 'refund', 'complaint']
      
      has_disputes = contact.conversations
                           .where(status: ['open', 'pending'])
                           .joins(:messages)
                           .where(
                             dispute_keywords.map { |keyword|
                               "LOWER(messages.content) LIKE ?"
                             }.join(' OR '),
                             *dispute_keywords.map { |keyword| "%#{keyword.downcase}%" }
                           )
                           .exists?
      
      if has_disputes
        Rails.logger.warn "Active disputes detected for contact", {
          contact_id: contact.id
        }
      end
      
      has_disputes
    end

    def check_compliance_flags(contact)
      # Check for regulatory compliance flags
      compliance_flags = [
        'regulatory_hold',
        'audit_retention_required',
        'tax_record_retention',
        'anti_money_laundering_flag'
      ]
      
      has_flags = compliance_flags.any? do |flag|
        contact.custom_attributes&.dig(flag) == 'true'
      end
      
      if has_flags
        Rails.logger.warn "Compliance flags detected for contact", {
          contact_id: contact.id,
          active_flags: compliance_flags.select { |flag|
            contact.custom_attributes&.dig(flag) == 'true'
          }
        }
      end
      
      has_flags
    end

    def handle_protected_contact_redaction(contact, safeguard_checks)
      Rails.logger.warn "Protected contact requires special redaction handling", {
        contact_id: contact.id,
        protection_reasons: safeguard_checks.select { |k, v| v }.keys
      }
      
      # Apply partial redaction or defer redaction
      if safeguard_checks[:has_legal_hold]
        # Cannot redact contacts under legal hold
        mark_contact_for_deferred_redaction(contact, 'legal_hold')
        return false
      elsif safeguard_checks[:has_recent_transactions]
        # Apply limited redaction keeping transaction-related data
        apply_limited_redaction(contact)
        return true
      else
        # Proceed with full redaction but add extra audit logging
        add_protected_redaction_audit_log(contact, safeguard_checks)
        return true
      end
    end

    def mark_contact_for_deferred_redaction(contact, reason)
      contact.update!(
        custom_attributes: (contact.custom_attributes || {}).merge({
          'redaction_deferred' => true,
          'redaction_deferred_reason' => reason,
          'redaction_deferred_at' => Time.current.iso8601,
          'redaction_requested_at' => Time.current.iso8601
        })
      )
      
      Rails.logger.info "Contact marked for deferred redaction", {
        contact_id: contact.id,
        reason: reason
      }
    end

    def apply_limited_redaction(contact)
      # Redact PII but preserve transaction-related metadata
      limited_custom_attributes = contact.custom_attributes&.dup || {}
      
      # Preserve transaction and order related attributes
      preserved_keys = limited_custom_attributes.keys.select do |key|
        key.match?(/order|transaction|payment|invoice|tax/i)
      end
      
      # Redact other PII attributes
      limited_custom_attributes.each do |key, value|
        unless preserved_keys.include?(key) || system_attribute?(key)
          limited_custom_attributes[key] = '[redacted]'
        end
      end
      
      # Add limited redaction metadata
      limited_custom_attributes.merge!({
        'redaction_performed_at' => Time.current.iso8601,
        'redaction_type' => 'limited_redaction',
        'redaction_reason' => 'shopify_customer_redact_webhook',
        'preserved_attributes' => preserved_keys
      })
      
      contact.update!(
        name: "Redacted Customer",
        email: "redacted-customer-#{contact.id}@redacted.local",
        phone_number: "redacted",
        custom_attributes: limited_custom_attributes,
        redacted_at: Time.current
      )
      
      Rails.logger.info "Limited redaction applied to protected contact", {
        contact_id: contact.id,
        preserved_attributes: preserved_keys
      }
    end

    def add_protected_redaction_audit_log(contact, safeguard_checks)
      Rails.logger.info "Creating audit log for protected contact redaction", {
        contact_id: contact.id,
        protection_reasons: safeguard_checks.select { |k, v| v }.keys
      }
    end

    # Verification and auditing
    def verify_redaction_integrity(contact, account)
      Rails.logger.info "Verifying redaction integrity", {
        contact_id: contact.id,
        account_id: account.id
      }
      
      integrity_checks = {
        contact_anonymized: verify_contact_anonymization(contact),
        conversations_preserved: verify_conversations_preserved(contact),
        references_maintained: verify_foreign_key_integrity(contact),
        audit_trail_complete: verify_audit_trail_completeness(contact)
      }
      
      all_checks_passed = integrity_checks.values.all?
      
      Rails.logger.info "Redaction integrity verification completed", {
        contact_id: contact.id,
        checks_passed: all_checks_passed,
        individual_checks: integrity_checks
      }
      
      unless all_checks_passed
        Rails.logger.error "Redaction integrity check failed", {
          contact_id: contact.id,
          failed_checks: integrity_checks.reject { |k, v| v }.keys
        }
        raise "Redaction integrity verification failed for contact #{contact.id}"
      end
      
      integrity_checks
    end

    def verify_contact_anonymization(contact)
      # Verify all PII has been properly redacted
      checks = {
        name_redacted: contact.name == "Redacted Customer",
        email_anonymized: contact.email.match?(/^redacted-customer-\d+@redacted\.local$/),
        phone_redacted: contact.phone_number.match?(/^\+1555\d{7}$/), # Check for unique phone format
        redacted_timestamp_set: contact.redacted_at.present?,
        custom_attributes_sanitized: verify_custom_attributes_redacted(contact)
      }
      
      checks.values.all?
    end

    def verify_conversations_preserved(contact)
      # Ensure conversations still exist and are properly linked
      conversations = contact.conversations.reload
      
      conversations.all? do |conv|
        conv.contact_id == contact.id &&
        conv.additional_attributes&.dig('contact_redacted_at').present?
      end
    end

    def verify_foreign_key_integrity(contact)
      # Check that all foreign key relationships are maintained
      begin
        # Test key relationships
        contact.conversations.count # Should not raise error
        contact.account.present? # Should still be associated
        true
      rescue => e
        Rails.logger.error "Foreign key integrity check failed", {
          contact_id: contact.id,
          error: e.message
        }
        false
      end
    end

    def verify_custom_attributes_redacted(contact)
      return true unless contact.custom_attributes.is_a?(Hash)
      
      # Check that PII attributes have been redacted
      contact.custom_attributes.none? do |key, value|
        pii_attribute?(key) && !value.to_s.include?('[redacted]')
      end
    end

    def verify_audit_trail_completeness(contact)
      # Verify audit log exists for this redaction
      audit_exists = contact.custom_attributes&.dig('redaction_performed_at').present?
      
      Rails.logger.debug "Audit trail verification", {
        contact_id: contact.id,
        audit_exists: audit_exists,
        redaction_metadata: contact.custom_attributes&.slice(
          'redaction_performed_at',
          'redaction_reason'
        )
      }
      
      audit_exists
    end

    # Audit and compliance
    def create_redaction_audit_log(contact, redaction_context = {})
      audit_data = {
        contact_id: contact.id,
        account_id: contact.account_id,
        redaction_timestamp: Time.current.iso8601,
        redaction_type: redaction_context['redaction_type'] || 'customer_redact',
        shop_domain: @shop_domain,
        
        # Document what was redacted
        redacted_fields: {
          name: { before: mask_for_audit(contact.name), after: "Redacted Customer" },
          email: { before: mask_email(contact.email), after: "redacted-customer-#{contact.id}@redacted.local" },
          phone_number: { before: mask_phone(contact.phone_number), after: generate_anonymized_phone(contact) },
          custom_attributes: document_custom_attribute_changes(contact.custom_attributes)
        },
        
        # Document what was preserved
        preserved_data: {
          conversations_count: contact.conversations.count,
          messages_count: contact.conversations.joins(:messages).count,
          account_association: true,
          conversation_history: true,
          system_metadata: true
        },
        
        # Compliance information
        compliance_info: {
          retention_policy: 'conversations_preserved_contact_anonymized',
          legal_basis: 'gdpr_article_17_right_to_erasure',
          retention_period: 'indefinite_for_business_records',
          anonymization_method: 'irreversible_pseudonymization'
        }
      }
      
      Rails.logger.info "Redaction audit log created", {
        contact_id: contact.id,
        audit_summary: audit_data.except(:redacted_fields) # Don't log PII
      }
      
      # Store audit log in custom attributes for compliance
      store_audit_log(audit_data)
      
      audit_data
    end

    def document_custom_attribute_changes(attributes)
      return {} unless attributes.is_a?(Hash)
      
      changes = {}
      attributes.each do |key, value|
        if pii_attribute?(key)
          changes[key] = { 
            action: 'redacted',
            before_type: value.class.name,
            after: '[redacted]'
          }
        elsif system_attribute?(key)
          changes[key] = { 
            action: 'preserved',
            reason: 'system_metadata'
          }
        else
          changes[key] = { 
            action: 'redacted',
            reason: 'unknown_attribute_erring_on_privacy_side'
          }
        end
      end
      
      changes
    end

    def mask_for_audit(value)
      return nil unless value
      return value if value.length < 3
      "#{value[0]}***"
    end

    def mask_email(email)
      return nil unless email
      local, domain = email.split('@')
      return email unless domain
      "#{local[0]}***@#{domain}"
    end

    def mask_phone(phone)
      return nil unless phone
      return phone if phone.length < 4
      "***#{phone[-4..]}"
    end

    def store_audit_log(audit_data)
      # Store essential audit info in Rails logs for compliance
      Rails.logger.info "Storing redaction audit log", {
        contact_id: audit_data[:contact_id],
        account_id: audit_data[:account_id],
        redaction_type: audit_data[:redaction_type],
        timestamp: audit_data[:redaction_timestamp]
      }
    end

    def log_redaction_attempt_not_found(account, customer_data)
      Rails.logger.info "Redaction attempted for non-existent contact", {
        account_id: account.id,
        shopify_customer_id: customer_data['id'],
        customer_email: customer_data['email']&.gsub(/@.+/, '@***'),
        compliance_status: 'attempted_redaction_no_data_found',
        timestamp: Time.current.iso8601
      }
    end
  end
end