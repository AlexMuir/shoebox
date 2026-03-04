# Location Autocomplete with Google Places Integration

## TL;DR

> **Quick Summary**: Build a combined location autocomplete that shows existing DB locations instantly, then Google Places results underneath. When a user selects a Google Place, auto-create the location with its parent hierarchy chain (country > city > place). Replace all 3 location dropdowns in the app with this new autocomplete.
>
> **Deliverables**:
> - `GooglePlacesService` — server-side proxy to Google Places API (New) for autocomplete + place details
> - `LocationHierarchyService` — builds ancestry parent chain from Google address_components
> - `LocationsController#search` — JSON endpoint returning local + Google results
> - `location_autocomplete_controller.js` — Stimulus controller with two-section dropdown, session tokens
> - `_location_autocomplete.html.erb` — reusable partial replacing all location dropdowns
> - DB migration adding `google_place_id` column for deduplication
> - Location#show updated to display photos from all descendant locations
> - Full TDD spec coverage for services, controller endpoint, and hierarchy logic
>
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 4 waves + final verification
> **Critical Path**: Task 1 (migration) → Task 3 (GooglePlacesService) → Task 6 (Controller#search) → Task 8 (Replace dropdowns)

---

## Context

### Original Request
User wants a combined autocomplete for tagging photos with locations. Local DB locations appear first (instant), Google Places results appear below. Locations form a hierarchy — selecting "Mombasa, Kenya" should auto-create Kenya as a parent and nest Mombasa under it. Browsing "photos in Africa" should include all descendant location photos. The autocomplete should replace all existing location dropdowns in the app.

### Interview Summary
**Key Discussions**:
- **External provider**: Google Places API (New) chosen over Nominatim for higher quality results
- **Hierarchy approach**: Ancestry gem tree traversal (already in use) — no PostGIS needed at this scale
- **Auto-hierarchy**: When selecting a Google Place, auto-create the parent chain (country > city > address) using `find_or_create_by` with `google_place_id` for deduplication
- **Hierarchy depth**: Smart defaults — countries stand alone, cities nest under country, addresses nest under city. Adapts to what Google provides.
- **Naming**: Auto-name from Google's display name, user can rename later via edit page
- **Scope**: Replace ALL location dropdowns — photo form, event form, location form parent selector
- **Testing**: TDD approach with RSpec + FactoryBot + WebMock

**Research Findings**:
- **PersonAutocomplete pattern exists**: Stimulus controller (179 lines), `PeopleController#search` (JSON endpoint), `_person_autocomplete.html.erb` partial — this is the exact template to follow
- **Location model**: `has_ancestry`, `geocoded_by :full_address`, lat/lng fields exist, geocoder callback commented out
- **No PostGIS**: PostgreSQL with btree_gist, pg_trgm, vector extensions. Ancestry tree traversal is sufficient.
- **Ancestry gem 5.0.0**: Materialized path, supports `.descendants`, `.subtree`, `.path` for hierarchy queries
- **Google Places API (New)**: POST autocomplete, GET place details with FieldMask, session tokens for billing
- **No existing service objects**: No `app/services/` directory — this establishes the convention
- **No HTTP stubbing**: No WebMock/VCR in project — must add for TDD

### Metis Review
**Identified Gaps** (all addressed):
- **Deduplication risk**: No uniqueness constraint on locations. Resolved by adding `google_place_id` column with partial unique index
- **Race condition**: Concurrent parent chain creation could create duplicates. Resolved with `find_or_create_by!` + database-level unique index + `ActiveRecord::RecordNotUnique` rescue
- **No test stubbing**: No WebMock gem. Resolved by adding to test group in Gemfile
- **Parent selector UX**: Location form parent field should be local-only (no Google results). Resolved with `localOnly` Stimulus value
- **API key missing in dev**: Must gracefully degrade. Resolved by returning local-only results when key absent, logging warning
- **Google API inconsistency**: Address components vary by place type. Resolved with smart parsing that handles variable-depth hierarchies
- **Legacy locations**: Existing locations lack `google_place_id`. Local search uses ILIKE on name (like PeopleController#search), not dependent on `google_place_id`

---

## Work Objectives

### Core Objective
Build a combined autocomplete system for location selection that merges instant local DB results with Google Places API suggestions, auto-creates hierarchical location chains from Google data, and replaces all existing location dropdowns in the application.

### Concrete Deliverables
- `db/migrate/xxx_add_google_place_id_to_locations.rb` — migration
- `app/services/google_places_service.rb` — Google Places API proxy
- `app/services/location_hierarchy_service.rb` — parent chain builder
- `app/controllers/locations_controller.rb` — enhanced with `search` action
- `app/javascript/controllers/location_autocomplete_controller.js` — Stimulus controller
- `app/views/shared/_location_autocomplete.html.erb` — reusable partial
- `app/views/photos/_form.html.erb` — dropdown replaced with autocomplete
- `app/views/events/_form.html.erb` — dropdown replaced with autocomplete
- `app/views/locations/_form.html.erb` — parent dropdown replaced with local-only autocomplete
- `app/views/locations/show.html.erb` — show descendant photos
- `spec/services/google_places_service_spec.rb` — service specs
- `spec/services/location_hierarchy_service_spec.rb` — hierarchy specs
- `spec/requests/locations_search_spec.rb` — request specs

### Definition of Done
- [x] `bundle exec rspec` passes with 0 failures
- [x] `bin/rubocop` passes with 0 offenses
- [x] `grep -r "f.association :location" app/views/` returns 0 results
- [x] `grep -r "f.association :parent" app/views/locations/` returns 0 results
- [x] `grep -r "location_autocomplete" app/views/` returns 3 results

### Must Have
- Local results appear in autocomplete dropdown, sourced from family's existing locations
- Google Places results appear in separate section below local results
- Selecting a Google Place auto-creates the location + parent chain with correct ancestry
- Duplicate locations prevented via `google_place_id` matching
- Session tokens passed through to Google for billing optimization
- Location form parent selector is local-only (no Google results)
- All 3 location dropdowns replaced with autocomplete
- Location#show page includes photos from descendant locations
- Graceful degradation when Google API key is missing (local-only mode)
- All queries scoped to `current_family`

### Must NOT Have (Guardrails)
- NO PostGIS extension, rgeo, or activerecord-postgis-adapter
- NO map/visualization (no Leaflet, no Google Maps JS widget)
- NO reverse geocoding from photo EXIF GPS data
- NO location merge/deduplication UI
- NO backfilling lat/lng for existing locations from Google
- NO address validation for manually entered locations
- NO changes to existing location CRUD actions (create, edit, update, destroy behavior unchanged)
- NO changes to location index view layout
- NO modifications to geocoder gem configuration or callbacks
- NO modifications to ancestry gem configuration or orphan strategy
- NO excessive comments, JSDoc, or over-abstraction — match existing codebase terseness
- NO `google-apis-places_v1` gem — use `Net::HTTP` (stdlib) for Google API calls
- NO new JS dependencies — vanilla Stimulus, match existing controller patterns exactly

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (RSpec + FactoryBot configured)
- **Automated tests**: TDD (RED → GREEN → REFACTOR)
- **Framework**: RSpec with FactoryBot + WebMock
- **Each task**: Write failing spec first, then implement to make it pass

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Backend/API**: Use Bash (curl/rspec) — Send requests, assert status + response fields
- **Frontend/UI**: Use Playwright (playwright skill) — Navigate, interact, assert DOM, screenshot
- **Services**: Use Bash (rspec) — Run specific spec files, verify pass counts

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — foundation, all independent):
├── Task 1: Migration + gems (google_place_id, webmock, bundle) [quick]
├── Task 2: Route + infrastructure (search route, app/services/ dir) [quick]

Wave 2 (After Wave 1 — core services + frontend, MAX PARALLEL):
├── Task 3: GooglePlacesService TDD (depends: 1) [deep]
├── Task 4: LocationHierarchyService TDD (depends: 1) [deep]
├── Task 5: Stimulus controller (depends: none, frontend-only) [unspecified-high]

Wave 3 (After Wave 2 — controller + partial):
├── Task 6: LocationsController#search TDD (depends: 2, 3, 4) [deep]
├── Task 7: Autocomplete partial + registration (depends: 5) [quick]

Wave 4 (After Wave 3 — integration + polish):
├── Task 8: Replace all 3 dropdowns + Location#show descendants (depends: 6, 7) [unspecified-high]
├── Task 9: Edge cases + graceful degradation (depends: 6) [unspecified-high]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Real manual QA [unspecified-high]
├── Task F4: Scope fidelity check [deep]

Critical Path: Task 1 → Task 3 → Task 6 → Task 8 → F1-F4
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 3 (Wave 2)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 3, 4 | 1 |
| 2 | — | 6 | 1 |
| 3 | 1 | 6 | 2 |
| 4 | 1 | 6 | 2 |
| 5 | — | 7 | 2 |
| 6 | 2, 3, 4 | 8, 9 | 3 |
| 7 | 5 | 8 | 3 |
| 8 | 6, 7 | F1-F4 | 4 |
| 9 | 6 | F1-F4 | 4 |

### Agent Dispatch Summary

- **Wave 1**: 2 tasks — T1 → `quick`, T2 → `quick`
- **Wave 2**: 3 tasks — T3 → `deep`, T4 → `deep`, T5 → `unspecified-high`
- **Wave 3**: 2 tasks — T6 → `deep`, T7 → `quick`
- **Wave 4**: 2 tasks — T8 → `unspecified-high`, T9 → `unspecified-high`
- **FINAL**: 4 tasks — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs


- [x] 1. Migration: Add google_place_id column + WebMock gem

  **What to do**:
  - Add `webmock` gem to `:test` group in Gemfile, run `bundle install`
  - Configure WebMock in `spec/rails_helper.rb`: `require 'webmock/rspec'` and `WebMock.disable_net_connect!(allow_localhost: true)`
  - Generate migration: `add_google_place_id_to_locations`
    - Add `google_place_id` column (string, nullable) to locations table
    - Add partial unique index on `[:family_id, :google_place_id]` WHERE `google_place_id IS NOT NULL`
  - Run `bin/rails db:migrate`
  - Verify `db/structure.sql` updated with new column and index

  **Must NOT do**:
  - Do NOT add any other columns (no `place_types`, no `formatted_address`)
  - Do NOT modify existing columns or indexes
  - Do NOT change the Location model yet (no validations, no new attributes)
  - Do NOT add `google-apis-places_v1` gem

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single migration + Gemfile change, straightforward Rails task
  - **Skills**: []
    - No special skills needed for migration work

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Tasks 3, 4 (services need the column + webmock)
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `db/migrate/20260228215718_create_locations.rb` — Migration style for this project
  - `db/structure.sql:357-372` — Current locations table schema to understand existing columns
  - `Gemfile:38` — Where geocoder gem is listed (add webmock nearby in test group)

  **API/Type References**:
  - `app/models/location.rb` — Current Location model (do NOT modify in this task)

  **Test References**:
  - `spec/rails_helper.rb` — Where to add WebMock configuration

  **WHY Each Reference Matters**:
  - The migration file shows the project's migration style (no annotations, standard Rails format)
  - The structure.sql shows the exact current schema so you know what column types and indexes exist
  - The rails_helper shows where to add test configuration (WebMock require + disable_net_connect)

  **Acceptance Criteria**:

  **TDD**: N/A (migration task, no business logic to test)

  - [x] Migration file exists and runs: `bin/rails db:migrate` succeeds
  - [x] `db/structure.sql` contains `google_place_id character varying` in locations table
  - [x] `db/structure.sql` contains partial unique index on `family_id, google_place_id`
  - [x] `bundle exec rspec` still passes (no regressions)
  - [x] `bin/rubocop` still passes
  - [x] WebMock is required in rails_helper and `disable_net_connect!` is configured

  **QA Scenarios:**

  ```
  Scenario: Migration adds google_place_id column
    Tool: Bash
    Preconditions: Database is migrated to current state
    Steps:
      1. Run: bin/rails db:migrate
      2. Run: bin/rails runner "puts Location.column_names.include?('google_place_id')"
      3. Run: bin/rails runner "puts Location.new(google_place_id: 'test').respond_to?(:google_place_id)"
    Expected Result: Step 1 exits 0, Steps 2-3 both print 'true'
    Failure Indicators: Migration error, column not found, ActiveRecord error
    Evidence: .sisyphus/evidence/task-1-migration.txt

  Scenario: Partial unique index prevents duplicate google_place_id within family
    Tool: Bash
    Preconditions: Migration has run
    Steps:
      1. Run: bin/rails runner "f = Family.first; l1 = f.locations.create!(name: 'Test', google_place_id: 'abc123'); begin; f.locations.create!(name: 'Test2', google_place_id: 'abc123'); rescue ActiveRecord::RecordNotUnique => e; puts 'UNIQUE_VIOLATION'; end"
    Expected Result: Prints 'UNIQUE_VIOLATION'
    Failure Indicators: Second record created without error
    Evidence: .sisyphus/evidence/task-1-unique-index.txt

  Scenario: WebMock configured correctly
    Tool: Bash
    Preconditions: Gemfile updated and bundled
    Steps:
      1. Run: bundle exec ruby -e "require 'webmock'; puts 'webmock loaded'"
      2. Run: grep -c 'webmock/rspec' spec/rails_helper.rb
    Expected Result: Step 1 prints 'webmock loaded', Step 2 prints '1'
    Failure Indicators: LoadError, grep returns 0
    Evidence: .sisyphus/evidence/task-1-webmock.txt
  ```

  **Commit**: YES
  - Message: `feat(locations): add google_place_id column and webmock for testing`
  - Files: `db/migrate/xxx_add_google_place_id_to_locations.rb`, `db/structure.sql`, `Gemfile`, `Gemfile.lock`, `spec/rails_helper.rb`
  - Pre-commit: `bundle exec rspec && bin/rubocop`

- [x] 2. Route + Infrastructure Setup

  **What to do**:
  - Add `search` collection route to locations resources in `config/routes.rb`
    - Change `resources :locations` to `resources :locations do collection do get :search end end`
    - Follow the exact pattern from people routes (line 18-22)
  - Create `app/services/` directory (this is the first service object in the project)
  - Create `app/services/application_service.rb` with a minimal base class:
    ```ruby
    class ApplicationService
      def self.call(...)
        new(...).call
      end
    end
    ```
  - Document Google API key credential path: the key should be stored at `Rails.application.credentials.dig(:google, :places_api_key)`

  **Must NOT do**:
  - Do NOT implement any controller actions yet
  - Do NOT add any service logic — just the base class and directory
  - Do NOT modify any existing routes

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Trivial file creation + single route addition
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Task 6 (controller needs the route)
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `config/routes.rb:18-22` — People search route pattern to follow exactly:
    ```ruby
    resources :people do
      collection do
        get :search
      end
    end
    ```
  - `config/routes.rb:24` — Current locations route to modify: `resources :locations`

  **WHY Each Reference Matters**:
  - The people routes block shows exactly how to add a collection search action — follow this pattern for locations
  - Line 24 is the exact line to modify to add the collection block

  **Acceptance Criteria**:

  **TDD**: N/A (infrastructure task)

  - [x] `bin/rails routes | grep location` shows `search_locations GET /locations/search(.:format) locations#search`
  - [x] `app/services/application_service.rb` exists with `self.call` class method
  - [x] `bin/rubocop` passes

  **QA Scenarios:**

  ```
  Scenario: Search route exists
    Tool: Bash
    Preconditions: Routes file updated
    Steps:
      1. Run: bin/rails routes -g location
    Expected Result: Output includes 'search_locations GET /locations/search(.:format) locations#search'
    Failure Indicators: Route not found, routing error
    Evidence: .sisyphus/evidence/task-2-routes.txt

  Scenario: Services directory and base class
    Tool: Bash
    Preconditions: Files created
    Steps:
      1. Run: test -f app/services/application_service.rb && echo 'EXISTS'
      2. Run: bin/rails runner "puts ApplicationService.respond_to?(:call)"
    Expected Result: Step 1 prints 'EXISTS', Step 2 prints 'true'
    Failure Indicators: File missing, LoadError, method not found
    Evidence: .sisyphus/evidence/task-2-services.txt
  ```

  **Commit**: YES (groups with Task 1)
  - Message: `chore(locations): add search route and services directory`
  - Files: `config/routes.rb`, `app/services/application_service.rb`
  - Pre-commit: `bin/rubocop`


- [x] 3. GooglePlacesService (TDD)

  **What to do**:
  - RED: Write `spec/services/google_places_service_spec.rb` first with WebMock stubs:
    - Test `autocomplete(query, session_token)`: stubs POST to Google autocomplete endpoint, returns parsed suggestions array `[{place_id:, description:, structured_name:}]`
    - Test `place_details(place_id, session_token)`: stubs GET to Google place details endpoint, returns parsed hash `{place_id:, name:, lat:, lng:, address_components:, formatted_address:}`
    - Test error handling: timeout returns empty array, 4xx/5xx returns empty array with Rails.logger.error
    - Test missing API key: returns empty array immediately without making HTTP call, logs warning
  - GREEN: Implement `app/services/google_places_service.rb`:
    - Inherits from `ApplicationService`
    - Uses `Net::HTTP` (stdlib) for all HTTP calls — NO external HTTP gems
    - `autocomplete(query, session_token)` method:
      - POST to `https://places.googleapis.com/v1/places:autocomplete`
      - Headers: `X-Goog-Api-Key`, `Content-Type: application/json`
      - Body: `{ input: query, sessionToken: session_token }`
      - Parse `response['suggestions']` array, extract `placePrediction.placeId` and `placePrediction.text.text`
      - Return array of hashes: `[{ place_id: '...', description: '...' }]`
    - `place_details(place_id, session_token)` method:
      - GET to `https://places.googleapis.com/v1/places/#{place_id}`
      - Headers: `X-Goog-Api-Key`, `X-Goog-FieldMask: id,displayName,formattedAddress,location,addressComponents`
      - Query param: `sessionToken=#{session_token}`
      - Parse response into structured hash with lat, lng, address_components, display name
      - Return hash: `{ place_id:, name:, lat:, lng:, address_components: [...], formatted_address: }`
    - API key from `Rails.application.credentials.dig(:google, :places_api_key)`
    - 3-second timeout on all HTTP calls
    - All errors rescued and logged, return empty result (never raise to caller)
  - REFACTOR: Extract HTTP helper method for shared header/timeout logic

  **Must NOT do**:
  - Do NOT add any HTTP client gems (no Faraday, no HTTParty) — use Net::HTTP only
  - Do NOT add `google-apis-places_v1` gem
  - Do NOT call this service from any controller yet (that is Task 6)
  - Do NOT create locations from Google data (that is Task 4)
  - Do NOT cache responses (premature optimization)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: TDD workflow with external API stubbing, Net::HTTP usage, multiple methods with error handling
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed — this is a backend service, no browser interaction

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5)
  - **Blocks**: Task 6 (controller uses this service)
  - **Blocked By**: Task 1 (needs webmock configured)

  **References**:

  **Pattern References**:
  - `app/services/application_service.rb` — Base class created in Task 2, inherit from this
  - `app/controllers/people_controller.rb:8-14` — Shows the JSON response shape pattern (simple hashes)

  **API/Type References**:
  - Google Places Autocomplete (New): `POST https://places.googleapis.com/v1/places:autocomplete`
    - Request body: `{ input: string, sessionToken: string }`
    - Response: `{ suggestions: [{ placePrediction: { placeId: string, text: { text: string } } }] }`
  - Google Place Details (New): `GET https://places.googleapis.com/v1/places/{placeId}`
    - Required header: `X-Goog-FieldMask: id,displayName,formattedAddress,location,addressComponents`
    - Response: `{ id: string, displayName: { text: string }, formattedAddress: string, location: { latitude: float, longitude: float }, addressComponents: [{ longText: string, shortText: string, types: [string] }] }`

  **Test References**:
  - `spec/rails_helper.rb` — WebMock is configured here (from Task 1)
  - `spec/factories.rb` — If factories are needed for test data

  **External References**:
  - Google Places API Autocomplete docs: https://developers.google.com/maps/documentation/places/web-service/place-autocomplete
  - Google Place Details docs: https://developers.google.com/maps/documentation/places/web-service/place-details

  **WHY Each Reference Matters**:
  - ApplicationService base class provides the `self.call` pattern
  - People controller search shows the JSON response shape to match (simple array of hashes)
  - Google API docs define exact request/response formats — field names are camelCase (placeId, displayName, longText)

  **Acceptance Criteria**:

  **TDD (RED then GREEN):**
  - [x] `spec/services/google_places_service_spec.rb` exists with tests for autocomplete, place_details, error handling, missing API key
  - [x] `bundle exec rspec spec/services/google_places_service_spec.rb` → ALL PASS, 0 failures
  - [x] Service uses Net::HTTP only (no external HTTP gems)
  - [x] `bin/rubocop app/services/google_places_service.rb` → 0 offenses

  **QA Scenarios:**

  ```
  Scenario: Service returns autocomplete suggestions
    Tool: Bash
    Preconditions: WebMock configured, API key in credentials
    Steps:
      1. Run: bundle exec rspec spec/services/google_places_service_spec.rb --format documentation
    Expected Result: All examples pass. Output includes 'autocomplete' and 'place_details' describe blocks
    Failure Indicators: Any failures or pending specs
    Evidence: .sisyphus/evidence/task-3-rspec.txt

  Scenario: Service gracefully handles missing API key
    Tool: Bash
    Preconditions: Tests written with WebMock
    Steps:
      1. Run: bundle exec rspec spec/services/google_places_service_spec.rb -e 'missing API key'
    Expected Result: Test passes, service returns empty array without making HTTP call
    Failure Indicators: Test failure, HTTP call attempted without key
    Evidence: .sisyphus/evidence/task-3-missing-key.txt
  ```

  **Commit**: YES (groups with Task 4)
  - Message: `feat(locations): add Google Places and hierarchy services with TDD specs`
  - Files: `app/services/google_places_service.rb`, `spec/services/google_places_service_spec.rb`
  - Pre-commit: `bundle exec rspec spec/services/ && bin/rubocop`

