module HasFuzzyDate
  extend ActiveSupport::Concern

  SEASONS = %w[spring summer autumn winter].freeze
  DATE_TYPES = %w[exact month season year decade circa unknown].freeze

  class_methods do
    def fuzzy_date_fields(prefix: nil, fields: [])
      # Just validates the date_type field
      date_type_field = fields.find { |f| f.to_s.include?("date_type") } || :date_type
      validates date_type_field, inclusion: { in: DATE_TYPES }, allow_nil: true
    end
  end

  # Build human-readable text from fuzzy date components
  def fuzzy_date_text(year, month, day, season, circa)
    return nil unless year.present?

    parts = []
    parts << "c." if circa

    if season.present?
      parts << season.capitalize
      parts << year.to_s
    elsif day.present? && month.present?
      date = Date.new(year, month, day)
      parts << date.strftime("%d %B %Y")
    elsif month.present?
      date = Date.new(year, month, 1)
      parts << date.strftime("%B %Y")
    else
      parts << year.to_s
    end

    parts.join(" ")
  end
end
