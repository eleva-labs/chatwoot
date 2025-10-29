# frozen_string_literal: true

class AiBackendListener < BaseListener
  # Handle account creation -> create store in AI backend
  def account_created(event)
    account = event.data[:account]
    user = account.users.first
    user_email = user&.email || account.support_email

    AiBackend::CreateStoreJob.perform_later(account.id, user_email)

    Rails.logger.info "AI Backend: Enqueued store creation for account #{account.id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue store creation for account #{account.id}: #{e.message}"
  end

  # Handle agent bot creation -> create agent system in AI backend
  def agent_bot_created(event)
    agent_bot = event.data[:agent_bot]
    account = agent_bot.account

    return unless account # Skip system bots (account_id is nil)

    AiBackend::CreateAgentSystemJob.perform_later(agent_bot.id, account.id)

    Rails.logger.info "AI Backend: Enqueued agent system creation for bot #{agent_bot.id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue agent system creation for bot #{agent_bot.id}: #{e.message}"
  end

  # Handle user addition to account -> create user in AI backend
  def agent_added(event)
    account = event.data[:account]

    # Find the account_user that was just created
    account_user = event.data[:account_user]
    user = account_user&.user

    return unless user

    AiBackend::CreateUserJob.perform_later(user.id, account.id)

    # If this user is an owner (administrator with nil inviter) and has a token,
    # sync it to the store (handles SuperAdmin adding existing owner to new account)
    if account.owner?(user) && user.access_token.present?
      Rails.configuration.dispatcher.dispatch(
        Events::Types::OWNER_TOKEN_UPDATED,
        Time.zone.now,
        account: account,
        user: user,
        token: user.access_token.token
      )
      Rails.logger.info "AI Backend: Dispatched owner token sync for user #{user.id} in account #{account.id}"
    end

    Rails.logger.info "AI Backend: Enqueued user creation for user #{user.id} in account #{account.id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue user creation for user #{user&.id}: #{e.message}"
  end

  # Handle account deletion -> delete store from AI backend
  def account_deleted(event)
    account_id = event.data[:account_id]

    AiBackend::DeleteStoreJob.perform_later(account_id)

    Rails.logger.info "AI Backend: Enqueued store deletion for account #{account_id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue store deletion for account #{account_id}: #{e.message}"
  end

  # Handle agent bot deletion -> delete agent system from AI backend
  def agent_bot_deleted(event)
    agent_bot_id = event.data[:agent_bot_id]
    account_id = event.data[:account_id]

    AiBackend::DeleteAgentSystemJob.perform_later(agent_bot_id, account_id)

    Rails.logger.info "AI Backend: Enqueued agent system deletion for bot #{agent_bot_id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue agent system deletion for bot #{agent_bot_id}: #{e.message}"
  end

  # Handle user removal from account -> delete user from AI backend
  def agent_removed(event)
    user_id = event.data[:user_id]
    account_id = event.data[:account_id]

    return unless user_id

    AiBackend::DeleteUserJob.perform_later(user_id, account_id)

    Rails.logger.info "AI Backend: Enqueued user deletion for user #{user_id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue user deletion for user #{user_id}: #{e.message}"
  end

  # Handle inbox creation -> create channel in AI backend
  def inbox_created(event)
    inbox = event.data[:inbox]
    account = inbox.account

    AiBackend::CreateChannelJob.perform_later(inbox.id, account.id)

    Rails.logger.info "AI Backend: Enqueued channel creation for inbox #{inbox.id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue channel creation for inbox #{inbox.id}: #{e.message}"
  end

  # Handle inbox deletion -> delete channel from AI backend
  def inbox_deleted(event)
    inbox_id = event.data[:inbox_id]
    account_id = event.data[:account_id]

    AiBackend::DeleteChannelJob.perform_later(inbox_id, account_id)

    Rails.logger.info "AI Backend: Enqueued channel deletion for inbox #{inbox_id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue channel deletion for inbox #{inbox_id}: #{e.message}"
  end

  # Handle agent bot assignment to inbox -> assign agent system to channel in AI backend
  def agent_bot_inbox_created(event)
    agent_bot_inbox = event.data[:agent_bot_inbox]

    AiBackend::AssignAgentBotToChannelJob.perform_later(
      agent_bot_inbox.agent_bot_id,
      agent_bot_inbox.inbox_id,
      agent_bot_inbox.inbox.account_id
    )

    Rails.logger.info "AI Backend: Enqueued agent bot #{agent_bot_inbox.agent_bot_id} assignment to channel #{agent_bot_inbox.inbox_id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue agent bot assignment: #{e.message}"
  end

  # Handle agent bot unassignment from inbox -> unassign agent system from channel in AI backend
  def agent_bot_inbox_deleted(event)
    agent_bot_id = event.data[:agent_bot_id]
    inbox_id = event.data[:inbox_id]
    account_id = event.data[:account_id]

    AiBackend::UnassignAgentBotFromChannelJob.perform_later(inbox_id, account_id)

    Rails.logger.info "AI Backend: Enqueued agent bot #{agent_bot_id} unassignment from channel #{inbox_id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue agent bot unassignment: #{e.message}"
  end

  # Handle owner token updates -> sync to AI backend store configuration
  def owner_token_updated(event)
    account = event.data[:account]
    user = event.data[:user]
    token = event.data[:token]

    AiBackend::SyncOwnerTokenJob.perform_later(account.id, user.id, token)

    Rails.logger.info "AI Backend: Enqueued owner token sync for account #{account.id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue owner token sync for account #{account.id}: #{e.message}"
  end

  # Handle bot token updates -> sync to AI backend agent system configuration
  def bot_token_updated(event)
    agent_bot = event.data[:agent_bot]
    account = event.data[:account]
    token = event.data[:token]

    AiBackend::SyncBotTokenJob.perform_later(agent_bot.id, account.id, token)

    Rails.logger.info "AI Backend: Enqueued bot token sync for agent_bot #{agent_bot.id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue bot token sync for agent_bot #{agent_bot.id}: #{e.message}"
  end
end
