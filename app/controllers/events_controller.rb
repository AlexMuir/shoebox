class EventsController < ApplicationController
  before_action :set_event, only: [ :show, :edit, :update, :destroy ]

  def index
    @events = current_family.events.reverse_chronological
  end

  def show
    @photos = @event.photos.recent
  end

  def new
    @event = current_family.events.build
  end

  def create
    @event = current_family.events.build(event_params)

    if @event.save
      redirect_to @event, notice: "Event created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to @event, notice: "Event updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: "Event deleted."
  end

  private

  def set_event
    @event = current_family.events.find(params[:id])
  end

  def event_params
    params.expect(event: [
      :title, :description, :location_id,
      :date_type, :year_from, :month_from, :day_from, :season_from, :circa_from,
      :year_to, :month_to, :day_to, :season_to, :circa_to, :date_display
    ])
  end
end
