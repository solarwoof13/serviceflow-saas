class CreateEmails < ActiveRecord::Migration[7.2]
  def change
    create_table :emails do |t|
      t.references :jobber_account, null: false, foreign_key: true
      t.references :visit, foreign_key: true
      t.string :recipient_email, null: false
      t.string :subject
      t.text :content
      t.string :status, default: 'pending'
      t.string :sendgrid_message_id
      t.jsonb :sendgrid_response
      t.datetime :sent_at
      t.datetime :data_expires_at
      t.timestamps
      
      t.index :sendgrid_message_id
      t.index :data_expires_at
      t.index :status
      t.index :sent_at
    end
  end
end
