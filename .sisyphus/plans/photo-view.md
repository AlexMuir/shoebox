# PhotoView: Facebook-Style Photo Viewer

## TL;DR

> **Quick Summary**: Build a Facebook-style full-screen photo viewer as a React component mounted inside the existing Rails/Stimulus app. Includes zoom/pan, face tagging via AJAX, responsive sidebar, and prev/next navigation through the gallery.
> 
> **Deliverables**:
> - React + Vite React plugin installed and configured
> - `PhotoView` React component tree (modal, image, toolbar, sidebar, navigation, tagging)
> - Stimulus bridge controller (`photo_view_controller.js`) that mounts/unmounts React from gallery thumbnails
> - JSON API endpoints on existing controllers (photos#show, photo_faces CRUD)
> - SCSS styles namespaced under `.photo-view-modal`
> - RSpec request specs for all new JSON endpoints
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES — 5 waves + final review
> **Critical Path**: T1 → T5 → T6 → T7/T8 → T11 → T12 → T17 → F1-F4

---

## Context

### Original Request
Clone Facebook's photo viewing UI into a PhotoView React component. Full-screen modal triggered from the gallery with: close button, zoom (4 levels with pan), face tagging (create/remove via AJAX with person autocomplete), fullscreen toggle, responsive sidebar at 900px breakpoint, and prev/next photo navigation.

### Interview Summary
**Key Discussions**:
- **React vs Stimulus**: User confirmed React despite it not being installed — complexity warrants it
- **Modal trigger**: Opens from the index/gallery grid (replaces the current link-to-show-page behavior)
- **Sidebar content**: Mirrors the show page — details, people, contributions (read-only display)
- **Navigation**: Prev/next arrows + keyboard (left/right/escape)
- **Tests**: Tests after implementation, RSpec + FactoryBot

**Research Findings**:
- `PhotoFace` already stores normalized 0-1 bounding boxes (x, y, width, height) with optional `person_id` — perfect for the tagging UI
- `GET /people/search?q=` already returns JSON `[{id, name}]` — autocomplete backend is ready
- `POST /people` already returns JSON `{id, name}` — "create new person" from autocomplete is ready
- `photo_faces` and `photo_people` controllers exist but respond with HTML redirects only — need JSON `respond_to` blocks
- `person_autocomplete_controller.js` has the CSRF token pattern to follow: `document.querySelector("meta[name='csrf-token']")?.content`
- Active Storage variants: `:large` (1600x1600) is the zoom source, `:thumb` (200x200) for gallery
- `oriented_variant(:large)` handles rotation correction — must use this, not raw `.variant(:large)`
- Stimulus controllers are manually registered in `controllers/index.js` — new bridge controller must be added there
- `import_detected_faces!` is called in `photos#show` and must also be called in the JSON endpoint
- Tabler Icons webfont is available for all icons (`ti ti-x`, `ti ti-zoom-in`, etc.)

### Metis Review
**Identified Gaps** (addressed):
- **Existing show page fate**: Show page stays unchanged. Modal is an addition, not a replacement. (Guardrail G5)
- **Gallery set size for prev/next**: Photo IDs serialized via data attribute on gallery container. Acceptable for v1.
- **Turbo + React coexistence**: Must unmount React in Stimulus `disconnect()` to prevent stale cached DOM.
- **Turbo URL conflicts**: Use `history.replaceState` only (not `pushState`) to avoid Turbo cache corruption.
- **Sidebar interactivity**: Sidebar is read-only display. No forms for contributions or person tagging in modal. (Guardrail G4)
- **Image resolution at 4x zoom**: `:large` (1600px) is acceptable for v1. Can add `:xlarge` variant later.
- **Active Storage URL expiry**: Signed URLs expire in 5 minutes. Acceptable for normal usage; edge case documented.
- **`import_detected_faces!` performance**: Idempotent after first run (checks existing signatures). Safe to call per request.
- **Face box edge clamping**: Frontend must clamp boxes so `x + width <= 1` and `y + height <= 1`.
- **Duplicate person tag**: `PhotoPerson` has uniqueness constraint. API returns 422 — React shows error gracefully.

---

## Work Objectives

### Core Objective
Add a Facebook-style full-screen photo viewer to the gallery, implemented as a React component mounted via Stimulus, with zoom/pan, AJAX face tagging, a read-only details sidebar, and keyboard-navigable prev/next.

### Concrete Deliverables
- `app/javascript/components/PhotoView/` — React component tree (PhotoViewModal, PhotoImage, PhotoToolbar, PhotoSidebar, PhotoNavigation, tagging components)
- `app/javascript/controllers/photo_view_controller.js` — Stimulus bridge controller
- Updated `app/javascript/controllers/index.js` — registers the new controller
- Updated `app/controllers/photos_controller.rb` — JSON response for `#show`
- Updated `app/controllers/photo_faces_controller.rb` — JSON responses for create/update/destroy
- Updated `app/views/photos/index.html.erb` — data attributes for React mounting + serialized photo IDs
- `app/assets/stylesheets/_photo_view.scss` — all new styles namespaced under `.photo-view-modal`
- Updated `app/assets/stylesheets/application.scss` — imports `_photo_view`
- Updated `package.json` — react, react-dom, @vitejs/plugin-react
- Updated `vite.config.ts` — React plugin added
- `spec/requests/photos_json_spec.rb` — request specs for photo JSON endpoint
- `spec/requests/photo_faces_json_spec.rb` — request specs for photo_faces JSON CRUD

### Definition of Done
- [ ] Clicking a thumbnail in the gallery grid opens the full-screen PhotoView modal
- [ ] Modal displays photo with close (X), zoom in/out, tag, fullscreen toolbar buttons
- [ ] Zoom works at 4 discrete levels with drag-to-pan
- [ ] Tag mode allows clicking to create face boxes with person autocomplete
- [ ] Existing tags show name callout on hover, X to remove on click
- [ ] Sidebar shows details, people, contributions at >= 900px width
- [ ] Prev/next arrows and keyboard left/right navigate between photos
- [ ] All new JSON endpoints return correct data
- [ ] `bundle exec rspec` passes with zero failures (including pre-existing tests)
- [ ] `bin/rubocop` passes with zero offenses
- [ ] Existing show page at `/photos/:id` works identically to before

### Must Have
- Full-screen dark overlay modal
- Close button (X) top-left
- Toolbar top-right: zoom in, zoom out, tag, fullscreen (4 buttons)
- 4 discrete zoom levels (1x, 1.5x, 2.25x, 3.375x) with drag-to-pan
- Tag mode: mutually exclusive with zoom, creates face boxes via AJAX
- Person autocomplete dropdown on face box creation (uses existing `/people/search`)
- Remove tag via X button with AJAX delete
- Click-outside logic: photo=new-tag, black-background=dismiss, sidebar=independent
- Tag overlay text: "Click on the photo to start tagging. Click on a tag to remove it." + "Finished tagging" button
- Prev/next arrows + keyboard left/right/escape
- Responsive sidebar: 360px right column at >= 900px, hidden below
- Read-only sidebar: details (date, location, event, photographer), people tagged, contributions
- URL updates via `history.replaceState` when viewing a photo
- React mounted/unmounted cleanly via Stimulus lifecycle

### Must NOT Have (Guardrails)
- **G1: React boundary** — React is ONLY for the PhotoView modal. No React in gallery grid, show page, or any other view
- **G2: No extra npm packages** — Only `react`, `react-dom`, `@vitejs/plugin-react`. No React Router, no state libraries, no zoom/pan libraries, no UI component libraries
- **G3: No new API namespace** — Add `respond_to` blocks to existing controllers. No `/api/v1/` namespace, no serializer gems
- **G4: Sidebar is read-only** — Display details, people, contributions. No contribution form, no "Tag Person" dropdown in modal. Users who want to edit go to the full show page
- **G5: Existing show page unchanged** — `/photos/:id` HTML view, `face_tagging_controller.js`, all existing behavior stays identical
- **G6: CSS namespace isolation** — All new styles under `.photo-view-modal` prefix in `_photo_view.scss`. No global style changes
- **G7: No mobile gestures** — No pinch-to-zoom, no swipe navigation. Desktop-first. Below 900px the sidebar hides — that's the only responsive behavior
- **G8: No `history.pushState`** — Use `replaceState` only to avoid Turbo cache corruption on back-button
- **G9: No pagination changes** — Gallery stays as-is (`current_family.photos.recent`). Prev/next traverses the full set
- **G10: Keyboard limited** — Left arrow (prev), Right arrow (next), Escape (close). No other keyboard shortcuts
- **G11: No face tagging controller changes** — `face_tagging_controller.js` stays untouched. The React modal has its own tagging implementation
- **Over-abstraction** — No generic "Modal" component, no "ZoomableImage" library abstraction. Build what's needed for PhotoView specifically
- **AI slop** — No excessive JSDoc comments, no "utils" files with one function, no wrapper components that add nothing, no commented-out code

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.
> Acceptance criteria requiring "user manually tests/confirms" are FORBIDDEN.

### Test Decision
- **Infrastructure exists**: YES (RSpec + FactoryBot)
- **Automated tests**: Tests-after (implement first, then add specs)
- **Framework**: RSpec with FactoryBot, request specs for JSON endpoints
- **Test commands**: `bundle exec rspec`, `bin/rubocop`

### QA Policy
Every task MUST include agent-executed QA scenarios (see TODO template below).
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Frontend/UI**: Use Playwright (`playwright` skill) — Navigate, interact, assert DOM, screenshot
- **API/Backend**: Use Bash (curl) — Send requests, assert status + response fields
- **Build/Config**: Use Bash — Run install commands, verify output

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Infrastructure + Backend API — 5 parallel):
├── Task 1: Install React + Vite plugin + configure [quick]
├── Task 2: Photo JSON API endpoint [unspecified-high]
├── Task 3: PhotoFaces JSON responses [quick]
├── Task 4: CSS foundation — _photo_view.scss [quick]
├── Task 5: Stimulus bridge controller + gallery wiring [unspecified-high]

Wave 2 (Core React Components — 5 parallel, depends: Wave 1):
├── Task 6: PhotoViewModal — overlay, close, keyboard, replaceState (depends: 1, 5) [visual-engineering]
├── Task 7: PhotoImage — display, zoom 4 levels, drag-to-pan (depends: 1, 4) [deep]
├── Task 8: PhotoToolbar — 4 buttons, state-driven disable (depends: 1) [visual-engineering]
├── Task 9: PhotoSidebar — details, people, contributions read-only (depends: 1, 2, 4) [visual-engineering]
├── Task 10: PhotoNavigation — prev/next arrows, keyboard, boundaries (depends: 1, 2) [visual-engineering]

