# Milestone 2 — Stone roof + Graphics Preset quality levels

Date: 2026-11-18

## Quality levels (player picks in Settings → Graphics → Graphics Preset)

| Preset | Campus files | What it is |
| --- | --- | --- |
| **Low (Faster campus)** | `assets/campus_low.glb`, `assets/runtime_campus_low/` | Game-ready rebuilds: items 1 (chairs) + 2 (roof) |
| **Medium (Recommended)** | `assets/campus.glb`, `assets/runtime_campus/` | Original campus, byte-identical to before this work |
| **High (Extra detail)** | `assets/campus_high.glb`, `assets/runtime_campus_high/` (not built yet) | Reserved; falls back to Medium until the files exist |

- One switch point: `scripts/launcher/campus_quality.gd`. It is used by the launcher registry, the mission loader, both mode adapters (Incident Response, After Hours), `campus_runtime.gd` and `zombie_game.gd`.
- The preset already controlled MSAA, shadows and draw distance; now it also picks the campus geometry. A new choice applies on the next mission load. The setting's tooltip says so.
- Test/capture override: `-- --campus-quality=low`.

## Roof (roadmap item 2)

- `E9 unified smooth stone roof and rounded frame`: 1,639,652 → **14,998 tris** (Medium ships the old 0.1 collapse, about 164k).
- Method: gentle collapse to 120k, then planar dissolve (1°), then collapse to 15k, then smooth-by-angle (30°). Takes 48 s; dissolving the full mesh first stalled for more than 10 min.
- Ground views match the original; an aerial view shows small lumps at two rounded roof corners (not visible from player height).
- Skills: `blender-director` → `asset-optimization` → `retopology` → `qa-review` → `godot-export`

## Numbers, harness views (Medium = before, Low = chairs + roof)

| View | FPS Medium → Low | Draw calls | Triangles drawn |
| --- | --- | --- | --- |
| Plaza | 12.6 → 23.7 | 1306 → 1150 | 1.87M → 0.55M |
| Reception | 7.5 → 18.3 | 1503 → 1309 | 3.22M → 0.84M |
| Auditorium rear | 11.7 → 19.7 | 1082 → 873 | 3.18M → 0.78M |
| Glazed entrance | 14.5 → 18.7 | 1260 → 1134 | 1.83M → 0.56M |
| Security | 13.2 → 19.9 | 1337 → 1206 | 1.97M → 0.69M |
| Auditorium teaching | 24.2 → 28.6 | 1252 → 1126 | 2.32M → 0.60M |
| Cream front | 12.8 → 13.4 | 2382 → 2256 | 2.76M → 1.49M |
| Cream 45° | 12.3 → 18.7 | 1654 → 1591 | 1.79M → 1.15M |

Campus total: 3.28M → 1.58M instanced tris. Low `campus_low.glb` is 37.7 MB; Low chunks are 34 MB, Medium chunks 41 MB.

**Triangles are no longer the bottleneck: draw calls (1,100–2,250) are.** Roadmap item 3 (merge by material) is next for FPS.

## Tests

- Launcher integration test, Medium and Low: mission reaches READY, 5 stations, 4 doors, 198 chair colliders. Low loads 17 MultiMesh batches (shared chairs), Medium 19.
- 5 checks fail on **both**, and fail identically on the original code with my changes stashed. They are pre-existing:
  - stale mesh/batch counts (5965/28)
  - 3 error/cancel-flow checks
- Capture harness: `passed=true failures=0 captures=18`.

## Files

- New: `scripts/launcher/campus_quality.gd`, `tools/campus_roof.py`, `tools/roof_preview.py`, `assets/campus_low.glb`(+ `.import`), `assets/asset-manifest-low.json`, `assets/source-inventory-low.json`, `assets/runtime_campus_low/` (95 files), `art_audit/.gdignore`
- Changed:
  - `tools/export_campus.py` (`--quality=low|medium`)
  - `tools/launcher/bake_campus_chunks.gd` (`--source=`, `--out=`)
  - `scripts/launcher/mode_registry.gd`, `mission_loader.gd`, `incident_mode_adapter.gd`
  - `scripts/antigravity/zombie/zombie_mode_adapter.gd`, `zombie_game.gd`
  - `scripts/campus_runtime.gd`, `scripts/antigravity/launcher/settings_page.gd`
- Restored to original: `assets/campus.glb`, `asset-manifest.json`, `source-inventory.json`
- Backups: `art_audit/backups/02_roof_2026-11-18/`

## Rebuild commands

```
blender --background --threads 4 --python tools/export_campus.py -- --quality=low
Godot --headless --path . --import
Godot --headless --path . -s tools/launcher/bake_campus_chunks.gd -- --source=res://assets/campus_low.glb --out=res://assets/runtime_campus_low
```

## Notes

- `campus.glb` is in Git LFS. Add `campus_low.glb` and `assets/runtime_campus_low/*.scn` to LFS before committing (≈72 MB).
- Godot had been importing `art_audit/` (backups, PNGs). `art_audit/.gdignore` now stops that.
