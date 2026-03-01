class Person < ApplicationRecord
  belongs_to :family
  belongs_to :user, optional: true
  has_many :photo_people, dependent: :destroy
  has_many :photo_faces, dependent: :nullify
  has_many :photos, through: :photo_people

  validates :first_name, presence: true
  validates :last_name, presence: true

  normalizes :first_name, :last_name, :maiden_name, with: ->(name) { name.squish }

  scope :alphabetical, -> { order(:last_name, :first_name) }

  def full_name
    [ first_name, last_name ].compact.join(" ")
  end
  alias_method :name, :full_name
  alias_method :display_name, :full_name

  def age
    return nil unless date_of_birth.present?
    reference_date = date_of_death || Date.current
    ((reference_date - date_of_birth).to_i / 365.25).floor
  end
end
