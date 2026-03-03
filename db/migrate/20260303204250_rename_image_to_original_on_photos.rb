# frozen_string_literal: true

class RenameImageToOriginalOnPhotos < ActiveRecord::Migration[8.1]
  def up
    ActiveStorage::Attachment.where(record_type: "Photo", name: "image").update_all(name: "original")
  end

  def down
    ActiveStorage::Attachment.where(record_type: "Photo", name: "original").update_all(name: "image")
  end
end
