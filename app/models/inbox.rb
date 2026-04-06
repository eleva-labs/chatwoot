# frozen_string_literal: true

# == Schema Information
#
# Table name: inboxes
#
#  id                            :integer          not null, primary key
#  allow_messages_after_resolved :boolean          default(TRUE)
#  auto_assignment_config        :jsonb
#  business_name                 :string
#  channel_type                  :string
#  csat_config                   :jsonb            not null
#  csat_survey_enabled           :boolean          default(FALSE)
#  email_address                 :string
#  enable_auto_assignment        :boolean          default(FALSE)
#  enable_email_collect          :boolean          default(TRUE)
#  greeting_enabled              :boolean          default(FALSE)
#  greeting_message              :string
#  lock_to_single_conversation   :boolean          default(FALSE), not null
#  name                          :string           not null
#  out_of_office_message         :string
#  sender_name_type              :integer          default("friendly"), not null
#  timezone                      :string           default("UTC")
#  working_hours_enabled         :boolean          default(FALSE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :integer          not null
#  channel_id                    :integer          not null
#  portal_id                     :bigint
#
# Indexes
#
#  index_inboxes_on_account_id                   (account_id)
#  index_inboxes_on_channel_id_and_channel_type  (channel_id,channel_type)
#  index_inboxes_on_portal_id                    (portal_id)
#
# Foreign Keys
#
#  fk_rails_...  (portal_id => portals.id)
#

