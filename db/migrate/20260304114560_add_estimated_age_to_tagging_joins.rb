class AddEstimatedAgeToTaggingJoins < ActiveRecord::Migration[8.1]
  def change
    add_column :photo_people, :estimated_age, :integer
    add_column :photo_faces, :estimated_age, :integer
  end
end
