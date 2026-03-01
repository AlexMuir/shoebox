# Photo Orientation + Face Recognition Prototype

## TL;DR

> **Quick Summary**: Add EXIF-based auto-orientation and a complete face recognition pipeline (detection → embedding → clustering → admin UI) to the Photos app, using a lightweight Python/FastAPI sidecar running InsightFace for ML inference, with Rails handling orchestration, storage, and UI.
>
> **Deliverables**:
> - EXIF auto-orient on all photo uploads (via Vips `autorot`)
> - Face detection (InsightFace SCRFD) identifying faces with bounding boxes
> - Face embedding (InsightFace ArcFace) generating 512-d vectors stored in pgvector
> - Face clustering (DBSCAN) automatically grouping faces into people
> - Lightweight admin UI for reviewing clusters, naming people, and excluding incorrect faces
> - Batch processing rake task for existing photos
> - RSpec test suite for all new services
>
> **Estimated Effort**: Large
> **Parallel Execution**: YES — 7 waves
> **Critical Path**: Task 4 → Task 7 → Task 8 → Task 9 → Task 12 → Task 13 → Task 16

---

## Context

### Original Request
User wants to detect incorrect photo orientation and fix it, and implement face recognition for their family photo app. Research into local models that can run without cloud APIs.

### Interview Summary
**Key Discussions**:
- Architecture: Initially chose pure Ruby with `onnxruntime`, then reconsidered after risk analysis. Switched to lightweight Python/FastAPI sidecar wrapping InsightFace — dramatically reduces risk, mirrors Immich’s proven architecture
- Scope: Full pipeline from orientation through face clustering to admin UI
- Orientation trigger: Auto on every upload via background job
- UI: Lightweight admin page for face cluster management (not integrated photo overlays)
- Tests: After implementation, not TDD
- GPU: Not available — CPU-only inference

**Research Findings**:
- Immich (gold standard) uses InsightFace SCRFD + ArcFace + ONNX Runtime + incremental DBSCAN
- `onnxruntime` Ruby gem: viable but preprocessing pipeline in Ruby is high-risk (no community examples)
- `neighbor` gem (ankane): Rails-native pgvector integration with cosine/euclidean search
- InsightFace Python package: `app.get(img)` returns faces with bbox, landmarks, AND embeddings in 4 lines
- A minimal FastAPI sidecar (~50 lines Python) eliminates all tensor manipulation risk on the Ruby side
- Active Storage's `image_processing` gem already applies Vips `autorot` on variants

### Metis Review
**Identified Gaps** (addressed):
- **ML orientation model doesn't exist as described**: The EfficientNetV2-S on HuggingFace is a general ImageNet classifier (1000 classes), not a purpose-trained 4-class orientation detector. Resolution: Use EXIF-only auto-orient for prototype; ML orientation deferred to phase 2
- **ONNX tensor manipulation in Ruby is high-risk**: No community examples of running InsightFace preprocessing in Ruby. Resolution: Moved ML inference to a Python sidecar where InsightFace handles all preprocessing natively
- **Face alignment in Ruby is complex**: Full 5-point Umeyama transform requires linear algebra. Resolution: InsightFace’s Python package handles alignment internally — no longer our problem
- **Photo factory uses fake data**: `StringIO.new("fake image data")` won't work for ML tests. Resolution: Added test fixture setup with real face images
- **First-ever custom job in codebase**: SolidQueue configured but never used. Resolution: Added SolidQueue smoke test task
- **Multi-tenancy risk**: Face clustering must scope to `family_id` to prevent cross-family face matching. Resolution: Explicit family scoping in all queries + isolation spec
- **face_regions vs photo_people relationship**: Resolution: `face_regions` stores detected faces with `person_id`; existing `photo_people` remains for manual tags. Naming a cluster assigns `person_id` on face_regions only — no auto-creation of `photo_people` records

---

## Work Objectives

### Core Objective
Build a working prototype of EXIF-based photo orientation correction and InsightFace-powered face recognition with clustering and a basic admin UI. ML inference runs in a lightweight Python/FastAPI sidecar; Rails handles orchestration, storage, clustering, and UI.

### Concrete Deliverables
- `ml_sidecar/` — Python FastAPI service wrapping InsightFace (~50 lines + Dockerfile)
- `app/services/orientation_service.rb` — EXIF auto-orient via Vips
- `app/services/face_analysis_client.rb` — HTTP client calling the Python sidecar
- `app/services/face_clustering_service.rb` — DBSCAN clustering
- `app/jobs/photo_analysis_job.rb` — Background job orchestrating the pipeline
- `app/models/face_region.rb` — Face bounding box + embedding model
- `app/controllers/face_clusters_controller.rb` — Admin UI controller
- Admin views for face cluster management
- `lib/tasks/ml.rake` — Batch processing + sidecar management tasks
- Database migrations for pgvector, face_regions table, photo analysis fields
- RSpec test suite for all services and controller
- `docker-compose.ml.yml` — Compose file for the ML sidecar

### Definition of Done
- [ ] `bundle exec rspec` passes with 0 failures
- [ ] `bin/rubocop` passes with 0 offenses
- [ ] Uploading a photo triggers orientation check + face analysis via background job
- [ ] Detected faces appear as clusters in the admin UI
- [ ] Clusters can be named (assigned to a Person)
- [ ] Batch processing handles all existing photos

### Must Have
- EXIF auto-orient on upload (Vips `autorot`)
- Face detection returning bounding box coordinates
- Face embedding as 512-d vectors in pgvector
- DBSCAN clustering scoped to `family_id`
- Admin UI to view/name face clusters
- Background job processing (not blocking uploads)
- Batch rake task for existing photos
- All face queries scoped to `current_family` (multi-tenancy)

### Must NOT Have (Guardrails)
- NO ML-based orientation detection (EXIF-only for prototype — ML orientation model doesn't exist as described)
- NO auto-creation of `photo_people` records from face recognition (face_regions only, human confirmation needed)
- NO GPU-specific code or CUDA dependencies
- NO heavy ML frameworks in Ruby (no onnxruntime, no tensor manipulation in Ruby)
- NO incremental clustering optimization (full re-cluster on demand is sufficient)
- NO face bounding box overlays drawn on photos in the UI (just the admin cluster list)
- NO cluster merge/split UI (name clusters, exclude faces — nothing more)
- NO new Ruby gems beyond: `neighbor` (+ transitive dependencies)
- NO video face detection
- NO over-abstraction or premature generalization of the ML pipeline

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (RSpec + FactoryBot)
- **Automated tests**: Tests-after (write specs after implementation works)
- **Framework**: `rspec-rails ~> 8.0`

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Backend services**: Use Bash (`bundle exec rails runner` / `bundle exec rspec`) — run service, assert output
- **Background jobs**: Use Bash — enqueue job, verify face_regions created
- **Admin UI**: Use Bash (`bundle exec rspec spec/requests/`) — request specs for status codes and content
- **Database**: Use Bash (`bundle exec rails runner`) — verify pgvector queries work

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — all parallel, scaffolding):
├── Task 1: Add Ruby gems (neighbor) + Python sidecar scaffold [quick]
├── Task 2: Database migrations (pgvector, face_regions, photo fields) [quick]
├── Task 3: Models + associations (FaceRegion, Photo updates) [quick]
├── Task 4: Python ML sidecar (FastAPI + InsightFace + Dockerfile) [deep]
└── Task 5: Test infrastructure (real face images, SolidQueue smoke test) [quick]

Wave 2 (Orientation + Sidecar Verification — parallel):
├── Task 6: OrientationService — EXIF auto-orient (depends: none) [quick]
└── Task 7: Sidecar integration test — verify API contract (depends: 4) [quick]

Wave 3 (Rails ML Client — single task, depends on sidecar):
└── Task 8: FaceAnalysisClient — HTTP client for sidecar (depends: 1, 7) [unspecified-high]

Wave 4 (Pipeline + Clustering — sequential chain):
├── Task 9: FaceClusteringService — DBSCAN (depends: 2, 3, 8) [deep]
├── Task 10: PhotoAnalysisJob — orchestration (depends: 6, 8, 9) [unspecified-high]
└── Task 11: Upload hook + batch rake task (depends: 10) [quick]

Wave 5 (UI — mostly parallel):
├── Task 12: FaceClustersController + routes + index view (depends: 3, 9) [visual-engineering]
├── Task 13: Cluster detail + person naming (depends: 12) [visual-engineering]
└── Task 14: Navigation + photo detail tags (depends: 12) [quick]

Wave 6 (Tests — parallel):
├── Task 15: Service specs (depends: 6, 8, 9) [unspecified-high]
└── Task 16: Integration + request specs (depends: 10, 13) [unspecified-high]

Wave FINAL (Verification — 4 parallel):
├── F1: Plan compliance audit [oracle]
├── F2: Code quality review [unspecified-high]
├── F3: Real manual QA [unspecified-high]
└── F4: Scope fidelity check [deep]

