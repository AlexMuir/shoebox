# frozen_string_literal: true

class StorytellingSessionsController < ApplicationController
  before_action :set_storytelling_session, only: :show

  def new
    @storytelling_session = current_family.storytelling_sessions.build
    @people = current_family.people.order(:first_name, :last_name)
  end

  def create
    permitted = storytelling_session_params
    person_ids = permitted.delete(:person_ids)

    @storytelling_session = current_family.storytelling_sessions.build(permitted)
    @storytelling_session.created_by = Current.user

    if @storytelling_session.save
      @storytelling_session.storyteller_ids = person_ids.compact_blank if person_ids
      redirect_to @storytelling_session, notice: "Storytelling session created."
    else
      @people = current_family.people.order(:first_name, :last_name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  private

  def set_storytelling_session
    @storytelling_session = current_family.storytelling_sessions.find(params[:id])
  end

  def storytelling_session_params
    params.require(:storytelling_session).permit(:location_id, person_ids: [])
  end
end
