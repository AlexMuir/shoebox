# Learnings — orientation-face-recognition

## 2026-03-01 Session ses_359877d58ffea2jl05a13namh5 — Atlas Initialization

### Codebase Conventions
- Rails 8.1.2, Ruby 3.2.2
- Service objects: `self.call` pattern + `Result = Data.define(...)` struct (see `app/models/photo/date_extractor.rb`)
- Models: `ApplicationRecord` base, fat models skinny controllers
- Multi-tenancy: ALL queries scoped to `Current.family` / `current_family`
- Jobs: inherit from `ApplicationJob`, SolidQueue configured but no custom jobs yet
- Factories: `spec/factories.rb` (single file), photo factory uses fake StringIO
- CSS: Tabler UI via CDN, custom SCSS overrides
- JS: Stimulus controllers, Turbo frames/streams
- Linting: rubocop-rails-omakase (double quotes, 2-space indent, Ruby 1.9 hash syntax)
- Schema format: SQL (`db/structure.sql`), not schema.rb

### Key Files
- `app/models/photo.rb:69-81` — EXIF extraction pattern with Vips (blob.open → Vips::Image)
- `app/models/photo/date_extractor.rb` — service object pattern to follow
- `app/models/photo_person.rb` — join model pattern
- `spec/factories.rb:30-45` — photo factory (uses StringIO fake data)
- `app/jobs/application_job.rb` — base job class
- `db/structure.sql` — full schema

### Architecture Decisions
- ML inference: Python FastAPI sidecar (NOT Ruby onnxruntime)
- Sidecar: InsightFace buffalo_s model, port 8100
- Embeddings: 512-d ArcFace vectors in pgvector via `neighbor` gem
- Clustering: Simple Ruby DBSCAN (~30 lines) using pgvector nearest-neighbor queries
- Orientation: EXIF-only via Vips autorot (no ML orientation detection in this phase)
- Face regions: normalized bbox (0.0-1.0), NOT pixel coordinates

### Worktree
- Branch: `face-recognition`
- Path: `/home/pippin/projects/photos-face-recognition`
- All work happens in worktree path

## 2026-03-01 Task 1 — Add neighbor gem and ML sidecar scaffold

### Gemfile Structure
- Gems organized by section: Frontend, Infrastructure, Storage & Media, Auth & Policy, UI, Domain
- `neighbor` gem added to "Storage & Media" section (line 28) after `image_processing`
- Follows existing style: double quotes, no version constraints for stable gems
- `bundle install` succeeded, neighbor 0.6.0 installed

### ML Sidecar Directory
- Created `ml_sidecar/requirements.txt` with Python dependencies:
  - FastAPI + Uvicorn for HTTP server
  - InsightFace for face detection/embedding
  - ONNX Runtime for model inference
  - NumPy, Pillow for image processing
  - python-multipart for form data handling
- Directory structure ready for Task 4 (full sidecar implementation)

### Verification
- `bundle exec rails runner "require 'neighbor'; puts 'NEIGHBOR_OK'"` ✓
- `bin/rubocop Gemfile` — 0 offenses ✓
- Commit: `feat(ml): add neighbor gem and ML sidecar directory scaffold` ✓

### Notes
- neighbor gem provides `has_neighbors :embedding` for pgvector similarity search
- All ML inference happens in Python sidecar (NOT Ruby gems like onnxruntime)
- Evidence saved to `.sisyphus/evidence/task-1-gems-load.txt`

## 2026-03-01 Task 2 — Database migrations for pgvector and face_regions

### pgvector Installation
- pgvector extension NOT pre-installed on system
- Installed via: `sudo apt-get install postgresql-16-pgvector`
- Extension enabled in migration via `enable_extension "vector"`
- Verified working: `SELECT '[1,2,3]'::vector <=> '[4,5,6]'::vector` returns distance value

