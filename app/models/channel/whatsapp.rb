# == Schema Information
#
# Table name: channel_whatsapp
#
#  id                             :bigint           not null, primary key
#  message_templates              :jsonb
#  message_templates_last_updated :datetime
#  phone_number                   :string           not null
#  provider                       :string           default("default")
#  provider_config                :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :integer          not null
#
# Indexes
#
#  index_channel_whatsapp_on_phone_number  (phone_number) UNIQUE
#

class Channel::Whatsapp < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_whatsapp'
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }].freeze

  # Override default threshold (2) from Reauthorizable concern
  # Higher threshold for WhatsApp/Whapi due to transient 401 errors during reconnection cycles
  AUTHORIZATION_ERROR_THRESHOLD = 3

  # default at the moment is 360dialog lets change later.
  PROVIDERS = %w[default whatsapp_cloud whapi].freeze
  before_validation :ensure_webhook_verify_token

  validates :provider, inclusion: { in: PROVIDERS }
  validates :phone_number, presence: true, uniqueness: true
  validate :validate_provider_config

  after_create :sync_templates
  after_destroy_commit :perform_provider_cleanup
  after_update :invalidate_provider_cache, if: -> { saved_change_to_provider_config? || saved_change_to_provider? }
  before_destroy :teardown_webhooks
  before_destroy :logout_user_from_whapi

  def name
    'Whatsapp'
  end

  def provider_config_object
    @provider_config_object ||= Whatsapp::ProviderConfigFactory.create(self)
  end

  def provider_service
    @provider_service ||= Whatsapp::ProviderServiceFactory.create(self)
  end

  def mark_message_templates_updated
    # rubocop:disable Rails/SkipsModelValidations
    update_column(:message_templates_last_updated, Time.zone.now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  delegate :send_message, to: :provider_service
  delegate :send_template, to: :provider_service
  delegate :sync_templates, to: :provider_service
  delegate :media_url, to: :provider_service
  delegate :api_headers, to: :provider_service

  def setup_webhooks
    perform_webhook_setup
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Webhook setup failed: #{e.message}"
    prompt_reauthorization!
  end

  private

  def ensure_webhook_verify_token
    provider_config['webhook_verify_token'] ||= SecureRandom.hex(16) if provider == 'whatsapp_cloud'
  end

  def validate_provider_config
    errors.add(:provider_config, 'Invalid Credentials') unless provider_config_object.validate_config?
  end

  def perform_provider_cleanup
    provider_config_object.cleanup_on_destroy
  end

  def invalidate_provider_cache
    @provider_config_object = nil
    @provider_service = nil
  end

  def perform_webhook_setup
    business_account_id = provider_config['business_account_id']
    api_key = provider_config['api_key']

    Whatsapp::WebhookSetupService.new(self, business_account_id, api_key).perform
  end

  def teardown_webhooks
    Whatsapp::WebhookTeardownService.new(self).perform
  end

  def logout_user_from_whapi
    return unless provider == 'whapi'
    return unless provider_config_object.respond_to?(:whapi_partner_channel?) && provider_config_object.whapi_partner_channel?

    # Extract channel token for logout
    channel_token = provider_config_object.api_key || provider_config_object.whapi_channel_token

    if channel_token.blank?
      Rails.logger.warn("[Channel::Whatsapp] No channel_token available for channel ##{id}, skipping logout")
      return
    end

    Rails.logger.info("[Channel::Whatsapp] Logging out user from Whapi before destroying channel ##{id}")
    service = Whatsapp::Partner::WhapiPartnerService.new
    service.logout_user(channel_token: channel_token)
  rescue StandardError => e
    # Don't block channel destruction if logout fails - log and continue
    Rails.logger.error("[Channel::Whatsapp] Failed to logout user from Whapi for channel ##{id}: #{e.message}")
    Rails.logger.error("[Channel::Whatsapp] Logout error backtrace: #{e.backtrace&.first(3)&.join("\n")}")
  end
end
