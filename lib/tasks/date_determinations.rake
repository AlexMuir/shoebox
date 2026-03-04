# frozen_string_literal: true

namespace :date_determinations do
  desc "Backfill existing photos' EXIF data into DateDetermination records"
  task backfill: :environment do
    dry_run = ENV["DRY_RUN"].present?

    # Find photos with taken_at but no exif DateDetermination
    photos_with_taken_at = Photo.where.not(taken_at: nil)

    total = photos_with_taken_at.count
    puts "Backfilling #{total} photos with EXIF data..."
    puts "(DRY RUN - no changes will be made)" if dry_run

    photos_with_taken_at.find_each.with_index do |photo, index|
      # Skip if already has exif determination
      next if photo.date_determinations.exists?(source_type: "exif")

      unless dry_run
        Photo::DateDeterminationService.from_exif(photo, taken_at: photo.taken_at)
      end

      puts "Processed #{index + 1}/#{total}" if (index + 1) % 10 == 0
    end

    puts "Done. #{total} photos processed."
  end
end
