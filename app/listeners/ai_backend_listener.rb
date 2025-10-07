# frozen_string_literal: true

class AiBackendListener < BaseListener
  # Handle account creation -> create store in AI backend
  def account_created(event)
    account = event.data[:account]
    user = account.users.first
    user_email = user&.email || account.support_email

    # Create store with account.id as external_id
    store_service = AiBackendService::StoreService.new
    store_service.create_store(account, user_email)

    Rails.logger.info "AI Backend: Store created for account #{account.id} (external_id)"
  rescue AiBackendService::StoreService::StoreError => e
    Rails.logger.error "AI Backend: Store creation failed for account #{account.id}: #{e.message}"
    # TODO: Retry strategy
  end

  # Handle agent bot creation -> create agent system in AI backend
  def agent_bot_created(event)
    agent_bot = event.data[:agent_bot]
    account = agent_bot.account

    return unless account # Skip system bots (account_id is nil)

    # Get store by account.id using external_id lookup
    store_service = AiBackendService::StoreService.new
    store_service.get_store(account.id) # Verify store exists

    # Create agent system with bot.id as external_id, using account.id as store external_id
    agent_system_service = AiBackendService::AgentSystemService.new
    agent_system_service.create_agent_system(agent_bot, account.id)

    Rails.logger.info "AI Backend: Agent system created for bot #{agent_bot.id} (external_id)"
  rescue AiBackendService::StoreService::StoreError, AiBackendService::AgentSystemService::AgentSystemError => e
    Rails.logger.error "AI Backend: Agent system creation failed for bot #{agent_bot.id}: #{e.message}"
    # TODO: Retry strategy
  end

  # Handle user addition to account -> create user in AI backend
  def agent_added(event)
    account = event.data[:account]

    # Find the account_user that was just created
    account_user = event.data[:account_user]
    user = account_user&.user

    return unless user

    # Get store by account.id using external_id lookup
    store_service = AiBackendService::StoreService.new
    store_service.get_store(account.id) # Verify store exists

    # Create user with user.id as external_id, using account.id as store external_id
    user_service = AiBackendService::UserService.new
    user_service.create_user(user, account.id)

    Rails.logger.info "AI Backend: User created for user #{user.id} in account #{account.id} (external_id)"
  rescue AiBackendService::StoreService::StoreError, AiBackendService::UserService::UserError => e
    Rails.logger.error "AI Backend: User creation failed for user #{user&.id}: #{e.message}"
    # TODO: Retry strategy
  end
end
