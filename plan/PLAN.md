# Photos — App Plan

## Overview

This is a website that lets families upload their old photos and then collaboratively organize them 
into a beautiful history. People are tagged, images are dated and located and the resulting files can 
be shared.  The files are securely stored and export is available so at no time is anyone locked in.

## Core Concepts

- Dates and times can be fuzzy - Summer 2020, or roughly 1890 are valid and we need to handle them.
- Events - Photos of a specific event are all grouped, an event might be a Party, or a Family Holiday.
- Location - a photo can be at a location.  A location might be an address, or just Kenya, or Africa.
- Photos can have one or more sources - which could be Lindsey Muir (linked) Red Photo Album, scanned by Alex Muir in 2006.
- Photos might have a photographer
- The context of a photo is built up over time and from multiple contributors. So we can see that Alex Muir said it was Chester Zoo,
  and Robin Muir said it was July 1984.
- I feel like initially there's a concept of Families, and users are members of one or more families.  These will overlap and I'm not clear at
  the moment on how we handle this but it's not a big concern. 
- Later I want AI powered features that:
  - Recognise faces
  - Make good guesses on the sequence of images based on the relative ages of faces - ie. teenager comes before young adult.
  - Identify photos from the same sequence (same background, same content etc.)
  - Correctly orientate photos. 
  - Try to match up the back of a photo with the front and identify any useful data on that back.  This might be two adjacent image files with very close timestamps, one with a white bacckground and similary dimensions.

- The original source files are always retained unaltered.
- Photos are batch uploaded and during this upload, context around their source can be added.  Eg. These photos were in Lindsey's Red album and are from around 1982 to 1990.  

---

## Tech Stack

Baseline pulled from [clockwork](../clockwork).

### Runtime

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | Ruby 3.4.7 | |
| Framework | Rails 8.1 | |
| Database | PostgreSQL (primary) | `pg ~> 1.1` |
| Database | SQLite (cache/queue/cable) | `sqlite3` |
| Server | Puma + Thruster | HTTP caching/compression, X-Sendfile |
| Background Jobs | Solid Queue | DB-backed, no Redis needed |
| Cache | Solid Cache | DB-backed |
| WebSockets | Solid Cable | DB-backed |
| Job Dashboard | Mission Control Jobs | |

### Frontend

| Layer | Choice | Notes |
|-------|--------|-------|
| JS Bundling | Vite | `vite_rails` + `vite-plugin-ruby` |
| Asset Pipeline | Propshaft | |
| CSS | Built through Vite | `dartsass-rails` |
| SPA-like nav | Turbo | `@hotwired/turbo` |
| JS framework | Stimulus | `@hotwired/stimulus` |
| Rich Text | Lexxy | `@37signals/lexxy` |
| Forms | Simple Form | |
| Components | ViewComponent | |

### Storage & Media

| Layer | Choice | Notes |
|-------|--------|-------|
| File Storage | Active Storage + AWS S3 | `aws-sdk-s3` |
| Image Processing | ImageProcessing     | `image_processing ~> 1.2` |
| Video | Mux | `mux_ruby` |
| PDF | pdf-reader | Page counting |
| Audio/Video | streamio-ffmpeg | |

### Domain Libraries

| Library | Purpose |
|---------|---------|
| action_policy | Authorization |
| ancestry | Tree/hierarchy structures |
| geocoder | Geocoding |
| countries | Country data |
| phonelib | Phone number parsing/validation |
| money-rails | Currency/money handling |
| resend | Transactional email |
| faker | Seed/test data |

### Testing & Quality

| Tool | Purpose |
|------|---------|
| RSpec | Test framework (`rspec-rails ~> 8.0`) |
| Factory Bot | Test factories (`factory_bot_rails`) |
| Shoulda Matchers | One-liner model/controller tests |
| Guard + guard-rspec | Auto-run tests on file change |
| Bundler Audit | Gem vulnerability scanning |
| Brakeman | Static security analysis |
| RuboCop (Rails Omakase) | Linting/style |

### Deployment

| Tool | Purpose |
|------|---------|
| Kamal | Container-based deploy |
| Thruster | HTTP acceleration for Puma |
| Docker | Containerization |

### Dev Process (Procfile.dev)

```
web:  bin/rails server -p 3000
css:  bin/rails dartsass:watch
vite: bin/vite dev
jobs: bin/jobs
```

---

## Data Model

<!-- Define your models, fields, and associations here. -->


## Third-Party Integrations

<!-- API keys, webhooks, external services. -->

| Service | Purpose | Config |
|---------|---------|--------|
| AWS S3 | File storage | `credentials.yml.enc` |
| Mux | Video processing | |
| Resend | Email delivery | |
| Algolia | Autocomplete/search | |

---
