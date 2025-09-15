# Edit db/migrate/20250915161405_add_columns_to_visits.rb
class AddColumnsToVisits < ActiveRecord::Migration[7.0]
  def change
    # Check and add only missing columns
    unless column_exists?(:visits, :jobber_visit_id)
      add_column :visits, :jobber_visit_id, :string
    end
    
    # Remove this line since completed_at already exists
    # add_column :visits, :completed_at, :datetime
    
    unless column_exists?(:visits, :data_expires_at)
      add_column :visits, :data_expires_at, :datetime
    end
    
    unless column_exists?(:visits, :jobber_account_id)
      add_column :visits, :jobber_account_id, :bigint
      add_index :visits, :jobber_account_id
    end
  end
end
