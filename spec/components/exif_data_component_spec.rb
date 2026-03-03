# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExifDataComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:photo) { build_stubbed(:photo, image_metadata: metadata) }

  context "when metadata is present" do
    let(:metadata) do
      {
        "file" => {
          "original_filename" => "test_image.jpg",
          "content_type" => "image/jpeg",
          "file_size" => 1_048_576,
          "file_modified_at" => "2023-01-01T12:00:00Z"
        },
        "dimensions" => {
          "width" => 1920,
          "height" => 1080
        },
        "exif" => {
          "make" => "Apple",
          "model" => "iPhone 12",
          "software" => "iOS 15.0",
          "exposure_time" => "1/60",
          "f_number" => 1.8,
          "iso" => 100,
          "focal_length" => "4.2mm",
          "flash" => "Off, Did not fire",
          "gps_latitude" => 37.7749,
          "gps_longitude" => -122.4194,
          "date_time_original" => "2023-01-01T10:00:00Z",
          "internal_secret_key" => "should_not_display"
        },
        "filename_date" => {
          "parsed" => true,
          "year" => 2023
        },
        "processing" => {
          "extracted_at" => "2023-01-02T12:00:00Z"
        }
      }
    end

    it "renders the component with metadata sections" do
      render_inline(described_class.new(photo: photo))

      expect(rendered_content).to include("card")
      expect(rendered_content).to include("File Info")
      expect(rendered_content).to include("Camera")
      expect(rendered_content).to include("Exposure")
      expect(rendered_content).to include("GPS")
      expect(rendered_content).to include("Dates")
    end

    it "displays formatted file size" do
      render_inline(described_class.new(photo: photo))

      expect(rendered_content).to include("1 MB")
    end

    it "displays specific metadata values" do
      render_inline(described_class.new(photo: photo))

      expect(rendered_content).to include("test_image.jpg")
      expect(rendered_content).to include("iPhone 12")
      expect(rendered_content).to include("1/60")
      expect(rendered_content).to include("37.7749")
    end

    it "excludes sensitive or internal keys" do
      render_inline(described_class.new(photo: photo))

      expect(rendered_content).not_to include("internal_secret_key")
      expect(rendered_content).not_to include("should_not_display")
    end
  end

  context "when metadata is empty" do
    let(:metadata) { {} }

    it "renders a 'No metadata available' message" do
      render_inline(described_class.new(photo: photo))

      expect(rendered_content).to include("No metadata available")
      expect(rendered_content).not_to include("<table")
    end
  end

  context "when metadata is nil" do
    let(:metadata) { nil }

    it "renders a 'No metadata available' message" do
      render_inline(described_class.new(photo: photo))

      expect(rendered_content).to include("No metadata available")
      expect(rendered_content).not_to include("<table")
    end
  end
end
