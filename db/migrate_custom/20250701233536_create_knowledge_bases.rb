class CreateKnowledgeBases < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :knowledge_bases, id: :uuid, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name
      t.integer :source_type
      t.string :url

      t.timestamps
    end
  end
end
