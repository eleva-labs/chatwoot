# frozen_string_literal: true

module AiBackendService::Schemas
  # Store creation/update request schema
  StoreRequest = Struct.new(
    :name,
    :email,
    :external_id,
    :is_active,
    :custom_attributes,
    keyword_init: true
  ) do
    def to_h
      {
        name: name,
        email: email,
        external_id: external_id.to_s,
        is_active: is_active,
        custom_attributes: custom_attributes || {}
      }
    end

    def self.from_account(account, user_email)
      new(
        name: account.name,
        email: user_email,
        external_id: account.id,
        is_active: true,
        custom_attributes: {}
      )
    end
  end

  # Store response schema
  StoreResponse = Struct.new(
    :id,
    :name,
    :email,
    :is_active,
    :external_id,
    :custom_attributes,
    keyword_init: true
  ) do
    def self.from_api(hash)
      new(**hash.symbolize_keys)
    end
  end

  # Agent system creation/update request schema
  AgentSystemRequest = Struct.new(
    :name,
    :external_id,
    :store_id,
    :description,
    :is_active,
    keyword_init: true
  ) do
    def to_h
      {
        name: name,
        external_id: external_id.to_s,
        store_id: store_id,
        description: description,
        is_active: is_active
      }
    end

    def self.from_agent_bot(agent_bot, store_id)
      new(
        name: agent_bot.name,
        external_id: agent_bot.id,
        store_id: store_id,
        description: agent_bot.description || '',
        is_active: true
      )
    end
  end

  # User creation/update request schema
  UserRequest = Struct.new(
    :name,
    :email,
    :external_id,
    :store_id,
    :is_active,
    keyword_init: true
  ) do
    def to_h
      {
        name: name,
        email: email,
        external_id: external_id.to_s,
        store_id: store_id,
        is_active: is_active
      }
    end

    def self.from_user(user, store_id)
      new(
        name: user.name,
        email: user.email,
        external_id: user.id,
        store_id: store_id,
        is_active: true
      )
    end
  end
end
