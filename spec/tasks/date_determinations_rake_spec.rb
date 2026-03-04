# frozen_string_literal: true

require "rails_helper"

RSpec.describe "date_determinations:backfill rake task" do
  before do
    Rails.application.load_tasks
  end

  let(:family) { create(:family) }

  describe "date_determinations:backfill" do
    it "finds photos with taken_at but no DateDetermination with source_type 'exif'" do
      photo_with_taken_at = create(:photo, family: family, taken_at: Time.zone.parse("2020-06-15 10:30:00"))
      create(:photo, family: family, taken_at: nil)

      expect {
        Rake::Task["date_determinations:backfill"].execute
      }.to change { DateDetermination.where(source_type: "exif").count }.by(1)

      determination = DateDetermination.where(source_type: "exif").first
      expect(determination.photo_id).to eq(photo_with_taken_at.id)
    end

    it "creates DateDetermination with correct year/month/day from taken_at" do
      photo = create(:photo, family: family, taken_at: Time.zone.parse("2020-06-15 10:30:00"))

      Rake::Task["date_determinations:backfill"].execute

      determination = DateDetermination.where(source_type: "exif").first
      expect(determination.determined_year).to eq(2020)
      expect(determination.determined_month).to eq(6)
      expect(determination.determined_day).to eq(15)
    end

    it "sets confidence to 0.95 for EXIF determinations" do
      photo = create(:photo, family: family, taken_at: Time.zone.parse("2020-06-15 10:30:00"))

      Rake::Task["date_determinations:backfill"].execute

      determination = DateDetermination.where(source_type: "exif").first
      expect(determination.confidence).to eq(0.95)
    end

    it "skips photos that already have an exif DateDetermination" do
      photo = create(:photo, family: family, taken_at: Time.zone.parse("2020-06-15 10:30:00"))
      create(:date_determination, photo: photo, source_type: "exif")

      expect {
        Rake::Task["date_determinations:backfill"].execute
      }.not_to change { DateDetermination.where(source_type: "exif").count }
    end

    it "is idempotent - running twice doesn't create duplicates" do
      photo = create(:photo, family: family, taken_at: Time.zone.parse("2020-06-15 10:30:00"))

      Rake::Task["date_determinations:backfill"].execute
      initial_count = DateDetermination.where(source_type: "exif").count

      Rake::Task["date_determinations:backfill"].reenable
      Rake::Task["date_determinations:backfill"].execute

      final_count = DateDetermination.where(source_type: "exif").count
      expect(final_count).to eq(initial_count)
    end

    it "handles multiple photos with taken_at" do
      photo1 = create(:photo, family: family, taken_at: Time.zone.parse("2020-06-15 10:30:00"))
      photo2 = create(:photo, family: family, taken_at: Time.zone.parse("2019-03-20 14:45:00"))
      photo3 = create(:photo, family: family, taken_at: nil)

      Rake::Task["date_determinations:backfill"].execute

      exif_determinations = DateDetermination.where(source_type: "exif")
      expect(exif_determinations.count).to eq(2)
      expect(exif_determinations.map(&:photo_id)).to match_array([ photo1.id, photo2.id ])
    end

    it "handles empty database gracefully" do
      expect {
        Rake::Task["date_determinations:backfill"].execute
      }.not_to raise_error
    end
  end
end
