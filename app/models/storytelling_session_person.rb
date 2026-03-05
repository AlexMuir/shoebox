# frozen_string_literal: true

class StorytellingSessionPerson < ApplicationRecord
  belongs_to :storytelling_session
  belongs_to :person

  validates :person_id, uniqueness: { scope: :storytelling_session_id }
end
