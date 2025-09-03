class AddProcessedVisitIdsToJobberAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :jobber_accounts, :processed_visit_ids, :jsonb
  end
end
