# Issues & Gotchas

## [2026-03-03] Known Issues

### Fixture images
- Only `spec/fixtures/photos/orientation/1_-90deg.jpg` exists
- For no-EXIF tests: generate a minimal PNG in-spec (e.g., using StringIO with raw PNG bytes, or Vips::Image.black(1,1).write_to_file)

### ApplicationService
- Check if `ApplicationService` base class exists before inheriting from it
- If not, create a simple PORO with `.call` class method

### Photo model callbacks
- `after_commit :enqueue_orientation_detection` — Task 4 should remove this (Task 6 replaces it)
- `extract_metadata` and `extract_exif_taken_at` callbacks reference `image` — must be updated to `original`

### view_component gem
- Already in Gemfile (line 33)
- `app/components/` directory does NOT exist yet — Task 5 must create it

### Variant definitions
- Currently on `has_one_attached :image` block
- Must move to `has_one_attached :working_image` block in Task 4
- `oriented_variant` method must be simplified to use `display_image.variant(name)`
