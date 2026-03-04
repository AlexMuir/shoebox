# frozen_string_literal: true

require "rails_helper"

RSpec.describe Photo, type: :model do
  describe "#import_detected_faces!" do
    it "creates face records from normalized metadata" do
      photo = create(:photo, width: 2000, height: 1000)
      metadata = photo.original.blob.metadata.merge(
        "detected_faces" => [
          { "x" => 0.1, "y" => 0.2, "width" => 0.25, "height" => 0.3, "confidence" => 0.95 },
          { "left" => 800, "top" => 100, "width" => 300, "height" => 250 }
        ]
      )
      photo.original.blob.update!(metadata: metadata)

      expect { photo.import_detected_faces! }.to change(photo.photo_faces, :count).by(2)

      face_one = photo.photo_faces.ordered.first
      expect(face_one.x.to_f).to eq(0.1)
      expect(face_one.y.to_f).to eq(0.2)
      expect(face_one.width.to_f).to eq(0.25)
      expect(face_one.height.to_f).to eq(0.3)
      expect(face_one.confidence.to_f).to eq(0.95)

      face_two = photo.photo_faces.ordered.second
      expect(face_two.x.to_f).to eq(0.4)
      expect(face_two.y.to_f).to eq(0.1)
      expect(face_two.width.to_f).to eq(0.15)
      expect(face_two.height.to_f).to eq(0.25)
    end

    it "imports Rekognition-style face details" do
      photo = create(:photo, width: 1000, height: 500)
      metadata = photo.original.blob.metadata.merge(
        "rekognition" => {
          "face_details" => [
            {
              "BoundingBox" => {
                "Left" => 0.25,
                "Top" => 0.1,
                "Width" => 0.2,
                "Height" => 0.4
              },
              "Confidence" => 99.1
            }
          ]
        }
      )
      photo.original.blob.update!(metadata: metadata)

      expect { photo.import_detected_faces! }.to change(photo.photo_faces, :count).by(1)

      face = photo.photo_faces.ordered.first
      expect(face.x.to_f).to eq(0.25)
      expect(face.y.to_f).to eq(0.1)
      expect(face.width.to_f).to eq(0.2)
      expect(face.height.to_f).to eq(0.4)
      expect(face.confidence.to_f).to eq(99.1)
    end

    it "does not create duplicate faces when imported multiple times" do
      photo = create(:photo, width: 1600, height: 900)
      metadata = photo.original.blob.metadata.merge(
        "detected_faces" => [
          { "x" => 0.2, "y" => 0.15, "width" => 0.2, "height" => 0.2 }
        ]
      )
      photo.original.blob.update!(metadata: metadata)

      photo.import_detected_faces!

      expect { photo.import_detected_faces! }.not_to change(photo.photo_faces, :count)
    end
  end

  describe "callbacks" do
    it "enqueues PhotoProcessingJob after creation" do
      expect {
        create(:photo)
      }.to have_enqueued_job(PhotoProcessingJob)
    end

    it "does not enqueue PhotoProcessingJob on update" do
      photo = create(:photo)

      expect {
        photo.update!(title: "New title")
      }.not_to have_enqueued_job(PhotoProcessingJob)
    end
  end

  describe "attachments" do
    it "uses original as the source attachment" do
      photo = build(:photo)

      expect(photo.original).to be_attached
      expect(photo).not_to respond_to(:image)
    end

    it "has a working_image attachment" do
      photo = build(:photo)

      expect(photo).to respond_to(:working_image)
      expect(photo.working_image).not_to be_attached
    end

    it "returns working_image when attached" do
      photo = create(:photo)
      photo.working_image.attach(
        io: StringIO.new("working image"),
        filename: "working.jpg",
        content_type: "image/jpeg"
      )

      expect(photo.display_image).to eq(photo.working_image)
    end

    it "falls back to original when working_image is not attached" do
      photo = create(:photo)

      expect(photo.display_image).to eq(photo.original)
    end

    it "exposes image_metadata as a hash" do
      photo = build(:photo)

      expect(photo.image_metadata).to be_a(Hash)
    end
  end

  describe "#oriented_variant" do
    it "returns the named variant when no correction needed" do
      photo = create(:photo, orientation_correction: 0)
      variant = photo.oriented_variant(:thumb)
      expect(variant).to be_present
    end

    it "applies rotation when correction is set" do
      photo = create(:photo, orientation_correction: 270)
      expect(photo.orientation_corrected?).to be true
      expect(photo.vips_rotation).to eq(:d270)
    end
  end

  describe "#extract_date_from_filename" do
    it "creates a DateDetermination with source_type 'filename'" do
      photo = create(:photo, original_filename: "2015-06-15_vacation.jpg")

      expect {
        photo.send(:extract_date_from_filename)
      }.to change(DateDetermination, :count).by(1)

      determination = photo.date_determinations.last
      expect(determination.source_type).to eq("filename")
      expect(determination.determined_year).to eq(2015)
      expect(determination.determined_month).to eq(6)
      expect(determination.determined_day).to eq(15)
    end

    it "sets confidence to 0.6 from ConfidenceScorer" do
      photo = create(:photo, original_filename: "2020-03-10_photo.jpg")

      photo.send(:extract_date_from_filename)

      determination = photo.date_determinations.last
      expect(determination.confidence).to eq(0.6)
    end

    it "still populates fuzzy date fields for backwards compatibility" do
      photo = create(:photo, original_filename: "2018-12-25_christmas.jpg")

      photo.send(:extract_date_from_filename)

      photo.reload
      expect(photo.year).to eq(2018)
      expect(photo.month).to eq(12)
      expect(photo.day).to eq(25)
      expect(photo.date_type).to eq("exact")
    end

    it "does not create DateDetermination if filename has no date" do
      photo = create(:photo, original_filename: "random_photo.jpg")

      expect {
        photo.send(:extract_date_from_filename)
      }.not_to change(DateDetermination, :count)
    end

    it "does not create DateDetermination if original_filename is blank" do
      photo = create(:photo, original_filename: nil)

      expect {
        photo.send(:extract_date_from_filename)
      }.not_to change(DateDetermination, :count)
    end
  end

  describe "#extract_exif_taken_at" do
    it "creates an EXIF date determination and keeps taken_at for compatibility" do
      photo = create(:photo)
      vips_image = instance_double(Vips::Image)
      exif_timestamp = "2020:07:04 10:11:12"
      expected_time = Time.strptime(exif_timestamp, "%Y:%m:%d %H:%M:%S")

      allow(Vips::Image).to receive(:new_from_file).and_return(vips_image)
      allow(vips_image).to receive(:get).with("exif-ifd2-DateTimeOriginal").and_return(exif_timestamp)

      expect {
        photo.send(:extract_exif_taken_at)
      }.to change(DateDetermination, :count).by(1)

      photo.reload
      determination = photo.date_determinations.last

      expect(determination.source_type).to eq("exif")
      expect(determination.determined_year).to eq(2020)
      expect(determination.determined_month).to eq(7)
      expect(determination.determined_day).to eq(4)
      expect(determination.confidence).to eq(0.95)
      expect(photo.determined_year).to eq(2020)
      expect(photo.taken_at).to be_within(1.second).of(expected_time)
    end

    it "does nothing when EXIF does not contain a parseable timestamp" do
      photo = create(:photo)
      vips_image = instance_double(Vips::Image)

      allow(Vips::Image).to receive(:new_from_file).and_return(vips_image)
      allow(vips_image).to receive(:get).with("exif-ifd2-DateTimeOriginal").and_return("not-a-date")

      expect {
        photo.send(:extract_exif_taken_at)
      }.not_to change(DateDetermination, :count)

      photo.reload
      expect(photo.taken_at).to be_nil
      expect(photo.determined_year).to be_nil
    end
  end
end

  describe "#determined_date_text" do
    it "returns nil when no determined date is set" do
      photo = build(:photo)
      expect(photo.determined_date_text).to be_nil
    end

    it "returns year only when only determined_year is set" do
      photo = build(:photo, determined_year: 1975)
      expect(photo.determined_date_text).to eq("1975")
    end

    it "returns month and year when determined_year and determined_month are set" do
      photo = build(:photo, determined_year: 1975, determined_month: 6)
      expect(photo.determined_date_text).to eq("June 1975")
    end

    it "returns full date when all determined date fields are set" do
      photo = build(:photo, determined_year: 1975, determined_month: 6, determined_day: 15)
      expect(photo.determined_date_text).to eq("15 June 1975")
    end
  end

  describe "#has_determined_date?" do
    it "returns false when no determined_year is set" do
      photo = build(:photo)
      expect(photo.has_determined_date?).to be false
    end

    it "returns true when determined_year is set" do
      photo = build(:photo, determined_year: 1975)
      expect(photo.has_determined_date?).to be true
    end

    it "returns true even if only determined_year is set" do
      photo = build(:photo, determined_year: 2000, determined_month: nil, determined_day: nil)
      expect(photo.has_determined_date?).to be true
    end
  end
