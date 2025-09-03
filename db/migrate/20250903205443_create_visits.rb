class CreateVisits < ActiveRecord::Migration[7.2]
  def change
    create_table :visits do |t|
      t.string :title
      t.text :notes
      t.references :wix_user, null: false, foreign_key: true
      t.datetime :completed_at

      t.timestamps
    end
  end
end
