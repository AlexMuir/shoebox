# Photos App — V1 Implementation Plan

## Executive Summary

Build a family photo sharing and organizing Rails 8.1 app from scratch, following patterns observed in the clockwork reference codebase. 10 core models, login-code authentication, session-based multi-family tenancy, Tabler UI, batch upload, fuzzy dates, collaborative contributions.

**Total tasks: 70** across **8 waves**, with **~20 tasks parallelizable** within their waves.

---

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Ruby version | 3.2.2 | Available now; Rails 8.1.2 compatible. Bump to 3.4.7 later. |
| Multi-tenancy | Session-based `Current.family` | Users belong to multiple families. Family ID stored in `session[:current_family_id]`, resolved in `before_action`. Auto-selects if user has only one family. |
| UI framework | Tabler via CDN | Bootstrap 5 superset with dashboard layout, sidebar, cards, tables. Includes Bootstrap — no separate Bootstrap CDN needed. Custom overrides in loose SCSS files. |
| CSS pipeline | Dart SASS via dartsass-rails | Custom SCSS overrides compiled by dartsass. Tabler itself loaded from CDN. |
| JS pipeline | Vite + Stimulus + Turbo | `vite_rails` gem, `@hotwired/turbo`, `@hotwired/stimulus`. |
| Fuzzy dates | `HasFuzzyDate` concern with column prefix | Reusable across Photo (`taken_`), Event (`start_`, `end_`). Auto-computes `sort_date` and `display_text`. |
| Location hierarchy | `ancestry` gem | Tree structure: Africa > Kenya > Nairobi. |
| Person tagging | `photo_people` join table (HABTM) | Simple join table, no model needed for v1. |
| File storage | Active Storage, local disk (dev) | S3 deferred. Original files never altered; variants for display. |
| Authentication | Login codes (no passwords) | 6-digit codes emailed, following clockwork pattern exactly. |
| Database | PostgreSQL primary + SQLite cache/queue/cable | Following clockwork's hybrid pattern. `structure.sql` format. |

---

## Data Model Summary

### 10 Models + 1 Join Table

```
Family
  has_many :family_memberships
  has_many :users, through: :family_memberships
  has_many :people, :photos, :events, :locations, :uploads

User
  has_many :family_memberships
  has_many :families, through: :family_memberships
  has_many :sessions, :login_codes, :contributions
  belongs_to :person, optional: true

FamilyMembership (join: users <-> families)
  belongs_to :user
  belongs_to :family
  # role: admin | member

Person (people IN photos — may link to a User)
  belongs_to :family
  has_one :user
  has_and_belongs_to_many :photos
  has_many :photographed_photos, class_name: "Photo", FK: :photographer_id

Photo
  belongs_to :family
  belongs_to :event, :location, :photographer (Person), :upload — all optional
  has_and_belongs_to_many :people
  has_many :sources (PhotoSource), :contributions
  has_one_attached :file
  include HasFuzzyDate (prefix: taken_)

Event
  belongs_to :family
  belongs_to :location, optional: true
  has_many :photos
  include HasFuzzyDate (prefix: start_)
  include HasFuzzyDate (prefix: end_)

Location
  belongs_to :family
  has_ancestry
  has_many :photos, :events

PhotoSource
  belongs_to :photo
  belongs_to :source_person (Person), optional
  belongs_to :scanned_by (Person), optional

Contribution
  belongs_to :photo
  belongs_to :user

Upload
  belongs_to :family, :user
  belongs_to :source_person (Person), :scanned_by (Person) — optional
  has_many :photos
```

---

## Wave 0: Project Bootstrap

**Goal:** Working Rails app that boots, connects to PG, runs Vite, compiles SCSS, and renders a page with Tabler styling.

**Dependencies:** None (starting point).

---

### Task 0.1 — Rails New

- **Category:** Setup
- **Skills:** Rails CLI
- **Command:** `rails new . --database=postgresql --skip-test --skip-jbuilder --css=sass --name=Photos`
- **Run from:** `/home/pippin/projects/photos`
- **Produces:** Full Rails skeleton. `--skip-test` because we use RSpec. `--css=sass` installs dartsass-rails.
- **Note:** Must preserve existing `plan/` directory.

---

### Task 0.2 — Gemfile Configuration

- **Category:** Setup
- **Skills:** Bundler
- **Depends on:** 0.1
- **File:** `Gemfile`
- **Action:** Replace generated Gemfile with curated gem list:

```ruby
source "https://rubygems.org"
ruby "3.2.2"

gem "rails", "~> 8.1.1"
gem "propshaft"
gem "pg", "~> 1.1"
gem "sqlite3"
gem "puma", ">= 5.0"
gem "vite_rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "dartsass-rails"
gem "solid_cache"
gem "solid_cable"
gem "solid_queue"
gem "mission_control-jobs"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "aws-sdk-s3", require: false
gem "image_processing", "~> 1.2"
gem "action_policy"
gem "view_component"
gem "faker"
gem "ancestry"
gem "geocoder"
gem "countries"
gem "simple_form"
gem "resend"
gem "tzinfo-data", platforms: %i[windows jruby]

group :test do
  gem "shoulda-matchers"
end

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 8.0.0"
  gem "factory_bot_rails"
end

group :development do
  gem "web-console"
  gem "guard"
  gem "guard-rspec", require: false
end
```

- **Then:** `bundle install`

---

### Task 0.3 — Database Configuration

- **Category:** Setup
- **Skills:** PostgreSQL, SQLite, Rails config
- **Depends on:** 0.2
- **File:** `config/database.yml`
- **Action:** Configure PG primary + SQLite for cache/queue/cable (following clockwork pattern):

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV["DB_HOST"] %>
  username: <%= ENV.fetch("DB_USERNAME", nil) %>
  password: <%= ENV.fetch("DB_PASSWORD", nil) %>

sqlite: &sqlite
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  primary:
    <<: *default
    database: photos_development
  cache:
    <<: *sqlite
    database: storage/photos_development_cache.sqlite3
    migrations_paths: db/cache_migrate
    schema_format: ruby
    schema_dump: cache_schema.rb
  queue:
    <<: *sqlite
    database: storage/photos_development_queue.sqlite3
    migrations_paths: db/queue_migrate
    schema_format: ruby
    schema_dump: queue_schema.rb
  cable:
    <<: *sqlite
    database: storage/photos_development_cable.sqlite3
    migrations_paths: db/cable_migrate
    schema_format: ruby
    schema_dump: cable_schema.rb