Wave 3 (Tagging System — 3 parallel, depends: Wave 2):
├── Task 11: Tag mode toggle + overlay text + finished button (depends: 7, 8) [visual-engineering]
├── Task 12: Face box creation + autocomplete + AJAX (depends: 3, 7, 11) [deep]
├── Task 13: Tag interaction + click-outside logic (depends: 3, 12) [deep]

Wave 4 (Polish + Tests — 5 parallel, depends: Wave 3):
├── Task 14: Fullscreen mode toggle (depends: 8, 9) [quick]
├── Task 15: Edge cases + error states (depends: 6-13) [unspecified-high]
├── Task 16: Loading states + optimistic UI (depends: 6-13) [quick]
├── Task 17: RSpec request specs for JSON endpoints (depends: 2, 3) [unspecified-high]
├── Task 18: Full regression + rubocop (depends: 17) [quick]

Wave FINAL (After ALL tasks — 4 parallel review agents):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Real manual QA — Playwright [unspecified-high + playwright]
└── Task F4: Scope fidelity check [deep]

Critical Path: T1 → T5 → T6 → T7 → T11 → T12 → T13 → T15 → F1-F4
Parallel Speedup: ~65% faster than sequential
Max Concurrent: 5 (Waves 1, 2)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 5-10 | 1 |
| 2 | — | 9, 10, 17 | 1 |
| 3 | — | 12, 13, 17 | 1 |
| 4 | — | 7, 9 | 1 |
| 5 | — | 6 | 1 |
| 6 | 1, 5 | 15 | 2 |
| 7 | 1, 4 | 11, 12 | 2 |
| 8 | 1 | 11, 14 | 2 |
| 9 | 1, 2, 4 | 14 | 2 |
| 10 | 1, 2 | 15 | 2 |
| 11 | 7, 8 | 12 | 3 |
| 12 | 3, 7, 11 | 13 | 3 |
| 13 | 3, 12 | 15 | 3 |
| 14 | 8, 9 | 15 | 4 |
| 15 | 6-13 | F1-F4 | 4 |
| 16 | 6-13 | F1-F4 | 4 |
| 17 | 2, 3 | 18 | 4 |
| 18 | 17 | F1-F4 | 4 |

### Agent Dispatch Summary

- **Wave 1**: 5 tasks — T1 `quick`, T2 `unspecified-high`, T3 `quick`, T4 `quick`, T5 `unspecified-high`
- **Wave 2**: 5 tasks — T6 `visual-engineering`, T7 `deep`, T8 `visual-engineering`, T9 `visual-engineering`, T10 `visual-engineering`
- **Wave 3**: 3 tasks — T11 `visual-engineering`, T12 `deep`, T13 `deep`
- **Wave 4**: 5 tasks — T14 `quick`, T15 `unspecified-high`, T16 `quick`, T17 `unspecified-high`, T18 `quick`
- **FINAL**: 4 tasks — F1 `oracle`, F2 `unspecified-high`, F3 `unspecified-high`, F4 `deep`

---

## TODOs

### Wave 1 — Infrastructure + Backend API

- [x] 1. Install React + Vite React Plugin

  **What to do**:
  - Run `npm install react react-dom @vitejs/plugin-react`
  - Update `vite.config.ts` to import and add the React plugin to the plugins array
  - Verify the build works: `npx vite build --mode development` should succeed without errors
  - Do NOT add any React entrypoint or component files yet — just the infrastructure

  **Must NOT do**:
  - Install any other npm packages (no React Router, no state management, no UI libs)
  - Modify any existing JavaScript files beyond vite.config.ts
  - Create any React component files

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple package installation and config file update

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4, 5)
  - **Blocks**: Tasks 5, 6, 7, 8, 9, 10 (all React component work)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `vite.config.ts:1-14` — Current Vite config structure. Add React plugin alongside existing RubyPlugin()
  - `package.json:1-14` — Current dependencies. React goes in `dependencies`, plugin goes in `devDependencies`

  **External References**:
  - @vitejs/plugin-react — Vite plugin for React Fast Refresh + JSX transform

  **Acceptance Criteria**:
  - [ ] `npm ls react react-dom @vitejs/plugin-react` shows all three installed
  - [ ] `vite.config.ts` imports and uses the React plugin
  - [ ] `npx vite build --mode development` succeeds with exit code 0

  **QA Scenarios:**

  ```
  Scenario: React packages installed correctly
    Tool: Bash
    Steps:
      1. Run `npm ls react react-dom @vitejs/plugin-react`
      2. Assert exit code 0
      3. Assert output contains `react@` and `react-dom@` and `@vitejs/plugin-react@`
    Expected Result: All three packages listed without errors
    Evidence: .sisyphus/evidence/task-1-npm-ls.txt

  Scenario: Vite build succeeds with React plugin
    Tool: Bash
    Steps:
      1. Run `npx vite build --mode development`
      2. Assert exit code 0
      3. Assert no errors in output
    Expected Result: Build completes successfully
    Evidence: .sisyphus/evidence/task-1-vite-build.txt
  ```

  **Commit**: YES
  - Message: `build: add React and Vite React plugin`
  - Files: `package.json`, `package-lock.json`, `vite.config.ts`
  - Pre-commit: `npx vite build --mode development`

---

- [x] 2. Photo JSON API Endpoint

  **What to do**:
  - Add `respond_to` block to `PhotosController#show` that renders JSON when format is `.json`
  - JSON response shape:
    ```json
    {
      "id": 1,
      "title": "Beach Day",
      "description": "...",
      "image_url": "/rails/active_storage/representations/...",
      "width": 1600,
      "height": 1200,
      "date_text": "Summer 1985",
      "location": { "id": 1, "name": "Nairobi" } | null,
      "event": { "id": 1, "title": "Birthday" } | null,
      "photographer": { "id": 1, "name": "John Doe" } | null,
      "faces": [
        { "id": 1, "x": 0.3, "y": 0.2, "width": 0.1, "height": 0.12, "person": { "id": 1, "name": "Jane" } | null }
      ],
      "people": [
        { "id": 1, "name": "Jane Doe" }
      ],
      "contributions": [
        { "id": 1, "field_name": "Story", "value": "...", "note": "...", "user_email": "alex@example.com", "created_at": "2024-01-15" }
      ],
      "prev_id": 5 | null,
      "next_id": 7 | null
    }
    ```
  - Call `@photo.import_detected_faces!` before rendering JSON (same as HTML action does)
  - For `image_url`, use `rails_representation_url(@photo.oriented_variant(:large))` — this generates the signed Active Storage URL
  - For `prev_id`/`next_id`: query `current_family.photos.recent` to find adjacent photos. Use `@photo.created_at` for ordering. Return `nil` at boundaries
  - Keep the existing HTML response unchanged — just add the JSON format block

  **Must NOT do**:
  - Create a separate API controller or serializer
  - Add pagination
  - Modify the HTML response path

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Multiple concerns (JSON shape, adjacent query, Active Storage URL) requiring careful implementation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4, 5)
  - **Blocks**: Tasks 9, 10, 17
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `app/controllers/people_controller.rb:24-36` — JSON respond_to pattern to follow (especially lines 27-35 showing format.json)
  - `app/controllers/photos_controller.rb:10-13` — Existing show action. Add respond_to block here
  - `app/controllers/people_controller.rb:8-14` — Search action shows how to render JSON with `.map`

  **API/Type References**:
  - `app/models/photo.rb:35-42` — `date_text` and `display_title` methods for JSON fields
  - `app/models/photo.rb:63-70` — `oriented_variant(:large)` for image URL
  - `app/models/photo.rb:19-21` — photo_faces and people associations to include
  - `app/models/photo_face.rb:1-19` — PhotoFace attributes and methods (x, y, width, height, person)
  - `app/models/photo.rb:31-33` — Scopes for ordering photos (`.recent` = `order(created_at: :desc)`)

  **WHY Each Reference Matters**:
  - `people_controller.rb:24-36` — Copy this exact `respond_to` pattern for adding JSON to an existing action
  - `photo.rb:63-70` — MUST use `oriented_variant(:large)` not `image.variant(:large)` to get rotation-corrected image
  - `photo.rb:31-33` — The `.recent` scope defines the ordering for prev/next calculation

  **Acceptance Criteria**:
  - [ ] `GET /photos/:id.json` returns 200 with correct JSON shape
  - [ ] JSON includes `image_url` that resolves to a valid image
  - [ ] JSON includes `faces` array with correct bounding box data
  - [ ] JSON includes `people`, `contributions`, `prev_id`, `next_id`
  - [ ] `GET /photos/:id` (HTML) still renders the existing show page unchanged
  - [ ] `prev_id` is null for the most recent photo, `next_id` is null for the oldest

  **QA Scenarios:**

  ```
  Scenario: Photo JSON endpoint returns complete data
    Tool: Bash (curl)
    Preconditions: Dev server running, signed in as alex@example.com, at least 3 photos exist
    Steps:
      1. Obtain session cookie via login
      2. curl -s -b cookie -H 'Accept: application/json' http://localhost:3000/photos/1.json
      3. Parse response with jq
      4. Assert response contains keys: id, title, image_url, faces, people, contributions, prev_id, next_id
      5. Assert image_url starts with '/rails/active_storage'
      6. Assert faces is an array
    Expected Result: 200 response with all required fields present
    Failure Indicators: 406 Not Acceptable, missing keys, HTML returned instead of JSON
    Evidence: .sisyphus/evidence/task-2-photo-json.json

  Scenario: HTML show page still works
    Tool: Bash (curl)
    Steps:
      1. curl -s -b cookie http://localhost:3000/photos/1
      2. Assert response contains 'face-tagging' (Stimulus controller)
      3. Assert response contains 'photo-face-stage' (existing CSS class)
    Expected Result: HTML show page renders identically to before
    Evidence: .sisyphus/evidence/task-2-html-regression.html

  Scenario: Prev/next at boundaries returns null
    Tool: Bash (curl)
    Steps:
      1. Find the most recent photo ID
      2. curl its JSON endpoint
      3. Assert prev_id is null (no newer photo)
    Expected Result: Boundary photo has null for the appropriate direction
    Evidence: .sisyphus/evidence/task-2-boundary.json
  ```

  **Commit**: YES (groups with Task 3)
  - Message: `feat(api): add JSON responses to photos and photo_faces controllers`
  - Files: `app/controllers/photos_controller.rb`, `app/controllers/photo_faces_controller.rb`
  - Pre-commit: `bundle exec rspec spec/models/photo_spec.rb`