- [x] 4. LocationHierarchyService (TDD)

  **What to do**:
  - RED: Write `spec/services/location_hierarchy_service_spec.rb` first:
    - Test `create_from_google_place(family, place_details)`: given place details hash (from GooglePlacesService), creates location with correct attributes and ancestry
    - Test parent chain creation: given address_components containing `country: 'Kenya'` and `locality: 'Mombasa'`, creates Kenya as root, Mombasa as child of Kenya
    - Test smart depth: country-only place creates single root location. City creates country parent + city child. Address creates country > city > address (3 levels max)
    - Test deduplication: if Kenya (with matching google_place_id) already exists in family, reuse it as parent (don't create duplicate)
    - Test concurrent creation: if `ActiveRecord::RecordNotUnique` raised during find_or_create_by, rescue and retry find
    - Test family scoping: locations only matched/created within the given family
  - GREEN: Implement `app/services/location_hierarchy_service.rb`:
    - Inherits from `ApplicationService`
    - Main method: `call(family, place_details)` returns the leaf Location record
    - Parse `place_details[:address_components]` array:
      - Extract components by type: `country`, `administrative_area_level_1`, `locality`, `sublocality`, `route`
      - Build hierarchy from broadest (country) to most specific
    - For each **parent** level in the hierarchy (country, city):
      - `family.locations.find_or_create_by!(name: component_name, parent: parent_location)` — NOTE: Google `addressComponents` do NOT include per-component `placeId`, so parent dedup uses name+parent combo, NOT google_place_id
      - If `ActiveRecord::RecordNotUnique` raised, retry with `find_by` (concurrent creation recovery)
    - For the **leaf** location (the actual selected place):
      - Use `google_place_id` from the top-level place response for dedup: `family.locations.find_or_create_by!(google_place_id: place_details[:place_id]) do |loc| ... end`
    - Populate leaf location with full address fields: address_line_1, city, region, postal_code, country, lat, lng, google_place_id
    - Wrap the entire chain creation in a transaction
  - REFACTOR: Extract address component parsing into a private method

  **Must NOT do**:
  - Do NOT call GooglePlacesService from this service — it receives pre-fetched place_details as input
  - Do NOT modify existing locations (only create new ones or find existing)
  - Do NOT touch the geocoder configuration
  - Do NOT add continent-level locations (Africa, Europe, etc.) — hierarchy starts at country level from Google data

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex business logic with hierarchy building, dedup, concurrency handling, transaction wrapping
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 5)
  - **Blocks**: Task 6 (controller calls this after Google selection)
  - **Blocked By**: Task 1 (needs google_place_id column)

  **References**:

  **Pattern References**:
  - `app/models/location.rb:1-18` — Location model: `has_ancestry`, `belongs_to :family`, validates name presence. Know the full model before creating locations
  - `app/services/application_service.rb` — Base class to inherit from (created in Task 2)

  **API/Type References**:
  - Google addressComponents format (from Task 3 reference):
    ```json
    { "longText": "Kenya", "shortText": "KE", "types": ["country", "political"] }
    { "longText": "Mombasa", "shortText": "Mombasa", "types": ["locality", "political"] }
    ```
  - `db/structure.sql:357-372` — Locations table schema: name (required), address_line_1/2, city, region, postal_code, country, latitude, longitude, ancestry

  **Test References**:
  - `spec/factories.rb` — Location factory for test data: `factory :location do name { 'Test Location' }; family; end`

  **WHY Each Reference Matters**:
  - Location model shows validations (only name required) and ancestry setup — important for knowing what fields must be set
  - Google addressComponents format defines the exact input this service receives
  - Schema shows all available fields to populate
  - Location factory provides test data creation pattern

  **Acceptance Criteria**:

  **TDD (RED then GREEN):**
  - [x] `spec/services/location_hierarchy_service_spec.rb` exists with tests for chain creation, dedup, concurrent creation, family scoping
  - [x] `bundle exec rspec spec/services/location_hierarchy_service_spec.rb` → ALL PASS, 0 failures
  - [x] Service creates correct ancestry chain (parent_id relationships verified)
  - [x] `bin/rubocop app/services/location_hierarchy_service.rb` → 0 offenses

  **QA Scenarios:**

  ```
  Scenario: Creates country > city hierarchy from Google Place
    Tool: Bash
    Preconditions: Migration run, factories available
    Steps:
      1. Run: bundle exec rspec spec/services/location_hierarchy_service_spec.rb -e 'creates parent chain' --format documentation
    Expected Result: All examples pass. Kenya created as root, Mombasa as child of Kenya
    Failure Indicators: Wrong ancestry, missing parent, duplicate creation
    Evidence: .sisyphus/evidence/task-4-hierarchy.txt

  Scenario: Deduplicates existing locations by google_place_id
    Tool: Bash
    Preconditions: Family with existing Kenya location (with google_place_id)
    Steps:
      1. Run: bundle exec rspec spec/services/location_hierarchy_service_spec.rb -e 'dedup' --format documentation
    Expected Result: Reuses existing Kenya, creates only Mombasa as new child
    Failure Indicators: Duplicate Kenya created, RecordNotUnique error unhandled
    Evidence: .sisyphus/evidence/task-4-dedup.txt
  ```

  **Commit**: YES (groups with Task 3)
  - Message: `feat(locations): add Google Places and hierarchy services with TDD specs`
  - Files: `app/services/location_hierarchy_service.rb`, `spec/services/location_hierarchy_service_spec.rb`
  - Pre-commit: `bundle exec rspec spec/services/ && bin/rubocop`


