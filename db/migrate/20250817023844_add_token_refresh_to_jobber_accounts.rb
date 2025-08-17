class AddTokenRefreshToJobberAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :jobber_accounts, :refresh_token, :string
    add_column :jobber_accounts, :token_expires_at, :datetime
    add_column :jobber_accounts, :needs_reauthorization, :boolean, default: false
  end
end
