class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :family, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.references :location, foreign_key: true

      # Fuzzy date range for the event
      t.string :date_type, default: "unknown"
      t.integer :year_from
      t.integer :month_from
      t.integer :day_from
      t.string :season_from
      t.boolean :circa_from, default: false
      t.integer :year_to
      t.integer :month_to
      t.integer :day_to
      t.string :season_to
      t.boolean :circa_to, default: false
      t.string :date_display

      t.timestamps
    end

    add_index :events, [ :family_id, :title ]
    add_index :events, :year_from
  end
end
