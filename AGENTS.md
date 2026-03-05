# Photos - Agent Instructions

Photos is a Rails app for families to upload, organize, and collaboratively annotate their old photos.

## Database
The database schema is at db/structure.sql

## Project Stack
- **Backend:** Ruby 3.2.2, Rails 8.1.2
- **Frontend:** Vite, Stimulus, Turbo, React (for PhotoView)
- **CSS:** Tabler UI (via CDN), custom SCSS overrides
- **Database:** PostgreSQL (primary), SQLite (cache/queue/cable)
- **Testing:** RSpec, FactoryBot
- **Linting:** Rubocop (Omakase style)
- **Production Infrastructure:** Kamal, Docker

## Operational Commands

### Development Server
Start the Rails server and Vite dev server:
```bash
bin/dev
```

### Testing
Run the full test suite:
```bash
bundle exec rspec
```

Run a single test file:
```bash
bundle exec rspec spec/models/person_spec.rb
```

### Linting & Formatting
Run Rubocop (Ruby linter):
```bash
bin/rubocop
```

Auto-fix Rubocop offenses:
```bash
bin/rubocop -A
```

### Database
```bash
bin/rails db:migrate
bin/rails db:seed
```

## Procfile Processes
The `Procfile.dev` defines 5 processes required for development:
- `web`: Rails server (port 3000)
- `css`: DartSass watcher for SCSS
- `vite`: Vite dev server for JS/React
- `jobs`: Background job processor
- `orientation`: Python FastAPI service for orientation detection (port 8150)

## Git Hooks
A pre-commit hook blocks commits with 10 or more staged files unless `AGENTS.md` or `README.md` is also staged. This enforces documentation freshness on large changes.

**When blocked:**
- Update `AGENTS.md` (preferred) or `README.md` to reflect your changes
- Stage the updated file: `git add AGENTS.md`
- Then commit normally

Run `bin/setup` to install the hook.

## Code Style & Conventions

### Ruby / Rails
- **Formatting:** Follow the `rubocop-rails-omakase` rules.
  - Indentation: 2 spaces.
  - Quotes: Double quotes preferred for strings.
  - Hash syntax: Ruby 1.9 symbol syntax (`key: value`).
- **Naming:**
  - Classes/Modules: `PascalCase`
  - Variables/Methods: `snake_case`
  - Files: `snake_case.rb`
- **Patterns:**
  - Fat models, skinny controllers.
  - Use `ApplicationRecord` as the base class for models.
  - Multi-tenant via `belongs_to :family` — all queries scoped to `Current.family`.
  - `Current` model holds `family`, `user`, `session`.

### JavaScript / Frontend
- **Framework:** Stimulus controllers for most JS behavior.
- **Turbo:** Turbo Frames/Streams for partial page updates.
- **No semicolons** in JS/TS files.
- **React Bridge:** The advanced `PhotoViewApp` is a React component mounted by `photo_view_controller.js` using `createRoot`. This is the only place React is used.

## Services
### Python Orientation Service
Located in `services/orientation/`, this FastAPI microservice uses an EfficientNetV2 ONNX model to detect image orientation.
- **Port:** 8150
- **Endpoint:** `POST /predict` (accepts image file)
- **Returns:** Corrective rotation in degrees (0, 90, 180, 270) and confidence score.

## Authentication
The app uses a passwordless authentication flow:
1. User enters email in `SessionsController#new`.
2. `SessionsController#create` generates a `LoginCode` and sends it to the user.
3. In development, the code is served in `flash[:login_code]` and the `X-Login-Code` header.
4. User enters the code in `Sessions::LoginCodesController#show`.
5. `Sessions::LoginCodesController#create` verifies the code and establishes a session.
6. `Authentication` concern (in `app/controllers/concerns/`) manages session tokens.

## Key Domain Concepts
- **Fuzzy dates:** Photos and events use fuzzy dates (year only, season, decade, circa).
  - Fields: `date_type`, `year`, `month`, `day`, `season`, `circa`, `date_display`
  - Concern: `HasFuzzyDate` provides `fuzzy_date_text` helper.
- **Families:** Multi-tenant. Users can belong to multiple families.
  - Session stores current family. Switch via sidebar dropdown.
- **People vs Users:** `Person` = someone who appears in photos. `User` = someone who logs in.
  - A Person may optionally be linked to a User.
- **Photos:** Have Active Storage image attachments.
  - `original`: The raw uploaded file.
  - `working_image`: The processed image used for display.
