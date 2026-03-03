# frozen_string_literal: true

namespace :photos do
  desc "Backfill metadata and working images for existing photos"
  task backfill: :environment do
    photos = Photo.where(image_metadata: {}).or(Photo.where(image_metadata: nil))
    total = photos.count
    puts "Backfilling #{total} photos..."
    photos.find_each.with_index do |photo, index|
      PhotoProcessingJob.perform_later(photo.id)
      puts "Enqueued #{index + 1}/#{total}" if (index + 1) % 10 == 0
    end
    puts "Done. #{total} jobs enqueued."
  end
end
