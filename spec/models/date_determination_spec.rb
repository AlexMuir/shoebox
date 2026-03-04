require "rails_helper"

RSpec.describe DateDetermination, type: :model do
  it { should belong_to(:photo) }
  it { should belong_to(:created_by).class_name("User").optional }
  it { should belong_to(:photo_person).optional }
  it { should belong_to(:photo_face).optional }

  it { should validate_presence_of(:source_type) }
  it { should validate_inclusion_of(:source_type).in_array(%w[exif age_estimate manual filename]) }
  it { should validate_presence_of(:determined_year) }
  it { should validate_numericality_of(:confidence).is_greater_than_or_equal_to(0.0).is_less_than_or_equal_to(1.0).allow_nil }

  describe "scopes" do
    it "orders by confidence descending" do
      low = create(:date_determination, confidence: 0.3)
      high = create(:date_determination, confidence: 0.9)
      medium = create(:date_determination, confidence: 0.5)

      expect(DateDetermination.by_confidence).to eq([ high, medium, low ])
    end

    it "filters by source type" do
      exif = create(:date_determination, source_type: "exif")
      create(:date_determination, source_type: "manual")

      expect(DateDetermination.for_source_type("exif")).to eq([ exif ])
    end

    it "returns highest confidence from best" do
      low = create(:date_determination, confidence: 0.25)
      high = create(:date_determination, confidence: 0.95)

      expect(DateDetermination.best).to eq(high)
      expect(DateDetermination.best).not_to eq(low)
    end
  end

  describe "#determined_date_text" do
    it "builds fuzzy date text from determined fields" do
      determination = build(:date_determination, determined_year: 1975, determined_month: 6, determined_day: 15)

      expect(determination.determined_date_text).to eq("15 June 1975")
    end

    it "returns nil without determined year" do
      determination = build(:date_determination, determined_year: nil)

      expect(determination.determined_date_text).to be_nil
    end
  end

  describe "photo sync" do
    it "updates photo determined fields after save" do
      photo = create(:photo)
      determination = create(
        :date_determination,
        photo: photo,
        determined_year: 1975,
        determined_month: 6,
        determined_day: 15,
        confidence: 0.95
      )

      photo.reload

      expect(photo.determined_year).to eq(1975)
      expect(photo.determined_month).to eq(6)
      expect(photo.determined_day).to eq(15)
      expect(photo.best_date_determination_id).to eq(determination.id)
    end

    it "keeps highest confidence as best date determination" do
      photo = create(:photo)
      create(:date_determination, photo: photo, determined_year: 1968, confidence: 0.45)
      best = create(:date_determination, photo: photo, determined_year: 1975, confidence: 0.95)

      photo.reload

      expect(photo.determined_year).to eq(1975)
      expect(photo.best_date_determination_id).to eq(best.id)
    end
  end

  describe "Photo#determined_date_text" do
    it "uses determined date fields with fuzzy formatting" do
      photo = create(:photo, determined_year: 1984, determined_month: 3, determined_day: 4)

      expect(photo.determined_date_text).to eq("04 March 1984")
    end
  end
end
