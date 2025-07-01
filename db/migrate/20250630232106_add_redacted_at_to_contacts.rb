class AddRedactedAtToContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :redacted_at, :datetime, null: true, comment: 'Timestamp when contact data was redacted for privacy compliance'
    add_index :contacts, :redacted_at, name: 'index_contacts_on_redacted_at', comment: 'Index for efficiently querying redacted contacts'
  end
end
