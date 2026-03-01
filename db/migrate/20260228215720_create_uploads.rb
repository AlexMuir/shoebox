class CreateUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :uploads do |t|
      t.references :family, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :source_album
      t.string :source_owner
      t.string :scanned_by
      t.date :scanned_at
      t.text :notes
      t.integer :photos_count, default: 0

      # Approximate date range for the batch
      t.string :date_type, default: "unknown"
      t.integer :year_from
      t.integer :year_to

      t.string :status, null: false, default: "pending"

      t.timestamps
    end
  end
end
