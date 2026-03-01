class Contribution < ApplicationRecord
  belongs_to :photo
  belongs_to :user

  validates :field_name, presence: true
  validates :value, presence: true

  FIELD_NAMES = %w[date location person_tag event description title source].freeze

  validates :field_name, inclusion: { in: FIELD_NAMES }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_field, ->(field) { where(field_name: field) }
end
