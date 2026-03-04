class Person < ApplicationRecord
  belongs_to :family
  belongs_to :user, optional: true
  has_many :photo_people, dependent: :destroy
  has_many :photo_faces, dependent: :nullify
  has_many :photos, through: :photo_people

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :dob_year, numericality: { in: 1000..Date.current.year }, allow_nil: true

  normalizes :first_name, :last_name, :maiden_name, with: ->(name) { name.squish }

  scope :alphabetical, -> { order(:last_name, :first_name) }

  after_update :recalculate_date_determinations, if: :dob_changed?

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

  def dob_text
    return nil unless dob_year.present?
    dob_circa ? "c. #{dob_year}" : "#{dob_year}"
  end

  def has_dob?
    dob_year.present?
  end

  private

  def dob_changed?
    saved_change_to_dob_year? || saved_change_to_date_of_birth?
  end

  def recalculate_date_determinations
    recalculate_photo_person_determinations
    recalculate_photo_face_determinations
  end

  def recalculate_photo_person_determinations
    DateDetermination
      .for_source_type("age_estimate")
      .where(photo_person_id: photo_people.where.not(estimated_age: nil).select(:id))
      .find_each { |determination| recalculate_determination!(determination, determination.photo_person&.estimated_age) }
  end

  def recalculate_photo_face_determinations
    DateDetermination
      .for_source_type("age_estimate")
      .where(photo_face_id: photo_faces.where.not(estimated_age: nil).select(:id))
      .find_each { |determination| recalculate_determination!(determination, determination.photo_face&.estimated_age) }
  end

  def recalculate_determination!(determination, estimated_age)
    return if estimated_age.blank? || dob_year.blank?

    confidence = Photo::ConfidenceScorer.score_age_estimate(self, estimated_age)
    determination.update!(
      determined_year: dob_year + estimated_age,
      determined_month: date_of_birth&.month,
      determined_day: nil,
      confidence: confidence,
      source_detail: {
        estimated_age: estimated_age,
        person_dob_year: dob_year,
        person_dob_circa: dob_circa
      }
    )
  end
end
