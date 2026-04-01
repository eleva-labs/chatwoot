class AddProcessingStatusToKnowledgeBases < ActiveRecord::Migration[7.1]
  def change
    add_column :knowledge_bases, :status, :integer, default: 0, if_not_exists: true
    add_column :knowledge_bases, :error_message, :text, if_not_exists: true
    add_column :knowledge_bases, :chunk_count, :integer, default: 0, if_not_exists: true
    add_column :knowledge_bases, :processed_at, :datetime, if_not_exists: true
  end
end