Critical Path: Task 4 → Task 7 → Task 8 → Task 9 → Task 12 → Task 13 → Task 16
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 5 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 7, 8 | 1 |
| 2 | — | 9, 10 | 1 |
| 3 | — | 9, 12 | 1 |
| 4 | — | 7 | 1 |
| 5 | — | 15, 16 | 1 |
| 6 | — | 10 | 2 |
| 7 | 4 | 8 | 2 |
| 8 | 1, 7 | 9, 10 | 3 |
| 9 | 2, 3, 8 | 10, 12 | 4 |
| 10 | 6, 8, 9 | 11, 16 | 4 |
| 11 | 10 | 16 | 4 |
| 12 | 3, 9 | 13, 14 | 5 |
| 13 | 12 | 16 | 5 |
| 14 | 12 | — | 5 |
| 15 | 6, 8, 9 | — | 6 |
| 16 | 10, 13 | — | 6 |

### Agent Dispatch Summary

- **Wave 1**: 5 tasks — T1,T2,T3,T5 → `quick`, T4 → `deep`
- **Wave 2**: 2 tasks — T6 → `quick`, T7 → `quick`
- **Wave 3**: 1 task — T8 → `unspecified-high`
- **Wave 4**: 3 tasks — T9 → `deep`, T10 → `unspecified-high`, T11 → `quick`
- **Wave 5**: 3 tasks — T12 → `visual-engineering`, T13 → `visual-engineering`, T14 → `quick`
- **Wave 6**: 2 tasks — T15,T16 → `unspecified-high`
- **FINAL**: 4 tasks — F1 → `oracle`, F2-F3 → `unspecified-high`, F4 → `deep`

---

## TODOs


