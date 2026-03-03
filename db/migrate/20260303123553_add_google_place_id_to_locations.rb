class AddGooglePlaceIdToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :google_place_id, :string
    add_index :locations, [ :family_id, :google_place_id ], unique: true, where: "google_place_id IS NOT NULL"
  end
end
