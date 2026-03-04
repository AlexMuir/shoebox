# Learnings — location-autocomplete

## 2026-03-03 — Session Start

### Worktree
- Branch: `location-autocomplete`
- Path: `/home/pippin/projects/photos-location-autocomplete`
- Main project: `/home/pippin/projects/photos`

### Key Codebase Patterns

**Migration style**: Look at `db/migrate/20260228215718_create_locations.rb` — no annotations, standard Rails format.

**Service object pattern** (being established in Task 2): `app/services/application_service.rb` with `self.call(...)` forwarding to `new(...).call`

**PersonAutocomplete = THE template**:
- Stimulus: `app/javascript/controllers/person_autocomplete_controller.js` (179 lines)
  - 250ms debounce via setTimeout, min 2 chars
  - Targets: input, hidden, results, createForm
  - Values: searchUrl (String), createUrl (String)
  - handleOutsideClick = arrow function in connect/disconnect
  - escapeHtml helper at bottom
- Partial: `app/views/shared/_person_autocomplete.html.erb` (33 lines)
  - Locals: field_name, label, current_person, placeholder, required
  - data-controller on outer div, data-values as data attributes
  - input-group with text + hidden input
  - dropdown-menu results div
- Controller search: `app/controllers/people_controller.rb:8-14`
  - ILIKE query, current_family scoped, .alphabetical.limit(10)
  - Returns `render json: [...map...]`
- Route: `get :search` in collection block on people resources

**No semicolons in JS** — this is the house style.

**Rails credentials path for Google API**: `Rails.application.credentials.dig(:google, :places_api_key)`

### Critical Technical Details

**Google Places API (New)**:
- Autocomplete: `POST https://places.googleapis.com/v1/places:autocomplete`
  - Headers: `X-Goog-Api-Key`, `Content-Type: application/json`
  - Body: `{ input: query, sessionToken: session_token }`
  - Response: `{ suggestions: [{ placePrediction: { placeId: string, text: { text: string } } }] }`
- Place Details: `GET https://places.googleapis.com/v1/places/{placeId}`
  - Headers: `X-Goog-Api-Key`, `X-Goog-FieldMask: id,displayName,formattedAddress,location,addressComponents`
  - Query param: `sessionToken=...`
  - Response: `{ id: string, displayName: { text: string }, formattedAddress: string, location: { latitude, longitude }, addressComponents: [{ longText, shortText, types }] }`
- **CRITICAL**: Google addressComponents do NOT include per-component placeId
  - Parent dedup uses name+parent combo (name:, parent: location)
  - Only the leaf location uses google_place_id for dedup

**Ancestry gem**:
- `.subtree` returns self + all descendants (for descendant photo queries)
- `.descendants` returns only descendants (not self)
- `.parent` returns parent location record
- `.path` returns all ancestors + self

**Location model key facts**:
- `has_ancestry` (default options)
- `belongs_to :family`
- Only validates name presence
- geocode callback COMMENTED OUT — do NOT uncomment
- Scoped to `current_family` in controller

**3 dropdowns to replace**:
1. `app/views/photos/_form.html.erb:46` → `f.association :location`
2. `app/views/events/_form.html.erb:11` → `f.association :location`
3. `app/views/locations/_form.html.erb:10` → `f.association :parent`

**Spec/requests**: Directory may not exist yet — create it.

## 2026-03-03 — Task 2 Complete

### Routes Updated
- `config/routes.rb` line 24-29: Changed `resources :locations` to include collection block
- Added `get :search` and `post :create_from_google` routes
- Verified: `bin/rails routes -g location` shows both routes correctly

### ApplicationService Created
- File: `app/services/application_service.rb`
- Uses Ruby 3 forwarding syntax: `def self.call(...)`
- Verified: `ApplicationService.respond_to?(:call)` returns true
- Rails autoloads `app/services/` directory automatically

### Verification
- ✓ Routes verified with `bin/rails routes -g location`
- ✓ Service verified with `bin/rails runner`
- ✓ All 82 tests pass (no regressions)
- ✓ Commit: `3d6c40f chore(locations): add search route and services directory`
- ✓ Evidence saved to `.sisyphus/evidence/task-2-*.txt`

### Next Steps
- Task 3: Implement LocationsController#search action
- Task 4: Create LocationSearchService
- Task 5: Build Stimulus controller for location autocomplete
- Task 6: Implement create_from_google action

## 2026-03-03 — Task 3 - GooglePlacesService

### TDD Notes
- Started with `spec/services/google_places_service_spec.rb` and validated RED (missing constant).
- WebMock stubs cover autocomplete POST and place details GET using Google Places API (New) endpoints.
- Added missing API key behavior checks to ensure no HTTP requests are made.
- Added timeout/network/server failure scenarios to enforce safe fallbacks (`[]`/`nil`).