- [ ] 1. Add Ruby gems (neighbor) + create sidecar directory structure

  **What to do**:
  - Add to Gemfile: `gem "neighbor"`
  - Run `bundle install`
  - Verify gem loads: `bundle exec rails runner "require 'neighbor'; puts 'OK'"`
  - Create `ml_sidecar/` directory at project root with:
    - `ml_sidecar/requirements.txt` (placeholder: `fastapi`, `uvicorn`, `insightface`, `onnxruntime`, `numpy`, `Pillow`)
    - `ml_sidecar/.gitkeep`
  - Note: `rumale-clustering` is no longer needed — clustering will use a simple Ruby implementation or the sidecar can return cluster assignments

  **Must NOT do**:
  - Do not add `onnxruntime` or `rumale-clustering` Ruby gems (ML runs in Python now)
  - Do not install Python dependencies yet (Task 4 handles the full sidecar)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4, 5)
  - **Blocks**: Tasks 7, 8
  - **Blocked By**: None

  **References**:
  - `Gemfile` — current gem declarations, follow the existing grouping style (see `# Storage & Media` section)
  - [neighbor gem](https://www.rubydoc.info/gems/neighbor/0.5.1) — pgvector Rails integration by ankane
  - **WHY**: The `neighbor` gem provides `has_neighbors :embedding` for pgvector-backed nearest-neighbor search. It's the only ML-adjacent Ruby gem we need — all actual inference happens in the Python sidecar.

  **Acceptance Criteria**:
  - [ ] `bundle exec rails runner "require 'neighbor'; puts 'OK'"` prints OK
  - [ ] `ml_sidecar/requirements.txt` exists with correct dependencies
  - [ ] `bin/rubocop Gemfile` passes with 0 offenses

  ```
  Scenario: Neighbor gem loads successfully
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "require 'neighbor'; puts 'NEIGHBOR_OK'"
      2. Assert output contains 'NEIGHBOR_OK'
    Expected Result: Gem loads without error
    Evidence: .sisyphus/evidence/task-1-gems-load.txt
  ```

  **Commit**: YES
  - Message: `feat(ml): add neighbor gem and ML sidecar directory scaffold`
  - Files: `Gemfile`, `Gemfile.lock`, `ml_sidecar/requirements.txt`

- [ ] 2. Database migrations — pgvector extension, face_regions table, photo analysis fields

  **What to do**:
  - Create migration to enable pgvector extension: `enable_extension "vector"`
  - Create `face_regions` table with:
    - `photo_id` (bigint, NOT NULL, foreign key)
    - `person_id` (bigint, nullable, foreign key to people)
    - `x` (float, NOT NULL) — bounding box x coordinate (0.0 to 1.0, normalized)
    - `y` (float, NOT NULL) — bounding box y coordinate (0.0 to 1.0, normalized)
    - `width` (float, NOT NULL) — bounding box width (0.0 to 1.0, normalized)
    - `height` (float, NOT NULL) — bounding box height (0.0 to 1.0, normalized)
    - `embedding` (vector, limit: 512) — face embedding from ArcFace
    - `confidence` (float) — detection confidence score
    - `timestamps`
  - Add index on `photo_id`
  - Add index on `person_id`
  - Add index on `embedding` using `ivfflat` for nearest-neighbor search (with `lists: 100` — can be tuned later)
  - Add columns to `photos` table:
    - `faces_analyzed_at` (timestamp, nullable) — tracks when face analysis was last run
    - `orientation_corrected` (boolean, default: false) — tracks if orientation was fixed
  - Run `bin/rails db:migrate` to apply
  - Schema format is SQL (`structure.sql`), so verify `db/structure.sql` is updated

  **Must NOT do**:
  - Do not create a separate migration for each change — group logically (extension + table in one, photo columns in another)
  - Do not add IVFFlat index if table is empty (IVFFlat requires data to build — use exact search initially, add index via batch task later)
  - Do not modify existing columns on the photos table

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4, 5)
  - **Blocks**: Tasks 9, 10
  - **Blocked By**: None

  **References**:
  - `db/structure.sql:379-391` — `people` table schema (for foreign key reference)
  - `db/structure.sql:486-512` — `photos` table schema (for adding columns)
  - `db/migrate/20260228215711_enable_extensions.rb` — follow this pattern for enabling pgvector extension
  - [neighbor gem README](https://www.rubydoc.info/gems/neighbor/0.5.1) — migration syntax: `add_column :face_regions, :embedding, :vector, limit: 512`
  - Note: IVFFlat index requires populated data. For empty tables use exact (sequential) search. Add IVFFlat index in the batch processing task after data exists.

  **Acceptance Criteria**:
  - [ ] `bin/rails db:migrate` completes without error
  - [ ] `bundle exec rails runner "ActiveRecord::Base.connection.execute(\"SELECT '[1,2,3]'::vector\")"` succeeds (pgvector works)
  - [ ] `bundle exec rails runner "ActiveRecord::Base.connection.columns('face_regions').map(&:name).sort"` includes embedding, x, y, width, height, confidence
  - [ ] `bundle exec rails runner "ActiveRecord::Base.connection.columns('photos').map(&:name)"` includes faces_analyzed_at, orientation_corrected
  - [ ] `db/structure.sql` is updated with new tables and columns

  ```
  Scenario: pgvector extension is functional
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "result = ActiveRecord::Base.connection.execute(\"SELECT '[1,2,3]'::vector <=> '[4,5,6]'::vector AS distance\"); puts result.first['distance']"
      2. Assert output is a numeric distance value (not an error)
    Expected Result: Cosine distance computed successfully
    Evidence: .sisyphus/evidence/task-2-pgvector-query.txt

  Scenario: face_regions table exists with correct schema
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "puts ActiveRecord::Base.connection.columns('face_regions').map { |c| [c.name, c.sql_type].join(':') }.sort.join(', ')"
      2. Assert output includes: confidence:double precision, embedding:vector(512), height:double precision, width:double precision, x:double precision, y:double precision
    Expected Result: All columns present with correct types
    Evidence: .sisyphus/evidence/task-2-face-regions-schema.txt
  ```

  **Commit**: YES
  - Message: `feat(db): add pgvector extension, face_regions table, and photo analysis fields`
  - Files: `db/migrate/*.rb`, `db/structure.sql`
  - Pre-commit: `bin/rails db:migrate:status`

- [ ] 3. FaceRegion model + Photo model updates

  **What to do**:
  - Create `app/models/face_region.rb`:
    - `belongs_to :photo`
    - `belongs_to :person, optional: true`
    - `has_neighbors :embedding`
    - Scope `by_confidence` (ordered by confidence desc)
    - Scope `unassigned` (where person_id is nil)
    - Scope `assigned` (where person_id is not nil)
    - Validate presence of x, y, width, height, confidence
    - Validate numericality of x, y, width, height (0.0..1.0)
  - Update `app/models/photo.rb`:
    - Add `has_many :face_regions, dependent: :destroy`
    - Add scope `needs_face_analysis` → where faces_analyzed_at is nil and image is attached
    - Add method `face_analyzed?` → `faces_analyzed_at.present?`
  - Update `app/models/person.rb`:
    - Add `has_many :face_regions`
  - Create `spec/factories/face_regions.rb` factory

  **Must NOT do**:
  - Do not modify existing Person validations or associations beyond adding `has_many :face_regions`
  - Do not add any ML logic to models — models are data layer only
  - Do not add `dependent: :destroy` to Person → face_regions (deleting a person should unassign, not delete detections)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 5)
  - **Blocks**: Tasks 9, 12
  - **Blocked By**: None (model file can be created before migration runs; migration must run before tests)

  **References**:
  - `app/models/photo.rb` — existing Photo model with Active Storage, associations, scopes (follow exact style)
  - `app/models/person.rb` — existing Person model (add `has_many :face_regions` after line 5)
  - `app/models/photo_person.rb` — example join model pattern (validations, belongs_to style)
  - `spec/factories.rb:47-53` — existing Person factory pattern (follow for FaceRegion factory)
  - [neighbor gem](https://www.rubydoc.info/gems/neighbor/0.5.1) — `has_neighbors :embedding` declaration
  - **WHY**: FaceRegion stores normalized bounding box coordinates (0.0-1.0) so they work regardless of image variant size. The `has_neighbors` declaration enables `nearest_neighbors(:embedding, distance: "cosine")` queries.

  **Acceptance Criteria**:
  - [ ] `bundle exec rails runner "FaceRegion.new.respond_to?(:embedding)"` returns true
  - [ ] `bundle exec rails runner "FaceRegion.new.respond_to?(:nearest_neighbors)"` returns true
  - [ ] `bundle exec rails runner "Photo.new.respond_to?(:face_regions)"` returns true
  - [ ] `bundle exec rails runner "Person.new.respond_to?(:face_regions)"` returns true
  - [ ] `bin/rubocop app/models/face_region.rb app/models/photo.rb app/models/person.rb` passes

  ```
  Scenario: FaceRegion model validates correctly
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "fr = FaceRegion.new; fr.valid?; puts fr.errors.full_messages.sort.join(', ')"
      2. Assert output includes validation errors for x, y, width, height, confidence, photo
    Expected Result: Validates presence of required fields
    Evidence: .sisyphus/evidence/task-3-face-region-validations.txt

  Scenario: Photo has face_regions association
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "puts Photo.reflect_on_association(:face_regions).macro"
      2. Assert output is 'has_many'
    Expected Result: Association exists and is has_many
    Evidence: .sisyphus/evidence/task-3-photo-association.txt
  ```

  **Commit**: YES
  - Message: `feat(models): add FaceRegion model and face analysis associations`
  - Files: `app/models/face_region.rb`, `app/models/photo.rb`, `app/models/person.rb`, `spec/factories/face_regions.rb`


- [ ] 4. Python ML sidecar — FastAPI + InsightFace + Dockerfile

  **What to do**:
  - Create `ml_sidecar/main.py` — a minimal FastAPI app (~50-80 lines):
    - `POST /analyze` endpoint:
      - Accepts image as multipart upload or base64 in JSON body
      - Runs InsightFace `FaceAnalysis('buffalo_s')` on the image
      - Returns JSON array of detected faces, each with:
        - `bbox`: `[x1, y1, x2, y2]` (pixel coordinates)
        - `confidence`: float
        - `landmarks`: 5-point array `[[x,y], ...]`
        - `embedding`: 512-element float array (L2-normalized)
      - Returns empty array if no faces detected
    - `GET /health` endpoint:
      - Returns `{"status": "ok", "model": "buffalo_s"}`
      - Verifies model is loaded
    - On startup:
      - Load InsightFace model: `app = FaceAnalysis('buffalo_s'); app.prepare(ctx_id=-1)`
      - Model stays resident in memory (loaded once)
  - Create `ml_sidecar/Dockerfile`:
    - Base: `python:3.11-slim`
    - Install system deps: `libgl1-mesa-glx`, `libglib2.0-0` (OpenCV deps for InsightFace)
    - `pip install` from `requirements.txt`
    - Expose port 8100
    - CMD: `uvicorn main:app --host 0.0.0.0 --port 8100`
  - Update `ml_sidecar/requirements.txt` with pinned versions:
    - `fastapi>=0.100.0`
    - `uvicorn[standard]>=0.20.0`
    - `insightface>=0.7.3`
    - `onnxruntime>=1.16.0`
    - `numpy>=1.24.0`
    - `Pillow>=10.0.0`
    - `python-multipart>=0.0.6`
  - Create `docker-compose.ml.yml` at project root:
    ```yaml
    services:
      ml:
        build: ./ml_sidecar
        ports:
          - "8100:8100"
        volumes:
          - ml_models:/root/.insightface  # cached model downloads
        restart: unless-stopped
    volumes:
      ml_models:
    ```
  - Add `ML_SIDECAR_URL` to Rails config:
    - Default: `http://localhost:8100`
    - Configurable via `ENV['ML_SIDECAR_URL']`
    - Add to `config/application.rb` or a dedicated `config/ml.yml`
  - InsightFace auto-downloads the `buffalo_s` model on first use (~100MB, cached in the Docker volume)

  **Must NOT do**:
  - Do not make the sidecar complex — it's a thin wrapper, not a full service
  - Do not add authentication to the sidecar (it's an internal service)
  - Do not add database connections to the sidecar
  - Do not add more than 2 endpoints (analyze + health)
  - Do not over-engineer error handling — return HTTP 500 with error message on failure

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Python service creation, Dockerfile authoring, Docker Compose config, InsightFace API
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 5)
  - **Blocks**: Task 7 (sidecar must work before integration test)
  - **Blocked By**: None

  **References**:
  - [InsightFace Python package](https://github.com/deepinsight/insightface/tree/master/python-package) — `FaceAnalysis` class API. Key: `app = FaceAnalysis('buffalo_s'); app.prepare(ctx_id=-1); faces = app.get(img)`
  - [FastAPI docs](https://fastapi.tiangolo.com/) — minimal API setup, file upload handling
  - [Immich ML service](https://github.com/immich-app/immich/tree/main/machine-learning) — architecture reference (they do the same thing but more complex)
  - `Dockerfile` (project root) — existing Dockerfile pattern for base image and dependency installation style
  - `docker-compose.yml` or `docker-compose.*.yml` — check if any exist to follow conventions
  - **WHY**: This is the core architectural decision. Instead of replicating InsightFace's preprocessing pipeline in Ruby (~300 lines of fragile tensor code), we wrap it in ~50 lines of Python where it runs natively. The sidecar receives an image and returns structured face data. Rails never touches tensors.

  **Acceptance Criteria**:
  - [ ] `ml_sidecar/main.py` exists and is < 100 lines
  - [ ] `ml_sidecar/Dockerfile` builds successfully: `docker build -t photos-ml ml_sidecar/`
  - [ ] `docker-compose -f docker-compose.ml.yml up -d` starts the sidecar
  - [ ] `curl http://localhost:8100/health` returns `{"status": "ok"}`
  - [ ] `curl -X POST -F 'image=@spec/fixtures/images/one_face.jpg' http://localhost:8100/analyze` returns JSON with 1 face entry containing bbox, confidence, landmarks, embedding (512 elements)
  - [ ] `curl -X POST -F 'image=@spec/fixtures/images/no_faces.jpg' http://localhost:8100/analyze` returns empty array `[]`

  ```
  Scenario: Sidecar health check
    Tool: Bash
    Preconditions: docker-compose.ml.yml built and running
    Steps:
      1. Run: docker-compose -f docker-compose.ml.yml up -d
      2. Wait: sleep 30 (model download on first boot)
      3. Run: curl -s http://localhost:8100/health
      4. Assert: response contains '"status":"ok"'
    Expected Result: Sidecar is healthy and model is loaded
    Failure Indicators: Connection refused, 500 error, model download failure
    Evidence: .sisyphus/evidence/task-4-sidecar-health.txt

  Scenario: Face analysis returns structured data
    Tool: Bash
    Steps:
      1. Run: curl -s -X POST -F 'image=@spec/fixtures/images/one_face.jpg' http://localhost:8100/analyze | python3 -m json.tool
      2. Assert: JSON array with 1 element, each having bbox (4 numbers), confidence (float > 0.5), landmarks (5 pairs), embedding (512 floats)
    Expected Result: Structured face data returned
    Failure Indicators: Empty array for face image, missing fields, wrong embedding dimensions
    Evidence: .sisyphus/evidence/task-4-face-analysis.txt

  Scenario: No faces returns empty array
    Tool: Bash
    Steps:
      1. Run: curl -s -X POST -F 'image=@spec/fixtures/images/no_faces.jpg' http://localhost:8100/analyze
      2. Assert: response is '[]'
    Expected Result: Graceful empty response
    Evidence: .sisyphus/evidence/task-4-no-faces.txt
  ```

  **Commit**: YES
  - Message: `feat(ml): add Python FastAPI sidecar for InsightFace face analysis`
  - Files: `ml_sidecar/main.py`, `ml_sidecar/Dockerfile`, `ml_sidecar/requirements.txt`, `docker-compose.ml.yml`

- [ ] 5. Test infrastructure — real face image fixtures + SolidQueue smoke test

  **What to do**:
  - Create `spec/fixtures/images/` directory
  - Add curated test images (copyright-free from Unsplash or similar):
    - `one_face.jpg` — single person, clear face, well-lit
    - `three_faces.jpg` — group photo with 3 clearly visible faces
    - `no_faces.jpg` — landscape or object photo with zero faces
    - `rotated_exif.jpg` — photo with EXIF Orientation != 1 (e.g., rotated 90° CW)
    - Keep images small (< 500KB each) for fast test runs
  - Create a simple SolidQueue smoke test job:
    - `app/jobs/smoke_test_job.rb` — job that writes to a temp file to prove it ran
    - Verify via `bundle exec rails runner` that SolidQueue picks up and processes a job
    - This validates SolidQueue works before building the real PhotoAnalysisJob on top
  - Update `spec/factories.rb` to add a `:with_real_image` trait to the `:photo` factory:
    - Attaches `spec/fixtures/images/one_face.jpg` as a real Active Storage image

  **Must NOT do**:
  - Do not use copyrighted images
  - Do not use images larger than 1MB (slow tests)
  - Do not modify existing factory defaults — add traits only
  - Do not add more than the 4 test images listed above

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 4)
  - **Blocks**: Tasks 15, 16 (specs need real images)
  - **Blocked By**: None

  **References**:
  - `spec/factories.rb:30-45` — existing `:photo` factory (has `image { Rack::Test::UploadedFile.new(...) }` or similar)
  - `spec/spec_helper.rb` — RSpec configuration
  - `app/jobs/application_job.rb` — base job class (inherit from this)
  - `config/queue.yml` or SolidQueue configuration — verify queue names and worker setup
  - **WHY**: ML services need real JPEG pixels to test (the current factory uses `StringIO.new("fake image data")` which won't work for Vips or ONNX). The SolidQueue smoke test catches configuration issues early.

  **Acceptance Criteria**:
  - [ ] `spec/fixtures/images/one_face.jpg` exists and is a valid JPEG
  - [ ] `spec/fixtures/images/three_faces.jpg` exists with 3 faces
  - [ ] `spec/fixtures/images/no_faces.jpg` exists with 0 faces
  - [ ] `spec/fixtures/images/rotated_exif.jpg` has EXIF Orientation != 1
  - [ ] SolidQueue smoke test job processes successfully
  - [ ] Photo factory `:with_real_image` trait creates a valid Active Storage attachment

  ```
  Scenario: SolidQueue processes a job
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "SmokeTestJob.perform_later; sleep 3; puts File.exist?(Rails.root.join('tmp', 'smoke_test_completed'))"
      2. Assert: output is 'true'
    Expected Result: SolidQueue picks up and executes the smoke test job
    Failure Indicators: Job stays in queue, file not created, SolidQueue not running
    Evidence: .sisyphus/evidence/task-5-solidqueue-smoke.txt

  Scenario: Real image fixture is valid
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "img = Vips::Image.new_from_file('spec/fixtures/images/one_face.jpg'); puts \"#{img.width}x#{img.height}\""
      2. Assert: output is a valid dimension like '640x480' (not an error)
    Expected Result: Vips can load the test fixture as a real image
    Evidence: .sisyphus/evidence/task-5-fixture-valid.txt
  ```

  **Commit**: YES
  - Message: `chore(test): add face image fixtures and SolidQueue smoke test`
  - Files: `spec/fixtures/images/*`, `app/jobs/smoke_test_job.rb`, `spec/factories.rb`


- [ ] 6. OrientationService — EXIF auto-orient via Vips autorot

  **What to do**:
  - Create `app/services/orientation_service.rb` with `self.call(photo)` pattern:
    - Takes a Photo record with an attached image
    - Opens the image blob via `photo.image.blob.open`
    - Reads EXIF orientation via `Vips::Image.new_from_file(path)`
    - If orientation needs correction (not already upright):
      - Apply `vips_image.autorot` to get corrected image
      - Store corrected version back (either re-attach or note the correction)
    - Mark `photo.orientation_corrected = true`
    - Return a Result struct: `Result = Data.define(:corrected, :original_orientation)`
  - Note: Active Storage variants already auto-orient via `image_processing` gem, but the original blob is NOT auto-oriented. This service ensures the source image used for face detection is correctly oriented.
  - Handle edge cases:
    - Images with no EXIF data at all (skip, log)
    - Images already correctly oriented (no-op)
    - Non-JPEG images that don't support EXIF (skip)

  **Must NOT do**:
  - Do not add any ML-based orientation detection (EXIF-only for prototype)
  - Do not modify the original Active Storage blob — auto-orient is for processing only, originals stay untouched
  - Do not create a separate `app/services/` initializer — Rails autoloads this directory

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 7)
  - **Blocks**: Task 10
  - **Blocked By**: None (Vips is already installed; Wave 2 for organizational grouping)

  **References**:
  - `app/models/photo.rb:69-81` — existing `extract_exif_taken_at` method using Vips — follow this exact pattern for opening blob and reading EXIF
  - `app/models/photo/date_extractor.rb` — `self.call` + `Result` struct pattern to follow for service object style
  - ruby-vips docs: `Vips::Image#autorot` — automatically rotates image based on EXIF Orientation tag and strips the tag
  - ruby-vips docs: `Vips::Image#get('orientation')` — reads the EXIF orientation value (1-8)
  - **WHY**: The original blob is stored as-is (unrotated). Active Storage variants auto-orient when generating thumbs, but face detection runs on the original. This service provides a correctly-oriented image for the ML pipeline without modifying the stored original.

  **Acceptance Criteria**:
  - [ ] `app/services/orientation_service.rb` exists with `self.call` method
  - [ ] Service returns a Result struct with `:corrected` and `:original_orientation` fields
  - [ ] Given a photo with EXIF Orientation=6 (90° CW), service returns `corrected: true`
  - [ ] Given a photo with EXIF Orientation=1 (normal), service returns `corrected: false`
  - [ ] Given a photo with no EXIF data, service returns `corrected: false` without error
  - [ ] `bin/rubocop app/services/orientation_service.rb` passes

  ```
  Scenario: EXIF-rotated photo is detected
    Tool: Bash
    Preconditions: spec/fixtures/images/rotated_exif.jpg has EXIF Orientation != 1
    Steps:
      1. Run: bundle exec rails runner "
         photo = Photo.create!(family: Family.first, image: ActiveStorage::Blob.create_and_upload!(io: File.open('spec/fixtures/images/rotated_exif.jpg'), filename: 'test.jpg', content_type: 'image/jpeg'))
         result = OrientationService.call(photo)
         puts \"corrected:#{result.corrected} orientation:#{result.original_orientation}\"
         "
      2. Assert: output shows corrected:true and orientation is not 1
    Expected Result: Service detects the rotation and reports it
    Evidence: .sisyphus/evidence/task-6-orientation-detection.txt

  Scenario: Normal photo is not modified
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner with one_face.jpg (normal orientation)
      2. Assert: result.corrected is false
    Expected Result: No unnecessary correction
    Evidence: .sisyphus/evidence/task-6-normal-photo.txt
  ```

  **Commit**: YES
  - Message: `feat(orientation): add EXIF auto-orient service via Vips`
  - Files: `app/services/orientation_service.rb`

- [ ] 7. Sidecar integration test — verify API contract works end-to-end

  **What to do**:
  - With the sidecar running (`docker-compose -f docker-compose.ml.yml up -d`):
    - Verify `GET /health` returns 200 with `{"status": "ok"}`
    - Send `one_face.jpg` to `POST /analyze` and verify response structure:
      - Response is a JSON array
      - Each face object has: `bbox` (4 numbers), `confidence` (float), `landmarks` (5x2 array), `embedding` (512 floats)
      - Embedding is L2-normalized (magnitude ≈ 1.0)
    - Send `three_faces.jpg` and verify 3 faces returned
    - Send `no_faces.jpg` and verify empty array returned
    - Document the exact JSON response schema in `.sisyphus/drafts/sidecar-api-contract.md`
  - This contract document becomes the reference for Task 8 (Rails HTTP client)

  **Must NOT do**:
  - Do not write the Rails HTTP client yet — just verify the sidecar works
  - Do not modify the sidecar code — if it fails, fix in Task 4

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 6)
  - **Blocks**: Task 8
  - **Blocked By**: Task 4 (sidecar must be built), Task 5 (need test images)

  **References**:
  - `ml_sidecar/main.py` — the sidecar implementation (from Task 4)
  - `spec/fixtures/images/` — test images (from Task 5)
  - **WHY**: Verifying the API contract before writing the Rails client prevents integration issues. The contract document ensures the client matches exactly what the sidecar returns.

  **Acceptance Criteria**:
  - [ ] Sidecar responds to health check
  - [ ] Single face image returns 1 face with all required fields
  - [ ] Three face image returns 3 faces
  - [ ] No face image returns empty array
  - [ ] `.sisyphus/drafts/sidecar-api-contract.md` documents exact JSON schema
  - [ ] Embedding magnitude ≈ 1.0 (L2-normalized)

  ```
  Scenario: Full API contract verification
    Tool: Bash
    Steps:
      1. Run: curl -s http://localhost:8100/health | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['status']=='ok'; print('HEALTH_OK')"
      2. Run: curl -s -X POST -F 'image=@spec/fixtures/images/one_face.jpg' http://localhost:8100/analyze | python3 -c "
         import sys,json,math
         faces=json.load(sys.stdin)
         assert len(faces)==1, f'Expected 1 face, got {len(faces)}'
         f=faces[0]
         assert len(f['embedding'])==512, f'Expected 512-d, got {len(f["embedding"])}'
         mag=math.sqrt(sum(x*x for x in f['embedding']))
         assert 0.99<mag<1.01, f'Not L2-normalized: {mag}'
         print('FACE_OK')"
      3. Assert: both print OK
    Expected Result: Contract verified with real images
    Evidence: .sisyphus/evidence/task-7-api-contract.txt
  ```

  **Commit**: NO (contract doc only, no production code)

- [ ] 8. FaceAnalysisClient — HTTP client calling the Python sidecar from Rails

  **What to do**:
  - Create `app/services/face_analysis_client.rb` with `self.call(photo)` pattern:
    - Takes a Photo record with an attached image
    - Opens the image blob via `photo.image.blob.open`
    - Sends the image file to the sidecar: `POST http://{ML_SIDECAR_URL}/analyze`
    - Uses `Net::HTTP` (stdlib, no extra gems) for the HTTP request
    - Parses the JSON response into an array of `FaceData` structs:
      - `FaceData = Data.define(:bbox, :confidence, :landmarks, :embedding)`
    - Converts pixel-coordinate bounding boxes to normalized (0.0-1.0) format:
      - Needs the original image dimensions (width, height) to normalize
      - `normalized_x = bbox[0] / image_width`, etc.
    - Returns the array of `FaceData` structs
    - Handle errors:
      - Sidecar unreachable: rescue `Errno::ECONNREFUSED`, log warning, return empty array
      - Sidecar returns error: rescue HTTP error codes, log, return empty array
      - Timeout: set `read_timeout: 30` (face analysis can take a few seconds on CPU)

  **Must NOT do**:
  - Do not add HTTP client gems (Faraday, HTTParty) — use `Net::HTTP` from stdlib
  - Do not store raw pixel coordinates — always normalize to 0.0-1.0
  - Do not crash if sidecar is down — graceful degradation
  - Do not add retry logic in the client (the job handles retries)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: HTTP client with error handling, JSON parsing, coordinate normalization
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (single task)
  - **Blocks**: Tasks 9, 10
  - **Blocked By**: Tasks 1 (neighbor gem), 7 (API contract verified)

  **References**:
  - `.sisyphus/drafts/sidecar-api-contract.md` — CRITICAL: exact JSON response schema to parse
  - `app/services/orientation_service.rb` — follow same `self.call` + Result struct pattern
  - `app/models/photo.rb:69-81` — existing `blob.open` pattern for accessing image files
  - Ruby stdlib `Net::HTTP` docs — multipart file upload, timeouts, error handling
  - `config/application.rb` or `config/ml.yml` — where ML_SIDECAR_URL is configured (from Task 4)
  - **WHY**: This is the only point of contact between Rails and the ML sidecar. It translates the sidecar's raw JSON (pixel coordinates, float arrays) into Ruby structs that the rest of the pipeline understands. Normalizing coordinates here means all downstream code (clustering, UI) works with 0.0-1.0 values regardless of image size.

  **Acceptance Criteria**:
  - [ ] `app/services/face_analysis_client.rb` exists with `self.call(photo)` method
  - [ ] Given a photo with one face: returns 1 FaceData with 512-d embedding
  - [ ] Bounding box coordinates are normalized (0.0-1.0)
  - [ ] When sidecar is down: returns empty array, logs warning (no crash)
  - [ ] `bin/rubocop app/services/face_analysis_client.rb` passes

  ```
  Scenario: Client returns structured face data
    Tool: Bash
    Preconditions: Sidecar running, one_face.jpg fixture exists
    Steps:
      1. Run: bundle exec rails runner "
         photo = Photo.create!(family: Family.first, image: ActiveStorage::Blob.create_and_upload!(io: File.open('spec/fixtures/images/one_face.jpg'), filename: 'test.jpg', content_type: 'image/jpeg'))
         faces = FaceAnalysisClient.call(photo)
         puts \"count:#{faces.size} dims:#{faces.first&.embedding&.size}\"
         puts \"bbox_range:#{faces.first&.bbox&.all? { |v| v >= 0.0 && v <= 1.0 }}\"
         "
      2. Assert: count is 1, dims is 512, bbox_range is true
    Expected Result: Normalized face data from sidecar
    Evidence: .sisyphus/evidence/task-8-face-client.txt

  Scenario: Graceful degradation when sidecar is down
    Tool: Bash
    Steps:
      1. Stop the sidecar: docker-compose -f docker-compose.ml.yml down
      2. Run FaceAnalysisClient.call(photo)
      3. Assert: returns empty array, no exception raised
      4. Restart sidecar: docker-compose -f docker-compose.ml.yml up -d
    Expected Result: Client handles missing sidecar gracefully
    Evidence: .sisyphus/evidence/task-8-graceful-degradation.txt
  ```

  **Commit**: YES
  - Message: `feat(faces): add FaceAnalysisClient HTTP client for ML sidecar`
  - Files: `app/services/face_analysis_client.rb`

- [ ] 9. FaceClusteringService — DBSCAN on embeddings scoped to family

  **What to do**:
  - Create `app/services/face_clustering_service.rb` with `self.call(family)` pattern:
    - Takes a Family record
    - Loads all unassigned `FaceRegion` records for that family (via `face_regions.unassigned.joins(:photo).where(photos: { family_id: family.id })`)
    - Extracts embedding vectors as a 2D array
    - Runs DBSCAN clustering with a simple Ruby implementation (~30 lines, no gem needed):
      - Input: array of L2-normalized 512-d embeddings from FaceRegion records
      - Distance metric: Euclidean distance (for L2-normalized vectors, euclidean distance in [0, 2] range)
      - `eps`: 1.0 (euclidean distance threshold -- equivalent to ~0.5 cosine distance for L2-normalized vectors)
      - `min_samples`: 2 (minimum faces to form a cluster -- low for family photos)
      - Implementation: iterate over points, find eps-neighbors via pgvector distance query, expand clusters
      - Use `neighbor` gem's nearest-neighbor queries to find faces within eps distance efficiently
    - For each cluster (label != -1):
      - Create or find a Person record for the cluster
      - Strategy: if cluster overlaps with an existing named Person (any face_region in cluster already has a person_id), use that Person. Otherwise, create a new unnamed Person.
      - Assign `person_id` on all face_regions in the cluster
    - Noise points (label == -1): leave unassigned (person_id remains nil)
    - Return a Result struct: `Result = Data.define(:clusters_found, :faces_assigned, :noise_count)`
  - **CRITICAL multi-tenancy**: ALL queries MUST filter by `family_id`. Never cluster across families.
  - **DBSCAN implementation note**: A simple Ruby DBSCAN is ~30 lines. The algorithm is: (1) for each unvisited point, find all neighbors within eps distance, (2) if neighbors >= min_samples, start a new cluster and expand, (3) otherwise mark as noise. Use `FaceRegion.nearest_neighbors(:embedding, distance: :euclidean)` from the `neighbor` gem to efficiently find neighbors via pgvector.

  **Must NOT do**:
  - Do not cluster across family boundaries -- this is a privacy violation
  - Do not auto-create `photo_people` records -- face_regions.person_id only
  - Do not implement incremental clustering -- full re-cluster is fine for prototype
  - Do not delete existing person assignments when re-clustering -- only assign unassigned faces
  - Do not add any clustering gems (no rumale-clustering) -- simple Ruby implementation is sufficient

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: DBSCAN algorithm implementation, embedding distance calculations, multi-tenancy safety, pgvector queries
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (sequential)
  - **Blocks**: Tasks 10, 12
  - **Blocked By**: Tasks 2 (database), 3 (models), 8 (face analysis client provides embeddings)

  **References**:
  - `app/models/face_region.rb` -- scopes and associations (from Task 3)
  - [neighbor gem nearest_neighbors](https://www.rubydoc.info/gems/neighbor/0.5.1) -- `FaceRegion.nearest_neighbors(:embedding, distance: :euclidean)` for finding faces within eps distance
  - `app/models/person.rb` -- Person model for creating unnamed people (first_name: 'Unknown', last_name: 'Person N')
  - [DBSCAN algorithm](https://en.wikipedia.org/wiki/DBSCAN) -- reference for the simple Ruby implementation
  - ArcFace embeddings are L2-normalized, so euclidean distance in [0, 2] range. Distance 1.0 is approximately cosine similarity 0.5 (the typical threshold).
  - **WHY**: DBSCAN groups faces without needing to know how many people exist upfront. The `min_samples: 2` means a person needs at least 2 photos to form a cluster. Single-occurrence faces become noise (shown as 'Unmatched' in UI). A simple Ruby implementation avoids adding another gem dependency.

  **Acceptance Criteria**:
  - [ ] `app/services/face_clustering_service.rb` exists with `self.call(family)` method
  - [ ] Given a family with face_regions from 2 photos of the same person: groups them into 1 cluster
  - [ ] Given face_regions from 2 different families: does NOT cross-match
  - [ ] Noise points (single-occurrence faces) are left with `person_id: nil`
  - [ ] Re-clustering does not unassign previously named faces
  - [ ] `bin/rubocop app/services/face_clustering_service.rb` passes

  ```
  Scenario: Multi-tenancy isolation
    Tool: Bash
    Steps:
      1. Create two families with face_regions
      2. Run FaceClusteringService.call(family_1)
      3. Assert: only family_1's face_regions are touched
      4. Assert: family_2's face_regions remain unchanged
    Expected Result: Clustering is strictly scoped to the given family
    Failure Indicators: face_regions from family_2 get person_id assignments
    Evidence: .sisyphus/evidence/task-9-multi-tenancy.txt
  ```

  **Commit**: YES
  - Message: `feat(faces): add DBSCAN face clustering service`
  - Files: `app/services/face_clustering_service.rb`

- [ ] 10. PhotoAnalysisJob — orchestrate orientation + face analysis + storage

  **What to do**:
  - Create `app/jobs/photo_analysis_job.rb` inheriting from `ApplicationJob`:
    - `queue_as :default`
    - `def perform(photo_id)`:
      1. Find photo, guard against missing record (`Photo.find_by(id: photo_id)` — return early if nil)
      2. Guard against re-processing: skip if `photo.faces_analyzed_at.present?`
      3. Run OrientationService: `orientation_result = OrientationService.call(photo)`
      4. Run FaceAnalysisClient: `faces = FaceAnalysisClient.call(photo)`
      5. For each face in the response:
         - Create FaceRegion: `photo.face_regions.create!(x: face.bbox[0], y: face.bbox[1], width: face.bbox[2]-face.bbox[0], height: face.bbox[3]-face.bbox[1], confidence: face.confidence, embedding: face.embedding)`
      6. Update photo: `photo.update!(faces_analyzed_at: Time.current, orientation_corrected: orientation_result.corrected)`
    - Wrap everything in a `rescue => e` that logs the error and re-raises (so SolidQueue retries)
    - Add `retry_on StandardError, wait: :polynomially_longer, attempts: 3`

  **Must NOT do**:
  - Do not run clustering in this job — clustering is a separate operation (FaceClusteringService)
  - Do not process photos without an attached image
  - Do not re-process photos that already have `faces_analyzed_at` set
  - Do not crash if sidecar is unavailable — FaceAnalysisClient returns empty array gracefully

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Orchestration of multiple services, error handling, idempotency logic
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (sequential after Task 9)
  - **Blocks**: Task 11
  - **Blocked By**: Tasks 6, 8, 9

  **References**:
  - `app/jobs/application_job.rb` — base class to inherit from
  - `app/services/orientation_service.rb` — OrientationService.call(photo)
  - `app/services/face_analysis_client.rb` — FaceAnalysisClient.call(photo) — returns array of FaceData structs
  - `app/models/photo.rb:69-81` — existing `blob.open` + Vips pattern to follow
  - **WHY**: This job ties the entire ML pipeline together. It runs asynchronously via SolidQueue so uploads aren't blocked. The idempotency guard (`faces_analyzed_at`) prevents duplicate processing.

  **Acceptance Criteria**:
  - [ ] `app/jobs/photo_analysis_job.rb` exists inheriting from ApplicationJob
  - [ ] Given a photo with a face: running the job creates a FaceRegion record
  - [ ] Given a photo already analyzed: job skips without error
  - [ ] Given a photo that causes an error: job logs error and retries
  - [ ] `bin/rubocop app/jobs/photo_analysis_job.rb` passes

  ```
  Scenario: Full pipeline creates face regions
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "
         photo = Photo.create!(family: Family.first, image: ActiveStorage::Blob.create_and_upload!(io: File.open('spec/fixtures/images/one_face.jpg'), filename: 'face.jpg', content_type: 'image/jpeg'))
         PhotoAnalysisJob.perform_now(photo.id)
         photo.reload
         puts \"face_regions:#{photo.face_regions.count} analyzed:#{photo.faces_analyzed_at.present?} corrected:#{photo.orientation_corrected}\"
         "
      2. Assert: face_regions count is 1, analyzed is true
    Expected Result: One face region created, photo marked as analyzed
    Failure Indicators: 0 face_regions, faces_analyzed_at still nil
    Evidence: .sisyphus/evidence/task-10-full-pipeline.txt

  Scenario: Idempotent re-processing
    Tool: Bash
    Steps:
      1. Run PhotoAnalysisJob.perform_now twice on same photo
      2. Assert: face_regions count is still 1 (not doubled)
    Expected Result: Second run is a no-op
    Evidence: .sisyphus/evidence/task-10-idempotent.txt
  ```

  **Commit**: YES
  - Message: `feat(pipeline): add PhotoAnalysisJob orchestrating ML pipeline`
  - Files: `app/jobs/photo_analysis_job.rb`

- [ ] 11. Upload integration + batch processing rake task

  **What to do**:
  - Add `after_commit` callback to Photo model:
    - `after_commit :enqueue_face_analysis, on: :create, if: -> { image.attached? }`
    - `def enqueue_face_analysis; PhotoAnalysisJob.perform_later(id); end`
  - Add `rake ml:analyze_all` task to `lib/tasks/ml.rake`:
    - Finds all photos where `faces_analyzed_at` is nil and image is attached
    - Enqueues `PhotoAnalysisJob` for each, with a small delay between enqueues to avoid overwhelming the worker
    - Prints progress: `"Enqueued 150/500 photos for analysis"`
    - Add `rake ml:recluster[family_id]` task:
      - Runs `FaceClusteringService.call(family)` for a specific family or all families
      - Prints: `"Family 'Smith': 45 faces in 12 clusters, 3 unmatched"`
  - Add `rake ml:status` task:
    - Reports: total photos, analyzed count, unanalyzed count, face_regions count, clusters count

  **Must NOT do**:
  - Do not run jobs synchronously in the rake task — enqueue them for SolidQueue
  - Do not process all photos in a single transaction
  - Do not auto-trigger clustering after analysis — user should run `rake ml:recluster` manually

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (after Task 10)
  - **Blocks**: Task 16
  - **Blocked By**: Task 10

  **References**:
  - `app/models/photo.rb:27` — existing `after_commit :extract_dates_from_sources` callback — follow this exact pattern
  - `lib/tasks/` — existing rake tasks directory — create new `ml.rake` file here
  - `app/services/face_clustering_service.rb` — FaceClusteringService.call(family)
  - **WHY**: The upload hook makes face analysis automatic for new photos. The rake tasks handle existing photos and give operators control over clustering.

  **Acceptance Criteria**:
  - [ ] Creating a new Photo with an image enqueues a PhotoAnalysisJob
  - [ ] `rake ml:analyze_all` enqueues jobs for unanalyzed photos only
  - [ ] `rake ml:recluster` runs clustering for specified family
  - [ ] `rake ml:status` prints analysis statistics
  - [ ] `bin/rubocop app/models/photo.rb lib/tasks/ml.rake` passes

  ```
  Scenario: Upload triggers face analysis job
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "
         photo = Photo.create!(family: Family.first, image: ActiveStorage::Blob.create_and_upload!(io: File.open('spec/fixtures/images/one_face.jpg'), filename: 'upload.jpg', content_type: 'image/jpeg'))
         # Check SolidQueue for enqueued job
         puts \"enqueued:#{SolidQueue::Job.where(class_name: 'PhotoAnalysisJob').count}\"
         "
      2. Assert: enqueued count is >= 1
    Expected Result: PhotoAnalysisJob is enqueued automatically on photo creation
    Evidence: .sisyphus/evidence/task-11-upload-hook.txt

  Scenario: Batch processing rake task
    Tool: Bash
    Steps:
      1. Run: rake ml:status
      2. Assert: output shows photo counts and analysis status
    Expected Result: Status report is printed
    Evidence: .sisyphus/evidence/task-11-status.txt
  ```

  **Commit**: YES
  - Message: `feat(pipeline): integrate face analysis into upload and add batch processing`
  - Files: `app/models/photo.rb`, `lib/tasks/ml.rake`


- [ ] 12. FaceClustersController + routes + index view

  **What to do**:
  - Create `app/controllers/face_clusters_controller.rb`:
    - `before_action :authenticate_user!` (or whatever auth pattern is used)
    - `index` action:
      - Load all People for `current_family` that have face_regions: `current_family.people.joins(:face_regions).distinct.alphabetical`
      - Also load unmatched face_regions: `FaceRegion.unassigned.joins(:photo).where(photos: { family_id: current_family.id })`
      - Group unmatched by visual similarity (just show them in a grid, no grouping needed for prototype)
    - `show` action:
      - Load a specific Person's face_regions with associated photos
    - `update` action:
      - Assign a name (Person) to a cluster (handled in Task 14)
  - Add routes to `config/routes.rb`:
    - `resources :face_clusters, only: [:index, :show, :update]`
  - Create `app/views/face_clusters/index.html.erb`:
    - Page title: "Faces"
    - Grid of named people (card per person with representative face thumbnail + name + face count)
    - Below: grid of unmatched faces (faces without a person_id)
    - Each face thumbnail: crop from the original photo using the bounding box coordinates
    - Use Tabler card components (follow existing UI patterns)
  - For face thumbnails, create a helper or use Active Storage variant with crop:
    - Use the normalized bounding box (x, y, w, h) to define a crop region
    - Generate a thumbnail variant: `photo.image.variant(crop: [x_px, y_px, w_px, h_px], resize_to_fill: [80, 80])`
    - Or render via CSS `object-position` + `object-fit` on the existing thumbnail

  **Must NOT do**:
  - Do not create a separate admin namespace — keep it flat like existing controllers
  - Do not implement drag-and-drop or complex JS interactions
  - Do not draw bounding boxes on photos
  - Do not implement merge/split operations

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI layout with Tabler cards, face thumbnail rendering, responsive grid
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5 (first in sequence)
  - **Blocks**: Tasks 13, 14
  - **Blocked By**: Tasks 3, 9

  **References**:
  - `app/controllers/people_controller.rb` — follow this exact pattern for controller structure, `current_family` scoping, `before_action`
  - `app/views/photos/index.html.erb` — card grid pattern to follow for face cluster layout
  - `app/views/layouts/shared/_sidebar.html.erb` — navigation pattern (add Faces link here in Task 14)
  - `config/routes.rb` — existing route patterns
  - Tabler UI docs: card components, avatar components, grid layout
  - **WHY**: The face clusters page is the primary interface for reviewing and naming detected faces. It should feel like a natural extension of the existing People page.

  **Acceptance Criteria**:
  - [ ] `GET /face_clusters` returns 200
  - [ ] Index page shows named people with face counts
  - [ ] Index page shows unmatched faces
  - [ ] Face thumbnails render (cropped from photos)
  - [ ] Only current family's faces are shown
  - [ ] `bin/rubocop app/controllers/face_clusters_controller.rb` passes

  ```
  Scenario: Face clusters index loads
    Tool: Bash
    Steps:
      1. Run: bundle exec rspec spec/requests/face_clusters_spec.rb (create this spec)
      2. Assert: GET /face_clusters returns 200 with expected content
    Expected Result: Page renders with face cluster data
    Evidence: .sisyphus/evidence/task-12-index-page.txt

  Scenario: Multi-tenancy in UI
    Tool: Bash
    Steps:
      1. Sign in as user from family A
      2. GET /face_clusters
      3. Assert: response body does not contain face data from family B
    Expected Result: Only current family's faces shown
    Evidence: .sisyphus/evidence/task-12-tenancy.txt
  ```

  **Commit**: YES
  - Message: `feat(ui): add face clusters index page`
  - Files: `app/controllers/face_clusters_controller.rb`, `app/views/face_clusters/index.html.erb`, `config/routes.rb`

- [ ] 13. Cluster detail view + person naming/assignment

  **What to do**:
  - Create `app/views/face_clusters/show.html.erb`:
    - Show all face_regions for a Person, displayed as a grid of face thumbnails
    - Show the Person's name (or "Unnamed" if not yet named)
    - Include a simple form to name the cluster:
      - Dropdown of existing People (from `current_family.people`)
      - Or text fields to create a new Person (first_name, last_name)
    - Include an "Exclude" button on each face thumbnail:
      - Sets `face_region.person_id = nil` (removes from this cluster)
      - Simple `DELETE /face_clusters/:id/faces/:face_region_id` or similar
  - Update `FaceClustersController#update`:
    - Accepts `person_id` (assign to existing person) or `person_attributes` (create new)
    - Updates all face_regions in the cluster to point to the selected Person
  - Add a nested route for excluding faces:
    - `resources :face_clusters do; delete :exclude_face, on: :member; end` (or similar)

  **Must NOT do**:
  - Do not implement merge (combining two clusters into one)
  - Do not implement split (dividing a cluster)
  - Do not auto-create `photo_people` records when naming
  - Do not add complex JavaScript interactions — standard form submissions with Turbo

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Form design, Tabler UI components, show page layout
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5 (after Task 12)
  - **Blocks**: Task 16
  - **Blocked By**: Task 12

  **References**:
  - `app/controllers/people_controller.rb:21-36` — create/update pattern for Person records
  - `app/views/people/show.html.erb` — Person show page pattern
  - `app/models/person.rb` — Person attributes: first_name, last_name (required)
  - `app/views/face_clusters/index.html.erb` — created in Task 12 (link to show pages)
  - **WHY**: This is the core interaction: users review a cluster of faces and either name it as an existing Person or create a new one. Excluding a face handles misdetections.

  **Acceptance Criteria**:
  - [ ] `GET /face_clusters/:id` returns 200 showing face thumbnails for that cluster
  - [ ] Submitting a name assigns all face_regions to a Person
  - [ ] Exclude button removes a face_region from the cluster (sets person_id to nil)
  - [ ] `bin/rubocop app/controllers/face_clusters_controller.rb app/views/face_clusters/show.html.erb` passes

  ```
  Scenario: Name a face cluster
    Tool: Bash
    Steps:
      1. Create a Person and face_regions without person_id in the same family
      2. PATCH /face_clusters/:id with person_id
      3. Assert: face_regions now have person_id set
    Expected Result: All face_regions in cluster are assigned to the Person
    Evidence: .sisyphus/evidence/task-13-name-cluster.txt

  Scenario: Exclude a face from cluster
    Tool: Bash
    Steps:
      1. Have a face_region with person_id set
      2. DELETE exclude_face action
      3. Assert: face_region.person_id is now nil
    Expected Result: Face is removed from cluster
    Evidence: .sisyphus/evidence/task-13-exclude-face.txt
  ```

  **Commit**: YES
  - Message: `feat(ui): add cluster detail view with naming and face exclusion`
  - Files: `app/views/face_clusters/show.html.erb`, `app/controllers/face_clusters_controller.rb`, `config/routes.rb`

- [ ] 14. Navigation update + photo detail face tags

  **What to do**:
  - Add "Faces" link to sidebar navigation:
    - In `app/views/layouts/shared/_sidebar.html.erb` (or equivalent nav partial)
    - Add link to `face_clusters_path` with an appropriate Tabler icon (e.g., `ti-users` or `ti-face-id`)
    - Position after "People" link
  - Update photo show/detail view:
    - In `app/views/photos/show.html.erb` (or equivalent):
    - Add a "People in this photo" section below the photo
    - Show face_region thumbnails with Person names (or "Unknown" if unassigned)
    - Link each Person name to their `face_clusters_path(:id)` page
    - Show a badge with the count of detected faces
    - If `faces_analyzed_at` is nil, show a small "Analyzing..." indicator

  **Must NOT do**:
  - Do not draw bounding boxes on the photo image
  - Do not add complex JavaScript for face hovering/highlighting
  - Do not modify the photo edit form

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (can run parallel with Task 13 if needed)
  - **Parallel Group**: Wave 5 (with Tasks 12, 13)
  - **Blocks**: None
  - **Blocked By**: Task 12

  **References**:
  - `app/views/layouts/shared/_sidebar.html.erb` — existing nav links pattern (icon + label + active state)
  - `app/views/photos/show.html.erb` — existing photo detail layout
  - `app/models/photo.rb` — `photo.face_regions` and `photo.people` associations
  - [Tabler Icons](https://tabler.io/icons) — search for face/user icons
  - **WHY**: Users need to discover the Faces feature from navigation and see detected faces when viewing individual photos.

  **Acceptance Criteria**:
  - [ ] Sidebar has a "Faces" link pointing to `/face_clusters`
  - [ ] Photo show page displays detected people with thumbnails
  - [ ] Photo show page shows "Analyzing..." if faces_analyzed_at is nil
  - [ ] `bin/rubocop` passes on all modified view files

  ```
  Scenario: Navigation includes Faces link
    Tool: Bash
    Steps:
      1. Run: bundle exec rails runner "puts Rails.application.routes.url_helpers.face_clusters_path"
      2. Assert: output is /face_clusters
    Expected Result: Route exists and is reachable
    Evidence: .sisyphus/evidence/task-14-navigation.txt
  ```

  **Commit**: YES
  - Message: `feat(ui): add Faces navigation link and photo detail face tags`
  - Files: sidebar partial, `app/views/photos/show.html.erb`


- [ ] 15. Service specs — OrientationService, FaceAnalysisClient, FaceClusteringService

  **What to do**:
  - Create `spec/services/orientation_service_spec.rb`:
    - Test with rotated_exif.jpg fixture → returns corrected: true
    - Test with one_face.jpg (normal) → returns corrected: false
    - Test with non-image file → graceful error handling
  - Create `spec/services/face_analysis_client_spec.rb`:
    - Test with one_face.jpg (sidecar running) -> returns 1 FaceData struct
    - Test with three_faces.jpg -> returns 3 FaceData structs
    - Test with no_faces.jpg -> returns empty array
    - Verify all bounding box coordinates are normalized (0.0-1.0)
    - Verify embedding dimensions are 512
    - Test graceful degradation when sidecar is down -> returns empty array
  - Create `spec/services/face_clustering_service_spec.rb`:
    - Test with known embeddings that should cluster together
    - Test multi-tenancy isolation (families don't cross)
    - Test noise handling (single-occurrence faces remain unassigned)
    - Test re-clustering doesn't unassign named faces
  - All specs should use real image fixtures from `spec/fixtures/images/`
  - Specs requiring the sidecar should skip if it's not running (guard with `before { skip 'ML sidecar not running' unless FaceAnalysisClient.sidecar_available? }`)

  **Must NOT do**:
  - Do not mock the sidecar HTTP calls in integration specs -- test against real sidecar for integration confidence
  - Do not create more than 3 spec files (one per service)
  - Do not add slow specs without the :slow tag

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Writing comprehensive specs across 3 services with real sidecar integration
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 6 (with Task 16)
  - **Blocks**: None
  - **Blocked By**: Tasks 6, 8, 9 (services must exist)

  **References**:
  - `spec/models/person_spec.rb` — existing spec style (RSpec, `describe`/`context`/`it` blocks, FactoryBot)
  - `spec/spec_helper.rb` — RSpec configuration
  - `spec/fixtures/images/` — test image fixtures (from Task 5)
  - Each service file — public API to test against
  - **WHY**: Tests-after strategy per user's choice. These specs validate that the sidecar integration works correctly and that clustering behaves as expected with real images.

  **Acceptance Criteria**:
  - [ ] `bundle exec rspec spec/services/` passes with 0 failures
  - [ ] Each spec file has at least 3 test cases (happy path + edge cases)
  - [ ] Multi-tenancy isolation is explicitly tested in clustering spec
  - [ ] `bin/rubocop spec/services/` passes

  ```
  Scenario: All service specs pass
    Tool: Bash
    Steps:
      1. Run: bundle exec rspec spec/services/ --format documentation
      2. Assert: 0 failures, output shows all test names
    Expected Result: All service specs green
    Evidence: .sisyphus/evidence/task-15-service-specs.txt
  ```

  **Commit**: YES
  - Message: `test(faces): add specs for orientation and face recognition services`
  - Files: `spec/services/orientation_service_spec.rb`, `spec/services/face_analysis_client_spec.rb`, `spec/services/face_clustering_service_spec.rb`

- [ ] 16. Integration + request specs — PhotoAnalysisJob, admin UI, multi-tenancy

  **What to do**:
  - Create `spec/jobs/photo_analysis_job_spec.rb`:
    - Test that job creates face_regions for a photo with faces
    - Test idempotency (running twice doesn't duplicate face_regions)
    - Test graceful handling of missing photo
    - Test that `faces_analyzed_at` is set after processing
  - Create `spec/requests/face_clusters_spec.rb`:
    - Test `GET /face_clusters` returns 200
    - Test index page shows face clusters for current family only
    - Test `GET /face_clusters/:id` returns 200 with face thumbnails
    - Test `PATCH /face_clusters/:id` assigns person_id to face_regions
    - Test exclude face removes person_id
    - Test multi-tenancy: user from family A cannot see family B's clusters
  - Create `spec/models/photo_spec.rb` additions:
    - Test `after_commit` enqueues PhotoAnalysisJob
    - Test `needs_face_analysis` scope
    - Test `face_analyzed?` method
  - Run full suite: `bundle exec rspec`
  - Run linter: `bin/rubocop`

  **Must NOT do**:
  - Do not skip the multi-tenancy test — it's a privacy requirement
  - Do not mock everything — request specs should exercise the full stack

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Integration tests across jobs, controllers, and models
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 6 (with Task 15)
  - **Blocks**: None
  - **Blocked By**: Tasks 10, 13 (job and UI must exist)

  **References**:
  - `spec/models/person_spec.rb` — existing model spec pattern
  - `spec/factories.rb` — existing factories + `:with_real_image` trait (from Task 5)
  - `app/jobs/photo_analysis_job.rb` — job under test
  - `app/controllers/face_clusters_controller.rb` — controller under test
  - **WHY**: Integration specs verify the full pipeline works end-to-end and that multi-tenancy isolation is enforced at the controller level.

  **Acceptance Criteria**:
  - [ ] `bundle exec rspec spec/jobs/ spec/requests/face_clusters_spec.rb` passes with 0 failures
  - [ ] Multi-tenancy isolation test exists and passes
  - [ ] `bundle exec rspec` (full suite) passes with 0 failures
  - [ ] `bin/rubocop` passes with 0 offenses

  ```
  Scenario: Full test suite passes
    Tool: Bash
    Steps:
      1. Run: bundle exec rspec --format documentation
      2. Run: bin/rubocop
      3. Assert: 0 failures, 0 offenses
    Expected Result: Everything green
    Evidence: .sisyphus/evidence/task-16-full-suite.txt
  ```

  **Commit**: YES
  - Message: `test(faces): add integration and request specs for face recognition pipeline`
  - Files: `spec/jobs/photo_analysis_job_spec.rb`, `spec/requests/face_clusters_spec.rb`, `spec/models/photo_spec.rb`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `bin/rubocop` + `bundle exec rspec`. Review all changed files for: `as any`, empty rescues, `puts`/`p` in production code, commented-out code, unused requires. Check AI slop: excessive comments, over-abstraction, generic names (data/result/item/temp). Verify all services follow consistent patterns.
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start dev server. Upload a photo with faces. Verify: orientation is corrected (if EXIF indicates rotation), face detection job runs, face_regions are created, clusters appear in admin UI, naming a cluster assigns a Person. Test edge cases: photo with no faces, re-uploading same photo. Save evidence screenshots.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **T1**: `feat(ml): add neighbor gem and ML sidecar directory scaffold` -- Gemfile, Gemfile.lock, ml_sidecar/
- **T2**: `feat(db): add pgvector extension, face_regions table, and photo analysis fields` -- db/migrate/, db/structure.sql
- **T3**: `feat(models): add FaceRegion model and face analysis associations` -- app/models/
- **T4**: `feat(ml): add Python FastAPI sidecar for InsightFace face analysis` -- ml_sidecar/, docker-compose.ml.yml
- **T5**: `chore(test): add face image fixtures and SolidQueue smoke test` -- spec/fixtures/, app/jobs/smoke_test_job.rb
- **T6**: `feat(orientation): add EXIF auto-orient service via Vips` -- app/services/
- **T7**: No commit (contract doc only)
- **T8**: `feat(faces): add FaceAnalysisClient HTTP client for ML sidecar` -- app/services/
- **T9**: `feat(faces): add DBSCAN face clustering service` -- app/services/
- **T10**: `feat(pipeline): add PhotoAnalysisJob orchestrating ML pipeline` -- app/jobs/
- **T11**: `feat(pipeline): integrate face analysis into upload and add batch processing` -- app/models/photo.rb, lib/tasks/ml.rake
- **T12**: `feat(ui): add face clusters index page` -- app/controllers/, app/views/, config/routes.rb
- **T13**: `feat(ui): add cluster detail view with naming and face exclusion` -- app/views/, app/controllers/, config/routes.rb
- **T14**: `feat(ui): add Faces navigation link and photo detail face tags` -- sidebar partial, app/views/photos/
- **T15**: `test(faces): add specs for orientation and face recognition services` -- spec/services/
- **T16**: `test(faces): add integration and request specs for face recognition pipeline` -- spec/jobs/, spec/requests/

---

## Success Criteria

### Verification Commands
```bash
bundle exec rspec                    # Expected: 0 failures
bin/rubocop                          # Expected: 0 offenses
bundle exec rails runner "ActiveRecord::Base.connection.execute(\"SELECT '[1,2,3]'::vector\")"  # Expected: no error
bundle exec rails runner "FaceRegion.new.respond_to?(:embedding)"  # Expected: true
bundle exec rails runner "FaceRegion.new.respond_to?(:nearest_neighbors)"  # Expected: true
curl http://localhost:8100/health      # Expected: {"status": "ok"}
rake ml:analyze_all                  # Expected: enqueues jobs, processes photos, creates face_regions
rake ml:status                       # Expected: prints analysis statistics
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass
- [ ] ML sidecar running and healthy (`curl http://localhost:8100/health`)
- [ ] Face detection returns bounding boxes for test images
- [ ] Embeddings stored as 512-d vectors in pgvector
- [ ] Clusters group similar faces within same family
- [ ] Admin UI shows clusters and allows naming
- [ ] Upload triggers async face analysis
- [ ] Multi-tenancy isolation verified (no cross-family face matching)
