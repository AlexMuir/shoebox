class ContributionsController < ApplicationController
  before_action :set_photo

  def create
    @contribution = @photo.contributions.build(contribution_params)
    @contribution.user = Current.user

    if @contribution.save
      redirect_to @photo, notice: "Contribution added."
    else
      redirect_to @photo, alert: "Could not save contribution."
    end
  end

  private

  def set_photo
    @photo = current_family.photos.find(params[:photo_id])
  end

  def contribution_params
    params.expect(contribution: [ :field_name, :value, :note ])
  end
end