---

- [x] 3. PhotoFaces JSON Responses

  **What to do**:
  - Add `respond_to` blocks to `PhotoFacesController` for `create`, `update`, and `destroy` actions
  - **create** JSON response: return the created face as JSON `{ id, x, y, width, height, person: null }`
  - **update** JSON response: return the updated face as JSON `{ id, x, y, width, height, person: { id, name } | null }`
  - **destroy** JSON response: return `{ success: true }` with status 200
  - On validation failure, return `{ errors: [...] }` with status 422
  - Keep all existing HTML redirect behavior unchanged

  **Must NOT do**:
  - Change the existing HTML response behavior
  - Add new actions or routes
  - Create a serializer or API controller

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Straightforward respond_to additions following established pattern

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 5)
  - **Blocks**: Tasks 12, 13, 17
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `app/controllers/people_controller.rb:24-36` — JSON respond_to pattern (the canonical example in this codebase)
  - `app/controllers/photo_faces_controller.rb:1-45` — Current controller to modify. All three actions need JSON blocks

  **API/Type References**:
  - `app/models/photo_face.rb:1-38` — Model attributes (x, y, width, height, person_id) and validations
  - `app/models/person.rb:15-18` — `full_name` method for person name in JSON response

  **Acceptance Criteria**:
  - [ ] `POST /photos/:id/photo_faces.json` with valid params returns 201 with face JSON
  - [ ] `POST /photos/:id/photo_faces.json` with invalid params returns 422 with errors
  - [ ] `PATCH /photos/:id/photo_faces/:id.json` returns 200 with updated face JSON
  - [ ] `DELETE /photos/:id/photo_faces/:id.json` returns 200
  - [ ] All HTML redirect behavior unchanged

  **QA Scenarios:**

  ```
  Scenario: Create face via JSON
    Tool: Bash (curl)
    Steps:
      1. POST to /photos/1/photo_faces.json with body {"photo_face":{"x":0.3,"y":0.3,"width":0.1,"height":0.1}}
      2. Include X-CSRF-Token header
      3. Assert status 201
      4. Assert response contains id, x, y, width, height keys
    Expected Result: Face created, JSON returned with new ID
    Evidence: .sisyphus/evidence/task-3-create-face.json

  Scenario: Create face with invalid bounds
    Tool: Bash (curl)
    Steps:
      1. POST with body {"photo_face":{"x":0.95,"y":0.95,"width":0.1,"height":0.1}}
      2. Assert status 422
      3. Assert response contains errors array
    Expected Result: Validation error returned
    Evidence: .sisyphus/evidence/task-3-invalid-face.json

  Scenario: Delete face via JSON
    Tool: Bash (curl)
    Steps:
      1. DELETE /photos/1/photo_faces/:id.json
      2. Assert status 200
      3. Verify face no longer exists (GET parent photo JSON, check faces array)
    Expected Result: Face removed, success response
    Evidence: .sisyphus/evidence/task-3-delete-face.json
  ```

  **Commit**: YES (groups with Task 2)
  - Message: `feat(api): add JSON responses to photos and photo_faces controllers`
  - Files: `app/controllers/photo_faces_controller.rb`
  - Pre-commit: `bin/rubocop app/controllers/photo_faces_controller.rb`

---

- [x] 4. CSS Foundation — _photo_view.scss

  **What to do**:
  - Create `app/assets/stylesheets/_photo_view.scss` with the `.photo-view-modal` namespace
  - Define base styles for the full-screen overlay, image container, toolbar, sidebar layout, and responsive breakpoint
  - Key CSS concerns:
    - `.photo-view-modal` — fixed overlay, `inset: 0`, `z-index: 1050` (above Tabler's modals at 1040), black background `rgba(0,0,0,0.95)`
    - `.photo-view-modal__content` — flexbox container, photo area + sidebar side-by-side
    - `.photo-view-modal__image-area` — `flex: 1`, overflow hidden, position relative (for face boxes)
    - `.photo-view-modal__sidebar` — `width: 360px`, `flex-shrink: 0`, white background, overflow-y auto
    - `.photo-view-modal__toolbar` — position absolute top-right, flex row, gap, z-index above image
    - `.photo-view-modal__close` — position absolute top-left
    - `.photo-view-modal__nav-arrow` — position absolute, vertically centered, left/right edges of image area
    - `.photo-view-modal__face-box` — position absolute, border: 2px solid white, opacity 0.5, hover opacity 1, transition
    - `.photo-view-modal__tag-overlay` — position absolute bottom of image area, text overlay for tag mode
    - Responsive: `@media (max-width: 899px)` — hide sidebar, photo fills full width
    - Fullscreen mode: `.photo-view-modal--fullscreen .photo-view-modal__sidebar { display: none }`
  - Import the partial in `app/assets/stylesheets/application.scss` via `@import 'photo_view'`
  - Use Tabler color variables where available (e.g., `$primary`, `$secondary`)
  - Match existing SCSS style from `application.scss` (BEM-like naming, no nesting deeper than 3 levels)

  **Must NOT do**:
  - Add global styles that affect anything outside `.photo-view-modal`
  - Use CSS Modules or Shadow DOM
  - Import external CSS libraries
  - Modify existing styles in `application.scss` beyond adding the import

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Single SCSS file creation with well-defined naming conventions

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 5)
  - **Blocks**: Tasks 7, 9
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `app/assets/stylesheets/application.scss:1-87` — Existing SCSS patterns. Follow the same flat/BEM style. Import the new partial at the end of this file
  - `app/assets/stylesheets/application.scss:19-44` — `.photo-face-box` styling pattern for face box borders, hover effects, transitions — adapt this for the modal's face boxes
  - `app/views/layouts/application.html.erb:11-12` — Tabler CSS CDN URLs to understand available utility classes

  **WHY Each Reference Matters**:
  - `application.scss` — Must match the code style (indentation, naming, nesting depth) and add the import at the end
  - `.photo-face-box` — The existing face box styles are the direct inspiration for the modal's face tagging boxes

  **Acceptance Criteria**:
  - [ ] `app/assets/stylesheets/_photo_view.scss` exists with `.photo-view-modal` namespace
  - [ ] `application.scss` imports `_photo_view`
  - [ ] No global styles leak outside the namespace
  - [ ] Responsive breakpoint at 899px hides sidebar

  **QA Scenarios:**

  ```
  Scenario: SCSS file has correct namespace
    Tool: Bash (grep)
    Steps:
      1. grep -c 'photo-view-modal' app/assets/stylesheets/_photo_view.scss
      2. Assert count > 10 (many namespaced selectors)
      3. grep 'photo_view' app/assets/stylesheets/application.scss
      4. Assert import line exists
    Expected Result: All styles namespaced, import present
    Evidence: .sisyphus/evidence/task-4-scss-namespace.txt

  Scenario: No global style leaks
    Tool: Bash (grep)
    Steps:
      1. grep -P '^[a-z]' app/assets/stylesheets/_photo_view.scss (selectors not starting with . or &)
      2. Assert zero matches (all selectors should be class-based under the namespace)
    Expected Result: No bare element selectors or global classes
    Evidence: .sisyphus/evidence/task-4-no-global-leaks.txt
  ```

  **Commit**: YES (groups with Task 5)
  - Message: `feat(photo-view): add Stimulus bridge controller and CSS foundation`
  - Files: `app/assets/stylesheets/_photo_view.scss`, `app/assets/stylesheets/application.scss`
  - Pre-commit: `bin/rubocop`

---