- [x] 5. Location Autocomplete Stimulus Controller

  **What to do**:
  - Create `app/javascript/controllers/location_autocomplete_controller.js` modeled on `person_autocomplete_controller.js`
  - Stimulus values:
    - `searchUrl` (String): URL for the search endpoint (`/locations/search`)
    - `createUrl` (String): URL for create-from-google endpoint (`/locations/create_from_google`) — must match the `create_from_google` action defined in Task 6
    - `localOnly` (Boolean, default false): When true, skip Google Places section (for parent selector)
  - Stimulus targets: `input`, `hidden`, `results`, `createForm`
  - Behavior:
    - On input (with 250ms debounce, min 2 chars): fetch `GET {searchUrl}?q={query}&session_token={token}`
    - Generate session token (`crypto.randomUUID()`) on `connect()`, store as instance property
    - Render results in dropdown with TWO sections:
      - **Existing Locations** header: local results from DB (each with `data-location-id` and `data-action='click->location-autocomplete#selectLocal'`)
      - **Google Places** header (hidden when `localOnly` is true): Google results (each with `data-place-id` and `data-action='click->location-autocomplete#selectGoogle'`)
      - Show divider between sections
      - If local results empty, show 'No matching locations' under Existing header
      - If Google results empty (or loading), show spinner or 'Searching...'
    - `selectLocal(event)`: Set hidden field to location ID, input to location name, close dropdown
    - `selectGoogle(event)`: POST to `{createUrl}` with `{ place_id: ..., session_token: ... }` format JSON. On success, set hidden field to new location ID, input to location name, close dropdown. On error, show error message in dropdown. Generate new session token after selection.
    - Handle Escape key to close, outside click to close (match person autocomplete pattern exactly)
    - CSRF token handling for POST requests (match person autocomplete pattern)
  - Register in `app/javascript/controllers/index.js`:
    - `import LocationAutocompleteController from './location_autocomplete_controller'`
    - `application.register('location-autocomplete', LocationAutocompleteController)`

  **Must NOT do**:
  - Do NOT add any npm packages or JS dependencies
  - Do NOT use semicolons in JS (match existing codebase style)
  - Do NOT add keyboard navigation beyond Escape (keep simple like person autocomplete)
  - Do NOT call Google Places API directly from the browser — all calls go through Rails proxy
  - Do NOT add loading spinners or complex UI states beyond what person autocomplete has

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Substantial JS controller with two-section rendering, two selection flows, session token management
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed for building the controller (Task F3 will use it for QA)
    - `frontend-ui-ux`: Not needed — we are copying existing pattern, not designing new UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4)
  - **Blocks**: Task 7 (partial needs the controller)
  - **Blocked By**: None (frontend-only, no backend dependency)

  **References**:

  **Pattern References** (CRITICAL — copy this pattern closely):
  - `app/javascript/controllers/person_autocomplete_controller.js:1-179` — THE template. Copy structure exactly:
    - Line 4: targets and values declarations
    - Lines 10-17: connect/disconnect with outside click handler
    - Lines 25-35: onInput with debounce pattern (250ms, min 2 chars)
    - Lines 37-47: async search with fetch + JSON parsing
    - Lines 49-66: showResults rendering dropdown HTML
    - Lines 73-79: select handler setting hidden field + input value
    - Lines 168-172: handleOutsideClick arrow function
    - Lines 174-178: escapeHtml helper
  - `app/javascript/controllers/index.js:1-7` — How controllers are registered (import + application.register pattern)

  **WHY Each Reference Matters**:
  - Person autocomplete is the EXACT pattern to follow. The location autocomplete should feel identical in behavior — same debounce, same dropdown style, same keyboard handling. The differences are: two-section results (local + Google), two selection flows (selectLocal vs selectGoogle), session token management, and localOnly mode.

  **Acceptance Criteria**:

  **TDD**: N/A (Stimulus controller, no JS test infrastructure)

  - [x] `app/javascript/controllers/location_autocomplete_controller.js` exists
  - [x] Controller registered in `app/javascript/controllers/index.js`
  - [x] Controller has `searchUrl`, `createUrl`, `localOnly` values
  - [x] Controller has `input`, `hidden`, `results` targets
  - [x] No semicolons in JS file
  - [x] `bin/rubocop` passes (no Ruby changes but verify no regressions)

  **QA Scenarios:**

  ```
  Scenario: Controller file exists and is syntactically valid
    Tool: Bash
    Preconditions: File created
    Steps:
      1. Run: node -c app/javascript/controllers/location_autocomplete_controller.js
      2. Run: grep -c 'location-autocomplete' app/javascript/controllers/index.js
    Expected Result: Step 1 exits 0 (valid syntax), Step 2 prints '1' or more
    Failure Indicators: Syntax error, controller not registered
    Evidence: .sisyphus/evidence/task-5-js-valid.txt

  Scenario: Controller follows codebase style (no semicolons)
    Tool: Bash
    Preconditions: File created
    Steps:
      1. Run: grep -cP ';\s*$' app/javascript/controllers/location_autocomplete_controller.js || echo '0'
    Expected Result: Prints '0' (no lines ending with semicolons)
    Failure Indicators: Non-zero count of semicolons
    Evidence: .sisyphus/evidence/task-5-no-semicolons.txt
  ```

  **Commit**: YES (groups with Task 7)
  - Message: `feat(locations): add location autocomplete Stimulus controller and partial`
  - Files: `app/javascript/controllers/location_autocomplete_controller.js`, `app/javascript/controllers/index.js`
  - Pre-commit: `node -c app/javascript/controllers/location_autocomplete_controller.js`