### Implementation Notes
- Added `app/services/google_places_service.rb` inheriting from `ApplicationService`.
- Uses stdlib `Net::HTTP` only (no additional gems), with shared `make_request` method.
- Applies `X-Goog-Api-Key` to all requests, `Content-Type` for POST, and field mask for details GET.
- Maps camelCase Google response fields to snake_case hashes expected by the app.
- Logs missing API key with `Rails.logger.warn` and network/runtime failures with `Rails.logger.error`.

### Verification
- `bundle exec rspec spec/services/google_places_service_spec.rb --format documentation` -> 7 examples, 0 failures.
- `bin/rubocop app/services/google_places_service.rb spec/services/google_places_service_spec.rb` -> 0 offenses.
- LSP diagnostics clean for both changed files.

## Task 4 — LocationHierarchyService

### TDD Notes
- Started with `spec/services/location_hierarchy_service_spec.rb` and validated RED (`uninitialized constant LocationHierarchyService`).
- Spec covers country-only, city+country, street+city+country hierarchy depth, leaf dedup by `google_place_id`, parent dedup by `name + parent`, and family scoping.
- Initial GREEN attempt failed on ancestry lookup because `parent` is not a DB column; fixed by querying via `parent.children` for child dedup.

### Implementation Notes
- Added `app/services/location_hierarchy_service.rb` inheriting from `ApplicationService` with initializer-based `call` flow.
- Hierarchy components are extracted from Google `address_components`, filtered by supported types, and sorted broad-to-specific (`country` to `street_address`).
- Parent nodes are found/created in family scope only, using root name matching for roots and `parent.children` for nested nodes.
- Leaf node deduplicates strictly by `google_place_id`; no `formatted_address` assignment (column does not exist in `locations`).
- Leaf address data maps `lat/lng` to `latitude/longitude`, with optional `address_line_1`, `city`, `region`, `postal_code`, and `country` from components.

### Verification
- `bundle exec rspec spec/services/location_hierarchy_service_spec.rb --format documentation` -> 6 examples, 0 failures.
- `bundle exec rspec` -> 95 examples, 0 failures.
- `bin/rubocop app/services/location_hierarchy_service.rb` -> 0 offenses.
- LSP diagnostics clean for `app/services/location_hierarchy_service.rb` and `spec/services/location_hierarchy_service_spec.rb`.

## Task 5 — Stimulus Controller

### Controller: `app/javascript/controllers/location_autocomplete_controller.js`
- 155 lines, follows `person_autocomplete_controller.js` structure exactly
- Static values: `searchUrl` (String), `createUrl` (String), `localOnly` (Boolean)
- Static targets: `input`, `hidden`, `results`, `createForm`
- `connect()` generates `this.sessionToken = crypto.randomUUID()` for Google billing optimization
- 250ms debounce, min 2 chars (same as person autocomplete)
- `search()` sends `session_token` as query param to backend
- `showResults()` renders two-section dropdown: "Existing Locations" + "Google Places" (skips Google if `localOnlyValue`)
- Local results show `name — parent_name` display format
- `selectLocal()` sets hidden input to location ID
- `selectGoogle()` POSTs to `createUrlValue` with `place_id` + `session_token`, generates new session token on success
- Error handling: reverts input, shows error in `createFormTarget`
- `handleOutsideClick` arrow function, `escapeHtml`, `onKeydown` Escape — all same pattern as person autocomplete

### Registration
- Added to `app/javascript/controllers/index.js` as `"location-autocomplete"`
- Follows existing import+register pattern (no blank lines between import and register)

### Verification
- ✓ `node -c` syntax check passes (exit 0)
- ✓ 0 trailing semicolons (house style)
- ✓ Registration count = 1 in index.js
- ✓ Commit: `9d1c6e5 feat(locations): add location autocomplete Stimulus controller`
- ✓ Evidence saved to `.sisyphus/evidence/task-5-js-valid.txt`

## Task 6 — Controller Actions

### TDD Notes
- Added `spec/requests/locations_search_spec.rb` first and ran RED before implementation.
- Initial RED was 404 for both routes (`search` and `create_from_google`) since actions were not yet present in `LocationsController`.
- Request auth in this repo has no shared request helper yet; stubbing `Session.find_signed` to return a real `Session` record is the stable pattern for request specs here.

### Implementation Notes
- Added `LocationsController#search` using `current_family` scope (not `Current.family` directly) to match controller conventions.
- `search` returns `{ local: [], google: [] }` for blank or <2-char queries.
- Local search uses `ILIKE` name match, `.alphabetical`, `.limit(5)`, and maps `parent_name: loc.parent&.name`.
- Google autocomplete is only called when `session_token` is present.
- Added `LocationsController#create_from_google` that calls `GooglePlacesService#place_details` and `LocationHierarchyService.call(current_family, place_details)`.
- Nil place details return `422` with `{ error: "Place not found" }`; success returns `{ id, name }`.

### Verification
- `bundle exec rspec spec/requests/locations_search_spec.rb --format documentation` -> 8 examples, 0 failures.
- `bundle exec rspec` -> 103 examples, 0 failures.
- `bin/rubocop app/controllers/locations_controller.rb` -> 0 offenses.
- LSP diagnostics clean for `app/controllers/locations_controller.rb` and `spec/requests/locations_search_spec.rb`.

