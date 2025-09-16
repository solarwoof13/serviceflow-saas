class CreateEmailDeduplicationLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :email_deduplication_logs do |t|
      t.bigint :visit_id
      t.string :job_id, null: false
      t.string :customer_email, null: false
      t.string :webhook_topic
      t.string :email_status
      t.string :email_provider
      t.string :email_id
      t.text :email_subject
      t.text :email_content
      t.datetime :sent_at
      t.references :jobber_account, foreign_key: true
      t.timestamps
      
      t.index [:job_id, :customer_email], unique: true, name: 'idx_email_dedup'
      t.index :visit_id
      t.index :sent_at
    end
  end
end