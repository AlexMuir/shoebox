# frozen_string_literal: true

class PhotosController < ApplicationController
  before_action :set_photo, only: [ :show, :edit, :update, :destroy ]

  def index
    @photos = current_family.photos.recent
    @photos = @photos.where(event_id: params[:event_id]) if params[:event_id].present?
    @photos = @photos.where(year: params[:year]) if params[:year].present?
  end

  def show
    @photo.import_detected_faces!
    @photo_faces = @photo.photo_faces.includes(:person).ordered
  end

  def new
    @photo = current_family.photos.build
  end

  def create
    @photo = current_family.photos.build(photo_params)
    @photo.uploaded_by = Current.user

    if @photo.save
      PhotoProcessingJob.perform_later(@photo.id)
      redirect_to @photo, notice: "Photo uploaded successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @photo.update(photo_params)
      redirect_to @photo, notice: "Photo updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @photo.destroy
    redirect_to photos_path, notice: "Photo deleted."
  end

  private

  def set_photo
    @photo = current_family.photos.find(params[:id])
  end

  def photo_params
    params.expect(photo: [
      :title, :description, :original, :event_id, :location_id, :photographer_id,
      :date_type, :year, :month, :day, :season, :circa, :date_display
    ])
  end
end
