# Photo Metadata & Dual-Image Storage

## TL;DR

> **Quick Summary**: Implement dual Active Storage attachments (pristine original + auto-rotated working copy), comprehensive EXIF/metadata extraction via mini_exiftool into a unified jsonb structure, and an ExifDataComponent for metadata display.
>
> **Deliverables**:
> - Original file preserved unchanged as `has_one_attached :original`
> - Auto-rotated working copy as `has_one_attached :working_image` (source for all variants)
> - `image_metadata` jsonb column with all EXIF, file info, and filename-parsed dates
> - `Photo::MetadataExtractor` service for comprehensive extraction
> - `PhotoProcessingJob` replacing `OrientationDetectionJob`
> - `ExifDataComponent` ViewComponent for debugging display
> - Backfill rake task for existing photos
>
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 4 waves + final verification
> **Critical Path**: Task 1 → Task 3 → Task 6 → Task 13 → Final

---

## Context

### Original Request
Store original uploaded photos unchanged. Create a "working" version with user adjustments (auto-rotate). All displayed images and variants derive from the working copy. Extract all EXIF data and metadata into a unified structure. ViewComponent for EXIF display.

### Interview Summary
**Key Discussions**:
- Metadata storage: jsonb column on photos (semi-structured, no joins)
- EXIF gem: mini_exiftool (wraps ExifTool CLI — most comprehensive, handles HEIC/RAW/all formats)
- Processing: async background job, consistent with existing patterns
- Orientation: EXIF tag first, existing microservice (localhost:8150) as fallback for scans without EXIF
- Adjustments: just auto-rotate for now, extensible later
- Tests: TDD (red-green-refactor)
- Attachment rename: DB reference only (update active_storage_attachments name column)

### Metis Review
**Identified Gaps** (addressed):
- Thread safety: mini_exiftool uses class variables — need initializer to set once at boot
- Blob mechanics: working copy must be a NEW blob (not shared), created by downloading original → processing → uploading
- Storage optimization: skip creating working_image when orientation is 0/normal — views fallback to original
- ExifTool must be added to Dockerfile for production
- Existing photos need backfilling via rake task
- Test fixtures at `spec/fixtures/photos/orientation/` contain real images with EXIF data

---

## Work Objectives

### Core Objective
Separate photo storage into pristine original + processed working copy, extract comprehensive metadata into a queryable structure, and provide a debugging display component.

### Concrete Deliverables
- `has_one_attached :original` — pristine uploaded file
- `has_one_attached :working_image` — auto-rotated copy with variants (:thumb, :medium, :large)
- `image_metadata` jsonb column on photos table
- `Photo::MetadataExtractor` service
- `PhotoProcessingJob` background job
- `ExifDataComponent` ViewComponent
- `lib/tasks/photos.rake` backfill task
- All views updated to use working_image with fallback

### Definition of Done
- [x] `bundle exec rspec` — all tests pass (0 failures)
- [x] `bin/rubocop` — no offenses
- [x] Uploading a photo stores original unchanged and creates rotated working copy
- [x] `photo.image_metadata` contains EXIF, file info, and filename date data
- [x] ExifDataComponent renders on photo show page
- [x] Existing photos can be backfilled via rake task

### Must Have
- Original file is NEVER modified after upload
- Working image only created when rotation is needed (storage optimization)
- All variants derive from working_image (or original if no rotation needed)
- Fallback display: show original while working_image is being processed
- Comprehensive EXIF extraction (not just DateTimeOriginal)
- Thread-safe mini_exiftool configuration via initializer

### Must NOT Have (Guardrails)
- NO user-facing adjustment controls (crop, brightness, contrast) — just auto-rotate
- NO GPS map display or geocoding from EXIF GPS data
- NO metadata editing UI
- NO cloud storage changes (keep local disk)
- NO new JavaScript — ExifDataComponent is server-rendered
- DO NOT modify the original blob after upload, ever
- DO NOT share blobs between original and working_image — always create new blob for working copy

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (RSpec, FactoryBot)
- **Automated tests**: TDD (red-green-refactor)
- **Framework**: RSpec
- **Each task**: Write failing test FIRST → implement → verify pass

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Services/Models**: Use Bash (Rails runner / RSpec) — run tests, verify output
- **Views/Components**: Use Playwright — navigate, verify rendering, screenshot
- **Jobs**: Use Bash (Rails runner) — enqueue, verify processing, check results

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — no breaking changes, 2 parallel):
├── Task 1: Add mini_exiftool gem + initializer + Dockerfile [quick]
└── Task 2: Migration for image_metadata jsonb column [quick]

Wave 2 (Core Services & Model — 3 parallel):
├── Task 3: Photo::MetadataExtractor service (TDD) [deep] — depends: 1
├── Task 4: Update Photo model: dual attachments + rename (TDD) [deep] — depends: 1, 2
└── Task 5: ExifDataComponent (TDD) [visual-engineering] — depends: 2

Wave 3 (Job & Controllers — 4 parallel):
├── Task 6: PhotoProcessingJob (TDD) [deep] — depends: 3, 4
├── Task 7: Update UploadsController (TDD) [quick] — depends: 4
├── Task 8: Update PhotosController (TDD) [quick] — depends: 4
└── Task 9: Update all views with fallback display [quick] — depends: 4

Wave 4 (Wiring & Polish — 4 parallel):
├── Task 10: Wire ExifDataComponent into photo show page [quick] — depends: 5, 9
├── Task 11: Deprecate OrientationDetectionJob [quick] — depends: 6
├── Task 12: Backfill existing photos rake task [quick] — depends: 6
└── Task 13: End-to-end integration test [deep] — depends: 6, 7, 8, 9, 10

