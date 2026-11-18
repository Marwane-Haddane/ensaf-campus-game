# Phase 0 + Phase 1 — Setup status & Skill-to-Project Map

Date: 2026-11-18

## Phase 0 — readiness

| Item | Status |
| --- | --- |
| Blender skills pack (94 skills + `references/`) | Installed → `.claude/skills/`; agent rules → `CLAUDE.md` |
| `uv` / `uvx` | Installed (winget, v0.13.9). New shells need restart for PATH |
| Blender 4.3 | Running (`blender.exe`) |
| MCP for Blender addon | **NOT installed** — blocked by auto-mode permission guard; user runs it |
| `claude mcp add blender` | **NOT done** — user runs it, then restarts Claude Code so tools load |

## Tech stack

- **Engine:** Godot 4.3, **GL Compatibility** renderer (no SDFGI/SSR/volumetrics), 1280×720, MSAA 2x, occlusion culling on.
- **Bundled runtime:** `runtime/Godot.exe`; headless capture exe `C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe`.
- **Target:** Windows 64-bit PC, ~30 FPS envelope noted in `PROJECT.md` → performance is tight.
- **Exporter skill:** `godot-export` (glTF 2.0 / .glb, +Y up, metres; Blender (x,y,z) → Godot (x,z,-y)).
- **Campus source:** `../3D-modeling/campus-design-v9/ensaf-campus-v9-final.blend` → `assets/campus.glb`.
- **Runtime polish layer:** `scripts/antigravity/environment_polish.gd` (material overrides, lights). Many scripts build geometry at runtime (entrance, canopy, doors) — exports must keep node names stable.

## Art direction (detected)

| Axis | Skill | Why |
| --- | --- | --- |
| Style | `realistic-style` (lean, game-ready) | Photo-based real ENSA Fès campus, PBR intent, real dimensions |
| Mood — campus | `minimalist-style` + `brutalist-mood` touch | Cream render walls, glazed curtain wall, concrete plaza |
| Mood — After Hours | `apocalypse-worlds` + `dark-gritty-mood` | Zombie survival on same campus at night |
| Genre | `genre-survival`, `genre-shooter`, `genre-narrative-vn` (training) | FPS combat + scripted training |
| Export | `godot-export` | Godot 4.3 |

## Inventory (triangles from glTF accessors)

| Asset | Tris | Meshes | Mats | Textures | Note |
| --- | ---: | ---: | ---: | ---: | --- |
| `assets/campus.glb` | **1,146,868** unique (3.27M instanced) | 4,388 | 135 | **0** | Flat colours only; 5,965 nodes = draw-call heavy |
| `user_models/server_rack_1.glb` | 74,821 | 12 | 9 | 0 | Way over budget for a background prop |
| `user_models/gamer_setup_pack.glb` | 16,283 | 43 | 22 | 0 | Many small meshes/materials |
| `user_models/office_desk_140x60.glb` | 7,100 | 3 | 1 | 3 | OK |
| `user_models/office_chair.glb` | 5,029 | 1 | 1 | 3 | OK |
| `user_models/server_rack.glb` | 744 | 1 | 1 | 4 | OK |
| `user_models/supplied_bench.glb` / `supplied_bin.glb` | 3,132 / 2,206 | 12 / 3 | 2 | 0 | Untextured |
| `zombie/models/Characters_Shaun.gltf` | 27,713 | 11 | 1 | 1 | Stylized kit, 11 mesh parts |
| `zombie/models/hooded_warrior.glb` | 19,529 | 1 | 1 | 1 | |
| `zombie/models/winged_lion.glb` | 19,022 | 1 | 1 | 1 | |
| `zombie/models/pistol_hands.glb` | 12,793 | 3 | 3 | 4 | FP viewmodel |
| `zombie/models/benelli_m4.glb` | 8,728 | 2 | 2 | 7 | |
| `zombie/models/Zombie_Basic/Chubby.gltf` | 7,822 / 6,174 | 2–3 | 1 | 1 | Stylized low-poly kit |
| `zombie/props/*` (barrel, container, pickup…) | 240–6,432 | 1–4 | 1–3 | 1 | Fine |

Also: other campus versions v4–v9 in `3D-modeling/`, `ensa-teaching-interior-form.blend` → `assets/teaching_interior.scn`.

## Visual defects seen in existing captures

- Plaza: huge flat-tiled floor, no wear/decals/props; grass strips flat green; trees = blob spheres; palms = flat cards; empty horizon (no skyline/backdrop).
- Cream entrance: walls flat cream, no plaster/trim normal detail; interior grey boxes; signage text clipped above door.
- Curtain-wall building: good silhouette but no mullion depth/reflection variety.
- After Hours: purple brute + green zombies clash with realistic campus (style mismatch); daylight sky in "after hours".
- Tech: 1.15M unique tris, 135 untextured materials, 4,388 meshes → draw calls + memory the real bottleneck, not detail.

## Skill-to-Project map

| Game area / folder | Skills chain | Why |
| --- | --- | --- |
| `campus.glb` whole (source v9-final.blend) | `blender-director` → `asset-optimization` → `lod-pipeline` → `collision-proxy` → `godot-export` | First win = cut tris/draw calls (merge static by material, decimate instanced seats, LOD far buildings) |
| Plaza & ground | `environment-artist` → `materials` / `texture-workflow` → `set-dressing` | Tiling PBR paving + trim, decals, benches/bins/lamps rhythm |
| Trees & palms | `vegetation-artist` → `lowpoly-style` budget → `lod-pipeline` | Replace blob trees/flat palms with card-based palms + 2 LODs |
| Cream main entrance & façades | `archviz` → `hard-surface` (bevels, trims) → `uv-workflow` → `materials` | Plaster normal, stone trims, readable signage, deeper reveals |
| Glazed atrium / curtain wall | `archviz` → `materials` (glass) → `lighting` | Mullion depth, glass roughness, interior fake (cubemap/parallax) |
| Auditorium (81× seats) | `asset-optimization` → `lod-pipeline` | Seats 4.4k verts × 81 instances — biggest instanced cost |
| Reception / security interiors | `set-dressing` → `prop-artist` → `lighting` | Grey boxes → furnished rooms, baked-look lighting |
| `user_models/server_rack_1.glb` | `asset-optimization` → `retopology` → `texture-workflow` (bake) | 74.8k → ~3k tris + baked normal |
| `user_models/gamer_setup_pack.glb` | `asset-optimization` (merge meshes/materials, atlas) | 43 meshes/22 mats → 1–3 |
| bench / bin | `prop-artist` → `uv-workflow` → `texture-workflow` | Untextured |
| After Hours world | `apocalypse-worlds` → `dark-gritty-mood` → `set-dressing` → `lighting` (night) | Barricades, debris, burned cars, night lighting kit |
| Zombie characters | `character-artist` → `texture-workflow` (re-skin) → `rigging` keep | Match tone; keep rigs/anims to not break scripts |
| Weapons / viewmodel | `hard-surface` → `materials` | Already decent; low priority |
| All exports | `qa-review` → `references/validation-checklist.md` → `godot-export` | Keep node names, scale, axis; backups in `art_audit/backups/` |

## Next (Phase 2)

1. User finishes MCP setup (see chat).
2. Capture `art_audit/before/` via headless Godot harness (`tools/antigravity/preview_harness.gd`) + Blender viewport renders.
3. Ranked roadmap → user approval → Phase 3.
