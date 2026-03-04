class Photo::DateDeterminationService
  class << self
    def from_age_estimate(photo_person: nil, photo_face: nil)
      source = photo_person || photo_face
      return nil unless source

      person = source.person
      age = source.estimated_age
      return nil if person.blank? || age.blank? || !person.has_dob?

      determined_year = person.dob_year + age
      confidence = Photo::ConfidenceScorer.score_age_estimate(person, age)

      attributes = {
        photo_person: photo_person,
        photo_face: photo_face,
        source_detail: {
          estimated_age: age,
          person_dob_year: person.dob_year,
          person_dob_circa: person.dob_circa
        }
      }

      if person.date_of_birth.present?
        attributes[:determined_month] = person.date_of_birth.month
      end

      create_determination(
        photo: source.photo,
        source_type: "age_estimate",
        determined_year: determined_year,
        confidence: confidence,
        **attributes
      )
    end

    def from_exif(photo, taken_at:)
      return nil if photo.blank? || taken_at.blank?

      time = taken_at.to_time
      create_determination(
        photo: photo,
        source_type: "exif",
        determined_year: time.year,
        determined_month: time.month,
        determined_day: time.day,
        confidence: Photo::ConfidenceScorer.score_exif(taken_at),
        source_detail: { taken_at: taken_at }
      )
    end

    def from_filename(photo, date_result:)
      return nil if photo.blank? || date_result.blank? || date_result.year.blank?

      create_determination(
        photo: photo,
        source_type: "filename",
        determined_year: date_result.year,
        determined_month: date_result.month,
        determined_day: date_result.day,
        confidence: Photo::ConfidenceScorer.score_filename(date_result),
        source_detail: { pattern: date_result.pattern }
      )
    end

    def from_manual(photo, year:, month: nil, day: nil, user:)
      return nil if photo.blank? || year.blank?

      create_determination(
        photo: photo,
        source_type: "manual",
        determined_year: year,
        determined_month: month,
        determined_day: day,
        confidence: Photo::ConfidenceScorer.score_manual,
        created_by: user
      )
    end

    private

    def create_determination(photo:, source_type:, determined_year:, confidence:, **attributes)
      return nil if determined_year.blank?

      DateDetermination.create!(
        {
          photo: photo,
          source_type: source_type,
          determined_year: determined_year,
          confidence: confidence
        }.merge(attributes)
      )
    end
  end
end
