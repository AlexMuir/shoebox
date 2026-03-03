# frozen_string_literal: true

class PhotoProcessingJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
           wait: :polynomially_longer, attempts: 5

  ORIENTATION_SERVICE_URL = ENV.fetch(
    "ORIENTATION_SERVICE_URL",
    "http://localhost:8150"
  )

  EXIF_ORIENTATION_TO_ROTATION = {
    1 => 0,
    3 => 180,
    6 => 90,
    8 => 270
  }.freeze

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return unless photo.original.attached?

    photo.original.blob.open do |tempfile|
      metadata = Photo::MetadataExtractor.call(tempfile.path, photo.original_filename)
      photo.image_metadata = metadata
      apply_exif_date!(photo, metadata)

      rotation = detect_orientation(photo, metadata, tempfile)
      rotated_io, rotated_file = if rotation.present? && rotation != 0
        attach_rotated_working_image(photo, tempfile, rotation)
      end
      photo.save!
      rotated_io&.close
      rotated_file&.close!
    end
  end

  private

  def apply_exif_date!(photo, metadata)
    date_time_original = exif_value(metadata, :date_time_original)
    return if date_time_original.blank?

    parsed = Time.strptime(date_time_original, "%Y:%m:%d %H:%M:%S")
    photo.taken_at = parsed
    photo.year = parsed.year
    photo.month = parsed.month
    photo.day = parsed.day
    photo.date_type = "exact"
  rescue ArgumentError
    nil
  end

  def detect_orientation(photo, metadata, tempfile)
    exif_orientation = exif_value(metadata, :orientation)&.to_i
    return EXIF_ORIENTATION_TO_ROTATION[exif_orientation] if [ 3, 6, 8 ].include?(exif_orientation)
    return nil unless exif_orientation.nil? || exif_orientation == 1

    response = post_image(tempfile)
    body = JSON.parse(response.body)

    if response.is_a?(Net::HTTPSuccess) && body["rotation"]
      body["rotation"].to_i
    else
      Rails.logger.warn(
        "Orientation detection failed for Photo ##{photo.id}: #{body}"
      )
      nil
    end
  end

  def attach_rotated_working_image(photo, tempfile, rotation)
    tempfile.rewind
    rotated_file = ImageProcessing::Vips.source(tempfile.path).rotate(rotation).call
    io = File.open(rotated_file.path)
    photo.working_image.attach(
      io: io,
      filename: photo.original_filename,
      content_type: photo.original.content_type
    )

    [ io, rotated_file ]
  end

  def exif_value(metadata, key)
    exif = metadata[:exif] || metadata["exif"] || {}
    exif[key] || exif[key.to_s]
  end

  def post_image(tempfile)
    uri = URI.join(ORIENTATION_SERVICE_URL, "/predict")

    boundary = SecureRandom.hex(16)
    body = build_multipart_body(tempfile, boundary)

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
    request.body = body

    Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 30) do |http|
      http.request(request)
    end
  end

  def build_multipart_body(tempfile, boundary)
    tempfile.rewind
    filename = File.basename(tempfile.path)
    file_content = tempfile.read

    body = +""
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: image/jpeg\r\n"
    body << "\r\n"
    body << file_content
    body << "\r\n"
    body << "--#{boundary}--\r\n"
    body
  end
end
