# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InboxMember do
  include ActiveJob::TestHelper

  describe '#DestroyAssociationAsyncJob' do
    let(:inbox_member) { create(:inbox_member) }

    # ref: https://github.com/chatwoot/chatwoot/issues/4616
    context 'when parent inbox is destroyed', :perform_enqueued do
      it 'enques and processes DestroyAssociationAsyncJob' do
        inbox = inbox_member.inbox

        expect do
          perform_enqueued_jobs { inbox.destroy! }
        end.to change { InboxMember.exists?(inbox_member.id) }.from(true).to(false)
      end
    end
  end
end