test:
  primary:
    <<: *default
    database: photos_test
  cache:
    <<: *sqlite
    database: storage/photos_test_cache.sqlite3
    migrations_paths: db/cache_migrate
  queue:
    <<: *sqlite
    database: storage/photos_test_queue.sqlite3
    migrations_paths: db/queue_migrate
  cable:
    <<: *sqlite
    database: storage/photos_test_cable.sqlite3
    migrations_paths: db/cable_migrate
```

- **Also set** in `config/application.rb`: `config.active_record.schema_format = :sql`
- **Then:** `bin/rails db:create`

---

### Task 0.4 — Database Extensions Migration

- **Category:** Setup
- **Skills:** PostgreSQL
- **Depends on:** 0.3
- **File:** `db/migrate/TIMESTAMP_enable_extensions.rb`

```ruby
class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"
    enable_extension "pg_trgm"
  end
end
```

---

### Task 0.5 — Vite Installation

- **Category:** Setup
- **Skills:** Vite, Node.js
- **Depends on:** 0.2
- **Command:** `bundle exec vite install`
- **Produces:** `vite.config.ts`, `config/vite.json`, `app/javascript/entrypoints/application.js`
- **Configure `config/vite.json`:**

```json
{
  "all": {
    "sourceCodeDir": "app/javascript",
    "watchAdditionalPaths": []
  },
  "development": {
    "autoBuild": true,
    "publicOutputDir": "vite-dev",
    "port": 3036
  },
  "test": {
    "autoBuild": true,
    "publicOutputDir": "vite-test",
    "port": 3037
  }
}
```

- **Configure `vite.config.ts`:**

```typescript
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import path from 'path'

export default defineConfig({
  plugins: [RubyPlugin()],
  resolve: {
    alias: {
      lib: path.resolve(__dirname, 'app/javascript/lib')
    },
  },
})
```

---

### Task 0.6 — Stimulus + Turbo Setup

- **Category:** Setup
- **Skills:** Hotwire
- **Depends on:** 0.5
- **Files:**
  - `app/javascript/entrypoints/application.js` — import Turbo + Stimulus
  - `app/javascript/controllers/index.js` — Stimulus controller registration
  - `app/javascript/controllers/application.js` — base Stimulus application

**`entrypoints/application.js`:**

```javascript
import "@hotwired/turbo"
import "../controllers"
```

---

### Task 0.7 — RSpec + FactoryBot Setup

- **Category:** Testing
- **Skills:** RSpec
- **Depends on:** 0.2
- **Command:** `bin/rails generate rspec:install`
- **Configure `spec/rails_helper.rb`:**

```ruby
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("Production!") if Rails.env.production?
require 'rspec/rails'

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.filter_rails_from_backtrace!

  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
end
```

- **Create** `spec/support/request_helpers.rb` (shell — finalized in Wave 2)

---

### Task 0.8 — Simple Form Installation

- **Category:** Setup
- **Skills:** Simple Form, Tabler
- **Depends on:** 0.2
- **Command:** `rails generate simple_form:install --bootstrap`
- **Then customize** `config/initializers/simple_form.rb` — Bootstrap 5 wrappers (Tabler is Bootstrap 5 compatible). Follow clockwork's config:
  - `vertical_form` wrapper (default)
  - `vertical_boolean` wrapper
  - `vertical_collection` wrapper
  - `vertical_file` wrapper
  - `vertical_select` wrapper
  - `switch` wrapper
  - `input_group` wrapper

---

### Task 0.9 — Procfile.dev + bin/dev

- **Category:** Setup
- **Depends on:** 0.5
- **File:** `Procfile.dev`

```
web: bin/rails server -p 3000
css: bin/rails dartsass:watch
vite: bin/vite dev
jobs: bin/jobs
```

---

### Task 0.10 — Tabler CDN Integration + Layouts

- **Category:** Frontend
- **Skills:** HTML, Tabler, ERB
- **Depends on:** 0.5, 0.6
- **Files:**
  - `app/views/layouts/application.html.erb`
  - `app/views/layouts/shared/_head.html.erb`
  - `app/views/layouts/shared/_sidebar.html.erb` (placeholder)
  - `app/views/layouts/shared/_flash.html.erb`
  - `app/views/layouts/login.html.erb`
  - `app/assets/stylesheets/application.scss` (custom overrides only)

**`_head.html.erb`:**

```erb
<head>
  <title><%= content_for(:title) || "Photos" %></title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= yield :head if content_for?(:head) %>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/core@latest/dist/css/tabler.min.css">
  <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
  <%= vite_client_tag %>
  <%= vite_javascript_tag 'application' %>
</head>
```

**`application.html.erb`** (Tabler dashboard layout):

```erb
<!DOCTYPE html>
<html lang="en">
  <%= render 'layouts/shared/head' %>
  <body class="d-flex flex-column">
    <div class="page">
      <%= render 'layouts/shared/sidebar' %>
      <div class="page-wrapper">
        <div class="page-body">
          <div class="container-xl">
            <%= render 'layouts/shared/flash' %>
            <%= yield %>
          </div>
        </div>
      </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/@tabler/core@latest/dist/js/tabler.min.js"></script>
  </body>
</html>
```

**`login.html.erb`** (minimal centered layout for auth pages):

```erb
<!DOCTYPE html>
<html lang="en">
  <%= render 'layouts/shared/head' %>
  <body class="d-flex flex-column">
    <div class="page page-center">
      <div class="container container-tight py-4">
        <%= render 'layouts/shared/flash' %>
        <%= yield %>
      </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/@tabler/core@latest/dist/js/tabler.min.js"></script>
  </body>
