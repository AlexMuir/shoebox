class Event < ApplicationRecord
  include HasFuzzyDate

  belongs_to :family
  belongs_to :location, optional: true
  has_many :photos, dependent: :nullify

  fuzzy_date_fields prefix: "from", fields: %i[date_type year_from month_from day_from season_from circa_from]
  fuzzy_date_fields prefix: "to", fields: %i[date_type year_to month_to day_to season_to circa_to]

  validates :title, presence: true

  scope :chronological, -> { order(year_from: :asc, month_from: :asc) }
  scope :reverse_chronological, -> { order(year_from: :desc, month_from: :desc) }

  def date_range_display
    return date_display if date_display.present?

    from = fuzzy_date_text(year_from, month_from, day_from, season_from, circa_from)
    to = fuzzy_date_text(year_to, month_to, day_to, season_to, circa_to)

    if to.present? && from != to
      "#{from} – #{to}"
    else
      from
    end
  end
end
