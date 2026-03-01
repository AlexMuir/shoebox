class PhotoFace < ApplicationRecord
  belongs_to :photo
  belongs_to :person, optional: true
  belongs_to :tagged_by, class_name: "User", optional: true

  validates :x, :y, :width, :height, presence: true
  validates :x, :y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :width, :height, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validate :must_fit_within_photo

  scope :ordered, -> { order(:id) }

  def center_x
    x.to_f + (width.to_f / 2.0)
  end

  def center_y
    y.to_f + (height.to_f / 2.0)
  end

  def preview_zoom
    [ (1.0 / [ width.to_f, height.to_f ].max), 6.0 ].min.round(2)
  end

  private

  def must_fit_within_photo
    return if x.blank? || y.blank? || width.blank? || height.blank?

    if x.to_f + width.to_f > 1
      errors.add(:width, "extends outside image bounds")
    end

    if y.to_f + height.to_f > 1
      errors.add(:height, "extends outside image bounds")
    end
  end
end
