class Photo < ApplicationRecord
  include HasFuzzyDate

  belongs_to :family
  belongs_to :event, optional: true
  belongs_to :location, optional: true
  belongs_to :photographer, class_name: "Person", optional: true
  belongs_to :uploaded_by, class_name: "User", optional: true
  belongs_to :upload, optional: true, counter_cache: :photos_count

  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 200, 200 ]
    attachable.variant :medium, resize_to_limit: [ 800, 800 ]
    attachable.variant :large, resize_to_limit: [ 1600, 1600 ]
  end

  has_many :photo_sources, dependent: :destroy
  has_many :contributions, dependent: :destroy
  has_many :photo_people, dependent: :destroy
  has_many :photo_faces, dependent: :destroy
  has_many :people, through: :photo_people

  fuzzy_date_fields prefix: nil, fields: %i[date_type year month day season circa]

  validates :image, presence: true, on: :create

  before_save :extract_metadata, if: -> { image.attached? && image_changed? }
  after_commit :extract_dates_from_sources, on: :create, if: -> { image.attached? && taken_at.nil? }
  after_commit :enqueue_orientation_detection, on: :create, if: -> { image.attached? }

  scope :chronological, -> { order(year: :asc, month: :asc, day: :asc) }
  scope :reverse_chronological, -> { order(year: :desc, month: :desc, day: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  def date_text
    return date_display if date_display.present?
    fuzzy_date_text(year, month, day, season, circa)
  end

  def display_title
    title.presence || original_filename.presence || "Untitled Photo"
  end

  def orientation_corrected?
    orientation_correction.present? && orientation_correction != 0
  end

  def vips_rotation
    case orientation_correction
    when 90 then :d90
    when 180 then :d180
    when 270 then :d270
    else :d0
    end
  end

  VARIANT_OPTIONS = {
    thumb: { resize_to_fill: [ 200, 200 ] },
    medium: { resize_to_limit: [ 800, 800 ] },
    large: { resize_to_limit: [ 1600, 1600 ] }
  }.freeze

  def oriented_variant(name)
    options = VARIANT_OPTIONS.fetch(name)
    if orientation_corrected?
      image.variant(rotate: orientation_correction, **options)
    else
      image.variant(name)
    end
  end

  def import_detected_faces!
    return unless image.attached?

    detected_faces = extract_detected_faces(image.blob.metadata)
    return if detected_faces.empty?

    existing_signatures = photo_faces.map { |face| face_signature(face.attributes.symbolize_keys) }.to_set

    detected_faces.each do |raw_face|
      normalized = normalize_face_data(raw_face)
      next unless normalized

      signature = face_signature(normalized)
      next if existing_signatures.include?(signature)

      photo_faces.create!(normalized)
      existing_signatures.add(signature)
    end
  end

  private

  def image_changed?
    image.blob&.previously_new_record? || attachment_changes["image"].present?
  end

  def enqueue_orientation_detection
    OrientationDetectionJob.perform_later(id)
  end


  def extract_metadata
    return unless image.attached?
    blob = image.blob
    self.original_filename ||= blob.filename.to_s
    self.content_type = blob.content_type
    self.file_size = blob.byte_size

    if blob.content_type&.start_with?("image/") && blob.analyzed?
      self.width = blob.metadata[:width]
      self.height = blob.metadata[:height]
    end
  end

  def extract_dates_from_sources
    # Priority 1: EXIF DateTimeOriginal (most reliable)
    extract_exif_taken_at

    # Priority 2: Filename date patterns (fallback)
    extract_date_from_filename if taken_at.nil?
  end

  def extract_exif_taken_at
    image.blob.open do |tempfile|
      vips_image = Vips::Image.new_from_file(tempfile.path)
      raw = vips_image.get("exif-ifd2-DateTimeOriginal").to_s
      date_str = raw[/\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}/]
      if date_str.present?
        parsed = Time.strptime(date_str, "%Y:%m:%d %H:%M:%S") rescue nil
        update_column(:taken_at, parsed) if parsed
      end
    end
  rescue => e
    Rails.logger.warn("EXIF extraction failed for Photo ##{id}: #{e.message}")
  end

  def extract_date_from_filename
    return unless original_filename.present?

    result = Photo::DateExtractor.call(original_filename)
    return unless result

    updates = {}
    updates[:taken_at] = result.datetime || result.date if result.datetime || result.date

    # Also populate fuzzy date fields if not already set
    if year.nil? && result.year
      updates[:year] = result.year
      updates[:month] = result.month if result.month
      updates[:day] = result.day if result.day
      updates[:date_type] = result.day ? "exact" : (result.month ? "month" : "year")
    end

    update_columns(updates) if updates.any?
  rescue => e
    Rails.logger.warn("Filename date extraction failed for Photo ##{id}: #{e.message}")
  end

  def extract_detected_faces(metadata)
    return [] unless metadata.is_a?(Hash)

    candidates = [
      metadata["detected_faces"],
      metadata[:detected_faces],
      metadata["faces"],
      metadata[:faces],
      metadata.dig("custom", "detected_faces"),
      metadata.dig(:custom, :detected_faces),
      metadata.dig("face_detection", "faces"),
      metadata.dig(:face_detection, :faces),
      metadata.dig("analysis", "faces"),
      metadata.dig(:analysis, :faces),
      metadata.dig("rekognition", "face_details"),
      metadata.dig(:rekognition, :face_details)
    ]

    candidates.find { |item| item.is_a?(Array) } || []
  end

  def normalize_face_data(raw_face)
    face = raw_face.is_a?(Hash) ? raw_face.with_indifferent_access : nil
    return nil unless face

    box = face[:bounding_box].presence ||
      face[:boundingBox].presence ||
      face["BoundingBox"].presence ||
      face

    x = numeric_face_value(box, :x, :left)
    y = numeric_face_value(box, :y, :top)
    width_value = numeric_face_value(box, :width, :w)
    height_value = numeric_face_value(box, :height, :h)

    return nil if [ x, y, width_value, height_value ].any?(&:nil?)

    if uses_pixel_coordinates?(x, y, width_value, height_value)
      return nil if width.blank? || height.blank? || width.zero? || height.zero?

      x /= width.to_f
      y /= height.to_f
      width_value /= width.to_f
      height_value /= height.to_f
    end

    x = clamp_face_value(x)
    y = clamp_face_value(y)
    width_value = clamp_face_value(width_value)
    height_value = clamp_face_value(height_value)

    return nil if width_value <= 0 || height_value <= 0
    return nil if x + width_value > 1 || y + height_value > 1

    {
      x: x.round(6),
      y: y.round(6),
      width: width_value.round(6),
      height: height_value.round(6),
      confidence: numeric_face_value(face, :confidence)
    }
  end

  def numeric_face_value(hash, *keys)
    keys.each do |key|
      value = hash[key]
      value = hash[key.to_s] if value.blank?
      value = hash[key.to_s.camelize(:lower)] if value.blank?
      value = hash[key.to_s.camelize] if value.blank?
      value = hash[key.to_s.capitalize] if value.blank?
      return value.to_f if value.present?
    end

    nil
  end

  def uses_pixel_coordinates?(x, y, width_value, height_value)
    [ x, y, width_value, height_value ].any? { |value| value > 1 }
  end

  def clamp_face_value(value)
    [ [ value, 0.0 ].max, 1.0 ].min
  end

  def face_signature(face)
    [
      face[:x].to_f.round(4),
      face[:y].to_f.round(4),
      face[:width].to_f.round(4),
      face[:height].to_f.round(4)
    ]
  end
end