- [x] 6. LocationsController#search Endpoint (TDD)

  **What to do**:
  - RED: Write `spec/requests/locations_search_spec.rb` first:
    - Test local-only search: GET `/locations/search?q=Kenya` returns matching family locations as JSON
    - Test combined search: GET `/locations/search?q=Mombasa&session_token=abc` returns both `local` and `google` sections
    - Test family scoping: locations from other families NOT returned
    - Test authentication required: unauthenticated request redirected
    - Test empty query: returns empty results
    - Test short query (1 char): returns empty results (min 2 chars)
    - Test Google API failure: returns local results with empty google array
    - Stub GooglePlacesService in specs (do not stub HTTP — stub the service class)
  - GREEN: Add `search` action to `LocationsController`:
    - `def search`:
      - Return empty JSON if `params[:q]` blank or length < 2
      - Local search: `current_family.locations.where('name ILIKE :q', q: "%#{params[:q]}%").alphabetical.limit(5)`
      - Google search: `GooglePlacesService.new.autocomplete(params[:q], params[:session_token])` (skip if no API key configured)
      - Return JSON: `{ local: [{id:, name:, parent_name:}], google: [{place_id:, description:}] }`
      - For local results, include `parent_name` (parent location name if exists) for display context
    - Add `create_from_google` action (POST) for when user selects a Google Place:
      - Receives `{ place_id:, session_token: }` as JSON body
      - Calls `GooglePlacesService.new.place_details(place_id, session_token)` to fetch full place data
      - Calls `LocationHierarchyService.call(current_family, place_details)` to create location + parent chain
      - Returns JSON: `{ id:, name: }` of the created leaf location
      - Add route for this: `post :create_from_google, on: :collection` in routes.rb
  - REFACTOR: Extract search query sanitization

  **Must NOT do**:
  - Do NOT modify existing CRUD actions (index, show, new, create, edit, update, destroy)
  - Do NOT change the existing `location_params` method
  - Do NOT add pagination or infinite scroll
  - Do NOT add full-text search (pg_trgm) — simple ILIKE is sufficient for this scale

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: TDD with request specs, wiring two services together, two new controller actions, JSON responses
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 7)
  - **Blocks**: Tasks 8, 9 (integration needs working endpoint)
  - **Blocked By**: Tasks 2 (route), 3 (GooglePlacesService), 4 (LocationHierarchyService)

  **References**:

  **Pattern References**:
  - `app/controllers/people_controller.rb:8-14` — EXACT pattern for search action:
    ```ruby
    def search
      @people = current_family.people
        .where("first_name ILIKE :q OR ...", q: "%#{params[:q]}%")
        .alphabetical.limit(10)
      render json: @people.map { |p| { id: p.id, name: p.full_name } }
    end
    ```
  - `app/controllers/locations_controller.rb:1-57` — Current controller: before_action, set_location, location_params. Add new actions WITHOUT modifying existing ones.
  - `app/controllers/people_controller.rb:24-36` — People#create with `respond_to` for JSON format — pattern for create_from_google

  **API/Type References**:
  - `app/services/google_places_service.rb` — `autocomplete(query, session_token)` returns `[{place_id:, description:}]`
  - `app/services/location_hierarchy_service.rb` — `call(family, place_details)` returns Location record
  - `app/models/location.rb` — `has_ancestry` provides `.parent` method for `parent_name` in response

  **Test References**:
  - `spec/requests/` — This directory may not exist yet; create it. Follow standard RSpec request spec conventions (`describe 'GET /locations/search'`, `before { sign_in }`, `expect(response).to have_http_status(:ok)`)
  - `spec/factories.rb` — Location factory for test data

  **WHY Each Reference Matters**:
  - People search action is the EXACT pattern: ILIKE query, family scoped, limited, JSON response
  - Existing locations controller shows the before_action/private method structure to preserve
  - GooglePlacesService API defines what the controller calls and what response shape to expect

  **Acceptance Criteria**:

  **TDD (RED then GREEN):**
  - [x] `spec/requests/locations_search_spec.rb` exists with comprehensive tests
  - [x] `bundle exec rspec spec/requests/locations_search_spec.rb` → ALL PASS, 0 failures
  - [x] Search returns JSON with `local` and `google` keys
  - [x] `create_from_google` creates location with correct ancestry
  - [x] `bin/rubocop` → 0 offenses

  **QA Scenarios:**

  ```
  Scenario: Search endpoint returns local results
    Tool: Bash
    Preconditions: Test database seeded with locations, user authenticated
    Steps:
      1. Run: bundle exec rspec spec/requests/locations_search_spec.rb -e 'local' --format documentation
    Expected Result: All local search tests pass. Returns JSON with local array containing matching locations.
    Failure Indicators: Wrong JSON shape, missing family scoping, including other family's locations
    Evidence: .sisyphus/evidence/task-6-local-search.txt

  Scenario: create_from_google creates location with parent chain
    Tool: Bash
    Preconditions: GooglePlacesService stubbed, family exists
    Steps:
      1. Run: bundle exec rspec spec/requests/locations_search_spec.rb -e 'create_from_google' --format documentation
    Expected Result: Creates location, returns JSON with id and name, parent chain exists
    Failure Indicators: No parent created, wrong ancestry, missing google_place_id
    Evidence: .sisyphus/evidence/task-6-create-from-google.txt
  ```

  **Commit**: YES
  - Message: `feat(locations): add search endpoint with local and Google results`
  - Files: `app/controllers/locations_controller.rb`, `config/routes.rb`, `spec/requests/locations_search_spec.rb`
  - Pre-commit: `bundle exec rspec spec/requests/locations_search_spec.rb && bin/rubocop`

