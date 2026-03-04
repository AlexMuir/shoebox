class PhotoPerson < ApplicationRecord
  belongs_to :photo
  belongs_to :person
  belongs_to :tagged_by, class_name: "User", optional: true

  validates :person_id, uniqueness: { scope: :photo_id }
  validates :estimated_age, numericality: { in: 1..120 }, allow_nil: true
end
