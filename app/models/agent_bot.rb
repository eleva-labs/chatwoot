# == Schema Information
#
# Table name: agent_bots
#
#  id           :bigint           not null, primary key
#  bot_config   :jsonb
#  bot_type     :integer          default("webhook")
#  description  :string
#  name         :string
#  outgoing_url :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint
#
# Indexes
#
#  index_agent_bots_on_account_id  (account_id)
#

class AgentBot < ApplicationRecord
  include AccessTokenable
  include Avatarable
  include Events::Types

  has_many :agent_bot_inboxes, dependent: :destroy_async
  has_many :inboxes, through: :agent_bot_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  belongs_to :account, optional: true
  enum bot_type: { webhook: 0 }

  validates :outgoing_url, length: { maximum: Limits::URL_LENGTH_LIMIT }

  after_create_commit :notify_creation
  after_destroy_commit :dispatch_destroy_event

  def available_name
    name
  end

  def push_event_data(inbox = nil)
    {
      id: id,
      name: name,
      avatar_url: avatar_url || inbox&.avatar_url,
      type: 'agent_bot'
    }
  end

  def webhook_data
    {
      id: id,
      name: name,
      type: 'agent_bot'
    }
  end

  # Generate webhook URL for AI Backend integration
  # @return [String, nil] Webhook URL or nil for system bots
  def generate_webhook_url
    return nil if account_id.nil? # System bots don't need webhooks

    base_url = ai_backend_api_url
    query_params = {
      store_id: account_id,
      agent_system_id: id,
      id_type: AiBackendService::Constants::IdType::EXTERNAL
    }

    "#{base_url}/api/webhooks/chatwoot/message?#{query_params.to_query}"
  end

  def system_bot?
    account.nil?
  end

  private

  # Get AI Backend API URL from configuration
  # Priority: config > ENV > credentials
  # @return [String] AI Backend base URL
  def ai_backend_api_url
    Rails.application.config.ai_backend_api_url ||
      ENV['AI_BACKEND_URL'] ||
      Rails.application.credentials.ai_backend_api_url
  end

  def notify_creation
    return if system_bot? # Skip system bots

    # Dispatch agent bot creation event first
    Rails.configuration.dispatcher.dispatch(
      AGENT_BOT_CREATED,
      Time.zone.now,
      agent_bot: self
    )

    # Dispatch token update event AFTER creation event to ensure proper ordering
    # This ensures CreateAgentSystemJob runs before SyncBotTokenJob
    # NOTE: AccessToken is already created via after_create callback from AccessTokenable
    dispatch_bot_token_event if access_token.present?
  end

  def dispatch_bot_token_event
    Rails.configuration.dispatcher.dispatch(
      BOT_TOKEN_UPDATED,
      Time.zone.now,
      agent_bot: self,
      account: account,
      token: access_token.token
    )
    Rails.logger.info "Dispatched bot_token_updated event for agent_bot #{id}, account #{account_id}"
  rescue StandardError => e
    Rails.logger.error "Failed to dispatch bot_token_updated event: #{e.message}"
    # Don't raise - agent bot creation should succeed even if token sync fails
  end

  def dispatch_destroy_event
    return if system_bot? # Skip system bots

    Rails.configuration.dispatcher.dispatch(
      AGENT_BOT_DELETED,
      Time.zone.now,
      agent_bot_id: id,
      account_id: account_id
    )
  end
end
