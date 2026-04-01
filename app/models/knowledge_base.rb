# == Schema Information
#
# Table name: knowledge_bases
#
#  id            :uuid             not null, primary key
#  chunk_count   :integer          default(0)
#  error_message :text
#  name          :string
#  processed_at  :datetime
#  source_type   :integer
#  status        :integer          default("pending")
#  url           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :integer          not null
#
# Indexes
#
#  index_knowledge_bases_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class KnowledgeBase < ApplicationRecord
  belongs_to :account

  # NOTE: has_many_attached :files is incompatible with UUID primary keys
  # (ActiveStorage's record_id is bigint). Files are accessed via the url column
  # and the blob is looked up directly in TextExtractorService.

  validates :name, presence: true
  validates :account_id, presence: true
  validates :url, presence: true, if: :webpage_type?

  enum source_type: { webpage: 0, file: 1, image: 2 }
  enum status: { pending: 0, processing: 1, processed: 2, failed: 3 }, _prefix: :status

  private

  def webpage_type?
    source_type == 'webpage'
  end
end
