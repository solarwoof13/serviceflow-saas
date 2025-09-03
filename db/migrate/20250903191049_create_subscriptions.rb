class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.references :wix_user, null: false, foreign_key: true
      t.integer :level

      t.timestamps
    end
  end
end
