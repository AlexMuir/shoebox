
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

    respond_to do |format|
      format.html
      format.json { render json: photo_json }
    end
  end

  def new
    @photo = current_family.photos.build
  end

  def create
    @photo = current_family.photos.build(photo_params)
    @photo.uploaded_by = Current.user

    if @photo.save
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
      :title, :description, :image, :event_id, :location_id, :photographer_id,
      :date_type, :year, :month, :day, :season, :circa, :date_display
    ])
  end

  def photo_json
    ordered_ids = current_family.photos.recent.pluck(:id)
    current_index = ordered_ids.index(@photo.id)
    prev_id = current_index && current_index < ordered_ids.length - 1 ? ordered_ids[current_index + 1] : nil
    next_id = current_index && current_index > 0 ? ordered_ids[current_index - 1] : nil

    {
      id: @photo.id,
      title: @photo.display_title,
      description: @photo.description,
      image_url: @photo.image.attached? ? url_for(@photo.oriented_variant(:large)) : nil,
      width: @photo.width,
      height: @photo.height,
      date_text: @photo.date_text,
      location: @photo.location ? { id: @photo.location.id, name: @photo.location.name } : nil,
      event: @photo.event ? { id: @photo.event.id, title: @photo.event.title } : nil,
      photographer: @photo.photographer ? { id: @photo.photographer.id, name: @photo.photographer.full_name } : nil,
      faces: @photo_faces.map { |face|
        {
          id: face.id,
          x: face.x.to_f,
          y: face.y.to_f,
          width: face.width.to_f,
          height: face.height.to_f,
          person: face.person ? { id: face.person.id, name: face.person.full_name } : nil
        }
      },
      people: @photo.photo_people.includes(:person).map { |pp|
        { id: pp.person.id, name: pp.person.full_name }
      },
      contributions: @photo.contributions.includes(:user).map { |c|
        {
          id: c.id,
          field_name: c.field_name,
          value: c.value,
          note: c.note,
          user_email: c.user.email,
          created_at: c.created_at.to_date.iso8601
        }
      },
      prev_id: prev_id,
      next_id: next_id
    }
  end
end