- [x] 7. Location Autocomplete Partial + Controller Registration

  **What to do**:
  - Create `app/views/shared/_location_autocomplete.html.erb` modeled on `_person_autocomplete.html.erb`:
    - Accept locals: `field_name` (required), `label` (required), `current_location` (optional, default nil), `placeholder` (optional), `required` (optional, default false), `local_only` (optional, default false)
    - Wrap in `div` with `data-controller='location-autocomplete'`
    - Set `data-location-autocomplete-search-url-value` to `search_locations_path`
    - Set `data-location-autocomplete-create-url-value` to `create_from_google_locations_path(format: :json)`
    - Set `data-location-autocomplete-local-only-value` to the `local_only` local variable
    - Visible text input with `data-location-autocomplete-target='input'` and `data-action='input->location-autocomplete#onInput keydown->location-autocomplete#onKeydown'`
    - Hidden input with `name` set to `field_name` and `data-location-autocomplete-target='hidden'`
    - Dropdown container: `div.dropdown-menu.w-100` with `data-location-autocomplete-target='results'`
    - Clear button when `current_location` present
    - Use Bootstrap/Tabler classes matching person autocomplete exactly

  **Must NOT do**:
  - Do NOT add new CSS classes or custom styles — use existing Tabler/Bootstrap classes
  - Do NOT add inline styles beyond what person autocomplete uses
  - Do NOT modify the person autocomplete partial

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single partial file, copying an existing pattern exactly
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 6)
  - **Blocks**: Task 8 (views need this partial)
  - **Blocked By**: Task 5 (partial references the controller)

  **References**:

  **Pattern References** (CRITICAL — copy this partial structure):
  - `app/views/shared/_person_autocomplete.html.erb:1-33` — THE template:
    - Lines 3-5: local variable defaults (`current_person ||= nil`, `placeholder ||= ...`)
    - Lines 6-9: controller div with data-values
    - Lines 10-11: form label
    - Lines 12-19: input group with text input + hidden input
    - Lines 24-28: clear button (conditional)
    - Lines 30-31: dropdown results container
    - Line 32: create form container

  **WHY Each Reference Matters**:
  - Person autocomplete partial is the exact HTML structure to replicate. Same Bootstrap input-group layout, same dropdown-menu positioning, same target naming convention.

  **Acceptance Criteria**:

  - [x] `app/views/shared/_location_autocomplete.html.erb` exists
  - [x] Partial accepts `field_name`, `label`, `current_location`, `placeholder`, `required`, `local_only` locals
  - [x] Partial references `location-autocomplete` controller with correct data attributes
  - [x] `bin/rubocop` passes

  **QA Scenarios:**

  ```
  Scenario: Partial renders without error
    Tool: Bash
    Preconditions: Partial created, controller registered
    Steps:
      1. Run: bin/rails runner "ApplicationController.render(partial: 'shared/location_autocomplete', locals: { field_name: 'photo[location_id]', label: 'Location' })"
    Expected Result: Renders HTML string containing 'data-controller="location-autocomplete"' and hidden input with name 'photo[location_id]'
    Failure Indicators: Template error, missing controller reference, wrong field name
    Evidence: .sisyphus/evidence/task-7-partial-render.txt
  ```

  **Commit**: YES (groups with Task 5)
  - Message: `feat(locations): add location autocomplete Stimulus controller and partial`
  - Files: `app/views/shared/_location_autocomplete.html.erb`
  - Pre-commit: `bin/rubocop`