## Location Autocomplete Partial Creation

### Key Learnings
1. **ERB File Linting**: Rubocop does not lint `.erb` files by default. The Lint/Syntax error when explicitly running rubocop on ERB files is expected and not a blocker. The person_autocomplete partial has the same behavior.

2. **Stimulus Controller Value Naming**: The location_autocomplete_controller.js uses camelCase for static values (searchUrl, createUrl, localOnly), which automatically map to kebab-case data attributes (data-location-autocomplete-search-url-value, etc.).

3. **Location Model Attributes**: Location model uses `.name` (not `.full_name` like Person). This is critical for the display value in the text input.

4. **Local-Only Flag**: The `localOnly` boolean value is used by the Stimulus controller to conditionally show/hide the Google Places section in search results.

5. **Partial Structure**: The location autocomplete partial mirrors the person autocomplete exactly:
   - Same Bootstrap/Tabler classes (form-label, input-group, form-control, btn btn-outline-secondary, dropdown-menu)
   - Same Stimulus targets (input, hidden, results, createForm)
   - Same data-action bindings (input->location-autocomplete#onInput, keydown->location-autocomplete#onKeydown, click->location-autocomplete#clear)
   - Same conditional clear button (only shown when current_location is present)

6. **Route Paths**: 
   - Search: `search_locations_path` (GET)
   - Create from Google: `create_from_google_locations_path(format: :json)` (POST)

### Verification Steps Completed
- ✅ Partial renders without error via `bin/rails runner`
- ✅ Git commit created with message: `feat(locations): add location autocomplete partial`
- ✅ Full rubocop check passes (existing offenses unrelated to new file)


## Task 8 — Replace Dropdowns + Descendant Photos

### Changes Made
1. **photos/_form.html.erb**: Replaced `f.association :location` with `render 'shared/location_autocomplete'` using `field_name: 'photo[location_id]'`
2. **events/_form.html.erb**: Same replacement with `field_name: 'event[location_id]'`
3. **locations/_form.html.erb**: Replaced `f.association :parent` with autocomplete using `field_name: 'location[parent_id]'` and `local_only: true`
4. **locations_controller.rb**: Changed `@location.photos.recent` to `Photo.where(location: @location.subtree).recent` for descendant photo inclusion
5. **locations/show.html.erb**: Changed 3 occurrences of `@location.photos` to `@photos` (count, each, empty?)

### Key Learnings
- The `local_only: true` flag on the locations form prevents Google Places suggestions when editing parent location (only shows family's existing locations)
- `@location.subtree` (ancestry gem) includes self + all descendants, making it perfect for "show all photos in this location hierarchy"
- The `@photos` instance variable was already being set in the controller, so the view just needed to reference it instead of re-querying
- Rubocop pre-existing offenses (15) are all in config/initializers and db/seeds.rb — not related to this change
- All 103 specs pass with no regressions

### Verification
- ✅ `grep -r 'f.association :location' app/views/` returns 0 results
- ✅ `grep -r 'f.association :parent' app/views/locations/` returns 0 results
- ✅ `bundle exec rspec` → 103 examples, 0 failures
- ✅ `bin/rubocop` → 0 new offenses (15 pre-existing in unrelated files)
- ✅ Commit: `feat(locations): replace location dropdowns with autocomplete and show descendant photos`
## Task 9 — Empty Google Section Fix

### Change Made
Modified `app/javascript/controllers/location_autocomplete_controller.js` line 68-75:
- Changed condition from `if (!this.localOnlyValue)` to `if (!this.localOnlyValue && google.length > 0)`
- Removed the `else` branch that displayed "No Google results"
- Result: When Google returns empty (missing API key, error, or no results), the entire Google section is hidden (no divider, no header, no message)

### Edge Cases Verified (All Already Implemented)
1. ✅ Missing API key: `GooglePlacesService#api_key_present?` returns false, logs warning, returns `[]`
2. ✅ Concurrent creation: `ActiveRecord::RecordNotUnique` rescue in `LocationHierarchyService`
3. ✅ Same-name disambiguation: `parent_name` in local results JSON
4. ✅ Empty/short queries: controller returns `{ local: [], google: [] }` for < 2 chars
5. ✅ Google API timeout: 3-second timeout + rescue in `GooglePlacesService`

### Verification
- ✅ `node -c app/javascript/controllers/location_autocomplete_controller.js` → exit 0
- ✅ 0 trailing semicolons (house style maintained)
- ✅ `bundle exec rspec` → 103 examples, 0 failures
- ✅ `bin/rubocop` → 0 new offenses (15 pre-existing in unrelated files)
- ✅ Commit: `8a7a59c fix(locations): hide empty Google section in autocomplete dropdown`

### Key Insight
The fix is minimal and surgical: by adding `&& google.length > 0` to the condition, we skip the entire Google section rendering when there are no results. This is cleaner than showing a "No Google results" message, especially when the API key is missing or the service fails silently.
