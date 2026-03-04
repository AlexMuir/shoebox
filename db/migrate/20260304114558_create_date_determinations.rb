class CreateDateDeterminations < ActiveRecord::Migration[8.1]
  def change
    create_table :date_determinations do |t|
      t.references :photo, null: false, foreign_key: true
      t.string :source_type, null: false
      t.jsonb :source_detail, default: {}
      t.integer :determined_year
      t.integer :determined_month
      t.integer :determined_day
      t.decimal :confidence, precision: 5, scale: 3
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :photo_person, foreign_key: true
      t.references :photo_face, foreign_key: true

      t.timestamps
    end

    add_index :date_determinations, [ :photo_id, :confidence ]
    add_index :date_determinations, [ :photo_id, :source_type ]
  end
end
