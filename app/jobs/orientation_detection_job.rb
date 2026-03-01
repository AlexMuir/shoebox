class OrientationDetectionJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
           wait: :polynomially_longer, attempts: 5

  ORIENTATION_SERVICE_URL = ENV.fetch(
    "ORIENTATION_SERVICE_URL",
    "http://localhost:8150"
  )

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return unless photo.image.attached?

    rotation = detect_orientation(photo)
    photo.update_column(:orientation_correction, rotation) if rotation
  end

  private

  def detect_orientation(photo)
    photo.image.blob.open do |tempfile|
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
