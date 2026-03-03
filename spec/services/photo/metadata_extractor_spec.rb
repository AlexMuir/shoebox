# frozen_string_literal: true

require "rails_helper"
require "tempfile"

RSpec.describe Photo::MetadataExtractor do
  describe ".call" do
    let(:original_filename) { "IMG_20200615_143052.jpg" }
    let(:date_result) do
      Photo::DateExtractor::Result.new(
        year: 2020,
        month: 6,
        day: 15,
        hour: 14,
        minute: 30,
        second: 52,
        pattern: :compact_datetime
      )
    end

    it "returns the expected metadata structure for a JPEG with EXIF" do
      file = Tempfile.new([ "photo", ".jpg" ])
      file.binmode
      file.write("jpeg-bytes")
      file.close

      exif_time = Time.zone.parse("2020-06-15 14:30:52")
      exif_hash = {
        "Make" => "Canon",
        "Model" => "AE-1",
        "DateTimeOriginal" => exif_time,
        "ExposureTime" => "1/125",
        "FNumber" => 2.8,
        "ISO" => 100,
        "FocalLength" => "50.0 mm",
        "GPSLatitude" => -1.2921,
        "GPSLongitude" => 36.8219,
        "Orientation" => 6,
        "CustomTag" => "custom-value",
        "NilTag" => nil,
        "MIMEType" => "image/jpeg",
        "ImageWidth" => 3000,
        "ImageHeight" => 2000
      }
      exiftool = double("MiniExiftool", to_hash: exif_hash, imagewidth: 3000, imageheight: 2000)

      allow(MiniExiftool).to receive(:new).with(file.path).and_return(exiftool)
      allow(Photo::DateExtractor).to receive(:call).with(original_filename).and_return(date_result)

      metadata = described_class.call(file.path, original_filename)

      expect(metadata.keys).to contain_exactly(:file, :dimensions, :exif, :filename_date, :processing)
      expect(metadata[:file]).to include(
        original_filename: original_filename,
        content_type: "image/jpeg",
        file_size: 10,
        file_modified_at: be_a(Time)
      )
      expect(metadata[:dimensions]).to eq(width: 3000, height: 2000)
      expect(metadata[:exif]).to include(
        make: "Canon",
        model: "AE-1",
        date_time_original: exif_time,
        exposure_time: "1/125",
        f_number: 2.8,
        iso: 100,
        focal_length: "50.0 mm",
        gps_latitude: -1.2921,
        gps_longitude: 36.8219,
        orientation: 6,
        custom_tag: "custom-value"
      )
      expect(metadata[:exif]).not_to have_key(:nil_tag)
      expect(metadata[:exif]).not_to have_key(:mime_type)
      expect(metadata[:filename_date]).to eq(
        parsed: true,
        year: 2020,
        month: 6,
        day: 15,
        hour: 14,
        minute: 30,
        second: 52,
        pattern: :compact_datetime
      )
      expect(metadata[:processing][:extracted_at]).to be_a(ActiveSupport::TimeWithZone)

      file.unlink
    end

    it "returns an empty exif hash for a file without exif" do
      file = Tempfile.new([ "no-exif", ".png" ])
      file.binmode
      file.write("\x89PNG\r\n\x1A\n" + ("\x00" * 100))
      file.close

      metadata = described_class.call(file.path, "scan.png")

      expect(metadata[:exif]).to eq({})

      file.unlink
    end

    it "logs a warning and returns partial metadata when MiniExiftool fails" do
      file = Tempfile.new([ "photo", ".jpg" ])
      file.binmode
      file.write("jpeg-bytes")
      file.close

      allow(MiniExiftool).to receive(:new).and_raise(StandardError, "exiftool failed")
      allow(Rails.logger).to receive(:warn)

      metadata = described_class.call(file.path, original_filename)

      expect(Rails.logger).to have_received(:warn).with(/Photo::MetadataExtractor failed/)
      expect(metadata[:file][:original_filename]).to eq(original_filename)
      expect(metadata[:dimensions]).to eq(width: nil, height: nil)
      expect(metadata[:exif]).to eq({})
      expect(metadata[:processing][:extracted_at]).to be_a(ActiveSupport::TimeWithZone)

      file.unlink
    end
  end
end