- [x] 8. Replace All Location Dropdowns + Descendant Photos on Show Page

  **What to do**:
  - Replace **3 location dropdowns** with the new autocomplete partial:
  - **Photo form** (`app/views/photos/_form.html.erb:46`):
    - Remove: `<%= f.association :location, collection: current_family.locations, input_html: { class: 'form-select' }, label_html: { class: 'form-label' } %>`
    - Replace with: `<%= render 'shared/location_autocomplete', field_name: 'photo[location_id]', label: 'Location', current_location: photo.location, placeholder: 'Search for a location...' %>`
  - **Event form** (`app/views/events/_form.html.erb:11`):
    - Remove: `<%= f.association :location, collection: current_family.locations, input_html: { class: 'form-select' }, label_html: { class: 'form-label' } %>`
    - Replace with: `<%= render 'shared/location_autocomplete', field_name: 'event[location_id]', label: 'Location', current_location: event.location, placeholder: 'Search for a location...' %>`
  - **Location form parent** (`app/views/locations/_form.html.erb:10`):
    - Remove: `<%= f.association :parent, collection: current_family.locations.where.not(id: location.id), label: 'Parent Location', input_html: { class: 'form-select' }, label_html: { class: 'form-label' } %>`
    - Replace with: `<%= render 'shared/location_autocomplete', field_name: 'location[parent_id]', label: 'Parent Location', current_location: location.parent, placeholder: 'Search parent location...', local_only: true %>`
  - **Location#show descendant photos** (`app/views/locations/show.html.erb`):
    - Update `LocationsController#show` to change `@photos = @location.photos.recent` to `@photos = Photo.where(location: @location.subtree).recent`
    - Update the photos count in show view: `@location.photos.count` to `@photos.count` (or use the subtree-scoped count)
    - Add a note in the show view if photos are from child locations (optional visual indicator)

  **Must NOT do**:
  - Do NOT change any other part of the photo, event, or location forms
  - Do NOT modify form field names (must still submit as `photo[location_id]`, `event[location_id]`, `location[parent_id]`)
  - Do NOT add new form fields or remove existing ones
  - Do NOT change location index view, edit view layout, or destroy behavior
  - Do NOT change the show view layout — only modify the photos query and count

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Modifying 4 view files + 1 controller method, need to understand each form's context
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed for making changes (Task F3 will QA)

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Task 9)
  - **Blocks**: F1-F4 (final verification)
  - **Blocked By**: Tasks 6 (controller endpoint), 7 (partial)

  **References**:

  **Pattern References**:
  - `app/views/shared/_person_autocomplete.html.erb` — How the person autocomplete partial is used in other views — same render call pattern
  - `app/views/photos/_form.html.erb:46` — EXACT line to replace (location dropdown)
  - `app/views/events/_form.html.erb:11` — EXACT line to replace (location dropdown)
  - `app/views/locations/_form.html.erb:10` — EXACT line to replace (parent dropdown)
  - `app/views/locations/show.html.erb:9,64` — Photos query (`@location.photos`) and count display
  - `app/controllers/locations_controller.rb:8-12` — Show action setting `@photos`

  **API/Type References**:
  - `app/views/shared/_location_autocomplete.html.erb` — Partial interface: `field_name`, `label`, `current_location`, `placeholder`, `local_only`
  - `app/models/location.rb:2` — `has_ancestry` provides `.subtree` method for descendant queries

  **WHY Each Reference Matters**:
  - Each form file line number tells the executor exactly which line to find and replace
  - The partial interface defines exactly what locals to pass
  - The show action and view define where to change the photos query

  **Acceptance Criteria**:

  - [x] `grep -r 'f.association :location' app/views/` returns 0 results
  - [x] `grep -r 'f.association :parent' app/views/locations/` returns 0 results
  - [x] `grep -r 'location_autocomplete' app/views/` returns 3 results (photos, events, locations forms)
  - [x] Photo form submits `photo[location_id]` correctly
  - [x] Location form submits `location[parent_id]` correctly
  - [x] Location#show displays photos from descendant locations
  - [x] `bundle exec rspec` passes (no regressions)
  - [x] `bin/rubocop` passes

  **QA Scenarios:**

  ```
  Scenario: All location dropdowns replaced
    Tool: Bash
    Preconditions: All tasks 1-7 complete
    Steps:
      1. Run: grep -r 'f.association :location' app/views/ | wc -l
      2. Run: grep -r 'f.association :parent' app/views/locations/ | wc -l
      3. Run: grep -r 'location_autocomplete' app/views/ | wc -l
    Expected Result: Steps 1-2 return '0', Step 3 returns '3'
    Failure Indicators: Any dropdown not replaced, partial not rendered in all 3 forms
    Evidence: .sisyphus/evidence/task-8-dropdown-replacement.txt

  Scenario: Photo form autocomplete renders and submits
    Tool: Playwright (playwright skill)
    Preconditions: Dev server running (bin/dev), signed in as alex@example.com
    Steps:
      1. Navigate to /photos, click on any photo, click Edit
      2. Assert: page has element with data-controller='location-autocomplete'
      3. Assert: page has hidden input with name='photo[location_id]'
      4. Type 'Ches' into the location autocomplete input
      5. Wait 500ms for debounce + fetch
      6. Assert: dropdown appears with 'Existing Locations' section header
      7. Click on first local result
      8. Assert: hidden input value is set to a numeric ID
      9. Submit the form
      10. Assert: redirected to photo show page, location name displayed
    Expected Result: Autocomplete works end-to-end, photo saved with location
    Failure Indicators: No dropdown appears, form submission fails, wrong location saved
    Evidence: .sisyphus/evidence/task-8-photo-autocomplete.png

  Scenario: Location form parent selector is local-only
    Tool: Playwright (playwright skill)
    Preconditions: Dev server running, signed in
    Steps:
      1. Navigate to /locations/new
      2. Assert: parent field has data-location-autocomplete-local-only-value='true'
      3. Type 'UK' into parent autocomplete
      4. Wait 500ms
      5. Assert: dropdown shows 'Existing Locations' section but NO 'Google Places' section
    Expected Result: Only local results shown, no Google section
    Failure Indicators: Google section appears in local-only mode
    Evidence: .sisyphus/evidence/task-8-local-only-parent.png

  Scenario: Location show page includes descendant photos
    Tool: Playwright (playwright skill)
    Preconditions: Dev server running, signed in. Location 'UK' exists with child 'Edinburgh' that has photos
    Steps:
      1. Navigate to /locations (find UK in list)
      2. Click on UK
      3. Assert: photos section shows photos from Edinburgh (child location) in addition to direct UK photos
      4. Assert: photo count reflects total including descendants
    Expected Result: Descendant photos visible on parent location page
    Failure Indicators: Only direct photos shown, count wrong
    Evidence: .sisyphus/evidence/task-8-descendant-photos.png
  ```

  **Commit**: YES
  - Message: `feat(locations): replace all location dropdowns with autocomplete`
  - Files: `app/views/photos/_form.html.erb`, `app/views/events/_form.html.erb`, `app/views/locations/_form.html.erb`, `app/views/locations/show.html.erb`, `app/controllers/locations_controller.rb`
  - Pre-commit: `bundle exec rspec && bin/rubocop`

