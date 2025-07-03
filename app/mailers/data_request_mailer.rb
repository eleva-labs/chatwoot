# frozen_string_literal: true

class DataRequestMailer < ApplicationMailer
  default from: ENV.fetch('COMPLIANCE_EMAIL_FROM', 'privacy@chatwoot.com')

  def customer_data_response(email:, subject:, content:, data_request_id:, shop_domain:)
    @content = content
    @data_request_id = data_request_id
    @shop_domain = shop_domain
    @generated_at = Time.current

    context = {
      recipient: email&.gsub(/@.+/, '@***'),
      data_request_id: data_request_id,
      shop_domain: shop_domain
    }
    Rails.logger.info "Sending data request email: #{context.to_json}"

    mail(
      to: email,
      subject: subject,
      content_type: 'text/plain'
    ) do |format|
      format.text { render plain: @content }
    end
  end
end 