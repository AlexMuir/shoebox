class PhotoPeopleController < ApplicationController
  before_action :set_photo

  def create
    @photo_person = @photo.photo_people.build(
      person_id: params.dig(:photo_person, :person_id),
      tagged_by: Current.user
    )

    if @photo_person.save
      redirect_to @photo, notice: "Person tagged."
    else
      redirect_to @photo, alert: "Could not tag person."
    end
  end

  def destroy
    @photo_person = @photo.photo_people.find(params[:id])
    @photo_person.destroy
    redirect_to @photo, notice: "Person untagged."
  end

  private

  def set_photo
    @photo = current_family.photos.find(params[:photo_id])
  end
end
