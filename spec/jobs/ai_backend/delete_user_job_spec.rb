# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBackend::DeleteUserJob, type: :job do
  let(:user_id) { 789 }
  let(:service) { instance_double(AiBackendService::UserService) }

  before do
    allow(AiBackendService::UserService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when user deletion succeeds' do
      it 'calls UserService.delete_user with user ID' do
        expect(service).to receive(:delete_user).with(user_id).and_return(true)

        described_class.new.perform(user_id)
      end

      it 'logs success' do
        allow(service).to receive(:delete_user).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(user_id)

        expect(Rails.logger).to have_received(:info).with(/Successfully deleted user for user_id: 789/)
      end
    end

    context 'when user deletion fails' do
      it 'raises error for Sidekiq retry' do
        allow(service).to receive(:delete_user)
          .and_raise(AiBackendService::UserService::UserError, 'API error')

        expect { described_class.new.perform(user_id) }
          .to raise_error(AiBackendService::UserService::UserError)
      end

      it 'logs error before raising' do
        allow(service).to receive(:delete_user)
          .and_raise(AiBackendService::UserService::UserError, 'API error')
        allow(Rails.logger).to receive(:error)

        begin
          described_class.new.perform(user_id)
        rescue AiBackendService::UserService::UserError
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to delete user for user_id: 789/)
      end
    end
  end
end