</html>
```

---

### Task 0.11 — Active Storage Configuration

- **Category:** Setup
- **Depends on:** 0.3
- **Command:** `bin/rails active_storage:install && bin/rails db:migrate`
- **Verify** `config/storage.yml` has local disk config
- **Verify** `config/environments/development.rb` has `config.active_storage.service = :local`

---

### Task 0.12 — Verify Boot

- **Category:** Validation
- **Depends on:** 0.1–0.11
- **Action:** Run `bin/rails runner "puts 'OK'"` and `bin/rspec` (0 examples, 0 failures).

---

## Wave 1: Core Auth Models

**Goal:** Family, User, Session, LoginCode, FamilyMembership models with migrations, validations, associations. Current model configured.

**Dependencies:** Wave 0 complete.

---

### Task 1.1 — Family Model

- **Category:** Model
- **File:** `app/models/family.rb`, `db/migrate/TIMESTAMP_create_families.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| name | string | not null |
| description | text | |
| slug | string | not null, unique |

- **Model:** validates name + slug presence, slug uniqueness. `normalizes :slug`. `before_validation :generate_slug` on create (from name.parameterize). All domain `has_many` associations.

---

### Task 1.2 — User Model

- **Category:** Model
- **File:** `app/models/user.rb`, `db/migrate/TIMESTAMP_create_users.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| name | string | not null |
| email | string | not null, unique |
| person_id | bigint | nullable (FK added in Wave 3) |

- **Model:** validates name, email (presence + uniqueness). `normalizes :email` (strip + downcase). `belongs_to :person, optional: true`. Has `send_login_code` method. `can_login?` method.

---

### Task 1.3 — Session Model

- **Category:** Model
- **Depends on:** 1.2
- **File:** `app/models/session.rb`, `db/migrate/TIMESTAMP_create_sessions.rb`
- **Fields:** user_id (FK, not null), ip_address (string), user_agent (string)
- **Model:** `belongs_to :user`. Minimal — just like clockwork.

---

### Task 1.4 — LoginCode Model

- **Category:** Model
- **Depends on:** 1.2
- **File:** `app/models/login_code.rb`, `db/migrate/TIMESTAMP_create_login_codes.rb`
- **Fields:** user_id (FK, not null), code (string, not null, unique), expires_at (datetime, not null)
- **Model:** Follow clockwork exactly:
  - `CODE_LENGTH = 6`, `EXPIRATION_TIME = 15.minutes`
  - `active` scope: `where(expires_at: Time.current..)`
  - `stale` scope: `where(expires_at: ..Time.current)`
  - `generate_code` class method: 6-digit zero-padded random
  - `sanitize_code(code)`: strips non-digits
  - `consume(code)`: finds active code, destroys it, returns record
  - `before_validation :generate_code, :set_expiration` on create

---

### Task 1.5 — FamilyMembership Model

- **Category:** Model
- **Depends on:** 1.1, 1.2
- **File:** `app/models/family_membership.rb`, `db/migrate/TIMESTAMP_create_family_memberships.rb`
- **Fields:** user_id (FK, not null), family_id (FK, not null), role (string, not null, default: "member")
- **Indexes:** unique on `[user_id, family_id]`
- **Model:** validates role inclusion in `%w[admin member]`, uniqueness of user scoped to family. `admin?` method.

---

### Task 1.6 — Current Model

- **Category:** Model
- **Depends on:** 1.1, 1.2, 1.3
- **File:** `app/models/current.rb`

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :family, :session, :user

  def session=(value)
    super(value)
    self.user = session.user if value.present?
  end
end
```

---

### Task 1.7 — Core Factories

- **Category:** Testing
- **Depends on:** 1.1–1.5
- **File:** `spec/factories.rb`
- **Factories:** Family, User (with auto-created FamilyMembership + :admin trait), FamilyMembership, Session, LoginCode

---

### Task 1.8 — Core Model Specs

- **Category:** Testing
- **Depends on:** 1.7
- **Files:** `spec/models/{family,user,session,login_code,family_membership}_spec.rb`
- **Cover:** Validations, associations, scopes, `LoginCode.consume`, `User#send_login_code`, slug generation

---

## Wave 2: Authentication System

**Goal:** Full login flow — enter email, receive code, enter code, get session. Family selection after login. Logout.

**Dependencies:** Wave 1 complete.

---

### Task 2.1 — Authentication Concern

- **Category:** Controller concern
- **File:** `app/controllers/concerns/authentication.rb`
- **Pattern:** Follow clockwork's `Authentication` concern:
  - `include ViaLoginCode`
  - `before_action :require_authentication`
  - `allow_unauthenticated_access` / `require_unauthenticated_access` class methods
  - `resume_session` — find Session from `cookies.signed[:session_token]` via `Session.find_signed`
  - `start_new_session_for(user)` — create Session, set permanent signed cookie
  - `terminate_session` — destroy Session, delete cookie
  - `authenticated?` helper method
  - `request_authentication` — save return URL in session, redirect to `new_session_url`
  - `after_authentication_url` — returns saved URL or root
- **Key difference from clockwork:** No `require_workspace` — family resolution is in SetCurrentFamily.

---

### Task 2.2 — ViaLoginCode Concern

- **Category:** Controller concern
- **File:** `app/controllers/concerns/authentication/via_login_code.rb`
- **Pattern:** Follow clockwork exactly:
  - `pending_authentication_token_verifier` — `Rails.application.message_verifier(:pending_authentication)`
  - `email_address_pending_authentication` — verify token from cookie
  - `ensure_development_login_code_not_leaked` — `after_action` safety
  - `clear_pending_authentication_token`

---

### Task 2.3 — SetCurrentFamily Concern

- **Category:** Controller concern
- **File:** `app/controllers/concerns/set_current_family.rb`
- **Pattern:** Adapted from clockwork's `SetCurrentRequestDetails`:
  - `before_action :set_current_family`
  - Reads `session[:current_family_id]`, finds family from user's families
  - Auto-selects if user has exactly one family
  - Redirects to family picker if logged in but no family selected
  - `family_selection_exempt?` override hook for controllers that don't need family
  - `current_family` / `require_family` helper methods

---

### Task 2.4 — ApplicationController

- **Category:** Controller
- **File:** `app/controllers/application_controller.rb`

```ruby
class ApplicationController < ActionController::Base
  include Authentication
  include SetCurrentFamily
  allow_browser versions: :modern
end
```

---

### Task 2.5 — SessionsController + Views

- **Category:** Controller + Views
- **Depends on:** 2.1, 2.2
- **Files:**
  - `app/controllers/sessions_controller.rb`
  - `app/views/sessions/new.html.erb` — email input form (Tabler card layout)
