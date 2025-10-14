# == Schema Information
#
# Table name: agent_bot_inboxes
#
#  id           :bigint           not null, primary key
#  status       :integer          default("active")
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :integer
#  agent_bot_id :integer
#  inbox_id     :integer
#

class AgentBotInbox < ApplicationRecord
  validates :inbox_id, presence: true
  validates :agent_bot_id, presence: true
  before_validation :ensure_account_id

  belongs_to :inbox
  belongs_to :agent_bot
  belongs_to :account
  enum status: { active: 0, inactive: 1 }

  # Event callbacks for AI Backend synchronization
  after_create_commit :dispatch_create_event
  after_destroy_commit :dispatch_destroy_event

  private

  def ensure_account_id
    self.account_id = inbox&.account_id
  end

  # Dispatch event when agent bot is assigned to inbox
  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(
      Events::Types::AGENT_BOT_INBOX_CREATED,
      Time.zone.now,
      agent_bot_inbox: self
    )
  end

  # Dispatch event when agent bot is unassigned from inbox
  # Note: Object is destroyed at this point, so we pass IDs instead
  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(
      Events::Types::AGENT_BOT_INBOX_DELETED,
      Time.zone.now,
      agent_bot_inbox_id: id,
      agent_bot_id: agent_bot_id,
      inbox_id: inbox_id,
      account_id: account_id
    )
  end
end
