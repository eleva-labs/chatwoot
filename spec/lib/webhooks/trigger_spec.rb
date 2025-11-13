require 'rails_helper'

describe Webhooks::Trigger do
  subject(:trigger) { described_class }

  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, inbox: inbox) }
  let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }

  let!(:webhook_type) { :api_inbox_webhook }
  let!(:url) { 'https://test.com' }

  before do
    # Clear circuit breaker state before each test
    Rails.cache.clear
  end

  describe '#execute' do
    it 'triggers webhook' do
      payload = { hello: :hello }
      mock_response = double('response', code: 200)

      expect(RestClient::Request).to receive(:execute)
        .with(
          method: :post,
          url: url,
          payload: payload.to_json,
          headers: { content_type: :json, accept: :json },
          timeout: 5
        ).once.and_return(mock_response)
      trigger.execute(url, payload, webhook_type)
    end

    it 'updates message status if webhook fails for message-created event' do
      payload = { event: 'message_created', conversation: { id: conversation.id }, id: message.id }

      expect(RestClient::Request).to receive(:execute)
        .with(
          method: :post,
          url: url,
          payload: payload.to_json,
          headers: { content_type: :json, accept: :json },
          timeout: 5
        ).and_raise(RestClient::ExceptionWithResponse.new('error', 500)).at_least(:once)

      expect do
        trigger.execute(url, payload, webhook_type)
      rescue StandardError
        # Exception is re-raised after updating message status
      end.to change { message.reload.status }.from('sent').to('failed')
    end

    it 'updates message status if webhook fails for message-updated event' do
      payload = { event: 'message_updated', conversation: { id: conversation.id }, id: message.id }

      expect(RestClient::Request).to receive(:execute)
        .with(
          method: :post,
          url: url,
          payload: payload.to_json,
          headers: { content_type: :json, accept: :json },
          timeout: 5
        ).and_raise(RestClient::ExceptionWithResponse.new('error', 500)).at_least(:once)

      expect do
        trigger.execute(url, payload, webhook_type)
      rescue StandardError
        # Exception is re-raised after updating message status
      end.to change { message.reload.status }.from('sent').to('failed')
    end
  end

  it 'does not update message status if webhook fails for other events' do
    payload = { event: 'conversation_created', conversation: { id: conversation.id }, id: message.id }

    expect(RestClient::Request).to receive(:execute)
      .with(
        method: :post,
        url: url,
        payload: payload.to_json,
        headers: { content_type: :json, accept: :json },
        timeout: 5
      ).and_raise(RestClient::ExceptionWithResponse.new('error', 500)).at_least(:once)

    expect do
      trigger.execute(url, payload, webhook_type)
    rescue StandardError
      # Exception is re-raised, but message status should not change
    end.not_to(change { message.reload.status })
  end
end
