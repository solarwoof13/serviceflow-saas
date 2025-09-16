class CreateVisits < ActiveRecord::Migration[7.2]
  def change
    create_table :visits do |t|
      t.references :wix_user, foreign_key: true  # Links to Wix user
      t.references :jobber_account, foreign_key: true  # Links to Jobber
      t.string :jobber_visit_id, null: false
      t.string :job_number
      t.string :customer_name
      t.string :customer_email
      t.jsonb :property_address, default: {}
      t.text :service_notes
      t.datetime :completed_at
      t.datetime :data_expires_at  # For retention policy
      t.timestamps
      
      t.index :jobber_visit_id, unique: true
      t.index :data_expires_at
    end
  end
end