class AddProcessedVisitIdsToJobberAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :jobber_accounts, :processed_visit_ids, :text, array: true, default: []
    add_index :jobber_accounts, :processed_visit_ids, using: 'gin'
  end
end