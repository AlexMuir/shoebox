class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :family, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.references :event, foreign_key: true
      t.references :location, foreign_key: true
      t.references :photographer, foreign_key: { to_table: :people }

      # Fuzzy date for when the photo was taken
      t.string :date_type, default: "unknown"
      t.integer :year
      t.integer :month
      t.integer :day
      t.string :season
      t.boolean :circa, default: false
      t.string :date_display

      # Image metadata
      t.integer :width
      t.integer :height
      t.integer :file_size
      t.string :original_filename
      t.string :content_type

      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.references :upload, foreign_key: true

      t.timestamps
    end

    add_index :photos, [ :family_id, :year ]
    add_index :photos, :created_at
  end
end
