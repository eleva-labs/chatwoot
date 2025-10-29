# == Schema Information
#
# Table name: access_tokens
#
#  id         :bigint           not null, primary key
#  owner_type :string
#  token      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  owner_id   :bigint
#
# Indexes
#
#  index_access_tokens_on_owner_type_and_owner_id  (owner_type,owner_id)
#  index_access_tokens_on_token                    (token) UNIQUE
#

class AccessToken < ApplicationRecord
  include Events::Types

  has_secure_token :token
  belongs_to :owner, polymorphic: true

  after_create :notify_token_change
  after_update :notify_token_change, if: :saved_change_to_token?

  private

  def notify_token_change
    case owner_type
    when 'User'
      notify_owner_token_change
    when 'AgentBot'
      notify_bot_token_change
    end
  end

  def notify_owner_token_change
    return unless owner.is_a?(User)

    # Sync token for all accounts where user is owner
    owner.accounts.each do |account|
      next unless account.owner?(owner)

      Rails.configuration.dispatcher.dispatch(
        OWNER_TOKEN_UPDATED,
        Time.zone.now,
        account: account,
        user: owner,
        token: token
      )
    end
  end

  def notify_bot_token_change
    return unless owner.is_a?(AgentBot)
    return unless owner.account # Skip system bots (account_id IS NULL)

    # Skip automatic dispatch on creation - AgentBot handles this manually
    # to ensure proper event ordering (AGENT_BOT_CREATED before BOT_TOKEN_UPDATED)
    # Only dispatch on token updates (not creation)
    return if saved_change_to_id? # Skip on create (when id changes from nil)

    Rails.configuration.dispatcher.dispatch(
      BOT_TOKEN_UPDATED,
      Time.zone.now,
      agent_bot: owner,
      account: owner.account,
      token: token
    )
  end
end
