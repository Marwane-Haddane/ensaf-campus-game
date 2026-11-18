# Milestone 1 — Auditorium chairs (roadmap item 1)

Date: 2026-11-18 · Skills: `blender-director` → `asset-optimization` → `retopology` (per-part decimate) → `lod-pipeline` (Godot auto-LOD on import) → `qa-review` → `godot-export`

## What changed

- The 4 chair master meshes (23,276 tris, 6 materials each) became **2 shared meshes**, one per colour: `SM_E9_AuditoriumChair_Crimson` and `SM_E9_AuditoriumChair_Blue`. Each has **1,509 tris and 3 materials**: upholstery, plywood, steel.
- Removed: stitched piping tubes, tufting dots, sub-3 cm bolts, and cushion faces hidden against the shell. The perforated seat underside is rebuilt as a clean slab (convex hull).
- Each big shell is decimated separately; small parts (legs, feet, armrests) are untouched.
- All 198 chairs keep their object names, positions, seat collision boxes and MultiMesh batching.
- Source `.blend` untouched: the change is in-memory in `tools/export_campus.py`.

## Metrics (shipped look, polish on)

| View | FPS before → after | Draw calls | Triangles drawn |
| --- | --- | --- | --- |
| Plaza | 12.6 → **20.6** | 1306 → 1150 | 1.87M → 0.55M |
| Reception | 7.5 → **16.8** | 1503 → 1309 | 3.22M → 1.29M |
| Auditorium rear | 11.7 → **20.5** | 1082 → 873 | 3.18M → 1.23M |
| Glazed entrance | 14.5 → **21.3** | 1260 → 1134 | 1.83M → 0.56M |
| Security | 13.2 → **21.2** | 1337 → 1206 | 1.97M → 0.68M |
| Auditorium teaching | 24.2 → **26.6** | 1252 → 1126 | 2.32M → 1.04M |
| Cream front | 12.8 → 13.9 | 2382 → 2256 | 2.76M → 1.49M |
| Cream 45° | 12.3 → 16.7 | 1654 → 1591 | 1.79M → 1.15M |
| Cream inside-out | 34.5 → 30.6 (noise, nothing changed in view) | 328 → 328 | same |

- Campus instanced triangles: 3,275,284 → **1,730,686** (−47%).
- `campus.glb`: 42.6 MB → 41.4 MB.
- Chair triangles: 198 × 9.3k (old 0.4 decimation) → 198 × 1.5k.
- Harness: `passed=true failures=0 captures=18`.

## Files

- New: `tools/campus_chairs.py` (optimizer), `tools/chair_preview.py` (QA renders)
- Updated: `tools/export_campus.py`, `assets/campus.glb`, `assets/asset-manifest.json`, `assets/source-inventory.json`
- Backups: `art_audit/backups/01_chairs_2026-11-18/`
- QA renders: `art_audit/work/01_chairs/chair_*.png` (left = new, right = original)
- After captures: `art_audit/after/01_chairs/polished_*.png`, `harness_report.json`

## Known

- The Godot console run sometimes segfaults on exit, after the report is written. Seen once (first run), not on the second. Shutdown only, no effect on results.
- Cream front still slow (2,256 draws). That is roadmap item 3 (draw-call pass).
