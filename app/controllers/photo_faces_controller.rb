class PhotoFacesController < ApplicationController
  before_action :set_photo
  before_action :set_photo_face, only: [ :update, :destroy ]

  def create
    @photo_face = @photo.photo_faces.build(photo_face_params)
    @photo_face.tagged_by = Current.user if @photo_face.person_id.present?

    if @photo_face.save
      @photo_face.reload
      respond_to do |format|
        format.html { redirect_to @photo, notice: "Face added." }
        format.json { render json: photo_face_json(@photo_face), status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to @photo, alert: "Could not add face." }
        format.json { render json: { errors: @photo_face.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    attributes = photo_face_params
    attributes[:tagged_by] = Current.user if attributes[:person_id].present?

    if @photo_face.update(attributes)
      @photo_face.reload
      # Trigger date determination if person and age are both present
      if @photo_face.person_id.present? && @photo_face.estimated_age.present?
        Photo::DateDeterminationService.from_age_estimate(photo_face: @photo_face)
      end
      respond_to do |format|
        format.html { redirect_to @photo, notice: @photo_face.person_id.present? ? "Face tagged." : "Face untagged." }
        format.json { render json: photo_face_json(@photo_face), status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to @photo, alert: "Could not update face tag." }
        format.json { render json: { errors: @photo_face.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @photo_face.destroy
    respond_to do |format|
      format.html { redirect_to @photo, notice: "Face removed." }
      format.json { render json: { success: true } }
    end
  end

  private
  def photo_face_json(face)
    {
      id: face.id,
      x: face.x,
      y: face.y,
      width: face.width,
      height: face.height,
      estimated_age: face.estimated_age,
      person: face.person ? { id: face.person.id, name: face.person.full_name } : nil
    }
  end


  def set_photo
    @photo = current_family.photos.find(params[:photo_id])
  end

  def set_photo_face
    @photo_face = @photo.photo_faces.find(params[:id])
  end

  def photo_face_params
    params.expect(photo_face: [ :person_id, :x, :y, :width, :height, :confidence, :estimated_age ])
  end
end