- [x] 9. Edge Cases + Graceful Degradation

  **What to do**:
  - **Missing API key graceful degradation**:
    - In `GooglePlacesService`: if `Rails.application.credentials.dig(:google, :places_api_key)` is nil, return empty results immediately (no HTTP call)
    - Log `Rails.logger.warn('Google Places API key not configured')` on first call when key missing
    - In `LocationsController#search`: if Google returns empty (due to missing key or error), response still valid with `{ local: [...], google: [] }`
    - In Stimulus controller: if google section is empty, hide the 'Google Places' header entirely (don't show empty section)
  - **Concurrent parent chain creation**:
    - In `LocationHierarchyService`: wrap `find_or_create_by!` in rescue `ActiveRecord::RecordNotUnique`, then retry with `find_by!`
    - Verify the partial unique index on `[family_id, google_place_id]` handles this at DB level
  - **Same-name different-place display**:
    - In `LocationsController#search` local results: include `parent_name` in JSON so 'Cambridge' shows as 'Cambridge (UK)' vs 'Cambridge'
    - The Stimulus controller should render local results as: `location.name` + ` — ${location.parent_name}` when parent_name exists
  - **Empty/short queries**:
    - Controller returns `{ local: [], google: [] }` for queries shorter than 2 characters
    - Stimulus controller doesn't fire fetch for queries < 2 chars (matching person autocomplete min 2 char pattern)
  - **Special characters in search**:
    - Sanitize query in controller: strip leading/trailing whitespace
    - ILIKE query already handles special characters safely via parameterized query
  - **Google API timeout/error**:
    - GooglePlacesService has 3-second timeout
    - On timeout or error: log error, return empty array (never raise)
    - Controller returns local results normally with empty google array

  **Must NOT do**:
  - Do NOT add retry logic for Google API (single attempt with timeout is sufficient)
  - Do NOT add caching for Google results (premature optimization)
  - Do NOT add rate limiting (dev/small-scale app)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Cross-cutting edge cases touching service, controller, and frontend layers
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Task 8)
  - **Blocks**: F1-F4 (final verification)
  - **Blocked By**: Task 6 (controller endpoint must exist)

  **References**:

  **Pattern References**:
  - `app/services/google_places_service.rb` — Add API key check and timeout handling
  - `app/services/location_hierarchy_service.rb` — Add RecordNotUnique rescue
  - `app/controllers/locations_controller.rb` — Search action: add parent_name to response, handle empty queries
  - `app/javascript/controllers/location_autocomplete_controller.js` — Hide empty Google section, render parent_name

  **WHY Each Reference Matters**:
  - Each file is being hardened with edge case handling — the executor needs to know exactly which files to modify and what to add

  **Acceptance Criteria**:

  - [x] App works with no Google API key configured (local-only mode)
  - [x] Concurrent creation attempts don't cause 500 errors
  - [x] Same-name locations distinguishable in autocomplete results
  - [x] Empty/short queries return valid empty JSON
  - [x] `bundle exec rspec` passes
  - [x] `bin/rubocop` passes

  **QA Scenarios:**

  ```
  Scenario: Graceful degradation without Google API key
    Tool: Bash
    Preconditions: Google API key NOT set in credentials
    Steps:
      1. Run: bundle exec rspec spec/services/google_places_service_spec.rb -e 'missing API key'
    Expected Result: Test passes, returns empty array, logs warning
    Failure Indicators: HTTP call attempted, exception raised
    Evidence: .sisyphus/evidence/task-9-no-api-key.txt

  Scenario: Short query returns empty results
    Tool: Bash
    Preconditions: Authenticated session
    Steps:
      1. Run: bundle exec rspec spec/requests/locations_search_spec.rb -e 'short query'
    Expected Result: Returns { local: [], google: [] } for 1-char queries
    Failure Indicators: Error or non-empty results for short query
    Evidence: .sisyphus/evidence/task-9-short-query.txt

  Scenario: Concurrent creation handling
    Tool: Bash
    Preconditions: Location hierarchy service specs
    Steps:
      1. Run: bundle exec rspec spec/services/location_hierarchy_service_spec.rb -e 'concurrent' --format documentation
    Expected Result: RecordNotUnique rescued, retry finds existing record
    Failure Indicators: Unrescued exception, duplicate records created
    Evidence: .sisyphus/evidence/task-9-concurrent.txt
  ```

  **Commit**: YES
  - Message: `fix(locations): handle edge cases and graceful degradation for autocomplete`
  - Files: Various (services, controller, JS controller)
  - Pre-commit: `bundle exec rspec && bin/rubocop`

