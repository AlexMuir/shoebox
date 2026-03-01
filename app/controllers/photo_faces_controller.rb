class PhotoFacesController < ApplicationController
  before_action :set_photo
  before_action :set_photo_face, only: [ :update, :destroy ]

  def create
    @photo_face = @photo.photo_faces.build(photo_face_params)
    @photo_face.tagged_by = Current.user if @photo_face.person_id.present?

    if @photo_face.save
      redirect_to @photo, notice: "Face added."
    else
      redirect_to @photo, alert: "Could not add face."
    end
  end

  def update
    attributes = photo_face_params
    attributes[:tagged_by] = Current.user if attributes[:person_id].present?

    if @photo_face.update(attributes)
      redirect_to @photo, notice: @photo_face.person_id.present? ? "Face tagged." : "Face untagged."
    else
      redirect_to @photo, alert: "Could not update face tag."
    end
  end

  def destroy
    @photo_face.destroy
    redirect_to @photo, notice: "Face removed."
  end

  private

  def set_photo
    @photo = current_family.photos.find(params[:photo_id])
  end

  def set_photo_face
    @photo_face = @photo.photo_faces.find(params[:id])
  end

  def photo_face_params
    params.expect(photo_face: [ :person_id, :x, :y, :width, :height, :confidence ])
  end
end
