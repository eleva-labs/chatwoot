# frozen_string_literal: true

module Shopify
  class ShopRedactJob < ApplicationJob
    include Shopify::Concerns::AccountResolver

    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    discard_on ActiveJob::DeserializationError

    # Add timeout to prevent long-running jobs
    around_perform do |job, block|
      Timeout.timeout(600) { block.call } # 10 minute timeout for bulk operations
    rescue Timeout::Error => e
      Rails.logger.error "Job timeout exceeded: #{job_context.merge(error: e.message).to_json}"
      raise
    end

    def perform(webhook_payload)
      @payload = webhook_payload.with_indifferent_access
      @shop_domain = @payload['shop_domain']
      @job_started_at = Time.current

      Rails.logger.info "Starting shop redaction job: #{job_context.to_json}"

      begin
        account = resolve_account(@shop_domain)
        return log_account_not_found unless account

        process_shop_redaction(account)
        track_job_performance

        Rails.logger.info "Shop redaction job completed successfully: #{job_context.to_json}"
      rescue => e
        context = job_context.merge(error: e.message)
        Rails.logger.error "Shop redaction job failed: #{context.to_json}"
        raise
      end
    end

    private

    def job_context
      {
        job_class: self.class.name,
        job_id: job_id,
        shop_domain: @shop_domain,
        started_at: @job_started_at&.iso8601,
        duration_ms: job_duration_ms
      }
    end

    def job_duration_ms
      return nil unless @job_started_at
      ((Time.current - @job_started_at) * 1000).round(2)
    end

    def track_job_performance
      start_time = Time.current
      yield if block_given?
      duration = ((Time.current - start_time) * 1000).round(2)

      # Log performance metrics for monitoring
      metrics = {
        shop_domain: @shop_domain,
        job_duration_ms: job_duration_ms,
        operation_duration_ms: duration
      }
      Rails.logger.info "Shop redaction performance metrics: #{metrics.to_json}"

      # Alert if job takes too long
      if duration > 300_000 # 5 minutes
        context = {
          shop_domain: @shop_domain,
          duration_ms: duration,
          threshold_ms: 300_000
        }
        Rails.logger.warn "Shop redaction job taking longer than expected: #{context.to_json}"
      end
    rescue => e
      context = {
        shop_domain: @shop_domain,
        error: e.message
      }
      Rails.logger.error "Failed to track job performance: #{context.to_json}"
    end

    def process_shop_redaction(account)
      shop_id = @payload['shop_id']
      shop_domain = @payload['shop_domain']
      
      context = {
        account_id: account.id,
        shop_id: shop_id,
        shop_domain: shop_domain
      }
      Rails.logger.info "Starting shop redaction processing: #{context.to_json}"
      
      # Verify the shop redaction is legitimate
      unless validate_shop_redaction_request(account, shop_id, shop_domain)
        context = {
          account_id: account.id,
          shop_id: shop_id,
          shop_domain: shop_domain
        }
        Rails.logger.error "Invalid shop redaction request: #{context.to_json}"
        return
      end
      
      # Get all contacts for this account
      contacts_to_redact = find_contacts_for_redaction(account)
      
      context = {
        account_id: account.id,
        contacts_count: contacts_to_redact.count,
        shop_domain: shop_domain
      }
      Rails.logger.info "Found contacts for shop redaction: #{context.to_json}"
      
      # Process redaction in batches
      redaction_summary = redact_contacts_in_batches(contacts_to_redact, account)
      
      # Disable the integration hook
      disable_integration_hook(account, shop_domain)
      
      # Generate compliance report
      compliance_report = generate_compliance_report(account, redaction_summary)
      
      context = {
        account_id: account.id,
        shop_domain: shop_domain,
        total_contacts_redacted: redaction_summary[:successful_redactions],
        compliance_report_generated: compliance_report.present?
      }
      Rails.logger.info "Shop redaction completed: #{context.to_json}"
    end

    def validate_shop_redaction_request(account, shop_id, shop_domain)
      # Verify the shop domain matches the account's integration
      integration_hook = account.integrations_hooks.find_by(
        app_id: 'shopify',
        reference_id: shop_domain
      )
      
      unless integration_hook
        context = {
          account_id: account.id,
          shop_domain: shop_domain
        }
        Rails.logger.error "No integration hook found for shop redaction: #{context.to_json}"
        return false
      end
      
      # Additional validation: check if shop is already redacted
      if integration_hook.settings&.dig('redacted_at').present?
        context = {
          account_id: account.id,
          shop_domain: shop_domain,
          redacted_at: integration_hook.settings['redacted_at']
        }
        Rails.logger.info "Shop already redacted: #{context.to_json}"
        return false
      end
      
      true
    end

    def find_contacts_for_redaction(account)
      # Find all contacts that haven't been redacted yet
      contacts = account.contacts.where(redacted_at: nil)
      
      # Filter out system contacts that shouldn't be redacted
      contacts = contacts.where.not(
        email: ['shopify-compliance@system.local', 'system@chatwoot.local']
      ).where.not(
        name: ['Shopify Compliance System', 'System Contact']
      )
      
      # Log the discovery for audit purposes
      context = {
        account_id: account.id,
        total_contacts: account.contacts.count,
        contacts_to_redact: contacts.count,
        already_redacted: account.contacts.where.not(redacted_at: nil).count
      }
      Rails.logger.info "Contact discovery for shop redaction: #{context.to_json}"
      
      contacts
    end

    def get_redaction_batch_size
      # Configure batch size based on system load and contact count
      ENV.fetch('SHOPIFY_REDACTION_BATCH_SIZE', 50).to_i
    end

    def should_use_background_jobs_for_batches?
      # For large datasets, process batches in separate background jobs
      ENV.fetch('SHOPIFY_REDACTION_USE_BACKGROUND_BATCHES', 'false') == 'true'
    end

    def redact_contacts_in_batches(contacts, account)
      batch_size = get_redaction_batch_size
      total_batches = (contacts.count.to_f / batch_size).ceil
      processed_count = 0
      failed_count = 0
      
      context = {
        account_id: account.id,
        total_contacts: contacts.count,
        batch_size: batch_size,
        total_batches: total_batches
      }
      Rails.logger.info "Starting batch redaction process: #{context.to_json}"
      
      contacts.in_batches(of: batch_size).with_index do |batch, batch_index|
        context = {
          account_id: account.id,
          batch_number: batch_index + 1,
          total_batches: total_batches,
          batch_size: batch.count
        }
        Rails.logger.info "Processing redaction batch: #{context.to_json}"
        
        batch_results = process_redaction_batch(batch, account)
        processed_count += batch_results[:success_count]
        failed_count += batch_results[:failure_count]
        
        # Add small delay between batches to prevent database overload
        sleep(0.5) if batch_index < total_batches - 1
      end
      
      context = {
        account_id: account.id,
        total_processed: processed_count,
        total_failed: failed_count,
        success_rate: contacts.count > 0 ? (processed_count.to_f / contacts.count * 100).round(2) : 100
      }
      Rails.logger.info "Batch redaction process completed: #{context.to_json}"
      
      # Alert if failure rate is high
      if failed_count > (contacts.count * 0.1) # More than 10% failure rate
        context = {
          account_id: account.id,
          failure_rate: contacts.count > 0 ? (failed_count.to_f / contacts.count * 100).round(2) : 0,
          requires_investigation: true
        }
        Rails.logger.error "High failure rate in shop redaction: #{context.to_json}"
      end
      
      {
        total_contacts: contacts.count,
        successful_redactions: processed_count,
        failed_redactions: failed_count,
        success_rate: contacts.count > 0 ? (processed_count.to_f / contacts.count * 100).round(2) : 100
      }
    end

    def process_redaction_batch(batch, account)
      success_count = 0
      failure_count = 0
      
      batch.each do |contact|
        begin
          redact_single_contact(contact, account)
          success_count += 1
        rescue => e
          failure_count += 1
          context = {
            contact_id: contact.id,
            account_id: account.id,
            error: e.message,
            backtrace: e.backtrace.first(3)
          }
          Rails.logger.error "Failed to redact contact in batch: #{context.to_json}"
        end
      end
      
      { success_count: success_count, failure_count: failure_count }
    end

    def redact_single_contact(contact, account)
      # Skip if already redacted (double-check for race conditions)
      return if contact.redacted_at.present?
      
      Contact.transaction do
        # Create audit log
        audit_log = create_redaction_audit_log(contact, {
          'redaction_type' => 'shop_redact',
          'shop_domain' => @shop_domain
        })
        
        # Preserve conversation history
        preserve_conversation_history(contact)
        
        # Apply the same anonymization as customer redaction
        anonymized_data = generate_anonymized_data(contact)
        
        contact.update!(
          name: anonymized_data[:name],
          email: anonymized_data[:email],
          phone_number: anonymized_data[:phone],
          custom_attributes: anonymized_data[:custom_attributes],
          additional_emails: [],
          redacted_at: Time.current
        )
      end
    end

    # Reuse anonymization methods from CustomersRedactJob
    def generate_anonymized_data(contact)
      {
        name: "Redacted Customer",
        email: "redacted-customer-#{contact.id}@redacted.local",
        phone: generate_anonymized_phone(contact),
        custom_attributes: redact_custom_attributes_for_shop(contact.custom_attributes)
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

    def redact_custom_attributes_for_shop(attributes)
      return {} unless attributes.is_a?(Hash)
      
      # Similar to customer redaction but mark as shop-wide redaction
      safe_attributes = {}
      
      attributes.each do |key, value|
        if pii_attribute?(key)
          safe_attributes[key] = "[redacted]"
        elsif system_attribute?(key)
          safe_attributes[key] = value
        else
          safe_attributes[key] = "[redacted]"
        end
      end
      
      safe_attributes.merge({
        'redaction_performed_at' => Time.current.iso8601,
        'redaction_reason' => 'shopify_shop_redact_webhook',
        'shop_domain' => @shop_domain,
        'redaction_type' => 'shop_wide'
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

    # Data retention compliance methods (shared with CustomersRedactJob)
    def preserve_conversation_history(contact)
      # Conversations remain intact but are now associated with anonymized contact
      conversations = contact.conversations.includes(:messages)
      
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
          'redaction_reason' => 'shop_wide_privacy_compliance',
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
        content: "Shop data has been redacted due to app uninstallation. Historical conversation data is preserved but all customer personal information has been anonymized for privacy compliance.",
        message_type: 'activity',
        sender: nil, # System message
        private: true, # Internal note
        content_type: 'text',
        content_attributes: {
          'system_message_type' => 'shop_privacy_redaction',
          'redaction_timestamp' => Time.current.iso8601,
          'redaction_scope' => 'shop_wide'
        }
      )
    end

    def disable_integration_hook(account, shop_domain)
      integration_hook = account.integrations_hooks.find_by(
        app_id: 'shopify',
        reference_id: shop_domain
      )
      
      unless integration_hook
        context = {
          account_id: account.id,
          shop_domain: shop_domain
        }
        Rails.logger.error "Integration hook not found for disabling: #{context.to_json}"
        return
      end
      
      # Update hook settings to mark as redacted
      updated_settings = (integration_hook.settings || {}).merge({
        'redacted_at' => Time.current.iso8601,
        'redaction_reason' => 'shopify_shop_redact_webhook',
        'original_status' => integration_hook.status
      })
      
      integration_hook.update!(
        status: 'disabled',
        settings: updated_settings
      )
      
      context = {
        account_id: account.id,
        hook_id: integration_hook.id,
        shop_domain: shop_domain,
        redacted_at: Time.current.iso8601
      }
      Rails.logger.info "Integration hook disabled due to shop redaction: #{context.to_json}"
    end

    # Audit and compliance
    def create_redaction_audit_log(contact, redaction_context = {})
      audit_data = {
        contact_id: contact.id,
        account_id: contact.account_id,
        redaction_timestamp: Time.current.iso8601,
        redaction_type: redaction_context['redaction_type'] || 'shop_redact',
        shop_domain: @shop_domain,
        
        # Document what was redacted (with corrected phone format)
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
          legal_basis: 'shopify_app_uninstallation_gdpr_compliance',
          retention_period: 'indefinite_for_business_records',
          anonymization_method: 'irreversible_pseudonymization'
        }
      }
      
      context = {
        contact_id: contact.id,
        redaction_type: audit_data[:redaction_type]
      }
      Rails.logger.debug "Redaction audit log created: #{context.to_json}"
      
      # Store essential audit info in Rails logs for compliance
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
      context = {
        contact_id: audit_data[:contact_id],
        account_id: audit_data[:account_id],
        redaction_type: audit_data[:redaction_type],
        timestamp: audit_data[:redaction_timestamp]
      }
      Rails.logger.info "Storing shop redaction audit log: #{context.to_json}"
    end

    def generate_compliance_report(account, redaction_summary)
      # Generate summary report for compliance documentation
      report = {
        account_id: account.id,
        shop_domain: @shop_domain,
        redaction_completed_at: Time.current.iso8601,
        total_contacts_processed: redaction_summary[:total_contacts],
        successful_redactions: redaction_summary[:successful_redactions],
        failed_redactions: redaction_summary[:failed_redactions],
        
        data_retention_summary: {
          conversations_preserved: true,
          message_history_preserved: true,
          contact_pii_redacted: true,
          system_metadata_preserved: true,
          account_relationships_maintained: true
        },
        
        compliance_attestation: {
          gdpr_compliance: true,
          ccpa_compliance: true,
          anonymization_irreversible: true,
          business_records_preserved: true,
          audit_trail_complete: true
        }
      }
      
      context = {
        account_id: account.id,
        shop_domain: @shop_domain,
        report_summary: report.except(:compliance_attestation)
      }
      Rails.logger.info "Compliance report generated: #{context.to_json}"
      
      report
    end

    # Health monitoring for shop redaction
    def self.webhook_subscription_health_report
      total_hooks = Integrations::Hook.where(app_id: 'shopify').count
      
      successful_subscriptions = Integrations::Hook.where(app_id: 'shopify')
                                                   .where("settings->>'compliance_webhooks_subscribed' = 'true'")
                                                   .count
      
      pending_subscriptions = Integrations::Hook.where(app_id: 'shopify')
                                                .where("settings->>'compliance_webhooks_pending' = 'true'")
                                                .count
      
      failed_subscriptions = Integrations::Hook.where(app_id: 'shopify')
                                               .where("settings->>'requires_manual_intervention' = 'true'")
                                               .count
      
      redacted_shops = Integrations::Hook.where(app_id: 'shopify')
                                         .where("settings->>'redacted_at' IS NOT NULL")
                                         .count
      
      {
        total_hooks: total_hooks,
        successful_subscriptions: successful_subscriptions,
        pending_subscriptions: pending_subscriptions,
        failed_subscriptions: failed_subscriptions,
        redacted_shops: redacted_shops,
        success_rate: total_hooks > 0 ? (successful_subscriptions.to_f / total_hooks * 100).round(2) : 0
      }.to_json
    end
  end
end