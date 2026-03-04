class DateDetermination < ApplicationRecord
  include HasFuzzyDate

  SOURCE_TYPES = %w[exif age_estimate manual filename].freeze

  belongs_to :photo
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :photo_person, optional: true
  belongs_to :photo_face, optional: true

  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :determined_year, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }, allow_nil: true

  scope :by_confidence, -> { order(confidence: :desc) }
  scope :for_source_type, ->(type) { where(source_type: type) }
  scope :best, -> { order(confidence: :desc).first }

  after_save :update_photo_determined_date

  def determined_date_text
    fuzzy_date_text(determined_year, determined_month, determined_day, nil, false)
  end

  private

  def update_photo_determined_date
    photo.update_determined_date!
  end
end
