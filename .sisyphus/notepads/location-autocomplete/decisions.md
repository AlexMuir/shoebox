# Decisions — location-autocomplete

## 2026-03-03 — Session Start

- External provider: Google Places API (New), NOT Nominatim
- Hierarchy: Ancestry tree traversal (NO PostGIS)
- HTTP client: Net::HTTP (stdlib, NO Faraday/HTTParty)
- Auto-parent chain: country > city > address (smart depth from Google address_components)
- Leaf node dedup: google_place_id column (partial unique index)
- Parent node dedup: name + parent_location combo (no per-component placeId from Google)
- Auto-name from Google display name, user renames later on edit page
- Scope: All 3 dropdowns replaced (photo, event, location parent)
- Location parent selector: local-only mode (localOnly Stimulus value = true)
- Testing: TDD with RSpec + FactoryBot + WebMock
- Session tokens: generated in Stimulus on connect(), cleared after selection
- Graceful degradation: return local-only when API key absent, log warning
- NO google-apis-places_v1 gem — use Net::HTTP directly