Wave FINAL (After ALL — 4 parallel reviewers):
├── F1: Plan compliance audit (oracle)
├── F2: Code quality review (unspecified-high)
├── F3: Real manual QA (unspecified-high + playwright)
└── F4: Scope fidelity check (deep)

Critical Path: Task 1 → Task 3 → Task 6 → Task 13 → Final
Parallel Speedup: ~65% faster than sequential
Max Concurrent: 4 (Waves 3, 4)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 3, 4 | 1 |
| 2 | — | 4, 5 | 1 |
| 3 | 1 | 6 | 2 |
| 4 | 1, 2 | 6, 7, 8, 9 | 2 |
| 5 | 2 | 10 | 2 |
| 6 | 3, 4 | 11, 12, 13 | 3 |
| 7 | 4 | 13 | 3 |
| 8 | 4 | 13 | 3 |
| 9 | 4 | 10, 13 | 3 |
| 10 | 5, 9 | 13 | 4 |
| 11 | 6 | — | 4 |
| 12 | 6 | — | 4 |
| 13 | 6-10 | Final | 4 |

### Agent Dispatch Summary

- **Wave 1**: **2** — T1 → `quick`, T2 → `quick`
- **Wave 2**: **3** — T3 → `deep`, T4 → `deep`, T5 → `visual-engineering`
- **Wave 3**: **4** — T6 → `deep`, T7 → `quick`, T8 → `quick`, T9 → `quick`
- **Wave 4**: **4** — T10 → `quick`, T11 → `quick`, T12 → `quick`, T13 → `deep`
- **FINAL**: **4** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high` + `playwright`, F4 → `deep`

---

## TODOs

> Implementation + Test = ONE Task. Never separate.
> EVERY task MUST have: Recommended Agent Profile + Parallelization info + QA Scenarios.
> TDD: Write failing test FIRST → implement → verify pass.

- [x] 1. Add mini_exiftool gem + config initializer + Dockerfile

  **What to do**:
  - Add `gem "mini_exiftool"` to Gemfile after `gem "image_processing"`
  - Run `bundle install`
  - Create `config/initializers/mini_exiftool.rb`:
    ```ruby
    MiniExiftool.command = "exiftool"
    MiniExiftool.opts = "-n" # Use numerical values for orientation etc.
    ```
  - In `Dockerfile`, add `RUN apt-get update && apt-get install -y libimage-exiftool-perl` before the `COPY Gemfile` line
  - TDD: Write a test that `require "mini_exiftool"` succeeds and `MiniExiftool.command` is set

  **Must NOT do**:
  - Do NOT add any other gems
  - Do NOT modify any model or controller files

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Tasks 3, 4
  - **Blocked By**: None

  **References**:
  - `Gemfile:27` — `gem "image_processing"` line, add mini_exiftool nearby
  - `Dockerfile` — find the apt-get install line, add libimage-exiftool-perl
  - `config/initializers/` — directory for the new initializer

  **Acceptance Criteria**:
  - [x] `bundle exec ruby -e 'require "mini_exiftool"; puts MiniExiftool.command'` → prints `exiftool`
  - [x] `bin/rubocop config/initializers/mini_exiftool.rb` → no offenses
  - [x] `grep mini_exiftool Gemfile.lock` → gem is installed

  ```
  Scenario: mini_exiftool loads and is configured
    Tool: Bash
    Steps:
      1. Run `bundle exec ruby -e 'require "mini_exiftool"; puts MiniExiftool.command'`
      2. Assert output contains "exiftool"
    Expected Result: Command prints "exiftool", exit 0
    Evidence: .sisyphus/evidence/task-1-gem-configured.txt
  ```

  **Commit**: YES
  - Message: `chore(deps): add mini_exiftool gem with ExifTool config`
  - Files: `Gemfile`, `Gemfile.lock`, `config/initializers/mini_exiftool.rb`, `Dockerfile`

- [x] 2. Migration: add image_metadata jsonb column

  **What to do**:
  - Generate migration: `bin/rails generate migration AddImageMetadataToPhotos`
  - Edit migration:
    ```ruby
    def change
      add_column :photos, :image_metadata, :jsonb, default: {}
    end
    ```
  - Run `bin/rails db:migrate`
  - TDD: Write spec that verifies `Photo.new.image_metadata` returns `{}`

  **Must NOT do**:
  - Do NOT add any index on image_metadata yet (premature optimization)
  - Do NOT modify any model files

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None

  **References**:
  - `db/structure.sql` — existing photos table definition (line with `CREATE TABLE public.photos`)
  - `app/models/photo.rb` — model file (DO NOT MODIFY in this task)

  **Acceptance Criteria**:
  - [x] `bin/rails runner "puts Photo.column_names.include?('image_metadata')"` → true
  - [x] `bin/rails runner "puts Photo.new.image_metadata.class"` → Hash
  - [x] `db/structure.sql` contains `image_metadata jsonb DEFAULT '{}'::jsonb`

  ```
  Scenario: image_metadata column exists with correct default
    Tool: Bash
    Steps:
      1. Run `bin/rails runner "p = Photo.new; puts p.image_metadata.class; puts p.image_metadata == {}"`
      2. Assert output: "Hash" then "true"
    Expected Result: Column exists, defaults to empty hash
    Evidence: .sisyphus/evidence/task-2-column-exists.txt
  ```

  **Commit**: YES
  - Message: `feat(photos): add image_metadata jsonb column`
  - Files: `db/migrate/*_add_image_metadata_to_photos.rb`, `db/structure.sql`

- [x] 3. Photo::MetadataExtractor service (TDD)

  **What to do**:
  - RED: Write `spec/services/photo/metadata_extractor_spec.rb` first:
    - Test that given a file path to a JPEG with EXIF, it returns a hash with keys: `file`, `dimensions`, `exif`, `filename_date`, `processing`
    - Test that `exif` sub-hash contains camera make/model, date_time_original, exposure settings, GPS if present
    - Test that `filename_date` sub-hash contains parsed date from filename using existing `Photo::DateExtractor`
    - Test that a file with no EXIF returns empty `exif` hash but still populates `file` info
    - Use test fixtures from `spec/fixtures/photos/orientation/` — check which ones have EXIF data
  - GREEN: Create `app/services/photo/metadata_extractor.rb`:
    - Takes a file path and original_filename as arguments
    - Uses `MiniExiftool.new(file_path)` to extract all EXIF tags
    - Builds the unified metadata hash structure:
      ```ruby
      {
        file: { original_filename:, content_type:, file_size:, file_modified_at: },
        dimensions: { width:, height: },
        exif: { make:, model:, date_time_original:, exposure_time:, f_number:, iso:, focal_length:, gps_latitude:, gps_longitude:, orientation:, ...all other tags },
        filename_date: { parsed:, year:, month:, day:, hour:, minute:, second:, pattern: },
        processing: { extracted_at: }
      }
      ```
    - Uses `Photo::DateExtractor.call(original_filename)` for filename_date section
    - Gracefully handles missing EXIF (returns empty exif hash)
    - Gracefully handles MiniExiftool errors (logs warning, returns partial result)
  - REFACTOR: Extract EXIF tag mapping to a constant

  **Must NOT do**:
  - Do NOT modify Photo model
  - Do NOT modify any controller
  - Do NOT call this service from anywhere yet — Task 6 (PhotoProcessingJob) will wire it up

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5)
  - **Blocks**: Task 6
  - **Blocked By**: Task 1

  **References**:
  - `app/models/photo/date_extractor.rb` — Existing filename date parser. Call `Photo::DateExtractor.call(filename)` and map its Result struct into the `filename_date` section of the metadata hash
  - `app/models/photo.rb:103-114` — Existing `extract_metadata` method shows what file info is currently captured (original_filename, content_type, file_size, width, height). The new service should capture all of this and more
  - `app/models/photo.rb:124-136` — Existing `extract_exif_taken_at` method shows current EXIF extraction via libvips (only DateTimeOriginal). The new service replaces this with comprehensive extraction via mini_exiftool
  - `app/services/google_places_service.rb` — Reference for service class structure (inherits ApplicationService)
  - `spec/fixtures/photos/orientation/` — Test fixture images likely containing real EXIF data. Use `MiniExiftool.new(fixture_path)` in tests to verify extraction against known values
  - `config/initializers/mini_exiftool.rb` — Created by Task 1, ensures MiniExiftool.command is set

  **Acceptance Criteria**:
  - [x] `bundle exec rspec spec/services/photo/metadata_extractor_spec.rb` → PASS
  - [x] Service returns correct structure for JPEG with EXIF
  - [x] Service handles file with no EXIF gracefully (no errors, empty exif hash)
  - [x] `bin/rubocop app/services/photo/metadata_extractor.rb` → no offenses

  ```
  Scenario: Extract metadata from JPEG with EXIF
    Tool: Bash
    Steps:
      1. Run `bundle exec rspec spec/services/photo/metadata_extractor_spec.rb --format documentation`
      2. Assert all examples pass
      3. Run `bin/rails runner "result = Photo::MetadataExtractor.call('spec/fixtures/photos/orientation/landscape.jpg', 'IMG_20200615_143052.jpg'); puts result[:exif].keys.length"` (or whichever fixture exists)
      4. Assert exif keys count > 5
    Expected Result: Tests pass, service extracts multiple EXIF fields
    Evidence: .sisyphus/evidence/task-3-extractor-tests.txt

  Scenario: Handle file with no EXIF
    Tool: Bash
    Steps:
      1. Run `bin/rails runner "result = Photo::MetadataExtractor.call('spec/fixtures/photos/orientation/landscape.jpg', 'no_exif.png'); puts result[:file].present?"` (adapt fixture path as needed)
      2. Assert no error raised and file section is present
    Expected Result: Graceful handling, partial metadata returned
    Evidence: .sisyphus/evidence/task-3-no-exif.txt
  ```

  **Commit**: YES
  - Message: `feat(photos): add MetadataExtractor service with TDD`
  - Files: `app/services/photo/metadata_extractor.rb`, `spec/services/photo/metadata_extractor_spec.rb`

- [x] 4. Update Photo model: dual attachments + rename (TDD)

  **What to do**:
  - RED: Write/update `spec/models/photo_spec.rb`:
    - Test that `photo.original` is the attachment (not `photo.image`)
    - Test that `photo.working_image` attachment exists
    - Test `photo.display_image` returns working_image when attached, falls back to original
    - Test variant definitions exist on working_image (:thumb, :medium, :large)
    - Test `photo.image_metadata` is a hash (jsonb accessor)
  - GREEN — Migration:
    - Generate migration `RenameImageToOriginalOnPhotos`
    - In migration `up`: `ActiveStorage::Attachment.where(record_type: "Photo", name: "image").update_all(name: "original")`
    - In migration `down`: `ActiveStorage::Attachment.where(record_type: "Photo", name: "original").update_all(name: "image")`
    - Run `bin/rails db:migrate`
  - GREEN — Model changes to `app/models/photo.rb`:
    - Replace `has_one_attached :image do ... end` with:
      ```ruby
      has_one_attached :original
      has_one_attached :working_image do |attachable|
        attachable.variant :thumb, resize_to_fill: [200, 200]
        attachable.variant :medium, resize_to_limit: [800, 800]
        attachable.variant :large, resize_to_limit: [1600, 1600]
      end
      ```
    - Add `display_image` method:
      ```ruby
      def display_image
        working_image.attached? ? working_image : original
      end
      ```
    - Update `oriented_variant(name)` to use `display_image` instead of `image`:
      ```ruby
      def oriented_variant(name)
        display_image.variant(VARIANT_OPTIONS.fetch(name))
      end
      ```
      (No more rotation logic here — rotation is baked into working_image)
    - Update `image_changed?` private method: reference `original` instead of `image`
    - Update `extract_metadata` callback: reference `original` instead of `image`
    - Update `extract_exif_taken_at`: reference `original` instead of `image`
    - Update `import_detected_faces!`: reference `original` instead of `image`
    - Update `validates :image` → `validates :original`
    - Update `before_save` and `after_commit` callbacks: reference `original`
    - Remove `VARIANT_OPTIONS` constant and `oriented_variant` complexity — simplify to use `display_image.variant(name)`
  - REFACTOR: Clean up any dead code

  **Must NOT do**:
  - Do NOT modify controllers or views (those are Tasks 7-9)
  - Do NOT create the PhotoProcessingJob (that's Task 6)
  - Do NOT delete OrientationDetectionJob (that's Task 11)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 5)
  - **Blocks**: Tasks 6, 7, 8, 9
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `app/models/photo.rb` — ENTIRE FILE. This is the primary file being modified. Read it completely before making changes. Key sections:
    - Lines 11-15: Current `has_one_attached :image` with variant definitions
    - Lines 25-29: Callbacks referencing `image.attached?` and `image_changed?`
    - Lines 44-70: `orientation_corrected?`, `vips_rotation`, `VARIANT_OPTIONS`, `oriented_variant` — all need updating or simplification
    - Lines 72-90: `import_detected_faces!` references `image.blob.metadata`
    - Lines 94-96: `image_changed?` private method
    - Lines 103-114: `extract_metadata` references `image.attached?`, `image.blob`
    - Lines 124-136: `extract_exif_taken_at` references `image.blob.open`
  - `spec/models/photo_spec.rb` — May not exist yet. If it does, read and extend. If not, create following the pattern in `spec/requests/locations_spec.rb` for auth setup
  - `spec/factories.rb` — Location of photo factory: `factory :photo do; family; ...; end`. Check if it attaches an image fixture
  - `db/structure.sql` — Will be updated by migration

  **Acceptance Criteria**:
  - [x] `bundle exec rspec spec/models/photo_spec.rb` → PASS
  - [x] `bin/rails runner "puts Photo.new.respond_to?(:original)"` → true
  - [x] `bin/rails runner "puts Photo.new.respond_to?(:working_image)"` → true
  - [x] `bin/rails runner "puts Photo.new.respond_to?(:image)"` → false (removed)
  - [x] `bin/rubocop app/models/photo.rb` → no offenses
  - [x] Existing photo records' attachments still accessible via `photo.original`

  ```
  Scenario: Attachment renamed successfully
    Tool: Bash
    Steps:
      1. Run `bin/rails runner "photo = Photo.joins(:original_attachment).first; puts photo.original.attached?"` (if photos exist in dev DB)
      2. Assert output: true
      3. Run `bin/rails runner "puts Photo.new.respond_to?(:image)"` 
      4. Assert output: false
    Expected Result: Old attachment accessible via new name, old accessor gone
    Evidence: .sisyphus/evidence/task-4-attachment-renamed.txt

  Scenario: display_image fallback works
    Tool: Bash
    Steps:
      1. Run `bin/rails runner "photo = Photo.first; puts photo.display_image == photo.original"` (no working_image yet)
      2. Assert output: true
    Expected Result: Falls back to original when no working_image
    Evidence: .sisyphus/evidence/task-4-display-fallback.txt
  ```

  **Commit**: YES
  - Message: `feat(photos): dual attachments original + working_image`
  - Files: `app/models/photo.rb`, `db/migrate/*_rename_image_to_original_on_photos.rb`, `db/structure.sql`, `spec/models/photo_spec.rb`

- [x] 5. ExifDataComponent ViewComponent (TDD)

  **What to do**:
  - RED: Write `spec/components/exif_data_component_spec.rb`:
    - Test that component renders a table with EXIF sections when metadata is present
    - Test that component renders "No metadata available" when image_metadata is empty/nil
    - Test that sections are grouped: File Info, Camera, Exposure, GPS, Dates
    - Test that sensitive/internal keys are excluded from display
  - GREEN: Create `app/components/exif_data_component.rb` and `app/components/exif_data_component.html.erb`:
    - `initialize(photo:)` — takes a Photo record
    - Reads `photo.image_metadata` and groups into sections
    - Section grouping:
      - **File Info**: original_filename, content_type, file_size (formatted), dimensions
      - **Camera**: make, model, software
      - **Exposure**: exposure_time, f_number, iso, focal_length, flash
      - **GPS**: latitude, longitude (if present)
      - **Dates**: date_time_original, file_modified_at, filename parsed date, taken_at
    - Renders as a Tabler-styled card with collapsible sections
    - Handles missing/empty metadata gracefully
  - Create `app/components/` directory if it doesn't exist
  - REFACTOR: Extract section definitions to a constant

  **Must NOT do**:
  - Do NOT wire this into any view yet (Task 10 does that)
  - Do NOT add JavaScript interactivity
  - Do NOT display raw unsanitized metadata values

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4)
  - **Blocks**: Task 10
  - **Blocked By**: Task 2

  **References**:
  - `app/views/photos/show.html.erb` — The page where this component will eventually be rendered (Task 10). Read it to understand the Tabler card/layout pattern used
  - `app/views/locations/show.html.erb` — Another show page with Tabler card layout pattern for reference
  - `Gemfile:33` — `gem "view_component"` is already present
  - `app/components/` — Directory does NOT exist yet. Create it.
  - ViewComponent docs: `render ExifDataComponent.new(photo: @photo)` is the invocation pattern

  **Acceptance Criteria**:
  - [x] `bundle exec rspec spec/components/exif_data_component_spec.rb` → PASS
  - [x] Component renders metadata table when data present
  - [x] Component renders fallback when no metadata
  - [x] `bin/rubocop app/components/` → no offenses

  ```
  Scenario: Component renders with metadata
    Tool: Bash
    Steps:
      1. Run `bundle exec rspec spec/components/exif_data_component_spec.rb --format documentation`
      2. Assert all examples pass
    Expected Result: All component specs pass
    Evidence: .sisyphus/evidence/task-5-component-tests.txt
  ```

  **Commit**: YES
  - Message: `feat(components): add ExifDataComponent for metadata display`
  - Files: `app/components/exif_data_component.rb`, `app/components/exif_data_component.html.erb`, `spec/components/exif_data_component_spec.rb`

- [x] 6. PhotoProcessingJob (TDD)

  **What to do**:
  - RED: Write `spec/jobs/photo_processing_job_spec.rb`:
    - Test that job extracts metadata and stores in `image_metadata` column
    - Test that job creates working_image when orientation correction is needed
    - Test that job does NOT create working_image when orientation is 0/normal (storage optimization)
    - Test that job populates taken_at and fuzzy date fields from EXIF
    - Test that job handles missing photos (ActiveRecord::RecordNotFound discarded)
    - Test orientation detection: EXIF orientation tag tried first, microservice fallback
  - GREEN: Create `app/jobs/photo_processing_job.rb`:
    - `queue_as :default`
    - `discard_on ActiveRecord::RecordNotFound`
    - `retry_on` network errors (same pattern as OrientationDetectionJob)
    - `perform(photo_id)` flow:
      1. Find photo, verify original is attached
      2. Download original to tempfile via `photo.original.blob.open`
      3. Call `Photo::MetadataExtractor.call(tempfile.path, photo.original_filename)` → store result in `photo.image_metadata`
      4. Extract dates from metadata: EXIF DateTimeOriginal → taken_at + fuzzy date fields
      5. Determine orientation: check `metadata[:exif][:orientation]` EXIF tag first. If not present or 1 (normal), try the existing microservice as fallback
      6. If rotation needed: use `ImageProcessing::Vips.source(tempfile).rotate(degrees).call` to create rotated file, then `photo.working_image.attach(io: rotated_file, filename: photo.original_filename, content_type: photo.original.content_type)`
      7. If NO rotation needed: do NOT create working_image. The `display_image` method falls back to original.
      8. Save photo
  - REFACTOR: Extract orientation detection to private method

  **Must NOT do**:
  - Do NOT modify Photo model (already updated in Task 4)
  - Do NOT delete OrientationDetectionJob yet (Task 11)
  - Do NOT share blobs between original and working_image — always create a new blob

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7, 8, 9)
  - **Blocks**: Tasks 11, 12, 13
  - **Blocked By**: Tasks 3, 4

  **References**:
  - `app/jobs/orientation_detection_job.rb` — FULL FILE. This is the existing job being replaced. Copy the retry_on pattern, microservice URL config, `post_image` and `build_multipart_body` methods for fallback orientation detection. The new job wraps this logic as a fallback
  - `app/services/photo/metadata_extractor.rb` — Created by Task 3. Call `Photo::MetadataExtractor.call(tempfile_path, original_filename)` to get the metadata hash
  - `app/models/photo.rb` — Updated by Task 4. Use `photo.original.blob.open`, `photo.working_image.attach(...)`, `photo.image_metadata =`
  - `app/models/photo.rb:124-136` — Existing `extract_exif_taken_at` logic for date extraction from EXIF. Replicate this logic but using the metadata hash instead of direct libvips calls
  - EXIF orientation values: 1=normal, 3=180°, 6=90°CW, 8=90°CCW. Map to rotation degrees for ImageProcessing::Vips

  **Acceptance Criteria**:
  - [x] `bundle exec rspec spec/jobs/photo_processing_job_spec.rb` → PASS
  - [x] Job extracts and stores metadata in image_metadata
  - [x] Job creates working_image only when rotation needed
  - [x] Job skips working_image when no rotation needed
  - [x] `bin/rubocop app/jobs/photo_processing_job.rb` → no offenses

  ```
  Scenario: Job processes photo with EXIF orientation
    Tool: Bash
    Steps:
      1. Run `bundle exec rspec spec/jobs/photo_processing_job_spec.rb --format documentation`
      2. Assert all examples pass
    Expected Result: All job specs pass including orientation handling
    Evidence: .sisyphus/evidence/task-6-job-tests.txt

  Scenario: Job skips working_image for normal orientation
    Tool: Bash
    Steps:
      1. Run relevant spec example for no-rotation case
      2. Assert working_image is NOT attached after job completes
    Expected Result: Storage optimization verified
    Evidence: .sisyphus/evidence/task-6-skip-working.txt
  ```

  **Commit**: YES
  - Message: `feat(jobs): add PhotoProcessingJob replacing orientation detection`
  - Files: `app/jobs/photo_processing_job.rb`, `spec/jobs/photo_processing_job_spec.rb`

- [x] 7. Update UploadsController (TDD)

  **What to do**:
  - RED: Update `spec/requests/uploads_spec.rb` (or create if not exists):
    - Test that uploading files attaches to `photo.original` (not `photo.image`)
    - Test that `PhotoProcessingJob` is enqueued after upload
  - GREEN: Update `app/controllers/uploads_controller.rb`:
    - Line 72: Change `photo.image.attach(file)` → `photo.original.attach(file)`
    - After `photo.save`, enqueue: `PhotoProcessingJob.perform_later(photo.id)` (replacing the model callback)
  - Remove or update the `enqueue_orientation_detection` callback call if it's still triggered from the model

  **Must NOT do**:
  - Do NOT modify the upload form/views
  - Do NOT change strong params
  - Do NOT modify Photo model (already done in Task 4)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 6, 8, 9)
  - **Blocks**: Task 13
  - **Blocked By**: Task 4

  **References**:
  - `app/controllers/uploads_controller.rb` — FULL FILE. Key line 72: `photo.image.attach(file)` → `photo.original.attach(file)`. Also line 74: `photo.save` should be followed by `PhotoProcessingJob.perform_later(photo.id)` inside the save success block
  - `spec/requests/locations_search_spec.rb` — Pattern for request specs with auth setup
  - `app/models/photo.rb:29` — The `enqueue_orientation_detection` callback may need to be removed from the model since the controller now explicitly enqueues PhotoProcessingJob. Coordinate with Task 4's changes

  **Acceptance Criteria**:
  - [x] `bundle exec rspec spec/requests/uploads_spec.rb` → PASS (if spec exists)
  - [x] Upload attaches to `original` not `image`
  - [x] `bin/rubocop app/controllers/uploads_controller.rb` → no offenses

  ```
  Scenario: Upload attaches to original
    Tool: Bash
    Steps:
      1. Run `bundle exec rspec spec/requests/uploads_spec.rb --format documentation` (or relevant spec)
      2. Assert examples pass
    Expected Result: Controller correctly uses original attachment
    Evidence: .sisyphus/evidence/task-7-uploads-controller.txt
  ```

  **Commit**: YES (group with Tasks 8, 9)
  - Message: `refactor(controllers+views): use dual attachment pattern`
  - Files: `app/controllers/uploads_controller.rb`, `spec/requests/uploads_spec.rb`

- [x] 8. Update PhotosController (TDD)

  **What to do**:
  - RED: Update/create photo controller specs:
    - Test that creating a photo via the form still works with the new attachment name
    - Test that `PhotoProcessingJob` is enqueued after create
  - GREEN: Update `app/controllers/photos_controller.rb`:
    - In `photo_params`: change `:image` → `:original`
    - After successful create, enqueue `PhotoProcessingJob.perform_later(@photo.id)`

  **Must NOT do**:
  - Do NOT modify views (Task 9)
  - Do NOT modify Photo model

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 6, 7, 9)
  - **Blocks**: Task 13
  - **Blocked By**: Task 4

  **References**:
  - `app/controllers/photos_controller.rb` — FULL FILE. Key change: line 54 `photo_params` method, change `:image` → `:original`. Also line 23: after `@photo.save`, add `PhotoProcessingJob.perform_later(@photo.id)` in success block
  - `app/views/photos/_form.html.erb` — READ ONLY. Check if form uses `f.input :image` — if so, this needs to change to `:original` too. But that's a view change so note for Task 9

  **Acceptance Criteria**:
  - [x] `bundle exec rspec` passes for photo controller specs
  - [x] `bin/rubocop app/controllers/photos_controller.rb` → no offenses

  ```
  Scenario: Photo create uses original attachment
    Tool: Bash
    Steps:
      1. Run relevant photo controller specs
      2. Assert pass
    Expected Result: Controller correctly uses original attachment name
    Evidence: .sisyphus/evidence/task-8-photos-controller.txt
  ```

  **Commit**: YES (group with Tasks 7, 9)
  - Files: `app/controllers/photos_controller.rb`

- [x] 9. Update all views with fallback display

  **What to do**:
  - Update ALL view files that reference `photo.image.variant(...)` or `photo.oriented_variant(...)`:
    - `app/views/photos/index.html.erb:20` — `photo.image.variant(:thumb)` → `photo.display_image.variant(:thumb)`
    - `app/views/photos/show.html.erb:20` — `@photo.oriented_variant(:large)` → `@photo.display_image.variant(:large)`
    - `app/views/photos/show.html.erb:79` — `@photo.image.variant(:large)` → `@photo.display_image.variant(:large)`
    - `app/views/site/index.html.erb:59` — `photo.image.variant(:thumb)` → `photo.display_image.variant(:thumb)`
    - `app/views/uploads/show.html.erb:53` — `photo.image.variant(:thumb)` → `photo.display_image.variant(:thumb)`
    - `app/views/events/show.html.erb:46` — `photo.image.variant(:thumb)` → `photo.display_image.variant(:thumb)`
    - `app/views/locations/show.html.erb:73` — `photo.image.variant(:thumb)` → `photo.display_image.variant(:thumb)`
    - `app/views/people/show.html.erb:54` — `photo.image.variant(:thumb)` → `photo.display_image.variant(:thumb)`
  - Update `app/views/photos/_form.html.erb` if it references `:image` file field → `:original`
  - Update `app/views/uploads/new.html.erb` if it references `:image` → check and update
  - Grep for ANY remaining reference to `photo.image` or `.image.variant` and fix

  **Must NOT do**:
  - Do NOT add ExifDataComponent rendering (Task 10)
  - Do NOT modify controller logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 6, 7, 8)
  - **Blocks**: Tasks 10, 13
  - **Blocked By**: Task 4

  **References**:
  - `app/views/photos/index.html.erb:20` — `photo.image.variant(:thumb)`
  - `app/views/photos/show.html.erb:20` — `@photo.oriented_variant(:large)`
  - `app/views/photos/show.html.erb:79` — `@photo.image.variant(:large)` (face preview)
  - `app/views/site/index.html.erb:59` — `photo.image.variant(:thumb)`
  - `app/views/uploads/show.html.erb:53` — `photo.image.variant(:thumb)`
  - `app/views/events/show.html.erb:46` — `photo.image.variant(:thumb)`
  - `app/views/locations/show.html.erb:73` — `photo.image.variant(:thumb)`
  - `app/views/people/show.html.erb:54` — `photo.image.variant(:thumb)`
  - `app/views/photos/_form.html.erb` — Check for `:image` file input field
  - `app/views/uploads/new.html.erb` — Check for file upload field referencing image

  **Acceptance Criteria**:
  - [x] `grep -rn 'photo.image\|.image.variant\|oriented_variant' app/views/` → NO results (all references updated)
  - [x] `grep -rn 'display_image.variant' app/views/` → matches in all 7+ view files
  - [x] `bin/rubocop` → no offenses on changed views

  ```
  Scenario: No remaining references to photo.image in views
    Tool: Bash
    Steps:
      1. Run `grep -rn 'photo\.image\|@photo\.image\|\.image\.variant\|oriented_variant' app/views/`
      2. Assert: empty output (no matches)
      3. Run `grep -rn 'display_image' app/views/`
      4. Assert: 7+ matches across view files
    Expected Result: All views updated to display_image pattern
    Evidence: .sisyphus/evidence/task-9-views-updated.txt
  ```

  **Commit**: YES (group with Tasks 7, 8)
  - Files: all view files listed above

- [x] 10. Wire ExifDataComponent into photo show page

  **What to do**:
  - Add `<%= render ExifDataComponent.new(photo: @photo) %>` to `app/views/photos/show.html.erb`
  - Place it below the main photo display, in a new card section
  - Only render when `@photo.image_metadata.present?`
  - Wrap in a collapsible section (Tabler accordion or card collapse) so it doesn't dominate the page

  **Must NOT do**:
  - Do NOT modify the component itself (Task 5)
  - Do NOT add JavaScript for collapse (use Tabler's built-in collapse)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 11, 12, 13)
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 5, 9

  **References**:
  - `app/views/photos/show.html.erb` — The target view file. Add component rendering after the existing photo display section
  - `app/components/exif_data_component.rb` — Created by Task 5. Render with `ExifDataComponent.new(photo: @photo)`
  - Tabler collapse: `<div class="card"><div class="card-header" data-bs-toggle="collapse" data-bs-target="#exif-data">` pattern

  **Acceptance Criteria**:
  - [x] Photo show page renders without error
  - [x] ExifDataComponent visible when metadata present
  - [x] Component not rendered when metadata is empty

  ```
  Scenario: ExifDataComponent renders on photo show page
    Tool: Bash
    Steps:
      1. Run `bin/rails runner "photo = Photo.first; photo.update(image_metadata: {file: {original_filename: 'test.jpg'}})"`
      2. Run `curl -s http://localhost:3000/photos/#{photo_id} | grep -c 'exif\|metadata'`
      3. Assert: count > 0
    Expected Result: Component renders on the page
    Evidence: .sisyphus/evidence/task-10-component-wired.txt
  ```

  **Commit**: YES
  - Message: `feat(photos): wire ExifDataComponent into show page`
  - Files: `app/views/photos/show.html.erb`

- [x] 11. Deprecate OrientationDetectionJob

  **What to do**:
  - Update `app/jobs/orientation_detection_job.rb`:
    - Add a deprecation warning at the top of `perform`:
      ```ruby
      Rails.logger.warn("DEPRECATED: OrientationDetectionJob is replaced by PhotoProcessingJob")
      ```
    - Keep the job functional for now (in case queued jobs are still pending)
  - Remove the `enqueue_orientation_detection` callback from `app/models/photo.rb` (if not already removed in Task 4)
  - Remove the `orientation_corrected?` and `vips_rotation` methods from Photo model if no longer used

  **Must NOT do**:
  - Do NOT delete the job file entirely (queued jobs may still reference it)
  - Do NOT modify PhotoProcessingJob

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 10, 12, 13)
  - **Blocks**: None
  - **Blocked By**: Task 6

  **References**:
  - `app/jobs/orientation_detection_job.rb` — FULL FILE. Add deprecation warning to `perform` method
  - `app/models/photo.rb:29` — `after_commit :enqueue_orientation_detection` callback — remove if still present
  - `app/models/photo.rb:44-55` — `orientation_corrected?` and `vips_rotation` methods — check if still referenced anywhere before removing

  **Acceptance Criteria**:
  - [x] `grep -rn 'enqueue_orientation_detection' app/models/` → no results
  - [x] `grep -rn 'OrientationDetectionJob' app/models/` → no results
  - [x] `bin/rubocop app/jobs/orientation_detection_job.rb` → no offenses
  - [x] `bundle exec rspec` → no failures

  ```
  Scenario: Old job no longer triggered from model
    Tool: Bash
    Steps:
      1. Run `grep -rn 'OrientationDetectionJob\|enqueue_orientation_detection' app/models/`
      2. Assert: empty output
    Expected Result: Model no longer references old job
    Evidence: .sisyphus/evidence/task-11-deprecated.txt
  ```

  **Commit**: YES
  - Message: `chore(jobs): deprecate OrientationDetectionJob`
  - Files: `app/jobs/orientation_detection_job.rb`, `app/models/photo.rb` (if callback still present)

- [x] 12. Backfill existing photos rake task

  **What to do**:
  - Create `lib/tasks/photos.rake`:
    ```ruby
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
    ```
  - TDD: Write `spec/tasks/photos_rake_spec.rb` testing the task enqueues jobs

  **Must NOT do**:
  - Do NOT process photos synchronously (use background jobs)
  - Do NOT modify any model or service

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 10, 11, 13)
  - **Blocks**: None
  - **Blocked By**: Task 6

  **References**:
  - `app/jobs/photo_processing_job.rb` — Created by Task 6. The rake task enqueues this job for each photo
  - `lib/tasks/` — Standard Rails location for rake tasks

  **Acceptance Criteria**:
  - [x] `bin/rails -T photos` → shows `photos:backfill`
  - [x] `bin/rubocop lib/tasks/photos.rake` → no offenses

  ```
  Scenario: Rake task enqueues jobs
    Tool: Bash
    Steps:
      1. Run `bin/rails -T photos`
      2. Assert output includes "photos:backfill"
    Expected Result: Task is registered and listed
    Evidence: .sisyphus/evidence/task-12-rake-task.txt
  ```

  **Commit**: YES
  - Message: `feat(tasks): add photo backfill rake task`
  - Files: `lib/tasks/photos.rake`, `spec/tasks/photos_rake_spec.rb`

- [x] 13. End-to-end integration test

  **What to do**:
  - Create `spec/integration/photo_processing_spec.rb`:
    - Test the full flow: upload photo → original attached → PhotoProcessingJob runs → metadata extracted → working_image created (if rotation needed) → display_image returns correct attachment → variants work
    - Test with a real image fixture from `spec/fixtures/photos/orientation/`
    - Use `perform_enqueued_jobs` to run the job inline
    - Verify:
      - `photo.original.attached?` is true
      - `photo.image_metadata` is populated with EXIF data
      - `photo.image_metadata["file"]["original_filename"]` matches
      - `photo.image_metadata["exif"]` has camera/date keys
      - `photo.display_image` returns the correct attachment
      - `photo.display_image.variant(:thumb)` doesn't raise
    - Test edge case: photo with no EXIF (e.g., a plain PNG)
    - Test edge case: photo that doesn't need rotation

  **Must NOT do**:
  - Do NOT modify any implementation files
  - Do NOT skip any verification step

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on all prior tasks)
  - **Parallel Group**: Wave 4 (can run alongside 10, 11, 12 but needs their code)
  - **Blocks**: Final Verification Wave
  - **Blocked By**: Tasks 6, 7, 8, 9, 10

  **References**:
  - `spec/fixtures/photos/orientation/` — Test fixture images with real EXIF data
  - `spec/requests/locations_search_spec.rb` — Auth setup pattern for request specs
  - `spec/factories.rb` — Photo factory definition
  - `app/jobs/photo_processing_job.rb` — The job to test end-to-end
  - `app/services/photo/metadata_extractor.rb` — The service called by the job
  - `app/models/photo.rb` — The updated model with dual attachments

  **Acceptance Criteria**:
  - [x] `bundle exec rspec spec/integration/photo_processing_spec.rb` → PASS
  - [x] Full upload → process → display flow verified
  - [x] Edge cases covered (no EXIF, no rotation needed)

  ```
  Scenario: Full photo processing pipeline
    Tool: Bash
    Steps:
      1. Run `bundle exec rspec spec/integration/photo_processing_spec.rb --format documentation`
      2. Assert all examples pass
    Expected Result: Complete pipeline verified end-to-end
    Evidence: .sisyphus/evidence/task-13-integration.txt
  ```

  **Commit**: YES
  - Message: `test(photos): end-to-end integration spec for processing pipeline`
  - Files: `spec/integration/photo_processing_spec.rb`

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [x] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run Rails runner, check DB). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high`
  Run `bin/rubocop` + `bundle exec rspec`. Review all changed files for: empty rescues, `binding.pry`, `console.log`, commented-out code, unused methods. Check AI slop: excessive comments, over-abstraction, generic names. Verify thread safety of mini_exiftool usage.
  Output: `Rubocop [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [x] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill)
  Start dev server. Upload a photo via the upload form. Verify: original stored unchanged, working_image created with rotation, all variant sizes render correctly, ExifDataComponent displays on show page, metadata populated in DB. Test edge cases: photo with no EXIF, PNG file, already-correct orientation.
  Output: `Scenarios [N/N pass] | Edge Cases [N tested] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Task 1**: `chore(deps): add mini_exiftool gem with ExifTool config` — Gemfile, Gemfile.lock, config/initializers/mini_exiftool.rb, Dockerfile
- **Task 2**: `feat(photos): add image_metadata jsonb column` — migration, db/structure.sql
- **Task 3**: `feat(photos): add MetadataExtractor service with TDD` — app/services/photo/metadata_extractor.rb, spec/
- **Task 4**: `feat(photos): dual attachments original + working_image` — app/models/photo.rb, migration, spec/
- **Task 5**: `feat(components): add ExifDataComponent` — app/components/, spec/
- **Task 6**: `feat(jobs): add PhotoProcessingJob replacing orientation detection` — app/jobs/, spec/
- **Tasks 7-9**: `refactor(controllers+views): use dual attachment pattern` — controllers, views
- **Task 10**: `feat(photos): wire ExifDataComponent into show page` — view
- **Task 11**: `chore(jobs): deprecate OrientationDetectionJob` — app/jobs/
- **Task 12**: `feat(tasks): add photo backfill rake task` — lib/tasks/
- **Task 13**: `test(photos): end-to-end integration spec` — spec/

---

## Success Criteria

### Verification Commands
```bash
bundle exec rspec                    # Expected: 0 failures
bin/rubocop                          # Expected: 0 offenses
bin/rails runner "Photo.first.image_metadata"  # Expected: populated hash
bin/rails runner "Photo.first.original.attached?"  # Expected: true
bin/rails runner "Photo.first.working_image.attached?"  # Expected: true (if rotated)
```

### Final Checklist
- [x] All "Must Have" present
- [x] All "Must NOT Have" absent
- [x] All tests pass
- [x] Original files never modified
- [x] Working images correctly rotated
- [x] All views display photos correctly with fallback
- [x] ExifDataComponent renders metadata
- [x] Backfill task works on existing photos
