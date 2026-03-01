class CreatePhotoSources < ActiveRecord::Migration[8.1]
  def change
    create_table :photo_sources do |t|
      t.references :photo, null: false, foreign_key: true
      t.string :description, null: false
      t.references :source_person, foreign_key: { to_table: :people }
      t.references :scanned_by_person, foreign_key: { to_table: :people }
      t.date :scanned_at
      t.text :notes

      t.timestamps
    end
  end
end