- [x] 5. Stimulus Bridge Controller + Gallery Grid Wiring

  **What to do**:
  - Create `app/javascript/controllers/photo_view_controller.js` — a Stimulus controller that:
    - On `connect()`: does nothing immediately (lazy mount)
    - Defines an action `open` that:
      1. Creates a mount point div (`<div id="photo-view-root">`) and appends it to `document.body`
      2. Dynamically imports the React component: `const { PhotoViewApp } = await import('../components/PhotoView/PhotoViewApp')`
      3. Calls `createRoot(mountPoint).render(<PhotoViewApp ...props />)`
      4. Stores the root reference for cleanup
    - Defines a `close` method that unmounts React and removes the mount div
    - On `disconnect()`: calls `close()` if mounted (prevents stale DOM when Turbo caches)
    - Passes these props to React: `photoId` (from clicked thumbnail), `photoIds` (ordered array of all photo IDs in gallery), `csrfToken` (from meta tag)
  - Register it in `app/javascript/controllers/index.js`
  - Update `app/views/photos/index.html.erb`:
    - Wrap the photo grid in a container with `data-controller="photo-view"` and `data-photo-view-photo-ids-value="<%= @photos.pluck(:id).to_json %>"`
    - Change each thumbnail's `link_to photo_path(photo)` to a `button_tag` (or `link_to '#'`) with `data-action="click->photo-view#open"` and `data-photo-id="<%= photo.id %>"`
    - Prevent default navigation on click

  **Must NOT do**:
  - Create any React component files (that's Wave 2)
  - Modify the existing show page
  - Add React Router or client-side routing
  - Render React on page load — only on explicit user click

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Involves Stimulus controller creation, dynamic import pattern, and ERB template modification

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 4)
  - **Blocks**: Task 6
  - **Blocked By**: None (React package install happens in parallel, dynamic import won't resolve until React is installed, but the controller file itself can be written)

  **References**:

  **Pattern References**:
  - `app/javascript/controllers/index.js:1-9` — Manual controller registration pattern. Add the new controller import + register here
  - `app/javascript/controllers/person_autocomplete_controller.js:10-17` — Stimulus lifecycle methods (connect, disconnect) and cleanup pattern
  - `app/javascript/controllers/person_autocomplete_controller.js:141-148` — CSRF token extraction pattern: `document.querySelector("meta[name='csrf-token']")?.content`
  - `app/views/photos/index.html.erb:14-41` — Current gallery grid markup to modify. Each photo is a card with a link_to

  **External References**:
  - React 18 createRoot API — `import { createRoot } from 'react-dom/client'`

  **WHY Each Reference Matters**:
  - `controllers/index.js` — MUST add the new controller here or it won't be registered. This file uses manual registration, not auto-loading
  - `person_autocomplete_controller.js:141-148` — The exact CSRF token pattern to extract and pass to React as a prop
  - `photos/index.html.erb` — The gallery grid that will become the mount trigger. Must understand current structure to modify correctly

  **Acceptance Criteria**:
  - [ ] `photo_view_controller.js` exists and is registered in `index.js`
  - [ ] Gallery thumbnails have `data-action="click->photo-view#open"` and `data-photo-id`
  - [ ] Gallery container has `data-photo-view-photo-ids-value` with JSON array of IDs
  - [ ] Clicking a thumbnail does NOT navigate to the show page
  - [ ] `disconnect()` properly unmounts React if mounted

  **QA Scenarios:**

  ```
  Scenario: Gallery thumbnails have correct data attributes
    Tool: Playwright
    Preconditions: Dev server running, signed in, photos exist in gallery
    Steps:
      1. Navigate to /photos
      2. Assert at least one element with [data-action*="photo-view#open"] exists
      3. Assert container has [data-photo-view-photo-ids-value] attribute
      4. Parse the photo-ids-value as JSON, assert it's a non-empty array of numbers
    Expected Result: Gallery markup has all required data attributes for React mounting
    Failure Indicators: Missing data attributes, empty photo IDs array
    Evidence: .sisyphus/evidence/task-5-gallery-attributes.png

  Scenario: Thumbnail click does not navigate
    Tool: Playwright
    Steps:
      1. Navigate to /photos
      2. Note current URL
      3. Click first thumbnail
      4. Assert URL has NOT changed to /photos/:id
    Expected Result: Click is intercepted, no page navigation
    Evidence: .sisyphus/evidence/task-5-no-navigate.png
  ```

  **Commit**: YES (groups with Task 4)
  - Message: `feat(photo-view): add Stimulus bridge controller and CSS foundation`
  - Files: `app/javascript/controllers/photo_view_controller.js`, `app/javascript/controllers/index.js`, `app/views/photos/index.html.erb`
  - Pre-commit: `bin/rubocop`

---

### Wave 2 — Core React Components

- [x] 6. PhotoViewModal — Root Component + Overlay

  **What to do**:
  - Create `app/javascript/components/PhotoView/PhotoViewApp.jsx` — the root React component exported for the Stimulus bridge
  - Create `app/javascript/components/PhotoView/PhotoViewModal.jsx` — the full-screen overlay component
  - PhotoViewApp receives props from Stimulus: `{ photoId, photoIds, csrfToken, onClose }`
  - PhotoViewApp manages top-level state: `currentPhotoId`, `photoData` (fetched), `isFullscreen`, `zoomLevel`, `isTagMode`
  - PhotoViewModal renders:
    - Fixed overlay div with `.photo-view-modal` class on `document.body` (via React portal or direct mount)
    - Dark background (`rgba(0,0,0,0.95)`)
    - Close button (X) top-left using Tabler icon `ti ti-x` — calls `onClose`
    - Prevent body scroll when modal is open (`document.body.style.overflow = 'hidden'`, restore on unmount)
    - Keyboard handler: `Escape` closes modal
    - On mount: fetch photo data from `/photos/:id.json`, set loading state
    - `history.replaceState(null, '', '/photos/' + currentPhotoId)` when photo changes
    - On unmount: restore original URL via `replaceState`
  - Create `app/javascript/components/PhotoView/api.js` — shared fetch helper:
    - `fetchPhoto(photoId)` — GET `/photos/:id.json` with Accept: application/json
    - `createFace(photoId, faceData, csrfToken)` — POST
    - `updateFace(photoId, faceId, data, csrfToken)` — PATCH
    - `deleteFace(photoId, faceId, csrfToken)` — DELETE
    - `searchPeople(query)` — GET `/people/search?q=`
    - All include CSRF token header pattern from `person_autocomplete_controller.js`

  **Must NOT do**:
  - Add React Router or any routing library
  - Use `history.pushState` (use `replaceState` only)
  - Create a generic Modal component — build specifically for PhotoView
  - Add any npm dependencies

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: UI overlay component with DOM management (scroll lock, keyboard, URL)

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7, 8, 9, 10)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 1, 5

  **References**:

  **Pattern References**:
  - `app/javascript/controllers/person_autocomplete_controller.js:37-47` — Fetch pattern with headers (Accept: application/json)
  - `app/javascript/controllers/person_autocomplete_controller.js:141-148` — CSRF token + POST/JSON pattern to replicate in api.js
  - `app/assets/stylesheets/_photo_view.scss` — CSS classes to apply (created in Task 4)

  **API/Type References**:
  - Task 2's JSON response shape — the exact JSON structure that `fetchPhoto()` returns
  - `app/views/layouts/application.html.erb:7` — `csrf_meta_tags` proves the meta tag exists for CSRF extraction

  **Acceptance Criteria**:
  - [ ] `PhotoViewApp.jsx` and `PhotoViewModal.jsx` exist in `app/javascript/components/PhotoView/`
  - [ ] `api.js` exists with all fetch helpers
  - [ ] Modal renders as fixed overlay with dark background
  - [ ] Close button (X) renders top-left and calls onClose
  - [ ] Escape key closes modal
  - [ ] Body scroll is locked when modal is open, restored when closed
  - [ ] URL updates to `/photos/:id` when viewing a photo

  **QA Scenarios:**

  ```
  Scenario: Modal opens and displays photo
    Tool: Playwright
    Preconditions: Dev server running, signed in, photos in gallery
    Steps:
      1. Navigate to /photos
      2. Click first thumbnail (element with [data-action*="photo-view#open"])
      3. Wait for .photo-view-modal to appear (timeout: 5s)
      4. Assert .photo-view-modal is visible with position: fixed
      5. Assert close button (.photo-view-modal__close) is visible
      6. Assert an img element is present within the modal
    Expected Result: Full-screen modal overlay with photo and close button
    Failure Indicators: No modal appears, 404 on JSON fetch, no image
    Evidence: .sisyphus/evidence/task-6-modal-open.png

  Scenario: Escape key closes modal
    Tool: Playwright
    Steps:
      1. Open modal (click thumbnail)
      2. Press Escape key
      3. Assert .photo-view-modal is no longer in DOM
      4. Assert body scroll is restored (overflow is not hidden)
    Expected Result: Modal closes on Escape, body scroll unlocked
    Evidence: .sisyphus/evidence/task-6-escape-close.png

  Scenario: Close button (X) closes modal
    Tool: Playwright
    Steps:
      1. Open modal
      2. Click .photo-view-modal__close button
      3. Assert modal is removed from DOM
    Expected Result: Modal closes cleanly
    Evidence: .sisyphus/evidence/task-6-x-close.png
  ```

  **Commit**: YES (groups with Tasks 7-10)
  - Message: `feat(photo-view): core React component shell — modal, image, toolbar, sidebar, navigation`
  - Files: `app/javascript/components/PhotoView/*.jsx`, `app/javascript/components/PhotoView/api.js`
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 7. PhotoImage — Display, Zoom, Pan

  **What to do**:
  - Create `app/javascript/components/PhotoView/PhotoImage.jsx`
  - Receives props: `{ imageUrl, zoomLevel, onZoomChange, isTagMode, faces, onFaceClick, onImageClick }`
  - Image display:
    - `<img>` element with `object-fit: contain` to fill available space
    - Apply CSS transform: `transform: scale(${zoomScale})` where zoomScale maps levels 0-3 to [1, 1.5, 2.25, 3.375]
    - `transform-origin` follows the center of the viewport (or last pan position)
  - Zoom behavior:
    - 4 discrete levels: 0=1x, 1=1.5x, 2=2.25x, 3=3.375x
    - Controlled by parent state via `zoomLevel` prop and `onZoomChange` callback
    - When zoom level increases, preserve the visual center point
  - Pan behavior (only when zoomLevel > 0):
    - On mousedown: start tracking, store initial mouse position and current translate offset
    - On mousemove: calculate delta, apply `translate(dx, dy)` combined with the scale transform
    - On mouseup/mouseleave: stop tracking
    - Clamp translate so the image edges don't go past the container edges
    - `cursor: grab` when zoomed, `cursor: grabbing` while dragging
  - When `zoomLevel` changes to 0 (zoom out to fit): reset translate to (0, 0)
  - Position face boxes as absolute overlays on the image (percentage-based from face data)
  - When NOT in tag mode and NOT zoomed, show face labels on hover

  **Must NOT do**:
  - Use any zoom/pan library (build from CSS transforms + mouse events)
  - Add mobile touch/pinch-to-zoom
  - Handle tag creation (that's Task 12)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: Complex coordinate math for zoom transforms, pan clamping, and face overlay positioning. Requires careful CSS transform calculations

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6, 8, 9, 10)
  - **Blocks**: Tasks 11, 12
  - **Blocked By**: Tasks 1, 4

  **References**:

  **Pattern References**:
  - `app/assets/stylesheets/application.scss:19-44` — Existing `.photo-face-box` styling for face overlays. Adapt border, hover, and positioning pattern
  - `app/views/photos/show.html.erb:19-40` — How face boxes are currently positioned with percentage-based CSS (`left: x%, top: y%, width: w%, height: h%`). Use same approach in React
  - `app/assets/stylesheets/_photo_view.scss` — CSS classes for `.photo-view-modal__image-area` and face boxes (created in Task 4)

  **API/Type References**:
  - `app/models/photo_face.rb:6-8` — Face data shape: x, y, width, height (all 0-1 normalized floats)

  **WHY Each Reference Matters**:
  - `show.html.erb:19-40` — Shows the exact pattern for converting 0-1 normalized coordinates to CSS percentages
  - `application.scss:19-44` — Face box visual styling to match for consistency between show page and modal

  **Acceptance Criteria**:
  - [ ] Image displays correctly within container with `object-fit: contain`
  - [ ] 4 zoom levels work: 1x, 1.5x, 2.25x, 3.375x
  - [ ] Pan works when zoomed: drag moves the image within the container
  - [ ] Pan is clamped — image edges don't go past container
  - [ ] Zoom to level 0 resets pan position
  - [ ] Face boxes render at correct positions (percentage-based from face data)
  - [ ] Cursor changes to grab/grabbing when zoomed

  **QA Scenarios:**

  ```
  Scenario: Zoom levels work
    Tool: Playwright
    Steps:
      1. Open photo modal
      2. Assert image has transform: scale(1) (or no transform)
      3. Click zoom-in button (.photo-view-modal__toolbar-btn--zoom-in)
      4. Assert image container has CSS transform containing scale(1.5)
      5. Click zoom-in again
      6. Assert transform contains scale(2.25)
      7. Click zoom-in again
      8. Assert transform contains scale(3.375)
    Expected Result: Each click increases zoom by 1.5x multiplier
    Failure Indicators: No transform change, wrong scale values
    Evidence: .sisyphus/evidence/task-7-zoom-levels.png

  Scenario: Pan works when zoomed
    Tool: Playwright
    Steps:
      1. Open modal, zoom in once
      2. Mouse down on image, drag 100px right and 50px down
      3. Mouse up
      4. Assert image transform includes translate values
      5. Assert cursor was 'grabbing' during drag
    Expected Result: Image pans with mouse drag, clamped to container
    Evidence: .sisyphus/evidence/task-7-pan.png

  Scenario: Zoom out resets pan
    Tool: Playwright
    Steps:
      1. Open modal, zoom in twice, pan to a corner
      2. Click zoom-out twice to return to 1x
      3. Assert transform is scale(1) with no translate offset
    Expected Result: Pan resets to center when fully zoomed out
    Evidence: .sisyphus/evidence/task-7-zoom-reset-pan.png
  ```

  **Commit**: YES (groups with Tasks 6, 8, 9, 10)
  - Message: `feat(photo-view): core React component shell — modal, image, toolbar, sidebar, navigation`
  - Files: `app/javascript/components/PhotoView/PhotoImage.jsx`
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 8. PhotoToolbar — Action Buttons

  **What to do**:
  - Create `app/javascript/components/PhotoView/PhotoToolbar.jsx`
  - Receives props: `{ zoomLevel, maxZoom, isTagMode, isFullscreen, onZoomIn, onZoomOut, onToggleTag, onToggleFullscreen }`
  - Renders 4 icon buttons in a horizontal group, top-right of modal:
    1. **Zoom In** (`ti ti-zoom-in`): calls `onZoomIn`. Disabled when `zoomLevel >= maxZoom` (level 3)
    2. **Zoom Out** (`ti ti-zoom-out`): calls `onZoomOut`. Disabled when `zoomLevel <= 0`
    3. **Tag** (`ti ti-tag`): calls `onToggleTag`. Disabled when `zoomLevel > 0`. Active state when `isTagMode` is true
    4. **Fullscreen** (`ti ti-arrows-maximize` / `ti ti-arrows-minimize`): calls `onToggleFullscreen`. Icon changes based on `isFullscreen`
  - Disabled buttons: `opacity: 0.3`, `pointer-events: none`, `cursor: not-allowed`
  - Active tag button: highlighted border/background to indicate tag mode is on
  - When `isTagMode` is true: zoom in and zoom out buttons are disabled
  - Buttons use Tabler icon classes (already loaded via CDN)

  **Must NOT do**:
  - Implement zoom/tag/fullscreen logic (just call callbacks)
  - Add tooltips or dropdown menus
  - Use an icon library beyond Tabler Icons (already loaded via CDN)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: UI component with icons and state-driven visual feedback

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6, 7, 9, 10)
  - **Blocks**: Tasks 11, 14
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `app/views/layouts/application.html.erb:12` — Tabler Icons CDN URL (confirms `ti ti-*` classes are available globally)
  - `app/views/photos/index.html.erb:4-13` — Button/icon usage pattern in the app (`<i class="ti ti-upload icon"></i>`)
  - `app/assets/stylesheets/_photo_view.scss` — `.photo-view-modal__toolbar` CSS class (from Task 4)

  **Acceptance Criteria**:
  - [ ] 4 buttons render top-right of modal
  - [ ] Zoom in disabled at max zoom (level 3)
  - [ ] Zoom out disabled at min zoom (level 0)
  - [ ] Tag disabled when zoomed (level > 0)
  - [ ] Zoom buttons disabled when in tag mode
  - [ ] Fullscreen icon toggles between maximize/minimize
  - [ ] Tag button shows active state when tag mode is on

  **QA Scenarios:**

  ```
  Scenario: Toolbar button disable states
    Tool: Playwright
    Steps:
      1. Open modal (zoom level = 0)
      2. Assert zoom-out button is disabled
      3. Assert tag button is NOT disabled
      4. Click zoom-in button
      5. Assert tag button IS disabled (zoom > 0)
      6. Assert zoom-out button is NOT disabled
      7. Click zoom-in 3 more times to reach max
      8. Assert zoom-in button IS disabled
    Expected Result: Buttons enable/disable correctly based on state
    Failure Indicators: Button clickable when it should be disabled, or disabled when it should be enabled
    Evidence: .sisyphus/evidence/task-8-toolbar-states.png

  Scenario: Tag mode disables zoom
    Tool: Playwright
    Steps:
      1. Open modal at zoom level 0
      2. Click tag button
      3. Assert tag button has active/highlighted style
      4. Assert zoom-in button is disabled
      5. Assert zoom-out button is disabled
    Expected Result: Entering tag mode locks zoom controls
    Evidence: .sisyphus/evidence/task-8-tag-disables-zoom.png
  ```

  **Commit**: YES (groups with Tasks 6, 7, 9, 10)
  - Message: `feat(photo-view): core React component shell — modal, image, toolbar, sidebar, navigation`
  - Files: `app/javascript/components/PhotoView/PhotoToolbar.jsx`
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 9. PhotoSidebar — Details, People, Contributions (Read-Only)

  **What to do**:
  - Create `app/javascript/components/PhotoView/PhotoSidebar.jsx`
  - Receives props: `{ photoData, isVisible }` (photoData is the JSON response from Task 2)
  - Renders a 360px-wide right-side panel with white background, scrollable
  - Sections:
    1. **Details**: Date (photoData.date_text), Location (name, linked), Event (title, linked), Photographer (name, linked)
    2. **People**: List of tagged people (from photoData.people array) as badges/chips. Each shows person name. NOT editable — read-only display
    3. **Contributions**: List of contributions (from photoData.contributions array). Each shows field_name, value, note, user_email, date. Chronological order
  - Use Tabler CSS classes for card structure, definition lists, badges
  - When `isVisible` is false (fullscreen mode or below 900px), the sidebar is hidden via CSS
  - The sidebar does NOT contain any forms or editable elements
  - Add a link at the bottom: "View full details →" that links to `/photos/:id` (the existing show page) — opens in a new context (not within the modal)

  **Must NOT do**:
  - Add any forms (contribution form, person tagging dropdown)
  - Make anything editable
  - Fetch data independently (receives everything from parent via props)
  - Use React Router for links

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: Layout component with read-only data display using Tabler CSS

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6, 7, 8, 10)
  - **Blocks**: Task 14
  - **Blocked By**: Tasks 1, 2, 4

  **References**:

  **Pattern References**:
  - `app/views/photos/show.html.erb:146-226` — Current sidebar HTML structure. Mirror this layout in React using the same Tabler CSS classes (card, card-header, card-body, dl, row, etc.)
  - `app/views/photos/show.html.erb:86-96` — People badges display pattern. Use similar badge markup
  - `app/views/photos/show.html.erb:107-126` — Contributions list display pattern. Follow this structure

  **API/Type References**:
  - Task 2's JSON response shape — defines the exact data structure for `photoData` props

  **WHY Each Reference Matters**:
  - `show.html.erb:146-226` — The sidebar in the modal should look visually similar to the existing show page sidebar. Copy the Tabler class usage
  - `show.html.erb:86-96` — People are displayed as badges. Use the same `badge bg-primary-lt` pattern

  **Acceptance Criteria**:
  - [ ] Sidebar renders at 360px width on the right
  - [ ] Details section shows date, location, event, photographer from photo data
  - [ ] People section shows tagged people as badges
  - [ ] Contributions section shows list of contributions with field, value, user, date
  - [ ] No forms or editable elements in sidebar
  - [ ] "View full details" link points to `/photos/:id`
  - [ ] Sidebar hidden when fullscreen mode active

  **QA Scenarios:**

  ```
  Scenario: Sidebar displays photo details
    Tool: Playwright
    Preconditions: Photo has date, location, people tagged, and contributions
    Steps:
      1. Open modal for a photo with known data
      2. Assert .photo-view-modal__sidebar is visible
      3. Assert sidebar width is 360px
      4. Assert date text is displayed
      5. Assert at least one person badge is shown
      6. Assert at least one contribution is shown
    Expected Result: Sidebar shows all photo metadata, people, and contributions
    Failure Indicators: Empty sidebar, missing sections, 0px width
    Evidence: .sisyphus/evidence/task-9-sidebar-content.png

  Scenario: Sidebar has no forms
    Tool: Playwright
    Steps:
      1. Open modal
      2. Query sidebar for form, input, select, textarea elements
      3. Assert zero matches
    Expected Result: Sidebar is purely read-only
    Evidence: .sisyphus/evidence/task-9-sidebar-no-forms.png
  ```

  **Commit**: YES (groups with Tasks 6, 7, 8, 10)
  - Message: `feat(photo-view): core React component shell — modal, image, toolbar, sidebar, navigation`
  - Files: `app/javascript/components/PhotoView/PhotoSidebar.jsx`
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 10. PhotoNavigation — Prev/Next Arrows + Keyboard

  **What to do**:
  - Create `app/javascript/components/PhotoView/PhotoNavigation.jsx`
  - Receives props: `{ prevId, nextId, onNavigate, isTagMode }`
  - Renders two arrow buttons, one on each side of the image area:
    - Left arrow: `ti ti-chevron-left`, positioned vertically centered on the left edge of the image area
    - Right arrow: `ti ti-chevron-right`, vertically centered on the right edge
  - Left arrow calls `onNavigate(prevId)`, disabled/hidden when `prevId` is null
  - Right arrow calls `onNavigate(nextId)`, disabled/hidden when `nextId` is null
  - Semi-transparent background, visible on hover (Facebook-style)
  - Keyboard navigation registered in the PhotoViewModal (parent):
    - Left arrow key: navigate to prevId (if not null and not in tag mode)
    - Right arrow key: navigate to nextId (if not null and not in tag mode)
  - When navigating: parent fetches new photo data, updates state, resets zoom to 0, exits tag mode
  - Disable navigation while in tag mode (creating a face box should not accidentally navigate)

  **Must NOT do**:
  - Prefetch adjacent photo data (fetch on navigate)
  - Add animation/transitions between photos
  - Handle swipe gestures

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: UI navigation arrows with keyboard handler integration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6, 7, 8, 9)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 1, 2

  **References**:

  **Pattern References**:
  - `app/assets/stylesheets/_photo_view.scss` — `.photo-view-modal__nav-arrow` CSS class for positioning (from Task 4)

  **API/Type References**:
  - Task 2's JSON response — `prev_id` and `next_id` fields drive the navigation buttons

  **Acceptance Criteria**:
  - [ ] Left and right arrow buttons render on image area edges
  - [ ] Left arrow hidden/disabled when viewing the first photo (prevId is null)
  - [ ] Right arrow hidden/disabled when viewing the last photo (nextId is null)
  - [ ] Clicking an arrow loads the adjacent photo
  - [ ] Keyboard left/right arrows navigate between photos
  - [ ] Navigation resets zoom level to 0 and exits tag mode
  - [ ] Navigation disabled while in tag mode

  **QA Scenarios:**

  ```
  Scenario: Navigate to next photo
    Tool: Playwright
    Preconditions: Gallery has at least 3 photos
    Steps:
      1. Open modal for a middle photo (not first or last)
      2. Assert both left and right arrows are visible
      3. Click right arrow
      4. Wait for image to update (new src or loading state)
      5. Assert URL has changed to new photo ID
      6. Assert photo content has changed (different image_url or title in sidebar)
    Expected Result: Navigated to next photo, URL updated
    Failure Indicators: Same photo displayed, URL unchanged, error
    Evidence: .sisyphus/evidence/task-10-navigate-next.png

  Scenario: Keyboard navigation
    Tool: Playwright
    Steps:
      1. Open modal for a middle photo
      2. Press Right Arrow key
      3. Assert photo changed
      4. Press Left Arrow key
      5. Assert returned to original photo
    Expected Result: Keyboard arrows navigate between photos
    Evidence: .sisyphus/evidence/task-10-keyboard-nav.png

  Scenario: Navigation at boundary
    Tool: Playwright
    Steps:
      1. Open modal for the first photo in gallery
      2. Assert left arrow is hidden or disabled
      3. Assert right arrow is visible
    Expected Result: Cannot navigate before first photo
    Evidence: .sisyphus/evidence/task-10-boundary.png
  ```

  **Commit**: YES (groups with Tasks 6, 7, 8, 9)
  - Message: `feat(photo-view): core React component shell — modal, image, toolbar, sidebar, navigation`
  - Files: `app/javascript/components/PhotoView/PhotoNavigation.jsx`
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

