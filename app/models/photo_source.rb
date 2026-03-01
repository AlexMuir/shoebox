class PhotoSource < ApplicationRecord
  belongs_to :photo
  belongs_to :source_person, class_name: "Person", optional: true
  belongs_to :scanned_by_person, class_name: "Person", optional: true

  validates :description, presence: true
end
