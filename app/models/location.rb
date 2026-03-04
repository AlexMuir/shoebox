class Location < ApplicationRecord
  has_ancestry

  belongs_to :family
  has_many :photos, dependent: :nullify
  has_many :events, dependent: :nullify

  validates :name, presence: true

  geocoded_by :full_address
  # after_validation :geocode, if: ->(loc) { loc.full_address.present? && loc.latitude.blank? }

  scope :alphabetical, -> { order(:name) }
  scope :manual_entry, -> { where(manual: true) }

  def full_address
    [ address_line_1, address_line_2, city, region, postal_code, country ].compact.join(", ")
  end
end
