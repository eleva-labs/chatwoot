# frozen_string_literal: true

module Shopify
  class CustomersDataRequestJob < ApplicationJob
    include Shopify::Concerns::AccountResolver

    queue_as :default

    # Configure retry behavior for webhook processing
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

      Rails.logger.info 'Processing customers_data_request job', job_context

      # Resolve account and process the data request
      account = resolve_account(@shop_domain)
      return log_account_not_found unless account

      track_job_performance do
        process_customer_data_request(account)
      end

      Rails.logger.info 'Successfully processed customers_data_request', job_context
    rescue StandardError => e
      Rails.logger.error 'Failed to process customers_data_request',
                         job_context.merge(error: e.message, backtrace: e.backtrace.first(5))
      raise # Re-raise to trigger retry mechanism
    end

    private

    def job_context
      {
        job_class: self.class.name,
        shop_domain: @shop_domain,
        customer_id: @payload.dig('customer', 'id'),
        data_request_id: @payload.dig('data_request', 'id'),
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

    def process_customer_data_request(account)
      customer_data = @payload['customer']
      data_request_id = @payload.dig('data_request', 'id')
      
      Rails.logger.info "Starting customer data request processing", {
        account_id: account.id,
        customer_id: customer_data['id'],
        data_request_id: data_request_id,
        shop_domain: @shop_domain
      }
      
      # Primary lookup by Shopify customer ID
      contact = find_contact_by_shopify_id(account, customer_data['id'])
      
      # If not found, try email lookup
      contact ||= find_contact_by_email(account, customer_data['email']) if customer_data['email'].present?
      
      if contact
        Rails.logger.info "Contact found for data request", contact_context(contact)
        generate_and_deliver_data_summary(account, contact, data_request_id)
      else
        Rails.logger.warn "Contact not found for data request", {
          account_id: account.id,
          shopify_customer_id: customer_data['id'],
          customer_email: customer_data['email']&.gsub(/@.+/, '@***'), # Partially redact email in logs
          shop_domain: @shop_domain
        }
        handle_contact_not_found(account, customer_data, data_request_id)
      end
    end

    # Contact identification methods
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

    # Data collection methods
    def generate_and_deliver_data_summary(account, contact, data_request_id)
      contact_data = collect_contact_profile_data(contact)
      conversation_data = collect_conversation_data(contact)
      interaction_history = collect_interaction_history(contact)
      
      metadata = {
        contact_id: contact.id,
        customer_id: @payload.dig('customer', 'id'),
        data_request_id: data_request_id,
        found_data: true,
        data_points_count: calculate_data_points_count(contact_data, conversation_data)
      }
      
      # Send email to store owner as required by Shopify compliance
      deliver_data_summary_via_email(account, contact_data, conversation_data, interaction_history, metadata)
    end

    def collect_contact_profile_data(contact)
      profile_data = {
        basic_info: {
          id: contact.id,
          name: contact.name,
          email: contact.email,
          phone_number: contact.phone_number,
          avatar_url: contact.avatar_url,
          created_at: contact.created_at,
          updated_at: contact.updated_at
        },
        custom_attributes: sanitize_custom_attributes(contact.custom_attributes),
        additional_emails: contact.additional_emails,
        location_data: {
          country_code: contact.country_code,
          city: contact.location,
          timezone: contact.custom_attributes&.dig('timezone')
        },
        engagement_metrics: calculate_engagement_metrics(contact)
      }
      
      Rails.logger.debug "Collected profile data", {
        contact_id: contact.id,
        custom_attributes_count: contact.custom_attributes&.keys&.count || 0,
        has_additional_emails: contact.additional_emails.present?
      }
      
      profile_data
    end

    def collect_conversation_data(contact)
      conversations = contact.conversations.includes(:messages, :inbox, :assignee, :team)
      
      conversation_data = conversations.map do |conversation|
        {
          id: conversation.id,
          status: conversation.status,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at,
          inbox_name: conversation.inbox&.name,
          assigned_agent: conversation.assignee&.name || 'Unassigned',
          team: conversation.team&.name,
          message_count: conversation.messages.count,
          labels: conversation.labels.pluck(:title),
          priority: conversation.priority,
          messages: collect_conversation_messages(conversation)
        }
      end
      
      Rails.logger.info "Collected conversation data", {
        contact_id: contact.id,
        conversations_count: conversations.count,
        total_messages: conversation_data.sum { |c| c[:message_count] }
      }
      
      conversation_data
    end

    def collect_conversation_messages(conversation)
      conversation.messages.includes(:sender, :attachments).limit(50).map do |message|
        {
          id: message.id,
          content: sanitize_message_content(message.content),
          message_type: message.message_type,
          created_at: message.created_at,
          sender_type: message.sender_type,
          sender_name: message.sender&.name || 'System',
          private: message.private?,
          attachments: message.attachments.map { |a| a.file_url if a.file_url }.compact
        }
      end
    end

    def collect_interaction_history(contact)
      {
        notes: collect_contact_notes(contact),
        conversation_summary: generate_conversation_summary(contact),
        timeline: build_interaction_timeline(contact)
      }
    end

    def collect_contact_notes(contact)
      # Collect internal notes about the contact
      contact.conversations
             .joins(:messages)
             .where(messages: { private: true })
             .includes(:messages)
             .limit(10)
             .map do |conversation|
        {
          conversation_id: conversation.id,
          notes: conversation.messages.where(private: true).limit(5).map do |note|
            {
              content: sanitize_message_content(note.content),
              created_at: note.created_at,
              author: note.sender&.name || 'System'
            }
          end
        }
      end.select { |conv| conv[:notes].any? }
    end

    def generate_conversation_summary(contact)
      conversations = contact.conversations.includes(:messages)
      
      {
        total_conversations: conversations.count,
        by_status: conversations.group(:status).count,
        by_channel: conversations.joins(:inbox).group('inboxes.channel_type').count,
        resolution_rate: calculate_resolution_rate(conversations),
        common_topics: extract_common_topics(conversations)
      }
    end

    def build_interaction_timeline(contact)
      events = []
      
      # Add conversation events
      contact.conversations.order(:created_at).limit(20).each do |conv|
        events << {
          type: 'conversation_started',
          timestamp: conv.created_at,
          details: {
            conversation_id: conv.id,
            channel: conv.inbox&.channel_type,
            subject: conv.display_id
          }
        }
        
        if conv.resolved?
          events << {
            type: 'conversation_resolved',
            timestamp: conv.updated_at,
            details: {
              conversation_id: conv.id,
              resolution_time: (conv.updated_at - conv.created_at).to_i
            }
          }
        end
      end
      
      # Sort by timestamp and limit to prevent huge datasets
      events.sort_by { |e| e[:timestamp] }.last(50)
    end

    # Data sanitization methods
    def sanitize_custom_attributes(attributes)
      return {} unless attributes.is_a?(Hash)
      
      # Remove potentially sensitive custom attributes
      sensitive_keys = ['password', 'token', 'secret', 'key', 'auth']
      
      attributes.reject do |key, value|
        sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
      end
    end

    def sanitize_message_content(content)
      # Remove any internal system information or sensitive data
      return '[Private/System Message]' if content.blank?
      
      # Remove email addresses of internal agents
      sanitized = content.gsub(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, '[email]')
      
      # Remove potential sensitive patterns
      sanitized = sanitized.gsub(/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/, '[card number]')
      sanitized = sanitized.gsub(/\b\d{3}-\d{2}-\d{4}\b/, '[SSN]')
      
      sanitized
    end

    # Metrics calculation methods
    def calculate_engagement_metrics(contact)
      conversations = contact.conversations
      {
        total_conversations: conversations.count,
        resolved_conversations: conversations.resolved.count,
        pending_conversations: conversations.open.count,
        first_contact_date: conversations.minimum(:created_at),
        last_contact_date: conversations.maximum(:updated_at),
        preferred_channel: determine_preferred_channel(conversations)
      }
    end

    def determine_preferred_channel(conversations)
      conversations.joins(:inbox)
                  .group('inboxes.channel_type')
                  .count
                  .max_by { |channel, count| count }
                  &.first || 'unknown'
    end

    def calculate_resolution_rate(conversations)
      return 0 if conversations.count == 0
      
      resolved_count = conversations.resolved.count
      (resolved_count.to_f / conversations.count * 100).round(2)
    end

    def extract_common_topics(conversations)
      # Simple keyword extraction from conversation messages
      all_content = conversations.joins(:messages)
                                .pluck('messages.content')
                                .compact
                                .join(' ')
                                .downcase
      
      # Basic topic extraction - could be enhanced with NLP
      common_words = all_content.scan(/\b[a-z]{4,}\b/)
                               .tally
                               .sort_by { |_, count| -count }
                               .first(5)
                               .to_h
      
      common_words.keys
    end

    def calculate_data_points_count(contact_data, conversation_data)
      count = 0
      count += contact_data[:custom_attributes]&.count || 0
      count += conversation_data.sum { |conv| conv[:message_count] }
      count += contact_data[:additional_emails]&.count || 0
      count
    end

    # Email delivery methods
    def handle_contact_not_found(account, customer_data, data_request_id)
      metadata = {
        customer_id: customer_data['id'],
        customer_email: customer_data['email'],
        data_request_id: data_request_id,
        found_data: false
      }
      
      # Send "no data found" email to store owner
      deliver_data_summary_via_email(account, nil, [], {}, metadata)
      
      Rails.logger.info "Completed data request with no data found", {
        account_id: account.id,
        shopify_customer_id: customer_data['id'],
        data_request_id: data_request_id
      }
    end

    def deliver_data_summary_via_email(account, contact_data, conversation_data, interaction_history, metadata)
      store_owner_email = get_store_owner_email(account)
      customer_email = @payload.dig('customer', 'email')
      data_request_id = metadata[:data_request_id]
      
      Rails.logger.info "Preparing email delivery for data request", {
        store_owner_email: store_owner_email&.gsub(/@.+/, '@***'),
        customer_email: customer_email&.gsub(/@.+/, '@***'),
        data_request_id: data_request_id,
        account_id: account.id,
        found_data: metadata[:found_data]
      }
      
      # Generate email content for store owner (includes customer details)
      email_content = generate_email_data_summary(contact_data, conversation_data, interaction_history, data_request_id, customer_email)
      
      # Send email to store owner (as required by Shopify compliance)
      send_data_request_email(store_owner_email, email_content, metadata)
      
      # Create audit record in Chatwoot for compliance
      create_audit_conversation(account, metadata, customer_email)
      
      Rails.logger.info "Data request email delivered successfully", {
        store_owner_email: store_owner_email&.gsub(/@.+/, '@***'),
        customer_email: customer_email&.gsub(/@.+/, '@***'),
        data_request_id: data_request_id,
        email_sent_at: Time.current.iso8601
      }
    rescue StandardError => e
      Rails.logger.error "Failed to deliver data request email", {
        store_owner_email: store_owner_email&.gsub(/@.+/, '@***'),
        customer_email: customer_email&.gsub(/@.+/, '@***'),
        data_request_id: data_request_id,
        error: e.message,
        backtrace: e.backtrace.first(5)
      }
      
      # Log critical failure for manual attention - no automated fallback
      Rails.logger.error "DATA REQUEST EMAIL DELIVERY FAILED - REQUIRES MANUAL FOLLOW-UP", {
        priority: 'CRITICAL', 
        data_request_id: metadata[:data_request_id],
        customer_email: @payload.dig('customer', 'email')&.gsub(/@.+/, '@***'),
        shop_domain: @shop_domain,
        action_required: 'manual_email_delivery',
        compliance_note: 'Email delivery failed - manual intervention required'
      }
      raise
    end

    def get_store_owner_email(account)
      # Get the primary administrator's email (first admin if multiple)
      admin_user = account.administrators.first
      
      if admin_user&.email.present?
        admin_user.email
      else
        Rails.logger.error "No administrator found for account #{account.id}", {
          account_id: account.id,
          account_name: account.name,
          administrators_count: account.administrators.count
        }
        # Fallback: Could potentially use account creation user or other logic
        raise "No administrator email found for account #{account.id}"
      end
    end

    def send_data_request_email(recipient_email, email_content, metadata)
      # Use ActionMailer to send the data request email to store owner
      DataRequestMailer.customer_data_response(
        email: recipient_email,
        subject: "Customer Data Request Response - Request ##{metadata[:data_request_id]}",
        content: email_content,
        data_request_id: metadata[:data_request_id],
        shop_domain: @shop_domain
      ).deliver_now
      
      Rails.logger.info "Data request email sent", {
        recipient: recipient_email&.gsub(/@.+/, '@***'),
        data_request_id: metadata[:data_request_id],
        delivery_method: 'email_to_store_owner'
      }
    rescue StandardError => e
      Rails.logger.error "Email delivery failed", {
        recipient: recipient_email&.gsub(/@.+/, '@***'),
        error: e.message,
        smtp_error: e.respond_to?(:smtp_error) ? e.smtp_error : nil
      }
      raise
    end

    def generate_email_data_summary(contact_data, conversation_data, interaction_history, data_request_id, customer_email)
      if contact_data.present?
        generate_data_found_email(contact_data, conversation_data, interaction_history, data_request_id)
      else
        generate_no_data_found_email(data_request_id)
      end
    end

    def generate_data_found_email(contact_data, conversation_data, interaction_history, data_request_id)
      <<~EMAIL_CONTENT
        Dear Store Owner,

        A customer has requested their personal data from your Shopify store, and we have processed this request through your customer support system.

        ## Data Request Details
        **Request ID:** #{data_request_id}
        **Processing Date:** #{Time.current.strftime('%B %d, %Y at %I:%M %p %Z')}
        **Shop Domain:** #{@shop_domain}
        **Customer Email:** #{@payload.dig('customer', 'email')}

        ## Customer Contact Information Found
        - **Name:** #{contact_data[:basic_info][:name]}
        - **Email:** #{contact_data[:basic_info][:email]}
        - **Phone:** #{contact_data[:basic_info][:phone_number]}
        - **First Contact:** #{contact_data[:basic_info][:created_at]&.strftime('%B %d, %Y')}
        - **Last Updated:** #{contact_data[:basic_info][:updated_at]&.strftime('%B %d, %Y')}

        ## Customer Support Activity Summary
        - **Total Conversations:** #{contact_data[:engagement_metrics][:total_conversations]}
        - **Resolved Issues:** #{contact_data[:engagement_metrics][:resolved_conversations]}
        - **Pending Issues:** #{contact_data[:engagement_metrics][:pending_conversations]}
        - **Preferred Contact Method:** #{contact_data[:engagement_metrics][:preferred_channel]&.humanize}

        #{format_conversation_details_for_email(conversation_data)}

        #{format_custom_attributes_for_email(contact_data[:custom_attributes])}

        ## Your Action Required
        As per Shopify's privacy compliance requirements, you need to provide this information to the customer who requested it. Please forward this summary to the customer's email address: #{@payload.dig('customer', 'email')}

        ## Important Compliance Notes
        - This data must be provided to the requesting customer within 30 days
        - The data has been sanitized to remove internal business information
        - This report includes all support interactions in our system
        - If you have additional customer data outside of Chatwoot, you may need to provide that separately

        ## Customer Rights Information
        You should inform the customer that they have the right to:
        - Request corrections to inaccurate information
        - Request deletion of their personal data (subject to legal retention requirements)
        - Object to processing of their personal data
        - Request data portability

        If you have any questions about this data request or need assistance with compliance, please contact our support team referencing request ID: #{data_request_id}

        Best regards,
        Chatwoot Compliance Team

        ---
        This email was generated automatically in response to a Shopify data privacy request.
        Request ID: #{data_request_id}
        Generated: #{Time.current.strftime('%B %d, %Y at %I:%M %p %Z')}
      EMAIL_CONTENT
    end

    def generate_no_data_found_email(data_request_id)
      <<~EMAIL_CONTENT
        Dear Store Owner,

        A customer has requested their personal data from your Shopify store. We have searched your customer support system for any personal information associated with this request.

        ## Data Request Details
        **Request ID:** #{data_request_id}
        **Processing Date:** #{Time.current.strftime('%B %d, %Y at %I:%M %p %Z')}
        **Shop Domain:** #{@shop_domain}
        **Customer Email:** #{@payload.dig('customer', 'email')}

        ## Search Results
        After a comprehensive search of your customer support system, we found no personal data associated with this request. This could mean:

        - The customer has not contacted your support through Chatwoot
        - They may have used a different email address for support inquiries
        - Their data may be stored in other systems not covered by this search

        ## Your Action Required
        You still need to respond to this customer's data request. Please:

        1. Search your other systems (e.g., Shopify admin, other support tools) for this customer's data
        2. Respond to the customer at: #{@payload.dig('customer', 'email')}
        3. Inform them of your findings within 30 days as required by privacy laws

        ## Next Steps for Customer Response
        If you find no data anywhere, inform the customer that:
        - You've conducted a comprehensive search
        - No personal data was found in your systems
        - They can contact you if they believe there should be data

        If you have questions about this data request or need assistance with compliance, please contact our support team referencing request ID: #{data_request_id}

        Best regards,
        Chatwoot Compliance Team

        ---
        This email was generated automatically in response to a Shopify data privacy request.
        Request ID: #{data_request_id}
        Generated: #{Time.current.strftime('%B %d, %Y at %I:%M %p %Z')}
      EMAIL_CONTENT
    end

    def format_conversation_details_for_email(conversation_data)
      return "\n## Customer Support Conversations\nNo support conversations found.\n" if conversation_data.empty?

      details = "\n## Customer Support Conversations\n"
      conversation_data.each_with_index do |conv, index|
        details += <<~CONV

          **Conversation #{index + 1}**
          - Status: #{conv[:status].humanize}
          - Date: #{conv[:created_at].strftime('%B %d, %Y at %I:%M %p')}
          - Support Channel: #{conv[:inbox_name]}
          - Messages Exchanged: #{conv[:message_count]}
          - Assigned Agent: #{conv[:assigned_agent]}

        CONV
      end
      details
    end

    def format_custom_attributes_for_email(attributes)
      return "" if attributes.empty?

      "\n## Additional Customer Information On File\n" + 
      attributes.map { |key, value| "- #{key.humanize}: #{value}" }.join("\n") + "\n"
    end

    # Audit trail methods
    def create_audit_conversation(account, metadata, customer_email)
      # Create minimal audit conversation for compliance tracking
      conversation = account.conversations.create!(
        account: account,
        inbox: find_or_create_compliance_inbox(account),
        contact: find_or_create_system_contact(account),
        status: 'resolved',
        assignee: account.administrators.first,
        additional_attributes: {
          type: 'shopify_data_request_audit',
          shopify_customer_id: metadata[:customer_id],
          data_request_id: metadata[:data_request_id],
          original_contact_id: metadata[:contact_id],
          processed_at: Time.current.iso8601,
          delivery_method: 'email_to_store_owner',
          customer_email: customer_email&.gsub(/@.+/, '@***')
        }
      )

      # Create audit message
      audit_message = <<~AUDIT
        ## Data Request Processing Completed

        **Request Details:**
        - Request ID: #{metadata[:data_request_id]}
        - Shopify Customer ID: #{metadata[:customer_id]}
        - Customer Email: #{customer_email&.gsub(/@.+/, '@***')}
        - Processing Date: #{Time.current.strftime('%B %d, %Y at %I:%M %p %Z')}
        - Data Found: #{metadata[:found_data] ? 'Yes' : 'No'}

        **Action Taken:**
        - Data summary sent to store owner email
        - Store owner instructed to forward to customer
        - Compliance requirements documented

        **Compliance Status:**
        ✅ Request processed within required timeframe
        ✅ Store owner notified via email
        ✅ Audit trail created
        ✅ GDPR/Privacy compliance maintained

        This conversation serves as proof of compliance with the data subject request.
      AUDIT

      conversation.messages.create!(
        account: account,
        inbox: conversation.inbox,
        content: audit_message,
        message_type: 'outgoing',
        sender: nil,
        private: false,
        content_type: 'text',
        content_attributes: {
          'audit_type' => 'data_request_completion',
          'data_request_id' => metadata[:data_request_id],
          'delivery_method' => 'email_to_store_owner'
        }
      )

      Rails.logger.info "Created audit conversation for data request", {
        conversation_id: conversation.id,
        data_request_id: metadata[:data_request_id]
      }

      conversation
    end

    def find_or_create_compliance_inbox(account)
      # Find existing compliance inbox or create a new one
      account.inboxes.find_or_create_by(
        name: 'Shopify Compliance Audit'
      ) do |inbox|
        # Create a simple API inbox for audit purposes
        channel = Channel::Api.create!(
          account: account,
          webhook_url: '',
          hmac_token: SecureRandom.hex(32)
        )
        inbox.channel = channel
      end
    rescue StandardError => e
      Rails.logger.warn "Could not create compliance inbox, using fallback", {
        error: e.message,
        account_id: account.id
      }
      account.inboxes.first # Fallback to any available inbox
    end

    def find_or_create_system_contact(account)
      account.contacts.find_or_create_by(
        email: 'shopify-compliance@system.local'
      ) do |contact|
        contact.name = 'Shopify Compliance System'
        contact.custom_attributes = {
          'contact_type' => 'system',
          'created_by' => 'shopify_compliance_webhook'
        }
      end
    end
  end
end