### Wave 3 — Tagging System

- [x] 11. Tag Mode Activation + Overlay Text

  **What to do**:
  - Implement tag mode toggle in `PhotoViewApp.jsx` state management:
    - `isTagMode` state boolean, toggled by toolbar Tag button (Task 8)
    - When `isTagMode` becomes true: `zoomLevel` must be 0 (zoom buttons disable per Task 8)
    - When `zoomLevel` changes to > 0: `isTagMode` becomes false
  - Create `app/javascript/components/PhotoView/TagOverlay.jsx`:
    - Renders when `isTagMode` is true
    - Positioned at the bottom of the image area (overlaid on top of the photo)
    - Displays text: "Click on the photo to start tagging. Click on a tag to remove it."
    - Below the text: "Finished tagging" button that exits tag mode (`isTagMode = false`)
    - Semi-transparent dark background strip for readability
  - When entering tag mode:
    - Existing face boxes become interactive (clickable to remove)
    - Photo becomes clickable to create new face boxes (click handler added)
  - When exiting tag mode:
    - Any pending (unsaved) face box is dismissed
    - Face boxes return to display-only mode

  **Must NOT do**:
  - Implement the actual face box creation (that's Task 12)
  - Implement the remove-tag interaction (that's Task 13)
  - Just wire up the mode toggle and overlay UI

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: UI overlay with mode-switching state management

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T12 if split carefully, but safer sequential)
  - **Parallel Group**: Wave 3 start
  - **Blocks**: Task 12
  - **Blocked By**: Tasks 7, 8

  **References**:

  **Pattern References**:
  - `app/views/photos/show.html.erb:69-74` — Existing tag mode status text pattern ("Select a face box..." text). Adapt for the modal's overlay
  - `app/assets/stylesheets/_photo_view.scss` — `.photo-view-modal__tag-overlay` CSS class (from Task 4)

  **Acceptance Criteria**:
  - [ ] Clicking Tag button toggles `isTagMode` state
  - [ ] Overlay text appears at bottom of image area when in tag mode
  - [ ] "Finished tagging" button exits tag mode
  - [ ] Tag mode and zoom are mutually exclusive
  - [ ] Overlay text matches exactly: "Click on the photo to start tagging. Click on a tag to remove it."

  **QA Scenarios:**

  ```
  Scenario: Tag mode toggle and overlay
    Tool: Playwright
    Steps:
      1. Open modal
      2. Click tag button in toolbar
      3. Assert .photo-view-modal__tag-overlay is visible
      4. Assert text contains "Click on the photo to start tagging"
      5. Assert "Finished tagging" button is visible
      6. Click "Finished tagging"
      7. Assert overlay is no longer visible
    Expected Result: Tag mode shows/hides overlay with correct text
    Evidence: .sisyphus/evidence/task-11-tag-overlay.png

  Scenario: Tag mode forces zoom to 0
    Tool: Playwright
    Steps:
      1. Open modal, zoom in once (level 1)
      2. Assert tag button is disabled
      3. Zoom out to level 0
      4. Assert tag button is now enabled
      5. Click tag button
      6. Assert zoom-in button is disabled
    Expected Result: Mutual exclusion between tag mode and zoom
    Evidence: .sisyphus/evidence/task-11-tag-zoom-exclusive.png
  ```

  **Commit**: YES (groups with Tasks 12, 13)
  - Message: `feat(photo-view): face tagging system — create, remove, autocomplete, click-outside`
  - Files: `app/javascript/components/PhotoView/TagOverlay.jsx`, modifications to PhotoViewApp.jsx
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 12. Face Box Creation + Person Autocomplete

  **What to do**:
  - Create `app/javascript/components/PhotoView/FaceBoxCreator.jsx` (or add to PhotoImage.jsx):
    - When in tag mode and user clicks on the photo:
      1. Calculate click position relative to the image as normalized 0-1 coordinates
      2. Create a box centered on the click point, ~10% of the image dimensions (width: 0.1, height: 0.1)
      3. Clamp box so `x + width <= 1` and `y + height <= 1` (and `x >= 0`, `y >= 0`)
      4. Render the box with white border, 50% opacity (full opacity on hover)
      5. Show the autocomplete dropdown near the box
  - Create `app/javascript/components/PhotoView/PersonAutocomplete.jsx`:
    - Text input that searches people via `GET /people/search?q=` (from api.js)
    - 250ms debounce on input
    - Dropdown shows matching people: clicking a name:
      1. POST `/photos/:id/photo_faces.json` to create the face (x, y, width, height)
      2. PATCH `/photos/:id/photo_faces/:id.json` to assign the person_id
      3. Or: create with person_id in one POST if the controller supports it (it does — `photo_face_params` includes `person_id`)
      4. On success: dismiss the autocomplete, show the face as a tagged callout (name label)
      5. Re-fetch photo data to update state with new face
    - Dropdown also shows "Create new person..." option (follow pattern from `person_autocomplete_controller.js:87-120`)
    - If input is empty and user clicks, show all recent people (or just show empty state)
  - The CSRF token is passed from PhotoViewApp props (originally from Stimulus bridge)
  - Auto-focus the text input when the autocomplete appears

  **Must NOT do**:
  - Resize or drag face boxes (fixed size at ~10%)
  - Allow multiple pending boxes at once (one at a time)
  - Skip the clamping logic for edge boxes

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: Complex interaction: coordinate math, AJAX chain (create face + assign person), autocomplete with debounce, dropdown positioning

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on T11 for tag mode)
  - **Parallel Group**: Wave 3 (after T11)
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 3, 7, 11

  **References**:

  **Pattern References**:
  - `app/javascript/controllers/person_autocomplete_controller.js:25-47` — Search with debounce pattern (250ms timeout, fetch, dropdown render). Replicate this logic in React
  - `app/javascript/controllers/person_autocomplete_controller.js:49-66` — Dropdown rendering with person names as buttons. Adapt for React
  - `app/javascript/controllers/person_autocomplete_controller.js:87-165` — "Create new person" inline form pattern. Port to React
  - `app/javascript/controllers/person_autocomplete_controller.js:127-166` — AJAX create person with CSRF + error handling

  **API/Type References**:
  - `app/controllers/photo_faces_controller.rb:42-44` — `photo_face_params` accepts `person_id, x, y, width, height, confidence`. Can create face WITH person in one POST
  - `app/models/photo_face.rb:6-9` — Validations: x,y 0-1, width,height >0 <=1, must fit within photo. Frontend clamping prevents rejection
  - `app/controllers/people_controller.rb:8-14` — Search endpoint: `GET /people/search?q=` returns `[{id, name}]`
  - `app/controllers/people_controller.rb:24-36` — Create person endpoint for "Create new person" flow

  **WHY Each Reference Matters**:
  - `person_autocomplete_controller.js` — This is the EXISTING autocomplete. The React version should behave identically (same debounce, same dropdown structure, same create-new-person flow)
  - `photo_face.rb:6-9` — The validation rules define what the frontend must clamp to prevent 422 errors
  - `photo_faces_controller.rb:42-44` — Shows that person_id is in permitted params, so face can be created with person assignment in a single POST

  **Acceptance Criteria**:
  - [ ] Clicking photo in tag mode creates a face box at click position
  - [ ] Box is ~10% of image dimensions, centered on click, white border, 50% opacity
  - [ ] Box at image edge is clamped to fit within bounds
  - [ ] Autocomplete input appears and auto-focuses
  - [ ] Typing searches people with 250ms debounce
  - [ ] Clicking a person name creates the face via AJAX
  - [ ] On success: box shows person name label, autocomplete dismisses
  - [ ] "Create new person" option works
  - [ ] CSRF token included in all requests

  **QA Scenarios:**

  ```
  Scenario: Create face tag on photo
    Tool: Playwright
    Preconditions: Dev server running, signed in, photo open in modal, tag mode active, at least one person exists in the family
    Steps:
      1. Click on the center of the photo image
      2. Assert a new .photo-view-modal__face-box appears at approximately the click position
      3. Assert an autocomplete input is visible and focused
      4. Type the first 3 letters of a known person's name
      5. Wait for dropdown results (timeout: 2s)
      6. Assert dropdown contains the person's name
      7. Click the person's name in the dropdown
      8. Assert the face box now shows the person's name as a label
      9. Assert the autocomplete input is gone
    Expected Result: Face tag created via AJAX, visible with person name
    Failure Indicators: No box created, autocomplete doesn't appear, AJAX fails (422/500), name not shown
    Evidence: .sisyphus/evidence/task-12-create-face-tag.png

  Scenario: Face box clamped at image edge
    Tool: Playwright
    Steps:
      1. In tag mode, click near the bottom-right corner of the image (95%, 95%)
      2. Assert face box appears but does not extend beyond image bounds
      3. Assert box is visible (not clipped or hidden)
    Expected Result: Box is clamped to fit within image
    Evidence: .sisyphus/evidence/task-12-edge-clamp.png

  Scenario: Autocomplete with no matches
    Tool: Playwright
    Steps:
      1. Create a face box by clicking
      2. Type "zzzznonexistent"
      3. Wait for search results
      4. Assert dropdown shows "No matches found" or similar
      5. Assert "Create new person" option is still available
    Expected Result: Graceful empty state with create option
    Evidence: .sisyphus/evidence/task-12-no-matches.png
  ```

  **Commit**: YES (groups with Tasks 11, 13)
  - Message: `feat(photo-view): face tagging system — create, remove, autocomplete, click-outside`
  - Files: `app/javascript/components/PhotoView/FaceBoxCreator.jsx`, `app/javascript/components/PhotoView/PersonAutocomplete.jsx`
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 13. Tag Interaction + Click-Outside Logic

  **What to do**:
  - **Existing tag hover behavior** (when in tag mode):
    - Face boxes with a person show the person's name in a callout/label
    - On hover: border goes to full opacity (from 50%)
  - **Remove tag** (when in tag mode):
    - Clicking on an existing tagged face box shows a small X/close button on the box
    - Clicking the X sends `DELETE /photos/:id/photo_faces/:face_id.json`
    - On success: remove the face box from state, re-fetch photo data
  - **Click-outside logic** (critical — user specified this in detail):
    - When a face box is being created (autocomplete is showing):
      1. **Click within the photo area (but not on the autocomplete/box)**: Dismiss the current pending box. Create a NEW face box at the new click position
      2. **Click on the black background area** (outside the photo, outside the sidebar): Dismiss the pending box, do NOT create a new one
      3. **Click in the sidebar**: Do NOTHING with the tagging. Let the sidebar handle its own clicks independently. The pending box stays open
    - Implementation: Use event target checking to determine click zone (photo image area vs dark overlay vs sidebar div)
  - When NOT in tag mode: face boxes are display-only (no click interaction beyond optional hover labels)

  **Must NOT do**:
  - Change behavior when not in tag mode
  - Add any sidebar interactivity (it's read-only)
  - Handle the "create new person" flow (that's in Task 12)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: Complex click-event routing with zone detection, AJAX delete, state management for pending vs committed face boxes

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on T12 for face box creation)
  - **Parallel Group**: Wave 3 (after T12)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 3, 12

  **References**:

  **Pattern References**:
  - `app/javascript/controllers/person_autocomplete_controller.js:168-172` — Outside-click detection pattern (`!this.element.contains(event.target)`). Adapt for zone-based click routing
  - `app/assets/stylesheets/application.scss:19-44` — Face box hover/active states for visual consistency

  **API/Type References**:
  - Task 3's JSON delete endpoint — `DELETE /photos/:id/photo_faces/:id.json` returns `{ success: true }`

  **Acceptance Criteria**:
  - [ ] Clicking an existing tag in tag mode shows X button
  - [ ] Clicking X removes the tag via AJAX DELETE
  - [ ] Click in photo (with pending box) → dismisses old box, creates new box at click position
  - [ ] Click on black background (with pending box) → dismisses box, no new box
  - [ ] Click in sidebar (with pending box) → pending box stays, sidebar handles click normally
  - [ ] Face box hover shows full opacity border

  **QA Scenarios:**

  ```
  Scenario: Remove existing tag
    Tool: Playwright
    Preconditions: Photo has at least one tagged face (face with person_id)
    Steps:
      1. Open modal, enter tag mode
      2. Click on an existing tagged face box
      3. Assert X/close button appears on the face box
      4. Click the X button
      5. Assert face box is removed from the image
      6. Assert no error messages
    Expected Result: Tag removed via AJAX, face box disappears
    Failure Indicators: X doesn't appear, AJAX fails, box remains
    Evidence: .sisyphus/evidence/task-13-remove-tag.png

  Scenario: Click-outside to photo creates new box
    Tool: Playwright
    Steps:
      1. Enter tag mode, click on photo to create a box
      2. Assert autocomplete appears
      3. Click on a DIFFERENT position on the photo (not on autocomplete)
      4. Assert the FIRST box is dismissed
      5. Assert a NEW box appears at the second click position
      6. Assert autocomplete appears for the new box
    Expected Result: Clicking elsewhere on photo replaces the pending box
    Evidence: .sisyphus/evidence/task-13-click-photo-new-box.png

  Scenario: Click-outside to black background dismisses
    Tool: Playwright
    Steps:
      1. Enter tag mode, click on photo to create a box
      2. Click on the dark background area (outside photo and sidebar)
      3. Assert the pending box is dismissed
      4. Assert no new box was created
    Expected Result: Black background click cancels the pending tag
    Evidence: .sisyphus/evidence/task-13-click-bg-dismiss.png

  Scenario: Click in sidebar preserves pending box
    Tool: Playwright
    Preconditions: Screen width >= 900px (sidebar visible)
    Steps:
      1. Enter tag mode, click on photo to create a box
      2. Click somewhere in the sidebar
      3. Assert the pending face box is still visible
      4. Assert the autocomplete is still visible
    Expected Result: Sidebar clicks don't affect tagging state
    Evidence: .sisyphus/evidence/task-13-sidebar-independent.png
  ```

  **Commit**: YES (groups with Tasks 11, 12)
  - Message: `feat(photo-view): face tagging system — create, remove, autocomplete, click-outside`
  - Files: modifications to PhotoImage.jsx, FaceBoxCreator.jsx, PhotoViewApp.jsx
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

### Wave 4 — Polish + Tests

- [x] 14. Fullscreen Mode Toggle

  **What to do**:
  - In `PhotoViewApp.jsx`, add `isFullscreen` state (boolean, default false)
  - Toolbar fullscreen button (Task 8) toggles this state
  - When `isFullscreen` is true:
    - Add `.photo-view-modal--fullscreen` class to the modal container
    - This CSS class hides the sidebar (defined in Task 4's SCSS)
    - The photo/image area expands to fill the full width
    - Toolbar icon changes from `ti ti-arrows-maximize` to `ti ti-arrows-minimize`
  - When `isFullscreen` is false: sidebar is visible (at >= 900px width)
  - Fullscreen mode should persist across photo navigation (stay fullscreen when pressing prev/next)

  **Must NOT do**:
  - Use the browser's native Fullscreen API (not that kind of fullscreen — this is "hide sidebar" fullscreen)
  - Change any other component behavior

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple CSS class toggle on a state boolean

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 15, 16, 17, 18)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 8, 9

  **References**:
  - `app/assets/stylesheets/_photo_view.scss` — `.photo-view-modal--fullscreen` modifier class (Task 4)

  **Acceptance Criteria**:
  - [ ] Clicking fullscreen button hides sidebar
  - [ ] Clicking again restores sidebar
  - [ ] Photo area expands to full width when sidebar is hidden
  - [ ] Fullscreen persists across prev/next navigation

  **QA Scenarios:**

  ```
  Scenario: Toggle fullscreen
    Tool: Playwright
    Preconditions: Screen width >= 900px
    Steps:
      1. Open modal, assert sidebar is visible
      2. Click fullscreen button (.photo-view-modal__toolbar-btn--fullscreen)
      3. Assert sidebar (.photo-view-modal__sidebar) is hidden
      4. Assert image area fills full width
      5. Click fullscreen button again
      6. Assert sidebar is visible again
    Expected Result: Fullscreen toggles sidebar visibility
    Evidence: .sisyphus/evidence/task-14-fullscreen-toggle.png
  ```

  **Commit**: YES (groups with Tasks 15, 16)
  - Message: `feat(photo-view): fullscreen mode, edge cases, loading states`
  - Files: modifications to PhotoViewApp.jsx
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 15. Edge Cases + Error States

  **What to do**:
  - Handle these specific edge cases across the component tree:
    1. **Photo with no image attached**: Show placeholder icon + "No image attached" text (match `show.html.erb:41-46` pattern). Disable zoom and tag buttons
    2. **Photo with no faces**: Tag mode works normally (user can create new face boxes). No special empty state needed
    3. **First/last photo boundary**: Navigation arrows hidden (not just disabled) when at boundaries. Keyboard arrows do nothing at boundaries
    4. **Face box at image edge**: Already handled in Task 12 (clamping). Verify edge-case positions work: (0,0), (0.95, 0.95), (0, 0.95), (0.95, 0)
    5. **Duplicate person tag**: If AJAX returns 422 (person already tagged), show a brief error message near the face box
    6. **Network errors**: If any fetch/AJAX call fails, show a non-blocking error message (toast-style or inline). Don't crash the component
    7. **Photo deleted (404)**: If fetching photo JSON returns 404, show "Photo not found" and offer to close modal
    8. **Stale data after tag operations**: After creating or deleting a face, re-fetch the photo JSON to ensure sidebar and face list are up to date
    9. **Loading state during photo navigation**: Show a spinner/loading indicator while fetching the next photo's data

  **Must NOT do**:
  - Add retry logic
  - Add offline support
  - Add skeleton screens or blur-up image loading

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Multiple independent edge cases across several components

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 14, 16, 17, 18)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 6-13 (all core components must exist)

  **References**:
  - `app/views/photos/show.html.erb:41-46` — "No image attached" placeholder pattern. Use same Tabler icon (`ti ti-photo`) and style
  - `app/models/photo_person.rb:6` — Uniqueness validation that causes 422 on duplicate tag

  **Acceptance Criteria**:
  - [ ] Photo without image shows placeholder, zoom/tag disabled
  - [ ] Network error shows error message, component doesn't crash
  - [ ] 404 on photo fetch shows "Photo not found" with close option
  - [ ] After tagging, sidebar updates to show new tag
  - [ ] Loading spinner during navigation

  **QA Scenarios:**

  ```
  Scenario: Network error handling
    Tool: Playwright
    Steps:
      1. Open modal successfully
      2. Go offline (or intercept network to return 500)
      3. Click next arrow to navigate
      4. Assert an error message is shown (not a white screen)
      5. Assert the previous photo is still visible
    Expected Result: Graceful error display, no crash
    Evidence: .sisyphus/evidence/task-15-network-error.png

  Scenario: Data refreshes after tagging
    Tool: Playwright
    Steps:
      1. Open modal for a photo with no tags
      2. Enter tag mode, create a face tag with a person
      3. Assert the sidebar people section now shows the tagged person
    Expected Result: Sidebar updates after tag creation
    Evidence: .sisyphus/evidence/task-15-data-refresh.png
  ```

  **Commit**: YES (groups with Tasks 14, 16)
  - Message: `feat(photo-view): fullscreen mode, edge cases, loading states`
  - Files: modifications to multiple PhotoView components
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 16. Loading States + Optimistic UI

  **What to do**:
  - Add loading states to the PhotoView component:
    1. **Initial load**: When modal opens and photo JSON is being fetched, show a centered spinner within the dark overlay
    2. **Navigation loading**: When navigating to next/prev photo, show a spinner over the image area while new data loads
    3. **Tag operation loading**: Show subtle loading indicator on the face box while AJAX create/delete is in progress
  - Use simple CSS spinner (no animation library)
  - For tag operations: optimistically add/remove the face box from the UI, then confirm with server response. On failure, revert and show error

  **Must NOT do**:
  - Add skeleton screens or progressive image loading
  - Add transition animations between photos
  - Use any animation library

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple spinner component and optimistic state update pattern

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 14, 15, 17, 18)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 6-13

  **References**:
  - Tabler CSS has spinner classes — check Tabler docs for `.spinner-border` or similar

  **Acceptance Criteria**:
  - [ ] Spinner shows during initial photo load
  - [ ] Spinner shows during photo navigation
  - [ ] Face box shows loading state during AJAX operation
  - [ ] Optimistic UI: face box appears/disappears immediately, confirmed by server

  **QA Scenarios:**

  ```
  Scenario: Loading spinner on modal open
    Tool: Playwright
    Steps:
      1. Throttle network to slow 3G
      2. Click thumbnail to open modal
      3. Assert a spinner/loading element is visible
      4. Wait for photo to load
      5. Assert spinner is replaced by photo
    Expected Result: Loading state visible before photo appears
    Evidence: .sisyphus/evidence/task-16-loading-spinner.png
  ```

  **Commit**: YES (groups with Tasks 14, 15)
  - Message: `feat(photo-view): fullscreen mode, edge cases, loading states`
  - Files: modifications to PhotoView components
  - Pre-commit: `bin/rubocop && bundle exec rspec`

