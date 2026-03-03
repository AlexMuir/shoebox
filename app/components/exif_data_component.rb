# frozen_string_literal: true

class ExifDataComponent < ViewComponent::Base
  def initialize(photo:)
    @photo = photo
    @metadata = photo.image_metadata || {}
  end

  def has_metadata?
    @metadata.present?
  end

  def sections
    [
      { title: "File Info", data: file_info },
      { title: "Camera", data: camera_info },
      { title: "Exposure", data: exposure_info },
      { title: "GPS", data: gps_info },
      { title: "Dates", data: dates_info }
    ].reject { |section| section[:data].empty? }
  end

  private

  def file_info
    file = @metadata["file"] || {}
    dimensions = @metadata["dimensions"] || {}

    data = {}
    data["Filename"] = file["original_filename"] if file["original_filename"].present?
    data["Type"] = file["content_type"] if file["content_type"].present?
    data["Size"] = number_to_human_size(file["file_size"]) if file["file_size"].present?
    data["Dimensions"] = "#{dimensions["width"]} x #{dimensions["height"]}" if dimensions["width"].present? && dimensions["height"].present?
    data
  end

  def camera_info
    exif = @metadata["exif"] || {}

    data = {}
    data["Make"] = exif["make"] if exif["make"].present?
    data["Model"] = exif["model"] if exif["model"].present?
    data["Software"] = exif["software"] if exif["software"].present?
    data
  end

  def exposure_info
    exif = @metadata["exif"] || {}

    data = {}
    data["Exposure Time"] = exif["exposure_time"] if exif["exposure_time"].present?
    data["F-Number"] = exif["f_number"] if exif["f_number"].present?
    data["ISO"] = exif["iso"] if exif["iso"].present?
    data["Focal Length"] = exif["focal_length"] if exif["focal_length"].present?
    data["Flash"] = exif["flash"] if exif["flash"].present?
    data
  end

  def gps_info
    exif = @metadata["exif"] || {}

    data = {}
    data["Latitude"] = exif["gps_latitude"] if exif["gps_latitude"].present?
    data["Longitude"] = exif["gps_longitude"] if exif["gps_longitude"].present?
    data
  end

  def dates_info
    exif = @metadata["exif"] || {}
    file = @metadata["file"] || {}
    filename_date = @metadata["filename_date"] || {}
    processing = @metadata["processing"] || {}

    data = {}
    data["Original Date"] = exif["date_time_original"] if exif["date_time_original"].present?
    data["File Modified"] = file["file_modified_at"] if file["file_modified_at"].present?
    data["Filename Date"] = "Parsed" if filename_date["parsed"]
    data["Extracted At"] = processing["extracted_at"] if processing["extracted_at"].present?
    data
  end
end
