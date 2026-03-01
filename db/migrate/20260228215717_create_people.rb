class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.references :family, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :maiden_name
      t.date :date_of_birth
      t.date :date_of_death
      t.text :bio
      t.references :user, foreign_key: true

      t.timestamps
    end

    add_index :people, [ :family_id, :last_name, :first_name ]
  end
end
