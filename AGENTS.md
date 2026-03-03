# Photos - Agent Instructions

Photos is a Rails app for families to upload, organize, and collaboratively annotate their old photos.

## Database
The database schema is at db/structure.sql

## Project Stack

- Backend: Ruby 3.2.2, Rails 8.1.2
- Frontend: Vite, Stimulus, Turbo
- CSS: Tabler UI (via CDN), custom SCSS overrides
- Database: PostgreSQL (primary), SQLite (cache/queue/cable)
- Testing: RSpec, FactoryBot
- Linting: Rubocop (Omakase style)
- Production Infrastructure: Kamal, Docker

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

### Git Hooks

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

### JavaScript
- **Framework:** Stimulus controllers for JS behavior.
- **Turbo:** Turbo Frames/Streams for partial page updates.
- **No semicolons** in JS/TS files.

### Key Domain Concepts
- **Fuzzy dates:** Photos and events use fuzzy dates (year only, season, decade, circa).
  - Fields: `date_type`, `year`, `month`, `day`, `season`, `circa`, `date_display`
  - Concern: `HasFuzzyDate` provides `fuzzy_date_text` helper.
- **Families:** Multi-tenant. Users can belong to multiple families.
  - Session stores current family. Switch via sidebar dropdown.
- **People vs Users:** `Person` = someone who appears in photos. `User` = someone who logs in.
  - A Person may optionally be linked to a User.
- **Photos:** Have Active Storage image attachment with variants (:thumb, :medium, :large).
- **Contributions:** Collaborative context — any user can add info about a photo.
- **Locations:** Hierarchical via `ancestry` gem. Can be as vague as "Kenya" or as specific as a street address.

### General Guidelines
- **Modifying Code:** Always read the file first. Mimic existing style.
- **Tests:** Always write or update specs when changing logic.
- **Dependencies:** Do not add new gems or npm packages without explicit instruction.

## Directory Structure
- `app/javascript`: Frontend code (entrypoints, controllers).
- `app/assets/stylesheets`: Custom SCSS overrides (Tabler loaded via CDN).
- `bin/`: Executable scripts.
- `spec/`: RSpec tests.
- `vite.config.ts`: Vite configuration.

## Seed Data
Sign in with: `alex@example.com`, `robin@example.com`, or `lindsey@example.com`