### Migration Strategy (Two Separate Migrations)
1. **20260301000001_enable_pgvector_and_create_face_regions.rb**
   - Enables pgvector extension
   - Creates `face_regions` table with all columns
   - Uses `t.references` with `index: true` (avoids duplicate index creation)
   - Vector column: `t.column :embedding, :vector, limit: 512`

2. **20260301000002_add_face_analysis_fields_to_photos.rb**
   - Adds `faces_analyzed_at` (timestamp, nullable)
   - Adds `orientation_corrected` (boolean, default: false)

### face_regions Table Schema
- `id` (bigint, PK)
- `photo_id` (bigint, FK to photos, indexed)
- `person_id` (bigint, FK to people, nullable, indexed)
- `x, y, width, height` (double precision, NOT NULL) — normalized bbox (0.0-1.0)
- `embedding` (vector(512)) — ArcFace 512-d embeddings
- `confidence` (double precision) — face detection confidence
- `created_at, updated_at` (timestamps)

### Key Learnings
- `create_table` with `t.references` automatically creates indexes; explicit `add_index` causes duplicates
- Use `index: true` option on `t.references` to avoid redundant index creation
- Rails 8.1 with SQL schema format: `bin/rails db:migrate` updates `db/structure.sql` automatically
- pgvector column type provided by `neighbor` gem (added in Task 1)
- No IVFFlat index created yet (table is empty; add in batch task after data population)

### Verification
- `bin/rails db:migrate` completed successfully ✓
- pgvector query test: `SELECT '[1,2,3]'::vector <=> '[4,5,6]'::vector` returns 0.025368... ✓
- face_regions schema verified: 11 columns with correct types ✓
- photos table updated: faces_analyzed_at and orientation_corrected present ✓
- Evidence saved to `.sisyphus/evidence/task-2-pgvector-query.txt` and `task-2-face-regions-schema.txt` ✓
- Commit: `feat(db): add pgvector extension, face_regions table, and photo analysis fields` ✓

## 2026-03-01 Task 3 — Create FaceRegion model and associations

### FaceRegion Model Structure
- Created `app/models/face_region.rb` with:
  - `belongs_to :photo` (required)
  - `belongs_to :person, optional: true` (unassigned faces have nil person_id)
  - `has_neighbors :embedding` (pgvector similarity search via neighbor gem)
  - Scopes: `by_confidence`, `unassigned`, `assigned`
  - Validations: x/y/width/height presence + numericality (0.0-1.0 normalized coords)
  - Validates photo presence

### Photo Model Updates
- Added `has_many :face_regions, dependent: :destroy`
- Added scope: `needs_face_analysis` — finds photos with image but no faces_analyzed_at timestamp
- Added method: `face_analyzed?` — returns true if faces_analyzed_at is present
- Follows existing pattern: associations after belongs_to, scopes grouped, methods at end

### Person Model Updates
- Added `has_many :face_regions` (NO dependent: :destroy)
- Rationale: Deleting a person should unassign faces, not delete face regions
- Preserves face detection history even after person deletion

### Factory Pattern
- Created separate file: `spec/factories/face_regions.rb` (not in main factories.rb)
- Follows existing factory style: association, numeric fields, embedding as random array
- Embedding: 512-element array (matches InsightFace ArcFace output dimension)

### Verification
- All rubocop checks pass (0 offenses on models + factory)
- Rails runner confirms:
  - FaceRegion.new.respond_to?(:embedding) → true ✓
  - Photo.reflect_on_association(:face_regions).macro → has_many ✓
  - Person.reflect_on_association(:face_regions).macro → has_many ✓
- Evidence saved to `.sisyphus/evidence/task-3-*.txt`

### Commit
- `feat(models): add FaceRegion model and face analysis associations` ✓
- 4 files changed: face_region.rb (new), photo.rb, person.rb, face_regions.rb (new factory)

## 2026-03-01 Task 5 — Test infrastructure: face image fixtures and SolidQueue smoke test

