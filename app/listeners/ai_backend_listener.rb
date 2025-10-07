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

    AiBackend::DeleteAgentSystemJob.perform_later(agent_bot_id)

    Rails.logger.info "AI Backend: Enqueued agent system deletion for bot #{agent_bot_id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue agent system deletion for bot #{agent_bot_id}: #{e.message}"
  end

  # Handle user removal from account -> delete user from AI backend
  def agent_removed(event)
    user_id = event.data[:user_id]

    return unless user_id

    AiBackend::DeleteUserJob.perform_later(user_id)

    Rails.logger.info "AI Backend: Enqueued user deletion for user #{user_id}"
  rescue StandardError => e
    Rails.logger.error "AI Backend: Failed to enqueue user deletion for user #{user_id}: #{e.message}"
  end
end