- **Pattern:** Follow clockwork:
  - `rate_limit to: 10, within: 3.minutes, only: :create`
  - `require_unauthenticated_access except: :destroy`
  - `layout "login"`
  - `create` — find user by email, send login code, redirect. If not found, fake login code (no user enumeration).
  - `destroy` — terminate session, redirect to new session
  - `serve_development_login_code` — flash + X-Login-Code header in dev
  - `set_pending_authentication_token` — cookie with verified email

---

### Task 2.6 — LoginCodesController + Views

- **Category:** Controller + Views
- **Depends on:** 2.5
- **Files:**
  - `app/controllers/sessions/login_codes_controller.rb`
  - `app/views/sessions/login_codes/show.html.erb` — 6-digit code input form
- **Pattern:** Follow clockwork:
  - `require_unauthenticated_access`, `layout "login"`
  - `rate_limit to: 10, within: 15.minutes, only: :create`
  - `ensure_that_email_address_pending_authentication_exists`
  - `create` — consume code, verify email matches, start session, redirect
  - `invalid_code` — redirect with shake flash

---

### Task 2.7 — LoginCodeMailer

- **Category:** Mailer
- **Files:**
  - `app/mailers/application_mailer.rb`
  - `app/mailers/login_code_mailer.rb`
  - `app/views/login_code_mailer/sign_in_instructions.{html,text}.erb`
- **Subject:** `"Your login code is #{@login_code.code}"`

---

### Task 2.8 — Family Selection Controller + Views

- **Category:** Controller + Views
- **Depends on:** 2.3
- **Files:**
  - `app/controllers/family_selections_controller.rb` — shows picker, overrides `family_selection_exempt?`
  - `app/controllers/current_families_controller.rb` — `update` sets `session[:current_family_id]`
  - `app/views/family_selections/new.html.erb` — Tabler card list of user's families

---

### Task 2.9 — Auth Routes

- **Category:** Routing
- **Depends on:** 2.5, 2.6, 2.8
- **File:** `config/routes.rb`

```ruby
Rails.application.routes.draw do
  root "site#index"

  resource :session, only: [:new, :create, :destroy] do
    scope module: :sessions do
      resource :login_code, only: [:show, :create]
    end
  end

  resource :family_selection, only: [:new]
  resource :current_family, only: [:update]

  get "up" => "rails/health#show", as: :rails_health_check
end
```

---

### Task 2.10 — SiteController (Home Page Stub)

- **Category:** Controller + Views
- **Files:** `app/controllers/site_controller.rb`, `app/views/site/index.html.erb`
- **Action:** Simple authenticated landing page showing current family name. Verifies the full auth -> family -> render pipeline.

---

### Task 2.11 — Auth Request Specs + Request Helpers

- **Category:** Testing
- **Depends on:** 2.5–2.10
- **Files:**
  - `spec/requests/sessions_spec.rb`
  - `spec/requests/sessions/login_codes_spec.rb`
  - `spec/support/request_helpers.rb` (finalized)
- **RequestHelpers module:** `sign_in_as(user, family:)` — sends login code, posts email, posts code, sets family. Included for `type: :request`.
- **Also:** `after(:each)` hook to print response body on failure (like clockwork).
- **Cover:** Full login flow, invalid codes, expired codes, logout, family selection, auto-select single family.

---

### Task 2.12 — Development Seeds

- **Category:** Data
- **File:** `db/seeds.rb`
- **Creates:** Family ("The Muirs"), User ("Alex Muir", alex@example.com), FamilyMembership (admin).
- **Prints:** Login email. Notes that codes appear in dev flash.

---

## Wave 3: Domain Models

**Goal:** All remaining models with migrations, validations, associations. HasFuzzyDate and QuickSearchable concerns.

**Dependencies:** Wave 1 complete. **Can run in parallel with Wave 2.**

---

### Task 3.1 — HasFuzzyDate Concern

- **Category:** Model concern
- **File:** `app/models/concerns/has_fuzzy_date.rb`
- **Design:** Macro-style concern. `has_fuzzy_date :taken` expects these columns (all with prefix):
  - `{prefix}_date_type` (string, enum: exact/month/season/year/decade/circa/unknown)
  - `{prefix}_year` (integer)
  - `{prefix}_month` (integer, 1-12)
  - `{prefix}_day` (integer, 1-31)
  - `{prefix}_season` (string: spring/summer/autumn/winter)
  - `{prefix}_circa` (boolean)
  - `{prefix}_display_text` (string — human-readable, auto-generated or manual override)
  - `{prefix}_sort_date` (date — computed for ordering)
- **Callbacks:** `before_save` to compute sort_date and display_text
- **Validations:** month 1-12, day 1-31, season inclusion

**Also create** `app/models/fuzzy_date_formatter.rb`:
- `FuzzyDateFormatter.format(date_type:, year:, month:, day:, season:, circa:)`
- Returns: "Summer 1984", "c. 1890", "July 1984", "1990s", "15 March 2020", etc.

---

### Task 3.2 — QuickSearchable Concern

- **Category:** Model concern
- **File:** `app/models/concerns/quick_searchable.rb`
- **Pattern:** Follow clockwork exactly — LIKE for short queries (<5 chars), pg_trgm similarity for longer queries.

---

### Task 3.3 — Person Model

- **Category:** Model
- **Depends on:** 1.1 (Family)
- **File:** `app/models/person.rb`, `db/migrate/TIMESTAMP_create_people.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| family_id | bigint | FK, not null |
| first_name | string | not null |
| last_name | string | |
| date_of_birth | date | nullable |
| date_of_death | date | nullable |
| bio | text | |
| quick_search | string | |

- **Indexes:** `family_id`, `[family_id, last_name, first_name]`
- **Model:** `include QuickSearchable`. `belongs_to :family`. `has_one :user`. `has_and_belongs_to_many :photos`. `has_many :photographed_photos`. `full_name` method. `before_save :update_quick_search`.

---

### Task 3.4 — Add person_id FK to Users

- **Category:** Migration
- **Depends on:** 3.3
- **File:** `db/migrate/TIMESTAMP_add_person_foreign_key_to_users.rb`
- **Action:** `add_foreign_key :users, :people, column: :person_id`

---

### Task 3.5 — Location Model

- **Category:** Model
- **Depends on:** 1.1
- **File:** `app/models/location.rb`, `db/migrate/TIMESTAMP_create_locations.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| family_id | bigint | FK, not null |
| name | string | not null |
| ancestry | string | nullable (ancestry gem) |
| address_line_1 | string | |
| address_line_2 | string | |
| city | string | |
| state_province | string | |
| postal_code | string | |
| country_code | string | |
| latitude | decimal(10,6) | |
| longitude | decimal(10,6) | |
| quick_search | string | |