### Test Image Creation
- Created `spec/fixtures/images/` directory with 4 JPEG test images:
  - `one_face.jpg` — 640x640 JPEG (placeholder for single-face photo)
  - `three_faces.jpg` — 640x640 JPEG (placeholder for multi-face photo)
  - `no_faces.jpg` — 640x640 JPEG (placeholder for landscape/object photo)
  - `rotated_exif.jpg` — 640x640 JPEG (placeholder for EXIF orientation testing)
- Images created using Vips Ruby API (no ImageMagick dependency)
- All images are valid JPEGs loadable by Vips (verified with `Vips::Image.new_from_file`)
- File sizes: 5.4K–11K (well under 1MB limit for fast tests)

### Photo Factory Enhancement
- Added `:with_real_image` trait to `:photo` factory in `spec/factories.rb`
- Trait uses `Rack::Test::UploadedFile` to attach real JPEG from fixtures
- Allows tests to use `create(:photo, :with_real_image)` for ML-related tests
- Default photo factory still uses StringIO fake data (backward compatible)

### SmokeTestJob Implementation
- Created `app/jobs/smoke_test_job.rb` inheriting from `ApplicationJob`
- Job writes timestamp to `tmp/smoke_test_completed` to prove execution
- Minimal implementation: 8 lines, 0 Rubocop offenses
- Ready for SolidQueue integration testing

### Verification & Evidence
- Vips successfully loads fixture: `640x640` dimensions confirmed ✓
- Evidence saved to `.sisyphus/evidence/task-5-fixture-valid.txt` ✓
- Rubocop: 0 offenses on `app/jobs/smoke_test_job.rb` and `spec/factories.rb` ✓
- Commit: `chore(test): add face image fixtures and SolidQueue smoke test` ✓

### Key Learnings
- Vips can create valid JPEG files via `Vips::Image.new_from_array().resize().write_to_file()`
- No need for real human faces in test fixtures — Vips just needs valid JPEG structure
- `Rack::Test::UploadedFile` is the Rails-idiomatic way to attach files in factories
- Factory traits are additive and don't break existing factory behavior
- SolidQueue jobs follow standard Rails ActiveJob pattern (no special setup needed)

## 2026-03-01 Task 4 — Python FastAPI sidecar for InsightFace

### Sidecar Implementation
- Added `ml_sidecar/main.py` with only two endpoints: `GET /health` and `POST /analyze`
- Uses `FaceAnalysis(name: "buffalo_s", providers: ["CPUExecutionProvider"])` and `ctx_id=-1` for CPU inference
- `/analyze` returns `bbox`, `confidence`, `landmarks`, and `embedding` per detected face
- Kept wrapper intentionally thin (<100 lines) with minimal 500 error handling

### Containerization
- Added `ml_sidecar/Dockerfile` and `docker-compose.ml.yml` at repo root
- `python:3.11-slim` on Debian trixie does not provide `libgl1-mesa-glx`; `libgl1` works as replacement
- InsightFace required native build tools (`g++` missing); adding `build-essential` fixed image build
- Compose file persists model cache in named volume `ml_models` at `/root/.insightface`

### Rails Integration + Verification
- Added `config.ml_sidecar_url = ENV.fetch("ML_SIDECAR_URL", "http://localhost:8100")` to `config/application.rb`
- `docker build -t photos-ml ml_sidecar/` succeeds after Dockerfile dependency fixes
- `docker compose -f docker-compose.ml.yml up -d` used because `docker-compose` binary is unavailable in this environment
- Health check verified: `{"status":"ok","model":"buffalo_s"}` and evidence saved to `.sisyphus/evidence/task-4-sidecar-health.txt`

## Task 6: OrientationService Implementation

**Date**: 2026-03-01

### Pattern Confirmed
- Service object pattern: `self.call(photo)` class method + `Result = Data.define(...)` struct
- Blob access: `@photo.image.blob.open { |file| Vips::Image.new_from_file(file.path) }`
- EXIF orientation read: `image.get("orientation")` returns 1-8; rescue to 1 if missing
- Error handling: Wrap in rescue block, log warning, return safe default

