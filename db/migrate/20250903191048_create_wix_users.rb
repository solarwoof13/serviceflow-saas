class CreateWixUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :wix_users do |t|
      t.string :wix_id
      t.string :email
      t.jsonb :settings

      t.timestamps
    end
    add_index :wix_users, :wix_id
  end
end
