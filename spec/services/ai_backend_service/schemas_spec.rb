# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackendService::Schemas do
  describe 'StoreRequest' do
    let(:account) { create(:account, id: 123, name: 'Test Store') }

    describe '.from_account' do
      it 'creates store request from account' do
        request = described_class::StoreRequest.from_account(account, 'test@example.com')

        expect(request.name).to eq('Test Store')
        expect(request.email).to eq('test@example.com')
        expect(request.external_id).to eq(123)
        expect(request.is_active).to be true
        expect(request.custom_attributes).to eq({})
      end

      it 'uses account name and email' do
        request = described_class::StoreRequest.from_account(account, 'admin@example.com')

        expect(request.name).to eq(account.name)
        expect(request.email).to eq('admin@example.com')
      end
    end

    describe '#to_h' do
      it 'serializes to hash with string external_id' do
        request = described_class::StoreRequest.new(
          name: 'Test',
          email: 'test@example.com',
          external_id: 123,
          is_active: true,
          custom_attributes: { foo: 'bar' }
        )

        hash = request.to_h

        expect(hash[:external_id]).to eq('123') # Converted to string
        expect(hash[:name]).to eq('Test')
        expect(hash[:email]).to eq('test@example.com')
        expect(hash[:is_active]).to be true
        expect(hash[:custom_attributes]).to eq({ foo: 'bar' })
      end

      it 'handles nil custom_attributes' do
        request = described_class::StoreRequest.new(
          name: 'Test',
          email: 'test@example.com',
          external_id: 456,
          is_active: true,
          custom_attributes: nil
        )

        hash = request.to_h

        expect(hash[:custom_attributes]).to eq({})
      end

      it 'converts integer external_id to string' do
        request = described_class::StoreRequest.new(
          name: 'Test',
          email: 'test@example.com',
          external_id: 999,
          is_active: true
        )

        expect(request.to_h[:external_id]).to eq('999')
        expect(request.to_h[:external_id]).to be_a(String)
      end
    end
  end

  describe 'StoreResponse' do
    describe '.from_api' do
      it 'parses API response hash' do
        api_hash = {
          'id' => 'uuid-123',
          'name' => 'Test Store',
          'email' => 'test@example.com',
          'is_active' => true,
          'external_id' => '123',
          'custom_attributes' => { 'foo' => 'bar' }
        }

        response = described_class::StoreResponse.from_api(api_hash)

        expect(response.id).to eq('uuid-123')
        expect(response.name).to eq('Test Store')
        expect(response.email).to eq('test@example.com')
        expect(response.is_active).to be true
        expect(response.external_id).to eq('123')
        expect(response.custom_attributes).to eq({ 'foo' => 'bar' })
      end

      it 'symbolizes keys from API response' do
        api_hash = { 'id' => 'uuid-456', 'name' => 'Another Store', 'email' => 'test2@example.com' }

        response = described_class::StoreResponse.from_api(api_hash)

        expect(response.id).to eq('uuid-456')
        expect(response.name).to eq('Another Store')
      end
    end
  end

  describe 'AgentSystemRequest' do
    let(:agent_bot) { create(:agent_bot, id: 456, name: 'Test Bot', description: 'A test bot') }

    describe '.from_agent_bot' do
      it 'creates agent system request from agent bot' do
        request = described_class::AgentSystemRequest.from_agent_bot(agent_bot, 'store-uuid-123')

        expect(request.name).to eq('Test Bot')
        expect(request.external_id).to eq(456)
        expect(request.description).to eq('A test bot')
        expect(request.is_active).to be true
      end

      it 'handles nil description' do
        agent_bot.update(description: nil)
        request = described_class::AgentSystemRequest.from_agent_bot(agent_bot, 'store-uuid-123')

        expect(request.description).to eq('')
      end
    end

    describe '#to_h' do
      it 'serializes to hash with string external_id' do
        request = described_class::AgentSystemRequest.new(
          name: 'Test Bot',
          external_id: 789,
          description: 'Test description',
          is_active: true
        )

        hash = request.to_h

        expect(hash[:externalId]).to eq('789') # Converted to string and camelCase
        expect(hash[:name]).to eq('Test Bot')
        expect(hash[:description]).to eq('Test description')
        expect(hash[:isActive]).to be true
        expect(hash[:customAttributes]).to eq({})
      end
    end
  end

  describe 'UserRequest' do
    let(:user) { create(:user, id: 789, name: 'Test User', email: 'user@example.com') }

    describe '.from_user' do
      it 'creates user request from user' do
        request = described_class::UserRequest.from_user(user, 'store-uuid-123')

        expect(request.first_name).to eq('Test')
        expect(request.last_name).to eq('User')
        expect(request.email).to eq('user@example.com')
        expect(request.external_id).to eq(789)
        expect(request.role).to eq('admin')
      end
    end

    describe '#to_h' do
      it 'serializes to hash with string external_id' do
        request = described_class::UserRequest.new(
          first_name: 'Test',
          last_name: 'User',
          email: 'user@example.com',
          external_id: 999,
          role: 'admin'
        )

        hash = request.to_h

        expect(hash[:externalId]).to eq('999') # Converted to string and camelCase
        expect(hash[:firstName]).to eq('Test')
        expect(hash[:lastName]).to eq('User')
        expect(hash[:email]).to eq('user@example.com')
        expect(hash[:role]).to eq('admin')
        expect(hash[:customAttributes]).to eq({})
      end
    end
  end

  describe 'ChannelRequest' do
    let(:account) { create(:account, id: 456) }
    let(:inbox) { create(:inbox, id: 789, account: account, name: 'Test Channel', channel_type: 'Channel::WebWidget') }

    describe '.from_inbox' do
      it 'creates channel request from inbox' do
        request = described_class::ChannelRequest.from_inbox(inbox, account.id)

        expect(request.name).to eq('Test Channel')
        expect(request.channel_type).to eq('Channel::WebWidget')
        expect(request.platform).to eq('chatwoot')
        expect(request.external_id).to eq(789)
        expect(request.is_active).to be true
      end

      it 'always sets platform to chatwoot' do
        instagram_inbox = create(:inbox, channel_type: 'Channel::Instagram')
        request = described_class::ChannelRequest.from_inbox(instagram_inbox, account.id)

        expect(request.platform).to eq('chatwoot')
      end
    end

    describe '#to_h' do
      it 'serializes to hash with snake_case keys and string IDs' do
        request = described_class::ChannelRequest.new(
          name: 'Test Channel',
          channel_type: 'Channel::WebWidget',
          platform: 'chatwoot',
          external_id: 789,
          is_active: true
        )

        hash = request.to_h

        expect(hash[:external_id]).to eq('789')
        expect(hash[:name]).to eq('Test Channel')
        expect(hash[:platform]).to eq('chatwoot')
        expect(hash[:channel_type]).to eq('webwidget')
        expect(hash[:is_active]).to be true
      end

      it 'converts external_id to string' do
        request = described_class::ChannelRequest.new(
          name: 'Test',
          channel_type: 'Channel::Instagram',
          platform: 'chatwoot',
          external_id: 123,
          is_active: true
        )

        hash = request.to_h

        expect(hash[:external_id]).to eq('123')
        expect(hash[:external_id]).to be_a(String)
      end

      it 'normalizes channel_type to lowercase' do
        request = described_class::ChannelRequest.new(
          name: 'Test',
          channel_type: 'Channel::Instagram',
          platform: 'chatwoot',
          external_id: 123,
          is_active: true
        )

        hash = request.to_h

        expect(hash[:channel_type]).to eq('instagram')
      end
    end
  end
end
