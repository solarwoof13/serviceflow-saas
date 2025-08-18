class AddAccountIdToJobberAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :jobber_accounts, :account_id, :string
    add_index :jobber_accounts, :account_id, unique: true
  end
end