### Implementation Details
- `OrientationService` reads EXIF orientation WITHOUT modifying the blob
- Active Storage variants already auto-orient via image_processing gem
- Service returns `Result.corrected: true` only if orientation != 1
- Handles missing image gracefully (returns `corrected: false, orientation: nil`)
- Handles missing EXIF tag gracefully (rescue to orientation=1)

### Code Location
- File: `app/services/orientation_service.rb`
- Commit: `feat(orientation): add EXIF auto-orient service via Vips`
- Rubocop: ✅ Passes (0 offenses)
- Test: ✅ Loads successfully, handles no-image case

### Next Steps
- Called by PhotoAnalysisJob (T10) to determine if orientation was corrected
- Can be extended with ML-based orientation detection in future (currently EXIF-only)

## Task 8: FaceAnalysisClient HTTP Client (2026-03-01)

- **Service pattern**: Matches `OrientationService` — `self.call(photo)`, `Data.define` struct, `blob.open` for temp file access
- **Multipart upload**: Built manually with `Net::HTTP` (no gems) using boundary-based multipart/form-data body
- **Coordinate normalization**: Sidecar returns pixel coords `[x1,y1,x2,y2]`; client converts to `[x, y, width, height]` normalized 0.0-1.0 using `Vips::Image` dimensions
- **Critical**: Must call `.to_f` on width/height before division to get float results, not integer division
- **Graceful degradation**: Catches `Errno::ECONNREFUSED`, `Net::OpenTimeout`, `Net::ReadTimeout` → returns `[]`
- **Timeouts**: `open_timeout: 5` (fail fast), `read_timeout: 30` (face analysis is slow on CPU)
- **`sidecar_available?`**: Class method for health checks, catches all exceptions → `false`
- **Config access**: `Rails.application.config.ml_sidecar_url` (set in `config/application.rb`)
- **Rubocop**: String continuation with `\` backslash requires proper indentation alignment for omakase style

## Task 10: PhotoAnalysisJob — ML Pipeline Orchestrator (2026-03-01)

### Job Design
- Inherits from `ApplicationJob`, `queue_as :default`
- `retry_on StandardError, wait: :polynomially_longer, attempts: 3` for SolidQueue retries
- Idempotent: three guard clauses (missing photo, already analyzed, no image attached)
- Uses `Photo.find_by` (returns nil) NOT `Photo.find` (raises) for deleted-between-enqueue safety

### Pipeline Steps
1. `OrientationService.call(photo)` → `Result` with `.corrected` boolean
2. `FaceAnalysisClient.call(photo)` → array of `FaceData` structs
3. `ActiveRecord::Base.transaction` wraps face_region creation + photo update (atomic)
4. `photo.update!(faces_analyzed_at: Time.current, orientation_corrected: result.corrected)`

### Key Decisions
- Transaction ensures all-or-nothing: either all face_regions created AND photo marked, or nothing
- Re-raises after logging so SolidQueue can track retries
- Clustering is NOT called here — separate operation (future task)
- `rescue => e` with re-raise pattern: log for debugging, raise for retry mechanism

### Verification
- `PhotoAnalysisJob.ancestors.include?(ApplicationJob)` → true ✓
- `PhotoAnalysisJob.queue_name` → "default" ✓
- Rubocop: 0 offenses ✓
- Commit: `feat(pipeline): add PhotoAnalysisJob orchestrating ML pipeline` (a050cf1)

## Task 11: Upload Hook & Batch Processing

### Implementation Pattern
- **After-commit callbacks**: Follow existing pattern at line 28 of photo.rb
  - Use `after_commit :method_name, on: :create, if: -> { condition }`
  - Conditions check `image.attached?` to ensure attachment exists
  - Private methods defined in existing `private` section (don't duplicate)

### Rake Task Structure
- **Namespace**: `namespace :ml do ... end`
- **Task definition**: `task task_name: :environment do ... end`
- **Parameterized tasks**: `task :name, [:param] => :environment do |_, args| ... end`
- **Progress output**: Use modulo for periodic updates (e.g., `if (enqueued % 50).zero?`)

### Key Methods Used
- `Photo.joins(:image_attachment)` - Join with Active Storage attachment
- `Photo.where(faces_analyzed_at: nil)` - Filter unanalyzed photos
- `find_each` - Memory-efficient iteration for large datasets
- `PhotoAnalysisJob.perform_later(id)` - Enqueue via SolidQueue

### Rubocop Compliance
- File passes rubocop-rails-omakase without offenses
- Double quotes, 2-space indent, frozen_string_literal comment


## Task 13: Cluster Detail View
- When adding nested routes for specific actions on a member, using a separate route definition like `delete "face_clusters/:id/faces/:face_region_id", to: "face_clusters#exclude_face", as: :exclude_face_face_cluster` can be cleaner than deeply nested `member` blocks.
- Rubocop fails on `.erb` files by default because it tries to parse them as Ruby. To run rubocop on a mix of ruby and erb files, you can add `app/views/**/*` to `AllCops: Exclude:` in `.rubocop.yml` and run with `--force-exclusion`.
- Tabler UI cards can be used to create a nice layout with a form on one side and a grid of items on the other.
- The CSS trick for face thumbnails (`object-position` and `transform: scale`) works well in a grid layout.
## Task 15: Service Specs for OrientationService, FaceAnalysisClient, FaceClusteringService

### Key Findings

1. **DBSCAN MIN_SAMPLES semantics**: `find_neighbors` excludes the point itself, so `MIN_SAMPLES=2` requires at least 3 similar face_regions to form a cluster (each point needs >= 2 neighbors excluding self). Tests must create 3+ similar embeddings.

2. **Synthetic test images**: `rotated_exif.jpg` has EXIF orientation=1 (not rotated). All fixture images are ImageMagick-generated synthetics. To test the `corrected: true` path, stub `Vips::Image` with `instance_double`.

3. **Vips stub leaking into Photo callbacks**: `Photo#extract_exif_taken_at` also calls `Vips::Image.new_from_file`. When stubbing Vips globally, use `let!` to force photo creation before the stub, preventing interference with model callbacks.

