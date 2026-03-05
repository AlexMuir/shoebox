# frozen_string_literal: true

class StoriesController < ApplicationController
  before_action :set_storytelling_session

  def create
    @photo = current_family.photos.find(params[:story][:photo_id])
    @story = @storytelling_session.stories.build(photo: @photo)

    if params[:story][:audio].present?
      @story.audio.attach(params[:story][:audio])
    end

    if @story.audio.attached? && @story.save
      render json: {
        id: @story.id,
        photo_id: @story.photo_id,
        audio_url: rails_blob_url(@story.audio)
      }, status: :created
    else
      render json: { errors: @story.errors.full_messages.presence || [ "Audio file is required" ] }, status: :unprocessable_entity
    end
  end

  private

  def set_storytelling_session
    @storytelling_session = current_family.storytelling_sessions.find(params[:storytelling_session_id])
  end
end
