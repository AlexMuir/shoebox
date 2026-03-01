class LocationsController < ApplicationController
  before_action :set_location, only: [ :show, :edit, :update, :destroy ]

  def index
    @locations = current_family.locations.roots.alphabetical
  end

  def show
    @photos = @location.photos.recent
    @events = @location.events.reverse_chronological
    @children = @location.children.alphabetical
  end

  def new
    @location = current_family.locations.build
    @location.parent_id = params[:parent_id] if params[:parent_id]
  end

  def create
    @location = current_family.locations.build(location_params)

    if @location.save
      redirect_to @location, notice: "Location created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @location.update(location_params)
      redirect_to @location, notice: "Location updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @location.destroy
    redirect_to locations_path, notice: "Location deleted."
  end

  private

  def set_location
    @location = current_family.locations.find(params[:id])
  end

  def location_params
    params.expect(location: [
      :name, :address_line_1, :address_line_2, :city, :region, :postal_code,
      :country, :latitude, :longitude, :parent_id
    ])
  end
end