- **Contributions:** Collaborative context — any user can add info about a photo.
- **Locations:** Hierarchical via `ancestry` gem. Can be as vague as "Kenya" or as specific as a street address.
- **Date Determinations:** Provenance model tracking how a photo's date was determined.
  - Sources: EXIF metadata, age estimates, filename patterns, manual entry.
  - Model: `DateDetermination` with `source_type`, `confidence`, fuzzy date fields.
  - Confidence scoring: EXIF (0.95) > Manual (0.9) > Age+exact DOB (0.85) > Age+year DOB (0.75) > Age+circa DOB (0.7) > Filename (0.6).
  - Highest-confidence determination auto-updates `Photo#determined_*` fields.
  - Service: `Photo::DateDeterminationService` creates records from various sources.
  - Scorer: `Photo::ConfidenceScorer` assigns confidence based on source type.
  - Person DOB changes trigger recalculation of all age-based determinations.
  - Backfill task: `bin/rails date_determinations:backfill` for existing EXIF data.
- **Person DOB:** People have optional `dob_year` (integer) and `dob_circa` (boolean) for approximate birth years.
  - Used with `estimated_age` on `PhotoPerson`/`PhotoFace` to calculate photo dates.
  - `Person#dob_text` returns human-readable DOB string.
- **Photo tagging ages:** `PhotoPerson` and `PhotoFace` have optional `estimated_age` (integer, 1-120).
  - When set alongside a person's DOB, triggers automatic date determination.
- **Storytelling Mode:** Allows family members to record audio narrations over a slideshow of photos.
  - `StorytellingSession`: Groups selected photos for narration, with optional location and storyteller people.
  - `Story`: Audio recording (Active Storage `audio` attachment) linked to a photo and session.
  - Recording: Setup form selects photos/people/location → full-screen slideshow with MediaRecorder → audio saved per photo via fetch POST.
  - Playback: Stories shown in PhotoSidebar.jsx with native `<audio controls>`.
  - Audio formats: WebM/Opus (Chrome/Firefox), MP4/AAC (Safari).
  - Stimulus controllers: `storytelling_controller.js` (recording), `person_multi_select_controller.js` (setup form).

## Controllers
The application includes 16 primary controllers:
1. `ApplicationController`: Base class; handles authentication and multi-tenancy scoping.
2. `SiteController`: Landing page and general site navigation.
3. `SessionsController`: Initiates passwordless login by generating and sending codes.
4. `Sessions::LoginCodesController`: Verifies login codes and establishes user sessions.
5. `PhotosController`: Main CRUD for photos, gallery views, and filtering.
6. `ContributionsController`: Allows users to add metadata and comments to photos.
7. `PhotoPeopleController`: Manages associations between people and photos, including estimated age at tagging.
8. `PhotoFacesController`: Handles manual face tagging, coordinate management, and estimated age.
9. `PeopleController`: CRUD for people, including search, profile views, and DOB management.
10. `EventsController`: Organizes photos into named historical events.
11. `LocationsController`: Hierarchical location management with Google Maps integration.
12. `UploadsController`: Multi-step photo upload and processing pipeline.
13. `FamiliesController`: Handles multi-tenant scoping and family switching.
14. `Rails::HealthController`: Internal Rails endpoint for system health checks.
15. `StorytellingSessionsController`: Manages storytelling session setup (new/create) and slideshow recording interface (show).
16. `StoriesController`: Handles audio upload for storytelling recordings (create).

## Active Storage Variants
Photos use the following variants for the `working_image` attachment:
- `:thumb`: `resize_to_fill: [ 200, 200 ]`
- `:medium`: `resize_to_limit: [ 800, 800 ]`
- `:large`: `resize_to_limit: [ 1600, 1600 ]`

## Directory Structure
- `app/controllers`: Rails controllers (including `sessions/` namespace).
- `app/javascript/controllers`: Stimulus controllers.
- `app/javascript/components`: React components (primarily `PhotoView`).
- `app/models`: ActiveRecord models and concerns.
- `app/services`: Ruby service objects.
- `services/orientation`: Python orientation detection microservice.
- `spec/`: RSpec test suite.
- `db/`: Database schema and migrations.
- `app/services/photo/`: Photo-related service objects (date determination, confidence scoring).
- `lib/tasks/`: Custom rake tasks (date determination backfill).

## Seed Data
Sign in with: `alex@example.com`, `robin@example.com`, or `lindsey@example.com`
