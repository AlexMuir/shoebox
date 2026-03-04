require "rails_helper"

RSpec.describe Photo::DateDeterminationService do
  describe ".from_age_estimate" do
    context "with a photo_person" do
      it "creates a date determination when person has exact date_of_birth" do
        person = create(:person, dob_year: 1950, date_of_birth: Date.new(1950, 6, 10))
        photo = create(:photo, family: person.family)
        photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 25)

        allow(Photo::ConfidenceScorer).to receive(:score_age_estimate).with(person, 25).and_return(0.85)

        result = described_class.from_age_estimate(photo_person: photo_person)

        expect(result).to be_persisted
        expect(result.source_type).to eq("age_estimate")
        expect(result.photo).to eq(photo)
        expect(result.photo_person).to eq(photo_person)
        expect(result.determined_year).to eq(1975)
        expect(result.determined_month).to eq(6)
        expect(result.confidence).to eq(0.85)

        photo.reload
        expect(photo.determined_year).to eq(1975)
        expect(photo.best_date_determination_id).to eq(result.id)
      end

      it "creates a year-level determination when person has only dob_year" do
        person = create(:person, dob_year: 1950, dob_circa: true)
        photo = create(:photo, family: person.family)
        photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 25)

        allow(Photo::ConfidenceScorer).to receive(:score_age_estimate).with(person, 25).and_return(0.7)

        result = described_class.from_age_estimate(photo_person: photo_person)

        expect(result).to be_persisted
        expect(result.determined_year).to eq(1975)
        expect(result.determined_month).to be_nil
        expect(result.confidence).to eq(0.7)
      end

      it "returns nil when person has no DOB" do
        person = create(:person, dob_year: nil, date_of_birth: nil)
        photo = create(:photo, family: person.family)
        photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 25)

        expect {
          result = described_class.from_age_estimate(photo_person: photo_person)
          expect(result).to be_nil
        }.not_to change(DateDetermination, :count)
      end
    end

    context "with a photo_face" do
      it "creates a date determination when tagged person has DOB" do
        person = create(:person, dob_year: 1950)
        photo = create(:photo, family: person.family)
        photo_face = create(:photo_face, photo: photo, person: person, estimated_age: 25)

        allow(Photo::ConfidenceScorer).to receive(:score_age_estimate).with(person, 25).and_return(0.75)

        result = described_class.from_age_estimate(photo_face: photo_face)

        expect(result).to be_persisted
        expect(result.photo_face).to eq(photo_face)
        expect(result.determined_year).to eq(1975)
        expect(result.confidence).to eq(0.75)
      end

      it "returns nil when face is untagged" do
        photo_face = create(:photo_face, person: nil, estimated_age: 25)

        expect {
          result = described_class.from_age_estimate(photo_face: photo_face)
          expect(result).to be_nil
        }.not_to change(DateDetermination, :count)
      end
    end
  end

  describe ".from_exif" do
    it "creates a date determination from EXIF timestamp" do
      photo = create(:photo)
      taken_at = Time.zone.parse("1999-12-31 23:15:22")

      allow(Photo::ConfidenceScorer).to receive(:score_exif).with(taken_at).and_return(0.95)

      result = described_class.from_exif(photo, taken_at: taken_at)

      expect(result).to be_persisted
      expect(result.source_type).to eq("exif")
      expect(result.determined_year).to eq(1999)
      expect(result.determined_month).to eq(12)
      expect(result.determined_day).to eq(31)
      expect(result.confidence).to eq(0.95)
    end
  end

  describe ".from_filename" do
    it "creates a date determination from parsed filename result" do
      photo = create(:photo)
      date_result = Photo::DateExtractor::Result.new(year: 1984, month: 3, day: 4, pattern: :compact_date)

      allow(Photo::ConfidenceScorer).to receive(:score_filename).with(date_result).and_return(0.6)

      result = described_class.from_filename(photo, date_result: date_result)

      expect(result).to be_persisted
      expect(result.source_type).to eq("filename")
      expect(result.determined_year).to eq(1984)
      expect(result.determined_month).to eq(3)
      expect(result.determined_day).to eq(4)
      expect(result.confidence).to eq(0.6)
    end
  end

  describe ".from_manual" do
    it "creates a manual date determination with user attribution" do
      user = create(:user)
      photo = create(:photo, family: user.families.first)

      allow(Photo::ConfidenceScorer).to receive(:score_manual).and_return(0.9)

      result = described_class.from_manual(photo, year: 2001, month: 9, day: 8, user: user)

      expect(result).to be_persisted
      expect(result.source_type).to eq("manual")
      expect(result.created_by).to eq(user)
      expect(result.determined_year).to eq(2001)
      expect(result.determined_month).to eq(9)
      expect(result.determined_day).to eq(8)
      expect(result.confidence).to eq(0.9)
    end
  end

  describe "determined date priority updates" do
    it "keeps the photo's highest confidence determination" do
      photo = create(:photo)
      create(:date_determination, photo: photo, source_type: "manual", determined_year: 1960, confidence: 0.95)
      date_result = Photo::DateExtractor::Result.new(year: 1984, month: 3, day: 4, pattern: :compact_date)

      allow(Photo::ConfidenceScorer).to receive(:score_filename).with(date_result).and_return(0.6)

      described_class.from_filename(photo, date_result: date_result)

      photo.reload
      expect(photo.determined_year).to eq(1960)
    end
  end
end
