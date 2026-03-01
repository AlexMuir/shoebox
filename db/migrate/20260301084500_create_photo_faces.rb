class CreatePhotoFaces < ActiveRecord::Migration[8.1]
  def change
    create_table :photo_faces do |t|
      t.references :photo, null: false, foreign_key: true
      t.references :person, foreign_key: true
      t.references :tagged_by, foreign_key: { to_table: :users }
      t.decimal :x, precision: 8, scale: 6, null: false
      t.decimal :y, precision: 8, scale: 6, null: false
      t.decimal :width, precision: 8, scale: 6, null: false
      t.decimal :height, precision: 8, scale: 6, null: false
      t.decimal :confidence, precision: 8, scale: 6

      t.timestamps
    end

    add_index :photo_faces, [ :photo_id, :person_id ]

    add_check_constraint :photo_faces, "x >= 0 AND x <= 1", name: "photo_faces_x_range"
    add_check_constraint :photo_faces, "y >= 0 AND y <= 1", name: "photo_faces_y_range"
    add_check_constraint :photo_faces, "width > 0 AND width <= 1", name: "photo_faces_width_range"
    add_check_constraint :photo_faces, "height > 0 AND height <= 1", name: "photo_faces_height_range"
    add_check_constraint :photo_faces, "x + width <= 1", name: "photo_faces_x_width_range"
    add_check_constraint :photo_faces, "y + height <= 1", name: "photo_faces_y_height_range"
  end
end
