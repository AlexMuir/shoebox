class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.references :family, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address_line_1
      t.string :address_line_2
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :country
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :ancestry, collation: "C"

      t.timestamps
    end

    add_index :locations, :ancestry
    add_index :locations, [ :family_id, :name ]
  end
end