- **Indexes:** `family_id`, `ancestry`
- **Model:** `include QuickSearchable`. `has_ancestry`. `belongs_to :family`. `has_many :photos`, `:events`. `full_path` method (ancestors > self).

---

### Task 3.6 — Event Model

- **Category:** Model
- **Depends on:** 1.1, 3.1, 3.5
- **File:** `app/models/event.rb`, `db/migrate/TIMESTAMP_create_events.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| family_id | bigint | FK, not null |
| title | string | not null |
| description | text | |
| location_id | bigint | FK, nullable |
| start_{date_type,year,month,day,season,circa,display_text,sort_date} | (fuzzy date) | |
| end_{date_type,year,month,day,season,circa,display_text,sort_date} | (fuzzy date) | |
| quick_search | string | |

- **Model:** `include QuickSearchable, HasFuzzyDate`. `has_fuzzy_date :start`. `has_fuzzy_date :end`. `belongs_to :family`, `:location` (optional). `has_many :photos`. `scope :chronological`.

---

### Task 3.7 — Photo Model

- **Category:** Model
- **Depends on:** 1.1, 3.1, 3.3, 3.5, 3.6
- **File:** `app/models/photo.rb`, `db/migrate/TIMESTAMP_create_photos.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| family_id | bigint | FK, not null |
| title | string | |
| description | text | |
| event_id | bigint | FK, nullable |
| location_id | bigint | FK, nullable |
| photographer_id | bigint | FK to people, nullable |
| upload_id | bigint | FK, nullable |
| taken_{date_type,year,month,day,season,circa,display_text,sort_date} | (fuzzy date) | |
| quick_search | string | |

- **Model:** `include QuickSearchable, HasFuzzyDate`. `has_fuzzy_date :taken`. `has_one_attached :file`. `validates :file, presence: true`. `belongs_to` family, event (opt), location (opt), photographer/Person (opt), upload (opt). `has_and_belongs_to_many :people`. `has_many :sources (PhotoSource)`, `:contributions`. Scopes: `chronological`, `recent`.

---

### Task 3.8 — photo_people Join Table

- **Category:** Migration
- **Depends on:** 3.3, 3.7
- **File:** `db/migrate/TIMESTAMP_create_photo_people_join_table.rb`
- **Action:** `create_join_table :photos, :people` with unique index on `[photo_id, person_id]`.

---

### Task 3.9 — PhotoSource Model

- **Category:** Model
- **Depends on:** 3.7, 3.3
- **File:** `app/models/photo_source.rb`, `db/migrate/TIMESTAMP_create_photo_sources.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| photo_id | bigint | FK, not null |
| description | string | e.g. "Red Photo Album" |
| source_person_id | bigint | FK to people, nullable |
| scanned_by_id | bigint | FK to people, nullable |
| scanned_at | date | nullable |
| notes | text | |

- **Model:** `belongs_to :photo`. `belongs_to :source_person, class_name: "Person", optional: true`. `belongs_to :scanned_by, class_name: "Person", optional: true`.

---

### Task 3.10 — Contribution Model

- **Category:** Model
- **Depends on:** 3.7, 1.2
- **File:** `app/models/contribution.rb`, `db/migrate/TIMESTAMP_create_contributions.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| photo_id | bigint | FK, not null |
| user_id | bigint | FK, not null |
| field_name | string | not null |
| value | text | |
| note | text | |

- **Model:** `belongs_to :photo`, `:user`. `FIELD_NAMES = %w[date location person_tag event description photographer source]`. Validates field_name inclusion. Scopes: `recent`, `for_field(name)`.

---

### Task 3.11 — Upload Model

- **Category:** Model
- **Depends on:** 1.1, 1.2, 3.3
- **File:** `app/models/upload.rb`, `db/migrate/TIMESTAMP_create_uploads.rb`
- **Fields:**

| Column | Type | Constraints |
|--------|------|------------|
| family_id | bigint | FK, not null |
| user_id | bigint | FK, not null |
| source_description | string | e.g. "Lindsey's Red album" |
| source_person_id | bigint | FK to people, nullable |
| scanned_by_id | bigint | FK to people, nullable |
| date_range_start_year | integer | nullable |
| date_range_end_year | integer | nullable |
| date_range_description | string | nullable |
| notes | text | |
| photo_count | integer | default: 0 |
| status | string | default: "pending" |

- **Model:** `belongs_to :family`, `:user`. Optional `:source_person`, `:scanned_by` (both Person). `has_many :photos`. Validates status inclusion in `%w[pending processing complete failed]`. Scope: `recent`.

---

### Task 3.12 — Domain Model Factories

- **Category:** Testing
- **Depends on:** 3.3–3.11
- **File:** `spec/factories.rb` (append)
- **Action:** Factories for Person, Location, Event, Photo (with `fixture_file("photo.jpg")`), PhotoSource, Contribution, Upload.
- **Create** `spec/fixtures/files/photo.jpg` — small test JPEG.

---

### Task 3.13 — Domain Model Specs

- **Category:** Testing
- **Depends on:** 3.12
- **Files:** `spec/models/{person,location,event,photo,photo_source,contribution,upload}_spec.rb`
- **Cover:** Validations, associations, fuzzy date computation, sort_date, display_text generation, quick_search, Location ancestry/full_path.

---

## Wave 4: Application Chrome

**Goal:** Polished Tabler sidebar layout with navigation, family switcher, flash messages, dashboard.

**Dependencies:** Wave 2 complete.

---

### Task 4.1 — NavComponent (ViewComponent)

- **Category:** Frontend, ViewComponent
- **Files:** `app/components/nav_component.rb`
- **Pattern:** Adapted from clockwork's `Bootstrap::NavComponent` for Tabler vertical nav. `renders_many :items` (NavItemComponent). Each item: label, href, icon (Tabler icon name), active flag.

---

