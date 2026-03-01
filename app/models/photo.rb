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
  has_many :people, through: :photo_people

  fuzzy_date_fields prefix: nil, fields: %i[date_type year month day season circa]

  validates :image, presence: true, on: :create

  before_save :extract_metadata, if: -> { image.attached? && image_changed? }
  after_commit :extract_dates_from_sources, on: :create, if: -> { image.attached? && taken_at.nil? }

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

  private

  def image_changed?
    image.blob&.previously_new_record? || attachment_changes["image"].present?
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
end
