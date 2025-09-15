class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.references :jobber_account, null: false, foreign_key: true
      t.string :plan_type, default: 'basic'
      t.integer :retention_days, default: 60
      t.integer :email_limit, default: 100
      t.integer :emails_sent_this_period, default: 0
      t.datetime :billing_period_start
      t.datetime :billing_period_end
      t.boolean :active, default: true
      t.string :stripe_subscription_id
      t.timestamps
      
      t.index :billing_period_end
      t.index :active
    end
  end
end
