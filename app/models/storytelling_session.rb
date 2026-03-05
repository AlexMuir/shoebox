# frozen_string_literal: true

class StorytellingSession < ApplicationRecord
  belongs_to :family
  belongs_to :location, optional: true
  belongs_to :created_by, class_name: "User"

  has_many :storytelling_session_people, dependent: :destroy
  has_many :storytellers, through: :storytelling_session_people, source: :person
  has_many :stories, dependent: :destroy

  scope :recent, -> { order(created_at: :desc) }
end
