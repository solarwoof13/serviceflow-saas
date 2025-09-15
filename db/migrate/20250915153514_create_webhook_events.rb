class CreateWebhookEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :webhook_events do |t|
      t.string :event_type, null: false
      t.string :jobber_item_id
      t.jsonb :payload, default: {}
      t.string :processing_status, default: 'pending'
      t.text :error_message
      t.references :jobber_account, foreign_key: true
      t.timestamps
      
      t.index :jobber_item_id
      t.index :created_at
      t.index :processing_status
      t.index [:event_type, :created_at]
    end
  end
end
