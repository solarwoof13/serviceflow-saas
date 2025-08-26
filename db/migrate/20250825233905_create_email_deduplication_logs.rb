class CreateEmailDeduplicationLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :email_deduplication_logs do |t|
      t.string :visit_id, null: false, index: true
      t.string :job_id, index: true
      t.string :customer_email, null: false
      t.string :webhook_topic
      t.json :webhook_data
      t.string :email_status # 'sent', 'duplicate_blocked', 'failed'
      t.string :block_reason # Why it was blocked
      t.datetime :email_sent_at
      t.timestamps
    end
    
    # Ensure we can quickly check for duplicates
    add_index :email_deduplication_logs, [:visit_id, :customer_email], 
              name: 'idx_dedup_visit_customer', unique: false
    add_index :email_deduplication_logs, :created_at
  end
end
