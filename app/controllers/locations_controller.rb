class LocationsController < ApplicationController
  before_action :set_location, only: [ :show, :edit, :update, :destroy ]

  def index
    @locations = current_family.locations.manual_entry.alphabetical
  end

  def search
    query = params[:q].to_s
    if query.blank? || query.length < 2
      return render json: { local: [], google: [] }
    end

    local_results = current_family.locations
      .where("name ILIKE :q", q: "%#{query}%")
      .alphabetical
      .limit(5)
      .map { |loc| { id: loc.id, name: loc.name, parent_name: loc.parent&.name } }

    google_results = []
    if params[:session_token].present?
      google_results = GooglePlacesService.new.autocomplete(query, params[:session_token])
    end

    render json: { local: local_results, google: google_results }
  end

  def create_from_google
    place_details = GooglePlacesService.new.place_details(
      params[:place_id],
      params[:session_token]
    )

    if place_details.nil?
      return render json: { error: "Place not found" }, status: :unprocessable_entity
    end

    location = LocationHierarchyService.call(current_family, place_details)
    location.update!(manual: true)
    render json: { id: location.id, name: location.name }
  end

  def show
    @photos = Photo.where(location: @location.subtree).recent
    @events = @location.events.reverse_chronological
    @children = @location.children.alphabetical
  end

  def new
    @location = current_family.locations.build
    @location.parent_id = params[:parent_id] if params[:parent_id]
  end

  def create
    @location = current_family.locations.build(location_params)
    @location.manual = true
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
