class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  helper_method :current_family

  private

  def current_family
    Current.family
  end
end
