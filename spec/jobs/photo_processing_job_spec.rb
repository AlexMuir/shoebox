# frozen_string_literal: true

require "rails_helper"

RSpec.describe PhotoProcessingJob, type: :job do
  let(:fixture_image_path) { Rails.root.join("spec/fixtures/photos/orientation/1_-90deg.jpg") }

  def attach_fixture_image(photo)
    photo.original.attach(
      io: File.open(fixture_image_path),
      filename: "1_-90deg.jpg",
      content_type: "image/jpeg"
    )
  end

  def metadata_with_exif(orientation:, date_time_original: nil)
    {
      file: {},
      dimensions: { width: 1200, height: 800 },
      exif: {
        orientation: orientation,
        date_time_original: date_time_original
      }.compact,
      filename_date: {},
      processing: {}
    }
  end

  def stub_microservice_rotation(rotation)
    response = instance_double(Net::HTTPOK, body: { rotation: rotation }.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow_any_instance_of(described_class).to receive(:post_image).and_return(response)
  end

  describe "#perform" do
    it "extracts metadata and stores metadata + taken date fields" do
      photo = create(:photo)
      photo.original.purge
      attach_fixture_image(photo)

      metadata = metadata_with_exif(
        orientation: 1,
        date_time_original: "2020:07:14 11:22:33"
      )
      allow(Photo::MetadataExtractor).to receive(:call).and_return(metadata)
      stub_microservice_rotation(0)

      described_class.perform_now(photo.id)

      photo.reload
      expect(photo.image_metadata).to include(exif: include(orientation: 1, date_time_original: "2020:07:14 11:22:33"))
      expect(photo.taken_at).to be_present
      expect(photo.year).to eq(2020)
      expect(photo.month).to eq(7)
      expect(photo.day).to eq(14)
      expect(photo.date_type).to eq("exact")
    end

    it "creates a rotated working_image when EXIF orientation requires correction" do
      photo = create(:photo)
      photo.original.purge
      attach_fixture_image(photo)

      allow(Photo::MetadataExtractor).to receive(:call).and_return(metadata_with_exif(orientation: 6))

      described_class.perform_now(photo.id)

      photo.reload
      expect(photo.working_image).to be_attached
      expect(photo.working_image.blob_id).not_to eq(photo.original.blob_id)
    end

    it "does not create working_image when orientation is normal" do
      photo = create(:photo)
      photo.original.purge
      attach_fixture_image(photo)

      allow(Photo::MetadataExtractor).to receive(:call).and_return(metadata_with_exif(orientation: 1))
      stub_microservice_rotation(0)

      described_class.perform_now(photo.id)

      expect(photo.reload.working_image).not_to be_attached
    end

    it "discards missing photo records" do
      expect {
        described_class.perform_now(-1)
      }.not_to raise_error
    end

    it "returns early when no original is attached" do
      photo = create(:photo)
      photo.original.purge

      allow(Photo::MetadataExtractor).to receive(:call)

      described_class.perform_now(photo.id)

      expect(Photo::MetadataExtractor).not_to have_received(:call)
      expect(photo.reload.working_image).not_to be_attached
    end
  end
end
