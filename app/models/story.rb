# frozen_string_literal: true

class Story < ApplicationRecord
  belongs_to :storytelling_session
  belongs_to :photo

  has_one_attached :audio

  validate :acceptable_audio_content_type

  scope :for_photo, ->(photo) { where(photo: photo) }

  private

  def acceptable_audio_content_type
    return unless audio.attached?

    acceptable_types = %w[audio/webm audio/mp4 audio/ogg audio/mpeg]
    unless acceptable_types.include?(audio.content_type)
      errors.add(:audio, "must be an audio file (WebM, MP4, OGG, or MPEG)")
    end
  end
end
