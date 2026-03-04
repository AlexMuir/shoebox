# frozen_string_literal: true

class Photo::ConfidenceScorer
  class << self
    def score_exif(_taken_at)
      0.95
    end

    def score_filename(_date_result)
      0.6
    end

    def score_age_estimate(person, _estimated_age)
      return 0.85 if person.date_of_birth.present?
      return 0.7 if person.dob_circa?

      0.75
    end

    def score_manual
      0.9
    end
  end
end