---

- [x] 17. RSpec Request Specs for JSON Endpoints

  **What to do**:
  - Create `spec/requests/photos_json_spec.rb`:
    - Test `GET /photos/:id.json` returns correct JSON shape
    - Assert keys: id, title, image_url, faces, people, contributions, prev_id, next_id
    - Test with photo that has faces, people, contributions
    - Test with photo that has no faces (empty array)
    - Test prev_id/next_id at boundaries (first and last photo)
    - Test that HTML format still works (GET /photos/:id returns HTML)
  - Create `spec/requests/photo_faces_json_spec.rb`:
    - Test `POST /photos/:id/photo_faces.json` with valid params (201)
    - Test `POST /photos/:id/photo_faces.json` with invalid params (422)
    - Test `PATCH /photos/:id/photo_faces/:id.json` to assign person (200)
    - Test `DELETE /photos/:id/photo_faces/:id.json` (200)
    - Test HTML format still redirects (not JSON)
  - Use FactoryBot for test data setup
  - Follow existing spec patterns in the project

  **Must NOT do**:
  - Add system/integration specs (Playwright handles that)
  - Modify existing spec files
  - Add new gem dependencies for testing

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Multiple spec files with various scenarios, needs careful assertion of JSON shapes

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T14-16, independent of frontend)
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 18
  - **Blocked By**: Tasks 2, 3 (JSON endpoints must exist)

  **References**:

  **Pattern References**:
  - `spec/models/photo_spec.rb` — Existing photo spec patterns, FactoryBot usage
  - `spec/models/photo_face_spec.rb` — Existing photo_face spec patterns

  **API/Type References**:
  - Task 2's JSON response shape — exact keys to assert in specs
  - Task 3's JSON response shape — face CRUD response shapes

  **Acceptance Criteria**:
  - [ ] `spec/requests/photos_json_spec.rb` exists with >= 5 test cases
  - [ ] `spec/requests/photo_faces_json_spec.rb` exists with >= 4 test cases
  - [ ] `bundle exec rspec spec/requests/photos_json_spec.rb` passes
  - [ ] `bundle exec rspec spec/requests/photo_faces_json_spec.rb` passes
  - [ ] All pre-existing specs still pass

  **QA Scenarios:**

  ```
  Scenario: All request specs pass
    Tool: Bash
    Steps:
      1. Run `bundle exec rspec spec/requests/photos_json_spec.rb spec/requests/photo_faces_json_spec.rb --format documentation`
      2. Assert exit code 0
      3. Assert output shows >= 9 examples, 0 failures
    Expected Result: All JSON endpoint specs pass
    Evidence: .sisyphus/evidence/task-17-rspec-output.txt

  Scenario: No regression in existing specs
    Tool: Bash
    Steps:
      1. Run `bundle exec rspec --format documentation`
      2. Assert exit code 0
      3. Assert 0 failures
    Expected Result: Full suite passes including new and existing specs
    Evidence: .sisyphus/evidence/task-17-full-suite.txt
  ```

  **Commit**: YES (groups with Task 18)
  - Message: `test(photo-view): RSpec request specs for JSON endpoints + regression`
  - Files: `spec/requests/photos_json_spec.rb`, `spec/requests/photo_faces_json_spec.rb`
  - Pre-commit: `bundle exec rspec && bin/rubocop`

