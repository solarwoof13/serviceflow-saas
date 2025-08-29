class ConsolidateJobberAccountIds < ActiveRecord::Migration[7.0]
  def up
    # Copy account_id to jobber_id where jobber_id is blank
    JobberAccount.where(jobber_id: [nil, '']).find_each do |account|
      if account.account_id.present?
        Rails.logger.info "Fixing account ID #{account.id}: copying account_id to jobber_id"
        account.update_column(:jobber_id, account.account_id)
      end
    end
    
    # Remove the redundant column
    if column_exists?(:jobber_accounts, :account_id)
      remove_column :jobber_accounts, :account_id
    end
  end
  
  def down
    unless column_exists?(:jobber_accounts, :account_id)
      add_column :jobber_accounts, :account_id, :string
      add_index :jobber_accounts, :account_id, unique: true
    end
  end
end
