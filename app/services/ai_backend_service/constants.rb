# frozen_string_literal: true

module AiBackendService::Constants
  # ID types for querying resources
  module IdType
    EXTERNAL = 'external' # Chatwoot IDs (account.id, bot.id, user.id)
    INTERNAL = 'internal' # AI Backend UUIDs

    ALL = [EXTERNAL, INTERNAL].freeze

    def self.valid?(id_type)
      ALL.include?(id_type)
    end
  end

  # Configuration scopes (resource types that can have configurations)
  module Scope
    STORE = 'store'
    AGENT_SYSTEM = 'agent_system'
    USER = 'user'
    CHANNEL = 'channel'

    ALL = [STORE, AGENT_SYSTEM, USER, CHANNEL].freeze

    def self.valid?(scope)
      ALL.include?(scope)
    end
  end

  # Configuration keys for different config types
  module ConfigKey
    # Store configurations
    NOTIFICATIONS = 'notifications_config'
    MESSAGING = 'messaging_config'
    GENERAL_STORE = 'general_store_config'
    ECOMMERCE = 'ecommerce_config'
    CALENDLY = 'calendly_config'
    CONVERSATION = 'conversation_config'

    # Agent configurations
    AGENT_BEHAVIOR = 'agent_behavior_config'
    AGENT_KNOWLEDGE = 'agent_knowledge_config'

    # User configurations
    USER_PREFERENCES = 'user_preferences_config'

    ALL = [
      NOTIFICATIONS,
      MESSAGING,
      GENERAL_STORE,
      ECOMMERCE,
      CALENDLY,
      CONVERSATION,
      AGENT_BEHAVIOR,
      AGENT_KNOWLEDGE,
      USER_PREFERENCES
    ].freeze

    STORE_CONFIGS = [
      NOTIFICATIONS,
      MESSAGING,
      GENERAL_STORE,
      ECOMMERCE,
      CALENDLY,
      CONVERSATION
    ].freeze

    AGENT_CONFIGS = [
      AGENT_BEHAVIOR,
      AGENT_KNOWLEDGE
    ].freeze

    USER_CONFIGS = [
      USER_PREFERENCES
    ].freeze

    def self.valid?(config_key)
      ALL.include?(config_key)
    end

    def self.for_scope(scope)
      case scope
      when Scope::STORE
        STORE_CONFIGS
      when Scope::AGENT_SYSTEM
        AGENT_CONFIGS
      when Scope::USER
        USER_CONFIGS
      else
        []
      end
    end
  end

  # HTTP methods
  module HttpMethod
    GET = 'get'
    POST = 'post'
    PUT = 'put'
    PATCH = 'patch'
    DELETE = 'delete'

    ALL = [GET, POST, PUT, PATCH, DELETE].freeze
  end
end
