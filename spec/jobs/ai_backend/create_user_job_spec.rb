# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::CreateUserJob, type: :job do
  let(:user) { create(:user, id: 789, name: 'Test User') }
  let(:store_id) { 123 }
  let(:service) { instance_double(AiBackendService::UserService) }

  before do
    allow(AiBackendService::UserService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when user creation succeeds' do
      it 'calls UserService.create_user with correct params' do
        expect(service).to receive(:create_user).with(user, store_id).and_return(true)

        described_class.new.perform(user.id, store_id)
      end

      it 'logs success' do
        allow(service).to receive(:create_user).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(user.id, store_id)

        expect(Rails.logger).to have_received(:info).with(/Successfully created user for user_id: 789/)
      end
    end

    context 'when user creation fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:create_user)
          .and_raise(AiBackendService::UserService::UserError, 'API error')

        expect { described_class.new.perform(user.id, store_id) }
          .to raise_error(AiBackendService::UserService::UserError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:create_user)
          .and_raise(AiBackendService::UserService::UserError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(user.id, store_id)
        rescue AiBackendService::UserService::UserError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to create user for user_id: 789/)
      end
    end
  end
end