---

## Final Verification Wave

- [x] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high`
  Run `bin/rubocop` + `bundle exec rspec`. Review all changed files for: `as any`/`@ts-ignore`, empty catches, console.log in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names (data/result/item/temp). Verify Ruby style matches rubocop-rails-omakase rules. Verify JS matches existing controller patterns (no semicolons, Stimulus conventions).
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [x] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill)
  Start dev server with `bin/dev`. Sign in as `alex@example.com`. Navigate to photo edit form. Test autocomplete: type location name, verify local results appear, verify Google results appear (if API key configured), select a result, verify location is saved. Test location form parent autocomplete (local-only). Test edge cases: empty query, 1-character query, special characters. Navigate to a location show page with children, verify descendant photos display. Save screenshots to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination: Task N touching Task M's files. Flag unaccounted changes. Specifically verify: no PostGIS, no map widgets, no EXIF geocoding, no new JS deps, no geocoder changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Task 1**: `feat(locations): add google_place_id column and webmock for testing` — migration file, Gemfile, Gemfile.lock
- **Task 2**: `chore(locations): add search route and services directory` — routes.rb
- **Tasks 3-4**: `feat(locations): add Google Places and hierarchy services with TDD specs` — app/services/*, spec/services/*
- **Task 6**: `feat(locations): add search endpoint with local and Google results` — locations_controller.rb, spec/requests/*
- **Tasks 5+7**: `feat(locations): add location autocomplete Stimulus controller and partial` — JS controller, ERB partial, index.js
- **Tasks 8-9**: `feat(locations): replace all location dropdowns with autocomplete` — form views, show view, edge case handling

---

## Success Criteria

### Verification Commands
```bash
bundle exec rspec                                           # Expected: 0 failures
bin/rubocop                                                 # Expected: 0 offenses
grep -r "f.association :location" app/views/                # Expected: 0 results
grep -r "f.association :parent" app/views/locations/         # Expected: 0 results
grep -r "location_autocomplete" app/views/                  # Expected: 3 results
grep -r "location-autocomplete" app/javascript/             # Expected: controller + registration
bundle exec rspec spec/services/                            # Expected: all services pass
bundle exec rspec spec/requests/locations_search_spec.rb    # Expected: all requests pass
```

### Final Checklist
- [x] All "Must Have" present
- [x] All "Must NOT Have" absent
- [x] All RSpec tests pass
- [x] Rubocop clean
- [x] 3 dropdowns replaced with autocomplete
- [x] Google Places results visible in autocomplete (when API key configured)
- [x] Location hierarchy auto-created from Google Place selection
- [x] Location#show displays descendant photos
