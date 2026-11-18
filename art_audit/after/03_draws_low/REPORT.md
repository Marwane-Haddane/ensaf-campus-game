# Milestone 3 — Draw-call pass (Low preset only)

Date: 2026-11-18 · Skills: `asset-optimization` → `lod-pipeline` (render batching) → `lighting` (shadow budget) → `qa-review`

## Where draw calls came from (`tools/draw_profile.gd`, Low campus)

| View | All on | Sun shadow off | Local lights off | Glass hidden | Small objects not casting |
| --- | ---: | ---: | ---: | ---: | ---: |
| Plaza | 1150 | **635** | 1150 | 1067 | 977 |
| Reception | 1309 | **440** | 1266 | 1276 | 974 |
| Cream front | 2256 | **997** | 2256 | 2235 | 1875 |
| Auditorium rear | 873 | **352** | 869 | 855 | 737 |

The sun shadow pass (2 cascades) was about half of all draws and about 60% of triangles. The 17 lamp lights cost almost nothing.

## Changes (Low only; Medium proven unchanged)

1. **Sun shadow:** 1 cascade (`SHADOW_ORTHOGONAL`) over 24 m instead of 2 cascades (`scripts/main.gd`, `_apply_sun_quality`). After Hours on Low already turns sun shadows off.
2. **Small casters:** 3,128 meshes under 1.5 m (trim, pickets, props) no longer cast sun shadows (`campus_runtime.gd`, `_disable_small_shadow_casters`).
3. **Stronger merging:** multi-material meshes are merged per material, the cap rises from 1,200 to 6,000 tris, and there is no minimum group size. Result: 5,078 objects in 416 merged surfaces, vs 4,398 objects in 104 surfaces.

## Results (harness, 1280×720, MSAA 2x forced by harness)

| View | Medium FPS | Low FPS | Medium draws → Low | Medium tris → Low |
| --- | ---: | ---: | --- | --- |
| Plaza | 15.0 | **26.8** | 1306 → 869 | 1.87M → 0.57M |
| Reception | 12.3 | **22.3** | 1503 → 776 | 3.22M → 0.70M |
| Auditorium rear | 13.8 | **24.4** | 1082 → 535 | 3.18M → 0.63M |
| Glazed entrance | 14.7 | 18.7 | 1260 → 779 | 1.83M → 0.55M |
| Security | 12.7 | 17.3 | 1337 → 828 | 1.97M → 0.64M |
| Auditorium teaching | 24.8 | 27.2 | 1252 → 517 | 2.32M → 0.35M |
| Cream front | 12.9 | 15.1 | 2382 → 1070 | 2.76M → 1.08M |
| Cream 45° | 14.2 | 16.5 | 1654 → 902 | 1.79M → 0.90M |
| Cream inside-out | 41.1 | 35.2 | 328 → 233 | 0.22M → 0.11M |

- **Medium:** draws and triangles match the original baseline exactly in all 9 views. FPS differs between runs because this machine's timing is noisy (±3 FPS).
- **Low:** draws are 33–55% lower than Medium. Real Low play is also lighter than this table, because the preset turns MSAA off and the harness forces 2x.
- **Not reached:** 30 FPS in glazed entrance, security and cream views. Draws are now 500–1,000, so the remaining cost is likely pixel work (large glass, full-screen transparency) or CPU. That needs a GPU profile, not more merging.

## Tests

- Capture harness, Low and Medium: `passed=true failures=0 captures=18` each.
- Launcher integration test, Low: mission reaches READY. The same 5 pre-existing failures as the original code; no new failures.
- **Cost:** Low's first mission load is 17.5 s (Medium 16.1 s). The merge step now takes 0.74 s in one loading-screen frame (was 0.06 s).

## Files

- Changed:
  - `scripts/campus_runtime.gd` (Low shadow + merge rules; Medium path keeps its old rules)
  - `scripts/main.gd` (sun per preset)
- New: `tools/draw_profile.gd`
- Backups: `art_audit/backups/03_draws_2026-11-18/`
- Captures: `art_audit/after/03_draws_low/`, `art_audit/after/03_draws_medium/`
- Profile data: `art_audit/work/03_draws/profile.json`
