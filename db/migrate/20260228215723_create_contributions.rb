class CreateContributions < ActiveRecord::Migration[8.1]
  def change
    create_table :contributions do |t|
      t.references :photo, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :field_name, null: false
      t.text :value, null: false
      t.text :note

      t.timestamps
    end

    add_index :contributions, [ :photo_id, :field_name ]
  end
end
