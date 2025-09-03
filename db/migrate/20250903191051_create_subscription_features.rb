class CreateSubscriptionFeatures < ActiveRecord::Migration[7.2]
  def change
    create_table :subscription_features do |t|
      t.references :subscription, null: false, foreign_key: true
      t.references :feature, null: false, foreign_key: true

      t.timestamps
    end
  end
end
