class CreateEmails < ActiveRecord::Migration[7.2]
  def change
    create_table :emails do |t|
      t.string :subject
      t.text :content
      t.references :wix_user, null: false, foreign_key: true
      t.datetime :sent_at

      t.timestamps
    end
  end
end
