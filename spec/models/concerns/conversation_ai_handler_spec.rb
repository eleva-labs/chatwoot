# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationAiHandler do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe '#enable_ai!' do
    before do
      create(:agent_bot_inbox, inbox: inbox, status: :active)
    end

    context 'when Current.user is present' do
      before { Current.user = agent }
      after { Current.user = nil }

      it 'creates an activity message when enabling AI' do
        conversation.update!(custom_attributes: { 'ai_enabled' => false })

        expect do
          conversation.enable_ai!
        end.to have_enqueued_job(Conversations::ActivityMessageJob)
          .with(conversation, hash_including(
                                content: "#{agent.name} enabled AI for this conversation",
                                message_type: :activity
                              ))
      end

      it 'does not create activity if AI is already enabled' do
        conversation.update!(custom_attributes: { 'ai_enabled' => true })

        expect do
          conversation.enable_ai!
        end.not_to have_enqueued_job(Conversations::ActivityMessageJob)
      end
    end

    context 'when Current.user is not present' do
      it 'does not create an activity message' do
        conversation.update!(custom_attributes: { 'ai_enabled' => false })

        expect do
          conversation.enable_ai!
        end.not_to have_enqueued_job(Conversations::ActivityMessageJob)
      end
    end
  end

  describe '#disable_ai!' do
    context 'when Current.user is present' do
      before { Current.user = agent }
      after { Current.user = nil }

      it 'creates an activity message when disabling AI' do
        conversation.update!(custom_attributes: { 'ai_enabled' => true })

        expect do
          conversation.disable_ai!
        end.to have_enqueued_job(Conversations::ActivityMessageJob)
          .with(conversation, hash_including(
                                content: "#{agent.name} disabled AI for this conversation",
                                message_type: :activity
                              ))
      end

      it 'does not create activity if AI is already disabled' do
        conversation.update!(custom_attributes: { 'ai_enabled' => false })

        expect do
          conversation.disable_ai!
        end.not_to have_enqueued_job(Conversations::ActivityMessageJob)
      end
    end
  end
end
