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

  # Configuration keys and their expected fields (based on AI Backend Python schemas)
  #
  # Note: All configs support partial updates - you can send only the fields you want to update
  module ConfigKey
    # Store configurations
    GENERAL_STORE_CONFIG = 'general_store_config'
    NOTIFICATIONS_CONFIG = 'notifications_config'
    MESSAGING_CONFIG = 'messaging_config'
    ECOMMERCE_CONFIG = 'ecommerce_config'
    CALENDLY_CONFIG = 'calendly_config'
    CONVERSATION_CONFIG = 'conversation_config'

    # Agent system configurations
    AGENT_SYSTEM_CONFIG = 'agent_system_config'

    ALL = [
      GENERAL_STORE_CONFIG,
      NOTIFICATIONS_CONFIG,
      MESSAGING_CONFIG,
      ECOMMERCE_CONFIG,
      CALENDLY_CONFIG,
      CONVERSATION_CONFIG,
      AGENT_SYSTEM_CONFIG
    ].freeze

    STORE_CONFIGS = [
      GENERAL_STORE_CONFIG,
      NOTIFICATIONS_CONFIG,
      MESSAGING_CONFIG,
      ECOMMERCE_CONFIG,
      CALENDLY_CONFIG,
      CONVERSATION_CONFIG
    ].freeze

    AGENT_CONFIGS = [
      AGENT_SYSTEM_CONFIG
    ].freeze

    USER_CONFIGS = [].freeze

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
