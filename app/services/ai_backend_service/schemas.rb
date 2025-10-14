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
      # Convert camelCase API response to snake_case for internal use
      symbolized = hash.is_a?(Hash) ? hash.symbolize_keys : {}
      new(
        id: symbolized[:id],
        name: symbolized[:name],
        email: symbolized[:email],
        is_active: symbolized[:isActive] || symbolized[:is_active],
        external_id: symbolized[:externalId] || symbolized[:external_id],
        custom_attributes: symbolized[:customAttributes] || symbolized[:custom_attributes] || {}
      )
    end
  end

  # Agent system creation/update request schema
  AgentSystemRequest = Struct.new(
    :name,
    :external_id,
    :description,
    :is_active,
    :custom_attributes,
    keyword_init: true
  ) do
    def to_h
      {
        name: name,
        externalId: external_id.to_s,
        description: description,
        isActive: is_active,
        customAttributes: custom_attributes || {}
      }
    end

    def self.from_agent_bot(agent_bot, _store_id)
      new(
        name: agent_bot.name,
        external_id: agent_bot.id,
        description: agent_bot.description || '',
        is_active: true,
        custom_attributes: {}
      )
    end
  end

  # User creation/update request schema
  UserRequest = Struct.new(
    :first_name,
    :last_name,
    :email,
    :external_id,
    :role,
    :custom_attributes,
    keyword_init: true
  ) do
    def to_h
      {
        firstName: first_name,
        lastName: last_name || '',
        email: email,
        externalId: external_id.to_s,
        role: role,
        customAttributes: custom_attributes || {}
      }
    end

    def self.from_user(user, _store_id)
      # Split name into first and last name
      name_parts = user.name.to_s.split(' ', 2)

      new(
        first_name: name_parts[0] || user.name,
        last_name: name_parts[1] || '',
        email: user.email,
        external_id: user.id,
        role: 'admin',
        custom_attributes: {}
      )
    end
  end

  # Channel creation/update request schema
  ChannelRequest = Struct.new(
    :name,
    :channel_type,
    :platform,
    :external_id,
    :is_active,
    keyword_init: true
  ) do
    def to_h
      {
        external_id: external_id.to_s,
        name: name,
        platform: platform,
        channel_type: normalized_channel_type,
        is_active: is_active
      }
    end

    def self.from_inbox(inbox, _store_id)
      new(
        name: inbox.name,
        channel_type: inbox.channel_type,
        platform: 'chatwoot',
        external_id: inbox.id,
        is_active: true
      )
    end

    private

    def normalized_channel_type
      # Extract platform from channel_type (e.g., "Channel::Instagram" -> "instagram")
      channel_type.to_s.split('::').last.downcase
    end
  end
end
