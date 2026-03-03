# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Photo processing pipeline", type: :integration do
  let(:fixture_image_path) { Rails.root.join("spec/fixtures/photos/orientation/1_-90deg.jpg") }

  def stub_orientation_service_failure
    allow_any_instance_of(PhotoProcessingJob)
      .to receive(:post_image)
      .and_return(double(is_a?: false, body: "{}"))
  end

  def minimal_png_tempfile
    file = Tempfile.new([ "no_exif", ".png" ])
    file.binmode
    file.write(
      [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
        0x54, 0x08, 0x99, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
        0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82
      ].pack("C*")
    )
    file.rewind
    file
  end

  def attach_fixture_image(photo)
    photo.original.purge if photo.original.attached?
    photo.original.attach(
      io: File.open(fixture_image_path),
      filename: "1_-90deg.jpg",
      content_type: "image/jpeg"
    )
    photo.update!(original_filename: "1_-90deg.jpg")
  end

  it "runs the full pipeline for EXIF image metadata and display variants" do
    stub_orientation_service_failure
    photo = create(:photo)
    attach_fixture_image(photo)
    allow(Photo::MetadataExtractor).to receive(:call).and_return(
      {
        file: { original_filename: "1_-90deg.jpg" },
        dimensions: { width: 1200, height: 800 },
        exif: { orientation: 8 },
        filename_date: {},
        processing: {}
      }
    )

    expect { PhotoProcessingJob.new.perform(photo.id) }.not_to raise_error

    photo.reload
    expect(photo.original).to be_attached
    expect(photo.image_metadata).not_to eq({})
    expect(photo.image_metadata.dig("file", "original_filename")).to eq("1_-90deg.jpg")
    expect(photo.image_metadata["exif"]).to be_a(Hash)
    expect(photo.working_image).to be_attached
    expect(photo.display_image.blob_id).to eq(photo.working_image.blob_id)
    expect { photo.display_image.variant(:thumb) }.not_to raise_error
  end

  it "does not attach a working image when no rotation is needed" do
    stub_orientation_service_failure
    photo = create(:photo)
    png = minimal_png_tempfile

    photo.original.purge if photo.original.attached?
    photo.original.attach(
      io: File.open(png.path),
      filename: "no_exif.png",
      content_type: "image/png"
    )

    expect { PhotoProcessingJob.new.perform(photo.id) }.not_to raise_error
    expect(photo.reload.working_image).not_to be_attached
  ensure
    png&.close
    png&.unlink
  end

  it "returns early without error when the photo has no original" do
    stub_orientation_service_failure
    photo = create(:photo)
    photo.original.purge

    expect { PhotoProcessingJob.new.perform(photo.id) }.not_to raise_error
    expect(photo.reload.working_image).not_to be_attached
  end

  it "discards missing photo records without error" do
    stub_orientation_service_failure

    expect { PhotoProcessingJob.perform_now(-1) }.not_to raise_error
  end
end
