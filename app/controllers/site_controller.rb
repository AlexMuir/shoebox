class SiteController < ApplicationController
  def index
    @recent_photos = current_family.photos.recent.limit(12)
    @recent_uploads = current_family.uploads.recent.limit(5)
    @people_count = current_family.people.count
    @photos_count = current_family.photos.count
    @events_count = current_family.events.count
  end
end
