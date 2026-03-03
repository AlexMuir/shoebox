# Learnings

## [2026-03-03] Wave 1 Complete

### Worktree
- All work happens in `/home/pippin/projects/photos-photo-metadata` (branch: `photo-metadata`)
- Main repo at `/home/pippin/projects/photos` is READ ONLY

### mini_exiftool
- Gem installed, ExifTool CLI at `/usr/bin/exiftool` (version 12.76)
- Initializer at `config/initializers/mini_exiftool.rb` — sets `MiniExiftool.command = "exiftool"` and `MiniExiftool.opts = "-n"`
- Thread-safe: configured once at boot via initializer

### image_metadata column
- Already migrated: `image_metadata jsonb DEFAULT '{}'::jsonb` in `db/structure.sql`
- `Photo.new.image_metadata` returns `{}` (Hash)

### Fixture images
- Only ONE fixture image: `spec/fixtures/photos/orientation/1_-90deg.jpg` (has EXIF, rotated -90deg)
- For no-EXIF tests, generate a plain PNG in-spec using `MiniMagick` or `Vips` or just create a minimal PNG file

### Existing code patterns
- Service classes inherit from `ApplicationService` — see `app/services/google_places_service.rb`
- `Photo::DateExtractor` at `app/models/photo/date_extractor.rb` — call with `Photo::DateExtractor.call(filename)` returns a Result struct
- `extract_exif_taken_at` in Photo model uses libvips for DateTimeOriginal only — will be replaced
- `OrientationDetectionJob` calls external service at `ORIENTATION_SERVICE_URL` (default `http://localhost:8150`)

### Code style
- `# frozen_string_literal: true` at top of every Ruby file
- Double quotes for strings
- 2-space indent
- rubocop-rails-omakase style
- No semicolons in JS

### Active Storage
- Attachment rename: DB reference only — update `active_storage_attachments.name` column, no file moves
- Migration pattern: `ActiveStorage::Attachment.where(record_type: "Photo", name: "image").update_all(name: "original")`

## [2026-03-03] Task 3 - MetadataExtractor TDD
- Added `Photo::MetadataExtractor < ApplicationService` with `.call(file_path, original_filename)` API.
- Metadata shape includes `file`, `dimensions`, `exif`, `filename_date`, and `processing.extracted_at` (`Time.current`).
- `filename_date` delegates to `Photo::DateExtractor.call(original_filename)` and stores parsed boolean + structured parts.
- EXIF extraction now uses a constant tag map for key tags (`make`, `model`, `date_time_original`, exposure/focal/gps/orientation) plus all additional non-nil tags from `MiniExiftool#to_hash` after filtering non-EXIF file bookkeeping keys.
- No-EXIF behavior verified with generated minimal PNG bytes; service returns empty `exif` hash without raising.
- MiniExiftool failure path logs a warning and returns partial metadata (file info + filename date + processing timestamp).

## [2026-03-03] Task 4 - Dual Photo Attachments
- `Photo` now defines dual Active Storage attachments: `original` (source) and `working_image` (variant target).
- `display_image` returns `working_image` when attached, otherwise falls back to `original`.
- `oriented_variant` now always uses `display_image.variant(VARIANT_OPTIONS.fetch(name))`; rotation branching moved out of this method.
- Metadata/callback/faces paths were updated from `image` to `original` (`extract_metadata`, `extract_exif_taken_at`, `image_changed?`, and `import_detected_faces!`).
- Migration `RenameImageToOriginalOnPhotos` renames attachment references in `active_storage_attachments` (`image` <-> `original`) using reversible `up`/`down`.
- Factory/spec updates confirmed `photo.image` is gone, `photo.original` is the source attachment, and `photo.working_image` is available.

## Task 5: ExifDataComponent
- ViewComponent tests without Capybara can use `rendered_content` instead of `page` to check the output string.
- `ViewComponent::TestHelpers` needs to be included in the RSpec component tests if not globally configured.
- Tabler's collapse functionality works well with `data-bs-toggle="collapse"` and `data-bs-target="#id"`.

## [2026-03-03] Task 6 - PhotoProcessingJob TDD
- `PhotoProcessingJob` now centralizes metadata extraction and orientation handling from `photo.original`, replacing orientation-only behavior for this flow.
- EXIF orientation map used in job: `1 => 0`, `3 => 180`, `6 => 90`, `8 => 270`; when EXIF is `nil`/`1`, the job falls back to the orientation microservice (`post_image` + multipart helpers copied from OrientationDetectionJob pattern).
- Rotation path must keep a real IO open until `photo.save!`; closing the rotated file too early causes `IOError: closed stream` because Active Storage reads attachment IO during save.
- EXIF `date_time_original` parsing (`%Y:%m:%d %H:%M:%S`) is applied to `taken_at` and fuzzy date fields (`year`, `month`, `day`, `date_type = "exact"`) in the job.
- Spec coverage includes: metadata persistence, rotation attach behavior, non-rotation behavior, missing photo discard path, and no-original early return.
