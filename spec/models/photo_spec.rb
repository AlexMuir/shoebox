require "rails_helper"

RSpec.describe Photo, type: :model do
  describe "#import_detected_faces!" do
    it "creates face records from normalized metadata" do
      photo = create(:photo, width: 2000, height: 1000)
      metadata = photo.image.blob.metadata.merge(
        "detected_faces" => [
          { "x" => 0.1, "y" => 0.2, "width" => 0.25, "height" => 0.3, "confidence" => 0.95 },
          { "left" => 800, "top" => 100, "width" => 300, "height" => 250 }
        ]
      )
      photo.image.blob.update!(metadata: metadata)

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
      metadata = photo.image.blob.metadata.merge(
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
      photo.image.blob.update!(metadata: metadata)

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
      metadata = photo.image.blob.metadata.merge(
        "detected_faces" => [
          { "x" => 0.2, "y" => 0.15, "width" => 0.2, "height" => 0.2 }
        ]
      )
      photo.image.blob.update!(metadata: metadata)

      photo.import_detected_faces!

      expect { photo.import_detected_faces! }.not_to change(photo.photo_faces, :count)
    end
  end

  describe "callbacks" do
    it "enqueues OrientationDetectionJob after creation" do
      expect {
        create(:photo)
      }.to have_enqueued_job(OrientationDetectionJob)
    end

    it "does not enqueue OrientationDetectionJob on update" do
      photo = create(:photo)

      expect {
        photo.update!(title: "New title")
      }.not_to have_enqueued_job(OrientationDetectionJob)
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
end
