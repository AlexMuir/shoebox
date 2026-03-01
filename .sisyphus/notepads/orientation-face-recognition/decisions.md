# Decisions — orientation-face-recognition

## 2026-03-01 Session ses_359877d58ffea2jl05a13namh5 — Atlas Initialization

### Architecture
- Python sidecar (NOT pure Ruby onnxruntime) — user chose this after risk analysis
- InsightFace buffalo_s model (CPU-only, no GPU)
- neighbor gem for pgvector integration
- Simple Ruby DBSCAN (no rumale-clustering gem)

### Scope
- EXIF-only orientation (no ML orientation detection in Phase 1)
- Face regions only (no auto-creation of photo_people records)
- Lightweight admin UI (no bounding box overlays, no merge/split)
- Tests after implementation (not TDD)

### Deferred to Phase 2+
- ML-based orientation detection (image pixels)
- Scene/style matching for photo sequencing
