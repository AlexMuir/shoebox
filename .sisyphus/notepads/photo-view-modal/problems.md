# PhotoView Modal QA - Problems Found

## Date: 2026-03-03

### CRITICAL: PhotoView Modal Does Not Open

**Symptom**: Clicking a photo thumbnail on `/photos` navigates to the standard Rails show page (`/photos/:id`) instead of opening the React PhotoView modal.

**Root Cause**: Three critical files are MISSING from the implementation:

1. **`app/javascript/controllers/photo_view_controller.js`** — The Stimulus bridge controller that should intercept clicks and mount the React component. This file does NOT exist.

2. **`app/javascript/components/PhotoView/PhotoViewApp.jsx`** — The root React component that orchestrates the modal. This file does NOT exist.

3. **Gallery template lacks Stimulus wiring** — `app/views/photos/index.html.erb` has no `data-controller="photo-view"` on the grid container and no `data-action="click->photo-view#open"` on thumbnail links. It uses plain `<a href="/photos/:id">` links.

4. **Controller not registered** — `app/javascript/controllers/index.js` only registers 4 controllers: `person-autocomplete`, `file-timestamps`, `face-tagging`, `location-autocomplete`. No `photo-view` controller registration.

5. **No JSON API endpoint** — `/photos/:id.json` returns `ActionController::UnknownFormat`. The React component would need a JSON API to fetch photo data.

### What DOES Exist:
- `app/javascript/components/PhotoView/PhotoToolbar.jsx` — Zoom in/out, tag, fullscreen buttons (complete, well-structured)
- `app/javascript/components/PhotoView/PhotoSidebar.jsx` — Details, people, contributions sidebar (complete, well-structured)

### Minor: Active Storage 404s
- 4 image variants return 404 on the gallery page (files missing from disk, not a code issue)
- Affected files: `2010_12_25_12_09_42.jpg` (2 variants), `2010_12_25_12_13_03.jpg`, `three_faces.jpg`

### Infrastructure OK:
- Vite dev server: Running and serving JS correctly
- Stimulus: Loaded and functional (window.Stimulus available)
- Rails server: Running at port 3000
- Auth: Already logged in as alex@example.com
- Gallery renders 18 photos with thumbnails
- Standard photo show page works correctly (no JS errors)
