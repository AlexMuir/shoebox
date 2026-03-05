class CreateStorytellingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :storytelling_sessions do |t|
      t.references :family, null: false, foreign_key: true
      t.references :location, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }, null: false

      t.timestamps
    end

    create_table :storytelling_session_people do |t|
      t.references :storytelling_session, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true

      t.timestamps
    end

    add_index :storytelling_session_people, [ :storytelling_session_id, :person_id ], unique: true

    create_table :stories do |t|
      t.references :storytelling_session, null: false, foreign_key: true
      t.references :photo, null: false, foreign_key: true

      t.timestamps
    end
  end
end
