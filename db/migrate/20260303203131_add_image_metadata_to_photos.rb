class AddImageMetadataToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :image_metadata, :jsonb, default: {}
  end
end
