# frozen_string_literal: true

class Photo::MetadataExtractor < ApplicationService
  EXIF_TAG_MAP = {
    "Make" => :make,
    "Model" => :model,
    "DateTimeOriginal" => :date_time_original,
    "ExposureTime" => :exposure_time,
    "FNumber" => :f_number,
    "ISO" => :iso,
    "FocalLength" => :focal_length,
    "GPSLatitude" => :gps_latitude,
    "GPSLongitude" => :gps_longitude,
    "Orientation" => :orientation
  }.freeze

  NON_EXIF_TAGS = %i[
    source_file
    exif_tool_version
    file_name
    directory
    file_size
    file_modify_date
    file_access_date
    file_inode_change_date
    file_permissions
    file_type
    file_type_extension
    mime_type
    image_width
    image_height
    image_size
    megapixels
    warning
  ].freeze

  def initialize(file_path, original_filename)
    @file_path = file_path
    @original_filename = original_filename
  end

  def call
    metadata = base_metadata

    exiftool = MiniExiftool.new(@file_path)
    raw_tags = exiftool.to_hash

    metadata[:dimensions] = extract_dimensions(exiftool, raw_tags)
    metadata[:exif] = build_exif_hash(raw_tags)
    metadata
  rescue StandardError => e
    Rails.logger.warn("Photo::MetadataExtractor failed for #{@file_path}: #{e.class} #{e.message}")
    metadata
  end

  private

  def base_metadata
    {
      file: {
        original_filename: @original_filename,
        content_type: content_type,
        file_size: file_size,
        file_modified_at: file_modified_at
      },
      dimensions: {
        width: nil,
        height: nil
      },
      exif: {},
      filename_date: filename_date_hash,
      processing: {
        extracted_at: Time.current
      }
    }
  end

  def content_type
    Marcel::MimeType.for(Pathname.new(@file_path), name: @original_filename)
  rescue StandardError
    nil
  end

  def file_size
    File.size(@file_path)
  rescue StandardError
    nil
  end

  def file_modified_at
    File.mtime(@file_path)
  rescue StandardError
    nil
  end

  def filename_date_hash
    date_result = Photo::DateExtractor.call(@original_filename)

    {
      parsed: date_result.present?,
      year: date_result&.year,
      month: date_result&.month,
      day: date_result&.day,
      hour: date_result&.hour,
      minute: date_result&.minute,
      second: date_result&.second,
      pattern: date_result&.pattern
    }
  end

  def extract_dimensions(exiftool, raw_tags)
    tags = normalize_tags(raw_tags)

    {
      width: tags[:image_width] || exiftool.imagewidth,
      height: tags[:image_height] || exiftool.imageheight
    }
  rescue StandardError
    { width: nil, height: nil }
  end

  def build_exif_hash(raw_tags)
    tags = normalize_tags(raw_tags)
    mapped_tags = build_mapped_tags(raw_tags)
    additional_tags = tags.except(*NON_EXIF_TAGS, *EXIF_TAG_MAP.values).compact

    mapped_tags.merge(additional_tags)
  end

  def build_mapped_tags(raw_tags)
    EXIF_TAG_MAP.each_with_object({}) do |(source_key, target_key), hash|
      value = raw_tags[source_key]
      hash[target_key] = value unless value.nil?
    end
  end

  def normalize_tags(raw_tags)
    raw_tags.each_with_object({}) do |(key, value), hash|
      hash[key.to_s.underscore.to_sym] = value
    end
  end
end
