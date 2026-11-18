# Milestone 5 — High-preset vegetation

Date: 2026-11-18 · Skills: `environment-artist` → `vegetation-artist` → `texture-workflow` → `lookdev` → `qa-review`

## Decision

The new plants are on the **High** preset only. **Medium** keeps the original plants and **Low** is unchanged.

The source trees and palms have role `landscape` and no collision, so swapping them changes no gameplay.

## Kit (`tools/vegetation_kit_high.py`, Blender 4.3 + numpy, fixed seeds, no external images)

| Template | Tris | Replaces |
| --- | ---: | --- |
| SM_VEG_ShadeTree_A / B (olive-style, leaf-cluster cards on branches) | 652 / 612 | Campus plaza shade tree ×10, R3 Garden tree ×28, Courtyard planting ×4 (old crowns: blob spheres, 760 tris) |
| SM_VEG_Shrub | 120 | R3 low garden shrub ×6, Low garden shrub ×40 |
| SM_VEG_FanPalm (folded fan blades, ringed trunk, dead-frond skirt) | 1,160 | Campus fan palm ×7 (old: flat fans, 1,190 tris) |
| SM_VEG_SmallPalm | 840 | Palm trunk ×4 + 56 separate Palm frond meshes |

Textures in `assets/vegetation_high/`:
- 1024 px leaf atlas (albedo + alpha, normal) with 2 olive clusters, a shrub cluster and a fan-palm blade.
- 512 px tileable bark and palm-trunk sets.
- All are VRAM-compressed with mipmaps. Godot's automatic mesh LODs are turned off for the kit, because they would break the leaf cards.

Crown cards use normals that point out from the crown centre, so each crown shades as a soft volume. A vertex-colour AO darkens the inner and lower leaves.

## Runtime (`scripts/vegetation_high.gd`, called from `campus_runtime.gd` when the preset is high)

- Each original plant is fitted by its world bounds: height, width clamped to ±25%, and a random yaw seeded by its position.
- The original is hidden and the replacement is drawn as one MultiMesh per template under `HighVegetation`.
- `HighVegetation` sits outside `CampusRenderBatches`, so the polish pass keeps the alpha-cut materials.
- Result: 99 plants replaced and 56 loose fronds hidden.

## QA

- **Blender lookdev:** `art_audit/work/05_vegetation/lookdev_vegetation_high.png`.
- **Capture harness:** High `passed=true failures=0`, and Medium `passed=true` with no `high_vegetation` in its stats (unchanged).
- **Plaza:** real branching trees and fan palms with proper silhouettes and dappled shadows.
- **Known limit:** the leaf edges stay aliased. Alpha-to-coverage is set on the materials, but the GL Compatibility renderer shows no visible effect.

## Cost

- **Draw calls:** the same or slightly fewer than Medium (plaza 1,269 vs 1,306), because 5 MultiMeshes replace about 150 meshes.
- **Triangles:** about 85k more across the campus.
- **GPU time:** the back-to-back runs on this machine were noisy (±30% between identical runs). With all High features on, the first High run was 26–41 FPS, in line with Medium at 19–52.
