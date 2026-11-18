# Phase 2 — Baseline & Prioritized Enhancement Roadmap

Date: 2026-11-18 · Engine: Godot 4.3 GL Compatibility · 1280×720 MSAA 2x

## Baseline captures (`art_audit/before/`)

| Set | Files | Source |
| --- | --- | --- |
| In-game, raw | `baseline_*.png` (9 views) | `tools/antigravity/preview_harness.gd --mode=all` |
| In-game, as shipped (polish on) | `polished_*.png` (9 views) | same run |
| Blender source overview | `blender/01..03_blend_*.png` + `blender/blend_audit.json` | `blender -b ensaf-campus-v9-final.blend` audit script (read-only, not saved) |
| After Hours | `after_hours/20..22_*.png` | existing stage captures |
| Raw numbers | `harness_report.json`, `harness.log` | |

## Performance baseline (as shipped, polish on)

| View | FPS | Draw calls | Triangles drawn |
| --- | ---: | ---: | ---: |
| Plaza | 12.6 | 1,306 | 1.87M |
| Reception | 7.5 | 1,503 | 3.22M |
| Auditorium rear | 11.7 | 1,082 | 3.18M |
| Glazed entrance | 14.5 | 1,260 | 1.83M |
| Security | 13.2 | 1,337 | 1.97M |
| Auditorium teaching | 24.2 | 1,252 | 2.32M |
| Cream front | 12.8 | 2,382 | 2.76M |
| Cream 45° | 12.3 | 1,654 | 1.79M |
| Cream inside-out | 34.5 | 328 | 0.22M |

**Verdict:** game runs 7–15 FPS in most places. Target ≥ 30 FPS needs ≤ ~600k triangles and ≤ ~400 draw calls per view. Performance is the biggest "visual" problem — fix geometry budget first, then add looks.

## Source audit (`ensaf-campus-v9-final.blend`)

- 6,011 mesh objects, 4,391 unique meshes, **7.0M triangles** counting instances; 137 materials, **0 textures**.
- 859 live Bevel + 858 Weighted Normal modifiers (tris explode on export).
- 1,329 objects with unapplied scale; naming not `SM_` (keep names — Godot scripts look nodes up by name).
- Hot spots:

| Mesh | Tris each | Copies | Total |
| --- | ---: | ---: | ---: |
| E9 sculpted auditorium chair (4 masters) | 23,276 | 198 | **4.61M** |
| E9 unified smooth stone roof & rounded frame | 1,639,652 | 1 | **1.64M** |
| R3 PV solar module | 492 | 453 | 223k |
| School signs (3D text) | 26–27k | 2 | 54k |
| B two-seat desk | 3,440 | 15 | 52k |
| Garden tree variants | ~760 | 33 | 25k |

## Visual critique (from captures)

- **Plaza:** endless flat tile, no wear/curbs/drains/decals; grass strips flat; trees are lumpy spheres; palms are flat fans; empty horizon.
- **Cream entrance:** flat cream plaster, no reveal/trim depth; interior grey boxes; sign text clipped above canopy.
- **Glazed atrium:** strong silhouette, but glass milky, all-white interior, floor/stairs untextured, chain-link fence reads as noise.
- **Auditorium:** best room; chairs fine visually but cost 4.6M tris; ceiling OK; walls plain.
- **Security:** imported props look good next to flat white architecture → style mismatch; rack 75k tris.
- **After Hours:** daylight sky for "after hours"; stylized cartoon characters + realistic campus clash; props (crate) are black boxes; no ruin/barricade set-dressing.

## Prioritized roadmap (impact ÷ effort)

| # | Target | Defects | Budget / target | Skills chain |
| ---: | --- | --- | --- | --- |
| 1 | **Auditorium chairs** (`E9 - Sunken tiered auditorium…`) | 23k-tri chair ×198 | Chair LOD0 ≤ 1,500 tris, LOD1 ≤ 400; one shared mesh, 1 material + 512² baked normal/colour atlas | `blender-director` → `asset-optimization` → `retopology` → `uv-workflow` → `texture-workflow` (bake) → `lod-pipeline` → `godot-export` |
| 2 | **E9 stone roof/frame** (1 object) | 1.64M tris for a smooth shell | ≤ 15k tris, bevelled edges via normals, plaster/stone material | `asset-optimization` → `retopology` → `hard-surface` → `uv-workflow` → `materials` |
| 3 | **Whole-campus draw-call pass** | 1,000–2,400 draws, 137 mats | Apply/limit bevel modifiers (1 segment), merge static by building+material, cut to ≤ 40 shared materials, LOD far buildings, roof PV → 1 merged textured mesh | `asset-optimization` → `lod-pipeline` → `collision-proxy` → `qa-review` → `godot-export` |
| 4 | **Material/texture kit** (plaster, stone, paving, terrazzo, wood, carpet, metal, glass) | flat colours everywhere | 8–10 tiling PBR sets, 1024² (albedo+normal+ORM), trim sheet for façades | `realistic-style` → `materials` → `texture-workflow` → `lookdev` |
| 5 | **Plaza + vegetation** | blob trees, flat palms, empty ground | Palm ≤ 2k tris (cards), tree ≤ 1.5k + LOD; curbs, drains, decals, benches/bins/lamps | `environment-artist` → `vegetation-artist` → `set-dressing` → `lod-pipeline` |
| 6 | **Cream entrance & glazed façade** | flat walls, clipped signage, milky glass | Reveal depth, stone trims, sign as texture decal (54k → <1k tris), glass roughness + interior fake | `archviz` → `hard-surface` → `materials` → `lighting` |
| 7 | **Props over budget** (`server_rack_1.glb`, `gamer_setup_pack.glb`) | 75k tris; 43 meshes/22 mats | Rack ≤ 3k + baked normal; PC pack ≤ 3 meshes / 2 mats | `asset-optimization` → `texture-workflow` |
| 8 | **After Hours mood** | daylight, no ruin dressing, black-box crates | Night sky/lighting rig, barricades, debris, burnt car, emergency lights; texture crates | `apocalypse-worlds` → `dark-gritty-mood` → `set-dressing` → `prop-artist` → `lighting` |

Characters/weapons: keep for now (rigs + 20 anims wired into scripts; risky, low gain).

## Rules for Phase 3

- Back up every touched file to `art_audit/backups/` first; original `.blend` stays untouched — work on a copy `ensaf-campus-v10.blend`.
- Keep Godot node names that scripts reference (doors, entrance, spawns, collisions).
- After each item: re-run harness → `art_audit/after/`, compare FPS/draws/tris, report.

## Tooling note

Blender MCP add-on is **not** installed yet (no add-on in Blender, no `claude mcp` entry, port 9876 closed). Phase 2 used Blender's own command line (`blender -b … --python`) — same `bpy` API, read-only. Phase 3 can run either way.
