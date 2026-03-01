class AddOrientationCorrectionToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :orientation_correction, :integer, default: 0
  end
end
