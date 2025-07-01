# frozen_string_literal: true

class DataRequestMailer < ApplicationMailer
  default from: ENV.fetch('COMPLIANCE_EMAIL_FROM', 'privacy@chatwoot.com')

  def customer_data_response(email:, subject:, content:, data_request_id:, shop_domain:)
    @content = content
    @data_request_id = data_request_id
    @shop_domain = shop_domain
    @generated_at = Time.current

    Rails.logger.info "Sending data request email", {
      recipient: email&.gsub(/@.+/, '@***'),
      data_request_id: data_request_id,
      shop_domain: shop_domain
    }

    mail(
      to: email,
      subject: subject,
      content_type: 'text/plain'
    ) do |format|
      format.text { render plain: @content }
    end
  end
end 