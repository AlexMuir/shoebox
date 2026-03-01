class AddFileTimestampsToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :file_modified_at, :datetime
    add_column :photos, :taken_at, :datetime
  end
end
