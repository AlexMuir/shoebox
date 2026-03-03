# Decisions

## [2026-03-03] Architecture Decisions

### Dual attachment strategy
- `has_one_attached :original` — pristine uploaded file, NEVER modified
- `has_one_attached :working_image` — auto-rotated copy, source for all variants
- `display_image` method: returns `working_image` if attached, else `original`
- Working image only created when rotation is needed (storage optimization)
- New blob always created for working copy (never share blobs)

### Metadata hash structure
```ruby
{
  file: { original_filename:, content_type:, file_size:, file_modified_at: },
  dimensions: { width:, height: },
  exif: { make:, model:, date_time_original:, exposure_time:, f_number:, iso:, focal_length:, gps_latitude:, gps_longitude:, orientation:, ...all other tags },
  filename_date: { parsed:, year:, month:, day:, hour:, minute:, second:, pattern: },
  processing: { extracted_at: }
}
```

### EXIF orientation mapping
- 1 = normal (no rotation needed)
- 3 = 180°
- 6 = 90° CW
- 8 = 90° CCW

### Orientation detection priority
1. EXIF orientation tag (from mini_exiftool)
2. Fallback: existing microservice at `ORIENTATION_SERVICE_URL` (http://localhost:8150)

### Attachment rename
- DB reference only: `ActiveStorage::Attachment.where(record_type: "Photo", name: "image").update_all(name: "original")`
- No file moves needed
