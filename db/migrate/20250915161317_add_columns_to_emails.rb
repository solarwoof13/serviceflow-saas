class AddColumnsToEmails < ActiveRecord::Migration[7.0]
  def change
    # Check and add only missing columns
    unless column_exists?(:emails, :recipient_email)
      add_column :emails, :recipient_email, :string
    end
    
    unless column_exists?(:emails, :status)
      add_column :emails, :status, :string
    end
    
    # Remove this line since sent_at already exists
    # add_column :emails, :sent_at, :datetime
    
    unless column_exists?(:emails, :jobber_account_id)
      add_column :emails, :jobber_account_id, :bigint
      add_index :emails, :jobber_account_id
    end
    
    unless column_exists?(:emails, :visit_id)
      add_column :emails, :visit_id, :bigint
      add_index :emails, :visit_id
    end
  end
end
