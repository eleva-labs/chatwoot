# frozen_string_literal: true

class CreateWebhookDeliveries < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_deliveries do |t|
      t.string :job_id, null: false
      t.string :url, null: false
      t.integer :conversation_id
      t.integer :message_id
      t.string :webhook_type, null: false
      t.integer :attempt_count, default: 0, null: false
      t.string :status, default: 'pending', null: false
      t.text :last_error
      t.datetime :last_attempt_at
      t.datetime :delivered_at
      t.timestamps

      t.index :job_id, unique: true
      t.index [:status, :created_at]
      t.index [:conversation_id, :message_id]
      t.index :webhook_type
      t.index [:status, :attempt_count]
    end
  end
end