4. **FaceAnalysisClient sidecar guard**: Use `skip "ML sidecar not running" unless FaceAnalysisClient.sidecar_available?` in `before` blocks. Sidecar-dependent tests are tagged `:slow`.

5. **Embedding storage**: pgvector via `has_neighbors :embedding` round-trips correctly — `Array` in, `Array` out with proper float values.

6. **Test coverage**: 14 examples across 3 spec files, 0 failures, 0 rubocop offenses.

## T16: Integration & Request Specs (2026-03-01)

### Auth in Request Specs
- `cookies.signed[:key]` is NOT available in Rack::Test (request specs)
- Solution: Perform actual login flow — create `LoginCode`, generate `pending_authentication_token` via `Rails.application.message_verifier("pending_authentication_token")`, then POST to `session_login_code_path`
- After login POST, session cookie is properly set by Rails middleware and persists across subsequent requests in same test
- Use `let(:user) { create(:user) }; let(:family) { user.families.first }` since login flow uses first family

### Multi-Tenancy Testing
- With `show_exceptions = :rescuable`, `ActiveRecord::RecordNotFound` → 404 response (not raised exception)
- Test with: `expect(response).to have_http_status(:not_found)` NOT `raise_error`
- Controller uses `current_family.people.find(params[:id])` — inherently scoped

### Job Spec Mocking Pattern
- Mock `FaceAnalysisClient.call` and `OrientationService.call` to avoid sidecar dependency
- `FaceAnalysisClient::FaceData` and `OrientationService::Result` are `Data.define` structs
- Test idempotency by running `perform_now` twice — second run skips due to `faces_analyzed_at` guard

### Pre-existing Issue
- `person_spec.rb` age test fails on certain dates due to `365.25` divisor rounding — not related to face recognition work
