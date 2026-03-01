# Issues — orientation-face-recognition

## 2026-03-01 Session ses_359877d58ffea2jl05a13namh5 — Atlas Initialization

(No issues yet — starting fresh)

## F2: Code Quality Review Findings (2026-03-01)

### Issues Found

1. **N+1 query** — `app/views/face_clusters/index.html.erb:18`: `.count` on preloaded `:face_regions` association fires a new SQL COUNT per person. Should use `.size` to leverage preloaded data.

2. **Bare rescue** — `app/services/face_analysis_client.rb:31`: `rescue` with no exception class in `sidecar_available?`. Should specify `StandardError` or targeted exceptions (`Errno::ECONNREFUSED, Net::OpenTimeout`).

3. **Hard-coded MIME type** — `app/services/face_analysis_client.rb:88`: `Content-Type: image/jpeg` is used for ALL images including PNG/WebP. Should detect from file extension or use `application/octet-stream`.

4. **No HTTP status check** — `app/services/face_analysis_client.rb:79`: `JSON.parse(response.body)` without checking `response.is_a?(Net::HTTPSuccess)`. A 500 from the sidecar will parse error HTML/JSON unexpectedly.

5. **Missing transaction** — `app/services/face_clustering_service.rb:101`: Individual `update!` calls in `assign_clusters` are not wrapped in a transaction. Partial failure leaves inconsistent cluster assignments.

6. **Broad inline rescue** — `app/services/orientation_service.rb:33`: `image.get("orientation") rescue 1` catches all exceptions including NoMethodError/TypeError. Minor but could mask bugs.

### Clean Files (no issues)
- face_region.rb, face_clusters_controller.rb, photo_analysis_job.rb
- show.html.erb, ml.rake, ml_sidecar/main.py
- All 6 spec files

