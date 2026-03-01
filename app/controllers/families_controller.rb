class FamiliesController < ApplicationController
  def switch
    family = Current.user.families.find(params[:id])
    session = start_new_session_for(Current.user, family: family)
    redirect_to root_path, notice: "Switched to #{family.name}."
  end
end
