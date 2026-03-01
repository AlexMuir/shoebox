class Upload < ApplicationRecord
  belongs_to :family
  belongs_to :user
  has_many :photos, dependent: :nullify
  belongs_to :source_owner, class_name: "Person", optional: true
  belongs_to :scanned_by_person, class_name: "Person", optional: true

  validates :status, inclusion: { in: %w[pending processing completed failed] }

  scope :recent, -> { order(created_at: :desc) }

  def completed?
    status == "completed"
  end

  def date_range_display
    return nil unless year_from.present?
    if year_to.present? && year_to != year_from
      "#{year_from} – #{year_to}"
    else
      year_from.to_s
    end
  end
end