class Inbox < ApplicationRecord
  include Reportable
  include Avatarable
  include OutOfOffisable
  include AccountCacheRevalidator

  # Not allowing characters:
  validates :name, presence: true
  validates :account_id, presence: true
  validates :timezone, inclusion: { in: TZInfo::Timezone.all_identifiers }
  validates :out_of_office_message, length: { maximum: Limits::OUT_OF_OFFICE_MESSAGE_MAX_LENGTH }
  validates :greeting_message, length: { maximum: Limits::GREETING_MESSAGE_MAX_LENGTH }
  validate :ensure_valid_max_assignment_limit

  belongs_to :account
  belongs_to :portal, optional: true

  belongs_to :channel, polymorphic: true, dependent: :destroy

  has_many :campaigns, dependent: :destroy_async
  has_many :contact_inboxes, dependent: :destroy_async
  has_many :contacts, through: :contact_inboxes

  has_many :inbox_members, dependent: :destroy_async
  has_many :members, through: :inbox_members, source: :user
  has_many :conversations, dependent: :destroy_async
  has_many :messages, dependent: :destroy_async

  has_one :inbox_assignment_policy, dependent: :destroy
  has_one :assignment_policy, through: :inbox_assignment_policy
  has_one :agent_bot_inbox, dependent: :destroy_async
  has_one :agent_bot, through: :agent_bot_inbox
  has_many :webhooks, dependent: :destroy_async
  has_many :hooks, dependent: :destroy_async, class_name: 'Integrations::Hook'

  enum sender_name_type: { friendly: 0, professional: 1 }

  before_create :check_inbox_limit
  after_destroy :delete_round_robin_agents

  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event

  scope :order_by_name, -> { order('lower(name) ASC') }

  # Adds multiple members to the inbox
  # @param user_ids [Array<Integer>] Array of user IDs to add as members
  # @return [void]
  def add_members(user_ids)
    inbox_members.create!(user_ids.map { |user_id| { user_id: user_id } })
    update_account_cache
  end

  # Removes multiple members from the inbox
  # @param user_ids [Array<Integer>] Array of user IDs to remove
  # @return [void]
  def remove_members(user_ids)
    inbox_members.where(user_id: user_ids).destroy_all
    update_account_cache
  end

  # Sanitizes inbox name for balanced email provider compatibility
  # ALLOWS: /'._- and Unicode letters/numbers/emojis
  # REMOVES: Forbidden chars (\<>@") + spam-trigger symbols (!#$%&*+=?^`{|}~)
  def sanitized_name
    return default_name_for_blank_name if name.blank?

    sanitized = apply_sanitization_rules(name)
    sanitized.blank? && email? ? display_name_from_email : sanitized
  end

  def sms?
    channel_type == 'Channel::Sms'
  end

  def facebook?
    channel_type == 'Channel::FacebookPage'
  end

  def instagram?
    (facebook? || instagram_direct?) && channel.instagram_id.present?
  end

  def instagram_direct?
    channel_type == 'Channel::Instagram'
  end

  def web_widget?
    channel_type == 'Channel::WebWidget'
  end

  def api?
    channel_type == 'Channel::Api'
  end

  def email?
    channel_type == 'Channel::Email'
  end

  def twilio?
    channel_type == 'Channel::TwilioSms'
  end

  def twitter?
    channel_type == 'Channel::TwitterProfile'
  end

  def telegram?
    channel_type == 'Channel::Telegram'
  end

  def whatsapp?
    channel_type == 'Channel::Whatsapp'
  end

  def assignable_agents
    (account.users.where(id: members.select(:user_id)) + account.administrators).uniq
  end

  def active_bot?
    agent_bot_inbox&.active? || hooks.where(app_id: %w[dialogflow],
                                            status: 'enabled').count.positive?
  end

  def inbox_type
    channel.name
  end

  def webhook_data
    {
      id: id,
      name: name
    }
  end

  def callback_webhook_url
    case channel_type
    when 'Channel::TwilioSms'
      "#{ENV.fetch('FRONTEND_URL', nil)}/twilio/callback"
    when 'Channel::Sms'
      "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/sms/#{channel.phone_number.delete_prefix('+')}"
    when 'Channel::Line'
      "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/line/#{channel.line_channel_id}"
    when 'Channel::Whatsapp'
      "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/whatsapp/#{channel.phone_number}"
    end
  end

  def member_ids_with_assignment_capacity
    members.ids
  end

  # Agent bot working hours configuration
  # Determines if agent bot webhooks should respect business hours.
  # When enabled, incoming messages outside business hours will not trigger
  # agent bot webhooks, preventing conflicting automated responses.
  # Uses auto_assignment_config JSONB column to avoid migration (Chatwoot sync compatible).
  #
  # @return [Boolean] true if agent bot should respect working hours, false otherwise
  def agent_bot_respects_working_hours?
    auto_assignment_config&.dig('agent_bot_respects_working_hours') || false
  end

  # Sets the agent bot working hours respect flag
  #
  # @param value [Boolean] whether agent bot should respect working hours
  # @return [Boolean] the value that was set
  def agent_bot_respects_working_hours=(value)
    self.auto_assignment_config ||= {}
    self.auto_assignment_config['agent_bot_respects_working_hours'] = value
  end

  private

  def check_inbox_limit
    limit_service = Billing::UnifiedLimitService.new(account, :inbox)

    return true if limit_service.can_create?

    errors.add(:base, 'Inbox limit reached. Please purchase additional inbox seats or upgrade your plan.')
    throw :abort
  end

  def default_name_for_blank_name
    email? ? display_name_from_email : ''
  end

  def apply_sanitization_rules(name)
    name.gsub(/[\\<>@"!#$%&*+=?^`{|}~:;]/, '')         # Remove forbidden chars
        .gsub(/[\x00-\x1F\x7F]/, ' ')                   # Replace control chars with spaces
        .gsub(/\A[[:punct:]]+|[[:punct:]]+\z/, '')      # Remove leading/trailing punctuation
        .gsub(/\s+/, ' ')                               # Normalize spaces
        .strip
  end

  def display_name_from_email
    channel.email.split('@').first.parameterize.titleize
  end

  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(INBOX_CREATED, Time.zone.now, inbox: self)
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(INBOX_UPDATED, Time.zone.now, inbox: self, changed_attributes: previous_changes)
  end

  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(
      INBOX_DELETED,
      Time.zone.now,
      inbox_id: id,
      account_id: account_id,
      channel_type: channel_type
    )
  end

  def ensure_valid_max_assignment_limit
    # overridden in enterprise/app/models/enterprise/inbox.rb
  end

  def delete_round_robin_agents
    ::AutoAssignment::InboxRoundRobinService.new(inbox: self).clear_queue
  end

  def check_channel_type?
    ['Channel::Email', 'Channel::Api', 'Channel::WebWidget'].include?(channel_type)
  end
end

Inbox.prepend_mod_with('Inbox')
Inbox.include_mod_with('Audit::Inbox')
Inbox.include_mod_with('Concerns::Inbox')