### Task 4.2 — Sidebar Layout (Full Tabler)

- **Category:** Frontend
- **Depends on:** 4.1
- **File:** `app/views/layouts/shared/_sidebar.html.erb`
- **Action:** Full Tabler vertical navbar:
  - "Photos" app name at top
  - Nav items: Home, Photos, People, Events, Locations, Uploads
  - Active state via `controller_name`
  - Family switcher component at bottom
  - Current user name + Logout dropdown

---

### Task 4.3 — Family Switcher Component

- **Category:** Frontend, ViewComponent
- **Files:** `app/components/family_switcher_component.rb` + `.html.erb`
- **Action:** Dropdown showing current family. Lists all user's families with "Switch" buttons (PATCH to `current_family_path`).

---

### Task 4.4 — Flash Messages + Dismissable Controller

- **Category:** Frontend
- **Files:**
  - `app/views/layouts/shared/_flash.html.erb` — Tabler alerts for notice/alert
  - `app/javascript/controllers/dismissable_controller.js` — auto-hides after 5s

---

### Task 4.5 — Dashboard Home Page

- **Category:** Controller + Views
- **Depends on:** 4.2, Wave 3
- **File:** `app/views/site/index.html.erb`
- **Action:** Tabler dashboard cards:
  - Recent photos (8 thumbnails)
  - Stats row (photo/people/event/location counts)
  - Recent uploads
  - "Upload Photos" CTA

---

## Wave 5: CRUD Controllers + Views

**Goal:** Full CRUD for all domain resources. Tabler UI. All routes.

**Dependencies:** Wave 2 + Wave 3 complete. Wave 4 desirable but not blocking.

**Parallelization: Tasks 5.1–5.7 are independent — all can be built in parallel.**

### Shared Controller Pattern

Every resource controller scopes queries to `Current.family`:

```ruby
class ThingsController < ApplicationController
  before_action :set_thing, only: [:show, :edit, :update, :destroy]

  def index
    @things = Current.family.things
  end

  # ... standard CRUD ...

  private

  def set_thing
    @thing = Current.family.things.find(params[:id])
  end
end
```

---

### Task 5.1 — PeopleController + Views

- **Category:** Controller + Views
- **Files:**
  - `app/controllers/people_controller.rb`
  - `app/views/people/{index,show,new,edit}.html.erb`, `_form.html.erb`
- **Route:** `resources :people`
- **Index:** Tabler table — name, birth date, photo count
- **Show:** Profile card, linked user, photos they appear in, photos they took
- **Form:** first_name, last_name, date_of_birth, date_of_death, bio

---

### Task 5.2 — LocationsController + Views

- **Category:** Controller + Views
- **Files:**
  - `app/controllers/locations_controller.rb`
  - `app/views/locations/{index,show,new,edit}.html.erb`, `_form.html.erb`
- **Route:** `resources :locations`
- **Index:** Tree view indented by ancestry depth
- **Show:** Details, child locations, photos at this location
- **Form:** name, parent_id (select), address_line_1/2, city, state_province, postal_code, country_code, lat, lng

---

### Task 5.3 — EventsController + Views

- **Category:** Controller + Views
- **Files:**
  - `app/controllers/events_controller.rb`
  - `app/views/events/{index,show,new,edit}.html.erb`, `_form.html.erb`
- **Route:** `resources :events`
- **Index:** Cards/list with date range, photo count
- **Show:** Event details, photo grid
- **Form:** title, description, location_id (select), start fuzzy date fields, end fuzzy date fields
- **Also create:** `app/views/shared/_fuzzy_date_fields.html.erb` — reusable partial

---

### Task 5.4 — PhotosController + Views

- **Category:** Controller + Views
- **Files:**
  - `app/controllers/photos_controller.rb`
  - `app/views/photos/{index,show,new,edit}.html.erb`, `_form.html.erb`, `_photo_grid.html.erb`
- **Route:** `resources :photos`
- **Index:** Photo grid (thumbnails via Active Storage `variant(resize_to_fill: [300, 300])`)
- **Show:** Full image + metadata sidebar (date, location, event, photographer, people, sources, contributions)
- **Form:** file upload, title, description, event_id, location_id, photographer_id, taken fuzzy date fields, person_ids (multi-select)

---

### Task 5.5 — PhotoSourcesController (Nested)

- **Category:** Controller + Views
- **Files:**
  - `app/controllers/photo_sources_controller.rb`
  - `app/views/photo_sources/{new,edit}.html.erb`, `_form.html.erb`
- **Route:** `resources :photos do resources :sources, controller: "photo_sources", except: [:index, :show] end`
- **Form:** description, source_person_id, scanned_by_id, scanned_at, notes
- **Note:** Display inline on Photo show page. Create/edit redirect back to photo.

---

### Task 5.6 — ContributionsController (Nested)

- **Category:** Controller + Views
- **Files:**
  - `app/controllers/contributions_controller.rb`
  - `app/views/contributions/{new,_form,_contribution}.html.erb`
- **Route:** `resources :photos do resources :contributions, only: [:new, :create, :destroy] end`
- **Form:** field_name (select from FIELD_NAMES), value, note
- **Display:** Timeline on Photo show — "Alex said: location is Chester Zoo"

---

### Task 5.7 — FamilyMembershipsController

- **Category:** Controller + Views
- **Files:**
  - `app/controllers/family_memberships_controller.rb`
  - `app/views/family_memberships/{index,new}.html.erb`
