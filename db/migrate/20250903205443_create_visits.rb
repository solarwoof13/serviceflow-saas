class CreateVisits < ActiveRecord::Migration[7.2]
  def change
    create_table :visits do |t|
      t.references :jobber_account, null: false, foreign_key: true
      t.string :jobber_visit_id, null: false
      t.string :job_number
      t.string :customer_name
      t.string :customer_email
      t.jsonb :property_address
      t.text :service_notes
      t.datetime :completed_at
      t.datetime :data_expires_at
      t.timestamps
      
      t.index :jobber_visit_id, unique: true
      t.index :data_expires_at
      t.index :completed_at
    end
  end
end
