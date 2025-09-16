class CreateWixUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :wix_users do |t|
      t.string :wix_user_id, null: false  # From Wix
      t.string :email
      t.string :display_name
      t.references :jobber_account, foreign_key: true  # Links to Jobber
      t.string :subscription_plan, default: 'basic'  # basic, pro, enterprise
      t.integer :retention_days, default: 60  # 60, 90, 180
      t.integer :email_limit, default: 100
      t.integer :emails_sent_this_period, default: 0
      t.datetime :billing_period_start
      t.datetime :billing_period_end
      t.boolean :active, default: true
      t.timestamps
      
      t.index :wix_user_id, unique: true
      t.index :email
    end
  end
end