- **Route:** `resources :family_memberships, only: [:index, :new, :create, :destroy]`
- **Logic:** `create` finds/creates User by email, creates membership. `destroy` removes (admin only, can't remove self). Admin check in `before_action`.

---

### Task 5.8 — Full Routes File

- **Category:** Routing
- **Depends on:** 5.1–5.7
- **File:** `config/routes.rb`

```ruby
Rails.application.routes.draw do
  root "site#index"

  # Auth
  resource :session, only: [:new, :create, :destroy] do
    scope module: :sessions do
      resource :login_code, only: [:show, :create]
    end
  end
  resource :family_selection, only: [:new]
  resource :current_family, only: [:update]

  # Domain resources
  resources :people
  resources :locations
  resources :events
  resources :photos do
    resources :sources, controller: "photo_sources", except: [:index, :show]
    resources :contributions, only: [:new, :create, :destroy]
  end
  resources :uploads
  resources :family_memberships, only: [:index, :new, :create, :destroy]

  # Search
  get "search", to: "search#index"

  # Infrastructure
  mount MissionControl::Jobs::Engine, at: "/jobs"
  get "up" => "rails/health#show", as: :rails_health_check
end
```

---

### Task 5.9 — CRUD Request Specs

- **Category:** Testing
- **Depends on:** 5.1–5.7
- **Files:** `spec/requests/{people,locations,events,photos,photo_sources,contributions,family_memberships}_spec.rb`
- **Cover:** Index (family-scoped), show, create, update, destroy. Verify family scoping — can't access other family's data.

---

## Wave 6: Batch Upload

**Goal:** Batch-upload multiple photos with shared source context.

**Dependencies:** Wave 5 tasks 5.4 + 5.5.

---

### Task 6.1 — UploadsController + Views

- **Category:** Controller + Views
- **Files:**
  - `app/controllers/uploads_controller.rb`
  - `app/views/uploads/{index,new,show}.html.erb`
- **Route:** `resources :uploads` (in 5.8)
- **Index:** Recent uploads with status, photo count, date
- **Show:** Upload details + grid of created photos

---

### Task 6.2 — Batch Upload Form

- **Category:** Frontend
- **Depends on:** 6.1
- **File:** `app/views/uploads/_form.html.erb`
- **Fields:** source_description, source_person_id (select), scanned_by_id (select), date_range_description, date_range_start_year, date_range_end_year, notes, files[] (`multiple: true`)

---

### Task 6.3 — Dropzone Stimulus Controller

- **Category:** Frontend
- **File:** `app/javascript/controllers/dropzone_controller.js`
- **Action:** Drag-and-drop zone, file previews + count, integrates with form file input.

---

### Task 6.4 — Upload Processing Logic

- **Category:** Backend
- **Depends on:** 6.1, 6.2
- **File:** `app/controllers/uploads_controller.rb` (create action)
- **Logic:** Create Upload, iterate `params[:files]`, create Photo + PhotoSource per file with shared source context from the Upload. Update `photo_count` and `status` on completion.

---

### Task 6.5 — Upload Request Specs

- **Category:** Testing
- **File:** `spec/requests/uploads_spec.rb`
- **Cover:** Create with multiple files, verify Photos + PhotoSources created, status tracking, photo_count.

---

## Wave 7: Polish + Integration

**Goal:** Search, full seeds, final UI refinements, all tests green.

**Dependencies:** All previous waves.

---

### Task 7.1 — Search Integration

- **Category:** Feature
- **Files:**
  - `app/controllers/search_controller.rb`
  - `app/views/search/index.html.erb`
  - `app/javascript/controllers/search_controller.js` (debounced input)
- **Route:** `get "search"` (in 5.8)
- **Action:** Search box in sidebar. Queries Photos, People, Events, Locations via `quick_search`. Results grouped by type.

---

### Task 7.2 — Photo Gallery View

- **Category:** Frontend
- **Files:**
  - `app/views/photos/_photo_grid.html.erb` — responsive CSS Grid
  - `app/views/photos/index.html.erb` — enhanced grid view
  - `app/javascript/controllers/lightbox_controller.js` — simple lightbox
- **Action:** Thumbnails via `photo.file.variant(resize_to_fill: [300, 300])`. Click opens lightbox or navigates to show.

---

### Task 7.3 — Development Seeds (Full)

- **Category:** Data
- **File:** `db/seeds.rb`
- **Creates:**
  - 2 Families ("The Muirs", "The Smiths")
  - 3 Users: Alex (admin Muirs), Robin (member Muirs), Jordan (member of both)
  - 10 People per family
  - 5 Locations per family (with hierarchy: UK > England > Manchester)
  - 3 Events per family (with fuzzy dates)
  - 20 Photos per family (with sample images)
  - PhotoSources, Contributions
  - 1 Upload per family
  - Print login credentials

---

### Task 7.4 — Fuzzy Date Form Component

- **Category:** Frontend, ViewComponent + Stimulus
- **Files:**
  - `app/components/fuzzy_date_fields_component.rb` + `.html.erb`
  - `app/javascript/controllers/fuzzy_date_controller.js`
- **Action:** Reusable component. Stimulus controller shows/hides fields based on date_type:
  - exact -> year, month, day
  - month -> year, month
  - season -> year, season dropdown
  - year -> year only
  - decade -> year only
  - unknown -> hide all

---

### Task 7.5 — Final Test Suite

- **Category:** Testing
- **Depends on:** All previous
- **Action:** `bundle exec rspec` — all green.

---

### Task 7.6 — Smoke Test

- **Category:** Validation
- **Depends on:** 7.5
- **Action:** `bin/dev` + `bin/rails db:seed`. Manually verify:
  1. Login flow (email -> code -> session)
  2. Family switching (multi-family user)
  3. Auto-select (single-family user)
  4. CRUD for: People, Locations, Events, Photos, Sources, Contributions
  5. Batch upload (multiple files + source context)
  6. Search
  7. Photo gallery with thumbnails
  8. Sidebar nav with active states
  9. All pages render with Tabler styling
  10. Logout

---

## Critical Path

```
Wave 0 (Bootstrap)
  |
  v
Wave 1 (Core Models)
  |                    \
  v                     v
Wave 2 (Auth)         Wave 3 (Domain Models)  [PARALLEL]
  |                     |
  v                     |
Wave 4 (Chrome)         |
  |                     |
  +-------+-------------+
          |
          v
     Wave 5 (CRUD)    [5.1-5.7 PARALLEL]
          |
          v
     Wave 6 (Batch Upload)
          |
          v
     Wave 7 (Polish)
```

**Critical path: 0 -> 1 -> 3 -> 5 -> 6 -> 7**

---

## Parallelization Summary

| Wave | Tasks | Parallelizable Within Wave |
|------|-------|---------------------------|
| 0 | 12 | 0.4+0.11; 0.5+0.7+0.8 |
| 1 | 8 | 1.1+1.2; 1.3+1.4+1.5 |
| 2 | 12 | 2.1+2.2 |
| 3 | 13 | 3.3+3.5; 3.6+3.9+3.10+3.11; 3.1+3.2 |
| 4 | 5 | 4.3+4.4 |
| 5 | 9 | **5.1-5.7 all parallel** (best opportunity) |
| 6 | 5 | 6.2+6.3 |
| 7 | 6 | 7.1+7.2+7.3+7.4 |

**Waves 2+3 run in parallel after Wave 1.**
**Wave 4 runs in parallel with Wave 5.**

---

## Task Count

| Wave | Name | Tasks |
|------|------|-------|
| 0 | Project Bootstrap | 12 |
| 1 | Core Auth Models | 8 |
| 2 | Authentication System | 12 |
| 3 | Domain Models | 13 |
| 4 | Application Chrome | 5 |
| 5 | CRUD Controllers + Views | 9 |
| 6 | Batch Upload | 5 |
| 7 | Polish + Integration | 6 |
| **Total** | | **70** |

---

## Migrations (Ordered)

1. `enable_extensions` — btree_gist, pg_trgm
2. `create_families` — name, description, slug
3. `create_users` — name, email, person_id (column only)
4. `create_sessions` — user_id, ip_address, user_agent
5. `create_login_codes` — user_id, code, expires_at
6. `create_family_memberships` — user_id, family_id, role
7. `create_people` — family_id, first_name, last_name, dob, dod, bio, quick_search
8. `add_person_foreign_key_to_users` — FK constraint
9. `create_locations` — family_id, name, ancestry, address fields, lat/lng, quick_search
10. `create_events` — family_id, title, description, location_id, fuzzy date fields (x2), quick_search
11. `create_photos` — family_id, title, description, FKs, fuzzy date fields, quick_search
12. `create_photo_people_join_table` — photo_id, person_id
13. `create_photo_sources` — photo_id, description, source_person_id, scanned_by_id, scanned_at, notes
14. `create_contributions` — photo_id, user_id, field_name, value, note
15. `create_uploads` — family_id, user_id, source fields, date range fields, status

---

## File Tree (Final)

```
photos/
├── Gemfile
├── Procfile.dev
├── vite.config.ts
├── config/
│   ├── database.yml
│   ├── routes.rb
│   ├── storage.yml
│   ├── vite.json
│   └── initializers/simple_form.rb
├── app/
│   ├── components/
│   │   ├── nav_component.rb
│   │   ├── family_switcher_component.rb + .html.erb
│   │   └── fuzzy_date_fields_component.rb + .html.erb
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── concerns/
│   │   │   ├── authentication.rb
│   │   │   ├── authentication/via_login_code.rb
│   │   │   └── set_current_family.rb
│   │   ├── site_controller.rb
│   │   ├── sessions_controller.rb
│   │   ├── sessions/login_codes_controller.rb
│   │   ├── family_selections_controller.rb
│   │   ├── current_families_controller.rb
│   │   ├── people_controller.rb
│   │   ├── locations_controller.rb
│   │   ├── events_controller.rb
│   │   ├── photos_controller.rb
│   │   ├── photo_sources_controller.rb
│   │   ├── contributions_controller.rb
│   │   ├── uploads_controller.rb
│   │   ├── family_memberships_controller.rb
│   │   └── search_controller.rb
│   ├── javascript/
│   │   ├── entrypoints/application.js
│   │   └── controllers/
│   │       ├── application.js
│   │       ├── index.js
│   │       ├── dismissable_controller.js
│   │       ├── dropzone_controller.js
│   │       ├── fuzzy_date_controller.js
│   │       ├── search_controller.js
│   │       └── lightbox_controller.js
│   ├── mailers/
│   │   ├── application_mailer.rb
│   │   └── login_code_mailer.rb
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── current.rb
│   │   ├── family.rb
│   │   ├── family_membership.rb
│   │   ├── user.rb
│   │   ├── session.rb
│   │   ├── login_code.rb
│   │   ├── person.rb
│   │   ├── photo.rb
│   │   ├── photo_source.rb
│   │   ├── event.rb
│   │   ├── location.rb
│   │   ├── contribution.rb
│   │   ├── upload.rb
│   │   ├── fuzzy_date_formatter.rb
│   │   └── concerns/
│   │       ├── has_fuzzy_date.rb
│   │       └── quick_searchable.rb
│   └── views/
│       ├── layouts/
│       │   ├── application.html.erb
│       │   ├── login.html.erb
│       │   └── shared/ (_head, _sidebar, _flash)
│       ├── site/index.html.erb
│       ├── sessions/new.html.erb
│       ├── sessions/login_codes/show.html.erb
│       ├── family_selections/new.html.erb
│       ├── people/ (index, show, new, edit, _form)
│       ├── locations/ (index, show, new, edit, _form)
│       ├── events/ (index, show, new, edit, _form)
│       ├── photos/ (index, show, new, edit, _form, _photo_grid)
│       ├── photo_sources/ (new, edit, _form)
│       ├── contributions/ (new, _form, _contribution)
│       ├── uploads/ (index, new, show, _form)
│       ├── family_memberships/ (index, new)
│       ├── search/index.html.erb
│       ├── shared/_fuzzy_date_fields.html.erb
│       └── login_code_mailer/ (.html.erb + .text.erb)
├── db/
│   ├── migrate/ (15 migrations)
│   ├── seeds.rb
│   └── structure.sql
└── spec/
    ├── spec_helper.rb
    ├── rails_helper.rb
    ├── factories.rb
    ├── fixtures/files/photo.jpg
    ├── support/request_helpers.rb
    ├── models/ (10 spec files)
    └── requests/ (9 spec files)
```

---

## Deferred Items (NOT in V1)

1. **AI features** — Face recognition, sequence detection, orientation correction
2. **AWS S3** — Local disk only. S3 is a deploy-time config change.
3. **Mux video** — Photos only in v1
4. **Action Policy** — Gem included but full authorization deferred. Admin check only for memberships.
5. **Rich text (Lexxy)** — Plain text/textarea for descriptions
6. **money-rails, phonelib, pdf-reader, streamio-ffmpeg** — Not needed, omitted from Gemfile
7. **Devcontainer** — Deferred per requirements
8. **Kamal deployment** — Gem included, config deferred
9. **Email delivery** — Console logging in dev. Resend config deferred.
10. **Ruby 3.4.7** — Using 3.2.2. Upgrade deferred.
11. **Algolia search** — Using pg_trgm + QuickSearchable for v1