---

- [x] 18. Full Regression + Rubocop

  **What to do**:
  - Run the full test suite: `bundle exec rspec`
  - Run the linter: `bin/rubocop`
  - Fix any failures or offenses introduced by the work
  - Verify the Vite build succeeds: `npx vite build --mode development`
  - Verify the existing show page renders correctly by running `curl http://localhost:3000/photos/1` and checking for expected content

  **Must NOT do**:
  - Skip any failing tests
  - Add rubocop:disable comments without justification
  - Modify existing spec files to make them pass

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Run commands and fix simple issues

  **Parallelization**:
  - **Can Run In Parallel**: NO (must run after Task 17)
  - **Parallel Group**: Wave 4 (sequential after T17)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 17

  **Acceptance Criteria**:
  - [ ] `bundle exec rspec` — 0 failures
  - [ ] `bin/rubocop` — 0 offenses
  - [ ] `npx vite build --mode development` — exit code 0

  **QA Scenarios:**

  ```
  Scenario: Full green build
    Tool: Bash
    Steps:
      1. Run `bundle exec rspec --format progress`
      2. Assert 0 failures
      3. Run `bin/rubocop`
      4. Assert 0 offenses
      5. Run `npx vite build --mode development`
      6. Assert exit code 0
    Expected Result: All checks pass
    Evidence: .sisyphus/evidence/task-18-full-green.txt
  ```

  **Commit**: YES (groups with Task 17)
  - Message: `test(photo-view): RSpec request specs for JSON endpoints + regression`
  - Files: any files modified to fix issues
  - Pre-commit: `bundle exec rspec && bin/rubocop`
## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [x] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high`
  Run `bin/rubocop` + `bundle exec rspec`. Review all changed files for: `as any`/`@ts-ignore` (in JSX), empty catches, console.log in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names. Verify React components properly cleanup (no memory leaks, event listener removal). Check Stimulus bridge unmounts React in `disconnect()`.
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [x] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill)
  Start from clean state. Sign in as `alex@example.com`. Navigate to photos gallery. Execute EVERY QA scenario from EVERY task. Test cross-task integration: open modal → zoom → tag → navigate → close. Test edge cases: empty photo, boundary navigation, rapid zoom clicks, tag then navigate. Save screenshots to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination. Verify the existing show page at `/photos/:id` renders identically to before. Verify `face_tagging_controller.js` is unmodified.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| After Task(s) | Commit Message | Pre-commit Check |
|---------------|---------------|-----------------|
| 1 | `build: add React and Vite React plugin` | `npm ls react` |
| 2, 3 | `feat(api): add JSON responses to photos and photo_faces controllers` | `bundle exec rspec spec/requests/` |
| 4, 5 | `feat(photo-view): add Stimulus bridge controller and CSS foundation` | `bin/rubocop` |
| 6-10 | `feat(photo-view): core React component shell — modal, image, toolbar, sidebar, navigation` | `bin/rubocop && bundle exec rspec` |
| 11-13 | `feat(photo-view): face tagging system — create, remove, autocomplete, click-outside` | `bin/rubocop && bundle exec rspec` |
| 14-16 | `feat(photo-view): fullscreen mode, edge cases, loading states` | `bin/rubocop && bundle exec rspec` |
| 17-18 | `test(photo-view): RSpec request specs for JSON endpoints + regression` | `bundle exec rspec && bin/rubocop` |

---

## Success Criteria

### Verification Commands
```bash
# React installed and Vite configured
npm ls react react-dom @vitejs/plugin-react  # Expected: all listed
grep -q "react" vite.config.ts               # Expected: match found

# JSON API works
curl -s -b session http://localhost:3000/photos/1.json | jq '.id, .image_url, .prev_id, .next_id, (.faces | length)'
# Expected: photo ID, valid URL, adjacent IDs, face count >= 0

# Face CRUD via JSON
curl -s -X POST ... /photos/1/photo_faces.json  # Expected: 201 with face JSON
curl -s -X PATCH ... /photos/1/photo_faces/1.json # Expected: 200 with updated face
curl -s -X DELETE ... /photos/1/photo_faces/1.json # Expected: 200 or 204

# Test suite
bundle exec rspec  # Expected: 0 failures
bin/rubocop        # Expected: 0 offenses

# Show page unchanged
curl -s http://localhost:3000/photos/1 | grep "face-tagging"  # Expected: match (Stimulus controller still present)
```

### Final Checklist
- [x] All "Must Have" items present
- [x] All "Must NOT Have" items absent
- [x] All tests pass (`bundle exec rspec`)
- [x] All linting passes (`bin/rubocop`)
- [x] Existing show page unchanged
- [x] `face_tagging_controller.js` unmodified
